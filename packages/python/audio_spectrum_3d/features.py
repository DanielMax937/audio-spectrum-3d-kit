from __future__ import annotations

import wave
from dataclasses import dataclass
from pathlib import Path

import numpy as np

DEFAULT_SAMPLE_RATE = 16_000
LABELS = ("normal", "crackle", "wheeze", "both")


@dataclass(frozen=True)
class SpectrogramConfig:
    sample_rate: int = DEFAULT_SAMPLE_RATE
    fft_size: int = 1024
    hop_size: int = 512
    min_freq: float = 80.0
    max_freq: float = 2000.0
    db_floor: float = -80.0
    db_ceiling: float = 0.0


@dataclass(frozen=True)
class MelConfig:
    sample_rate: int = DEFAULT_SAMPLE_RATE
    duration_seconds: float = 5.0
    fft_size: int = 2048
    image_size: int = 128
    channels: tuple[tuple[int, int], ...] = ((64, 256), (128, 256), (64, 512))


def load_wav_mono(path: str | Path, target_sample_rate: int = DEFAULT_SAMPLE_RATE) -> tuple[np.ndarray, int]:
    """Load a PCM WAV file and return mono float32 samples in [-1, 1]."""
    wav_path = Path(path)
    with wave.open(str(wav_path), "rb") as reader:
        channels = reader.getnchannels()
        sample_width = reader.getsampwidth()
        sample_rate = reader.getframerate()
        frames = reader.readframes(reader.getnframes())

    pcm = _decode_pcm(frames, sample_width)
    if channels > 1:
        pcm = pcm.reshape(-1, channels).mean(axis=1)
    if sample_rate != target_sample_rate:
        pcm = _resample_linear(pcm, sample_rate, target_sample_rate)
        sample_rate = target_sample_rate
    return pcm.astype(np.float32), sample_rate


def spectrogram(pcm: np.ndarray, config: SpectrogramConfig | None = None) -> dict[str, object]:
    """Compute a normalized STFT spectrogram compatible with the HarmonyOS 3D view."""
    cfg = config or SpectrogramConfig()
    samples = np.asarray(pcm, dtype=np.float32)
    if samples.size < cfg.fft_size:
        samples = np.pad(samples, (0, cfg.fft_size - samples.size))

    window = np.hamming(cfg.fft_size).astype(np.float32)
    freq_values = np.fft.rfftfreq(cfg.fft_size, d=1.0 / cfg.sample_rate)
    keep = np.where((freq_values >= cfg.min_freq) & (freq_values <= cfg.max_freq))[0]

    rows: list[np.ndarray] = []
    for start in range(0, samples.size - cfg.fft_size + 1, cfg.hop_size):
        frame = samples[start : start + cfg.fft_size] * window
        spectrum = np.fft.rfft(frame)
        mag = np.abs(spectrum[keep])
        db = 20.0 * np.log10(mag + 1e-10)
        norm = (db - cfg.db_floor) / (cfg.db_ceiling - cfg.db_floor)
        rows.append(np.clip(norm, 0.0, 1.0).astype(np.float32))

    matrix = np.stack(rows, axis=0) if rows else np.zeros((0, keep.size), dtype=np.float32)
    return {
        "timeBins": int(matrix.shape[0]),
        "freqBins": int(matrix.shape[1]),
        "matrix": matrix,
        "maxFreq": float(cfg.max_freq),
        "maxTime": float(samples.size / cfg.sample_rate),
    }


def mel_tensor(pcm: np.ndarray, config: MelConfig | None = None) -> np.ndarray:
    """Return a 3x128x128 log-mel tensor matching the v8 edge-model input format."""
    cfg = config or MelConfig()
    max_samples = int(cfg.duration_seconds * cfg.sample_rate)
    samples = np.asarray(pcm, dtype=np.float32)[:max_samples]
    if samples.size < cfg.fft_size:
        samples = np.pad(samples, (0, cfg.fft_size - samples.size))

    channel_arrays = []
    for n_mels, hop_length in cfg.channels:
        channel = _mel_channel(samples, n_mels, hop_length, cfg)
        channel_arrays.append(_minmax(_resize2d(channel, cfg.image_size, cfg.image_size)))
    return np.stack(channel_arrays, axis=0).astype(np.float32)


def _decode_pcm(frames: bytes, sample_width: int) -> np.ndarray:
    if sample_width == 1:
        raw = np.frombuffer(frames, dtype=np.uint8).astype(np.float32)
        return (raw - 128.0) / 128.0
    if sample_width == 2:
        return np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    if sample_width == 3:
        data = np.frombuffer(frames, dtype=np.uint8).reshape(-1, 3)
        vals = data[:, 0].astype(np.int32) | (data[:, 1].astype(np.int32) << 8) | (data[:, 2].astype(np.int32) << 16)
        vals = np.where(vals & 0x800000, vals - 0x1000000, vals)
        return vals.astype(np.float32) / 8388608.0
    if sample_width == 4:
        return np.frombuffer(frames, dtype="<i4").astype(np.float32) / 2147483648.0
    raise ValueError(f"Unsupported WAV sample width: {sample_width}")


def _resample_linear(pcm: np.ndarray, source_rate: int, target_rate: int) -> np.ndarray:
    if pcm.size == 0 or source_rate == target_rate:
        return pcm
    src_x = np.arange(pcm.size, dtype=np.float64)
    dst_len = max(1, int(round(pcm.size * target_rate / source_rate)))
    dst_x = np.linspace(0, pcm.size - 1, dst_len)
    return np.interp(dst_x, src_x, pcm).astype(np.float32)


def _mel_channel(samples: np.ndarray, n_mels: int, hop_length: int, cfg: MelConfig) -> np.ndarray:
    window = np.hanning(cfg.fft_size).astype(np.float32)
    filters = _mel_filterbank(n_mels, cfg.fft_size, cfg.sample_rate)
    rows: list[np.ndarray] = []
    for start in range(0, samples.size - cfg.fft_size + 1, hop_length):
        frame = samples[start : start + cfg.fft_size] * window
        power = (np.abs(np.fft.rfft(frame)) ** 2).astype(np.float64)
        with np.errstate(divide="ignore", over="ignore", invalid="ignore"):
            mel_power = filters.astype(np.float64) @ power
        mel_power = np.nan_to_num(mel_power, nan=1e-10, posinf=1e10, neginf=1e-10)
        mel_power = np.maximum(mel_power, 1e-10)
        rows.append(10.0 * np.log10(mel_power).astype(np.float32))
    if not rows:
        return np.zeros((1, n_mels), dtype=np.float32)
    return np.stack(rows, axis=0).astype(np.float32)


def _mel_filterbank(n_mels: int, n_fft: int, sample_rate: int) -> np.ndarray:
    f_max = sample_rate / 2
    mel_points = np.linspace(_hz_to_mel(0), _hz_to_mel(f_max), n_mels + 2)
    hz_points = _mel_to_hz(mel_points)
    bin_points = np.floor((n_fft + 1) * hz_points / sample_rate).astype(int)
    filters = np.zeros((n_mels, n_fft // 2 + 1), dtype=np.float32)
    for mel_idx in range(n_mels):
        left, center, right = bin_points[mel_idx : mel_idx + 3]
        if center > left:
            filters[mel_idx, left:center] = (np.arange(left, center) - left) / (center - left)
        if right > center:
            filters[mel_idx, center:right] = (right - np.arange(center, right)) / (right - center)
    return filters


def _hz_to_mel(hz: float | np.ndarray) -> float | np.ndarray:
    return 2595.0 * np.log10(1.0 + np.asarray(hz) / 700.0)


def _mel_to_hz(mel: float | np.ndarray) -> float | np.ndarray:
    return 700.0 * (np.power(10.0, np.asarray(mel) / 2595.0) - 1.0)


def _resize2d(src: np.ndarray, target_h: int, target_w: int) -> np.ndarray:
    src_h, src_w = src.shape
    if src_h == target_h and src_w == target_w:
        return src.astype(np.float32)
    y = np.linspace(0, src_h - 1, target_h)
    x = np.linspace(0, src_w - 1, target_w)
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    y1 = np.minimum(y0 + 1, src_h - 1)
    x1 = np.minimum(x0 + 1, src_w - 1)
    wy = (y - y0)[:, None]
    wx = (x - x0)[None, :]
    top = (1.0 - wx) * src[y0[:, None], x0[None, :]] + wx * src[y0[:, None], x1[None, :]]
    bottom = (1.0 - wx) * src[y1[:, None], x0[None, :]] + wx * src[y1[:, None], x1[None, :]]
    return ((1.0 - wy) * top + wy * bottom).astype(np.float32)


def _minmax(values: np.ndarray) -> np.ndarray:
    v_min = float(values.min())
    v_max = float(values.max())
    if v_max - v_min <= 1e-8:
        return np.zeros_like(values, dtype=np.float32)
    return ((values - v_min) / (v_max - v_min)).astype(np.float32)

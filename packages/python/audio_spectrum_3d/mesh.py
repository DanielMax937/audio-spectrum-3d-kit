from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass(frozen=True)
class MeshConfig:
    time_bins: int = 72
    freq_bins: int = 44
    plot_width: float = 7.6
    plot_depth: float = 5.0
    height_scale: float = 2.0


def build_spectrum_mesh(spectrogram_data: dict[str, object], config: MeshConfig | None = None) -> dict[str, object]:
    """Build a portable 3D height-map mesh from normalized spectrogram data."""
    cfg = config or MeshConfig()
    matrix = np.asarray(spectrogram_data["matrix"], dtype=np.float32)
    if matrix.ndim != 2 or matrix.size == 0:
        raise ValueError("spectrogram_data['matrix'] must be a non-empty 2D matrix")

    terrain = _terrain(matrix, cfg)
    g_t, g_f = terrain.shape
    x_scale = cfg.plot_width / max(1, g_t - 1)
    z_scale = cfg.plot_depth / max(1, g_f - 1)

    vertices = []
    normals = []
    colors = []
    for ti in range(g_t):
        for fi in range(g_f):
            x = ti * x_scale - cfg.plot_width / 2
            z = (g_f - 1 - fi) * z_scale - cfg.plot_depth / 2
            y = float(terrain[ti, fi] * cfg.height_scale)
            vertices.append([float(x), y, float(z)])
            normals.append(_normal(terrain, ti, fi, x_scale, z_scale, cfg.height_scale))
            colors.append(_color(float(terrain[ti, fi])))

    indices = []
    for ti in range(g_t - 1):
        for fi in range(g_f - 1):
            a = ti * g_f + fi
            b = (ti + 1) * g_f + fi
            c = ti * g_f + fi + 1
            d = (ti + 1) * g_f + fi + 1
            indices.extend([a, b, c, c, b, d])

    return {
        "vertices": vertices,
        "normals": normals,
        "colors": colors,
        "indices": indices,
        "stats": {
            "timeBins": int(g_t),
            "freqBins": int(g_f),
            "vertices": len(vertices),
            "triangles": len(indices) // 3,
        },
    }


def _terrain(matrix: np.ndarray, cfg: MeshConfig) -> np.ndarray:
    g_t = max(2, min(matrix.shape[0], cfg.time_bins))
    g_f = max(2, min(matrix.shape[1], cfg.freq_bins))
    energy = np.zeros((g_t, g_f), dtype=np.float32)
    samples = []

    for ti in range(g_t):
        t0 = int(np.floor(ti * matrix.shape[0] / g_t))
        t1 = max(t0 + 1, int(np.floor((ti + 1) * matrix.shape[0] / g_t)))
        for fi in range(g_f):
            f0 = int(np.floor(fi * matrix.shape[1] / g_f))
            f1 = max(f0 + 1, int(np.floor((fi + 1) * matrix.shape[1] / g_f)))
            block = matrix[t0:min(matrix.shape[0], t1), f0:min(matrix.shape[1], f1)]
            max_energy = float(block.max())
            rms = float(np.sqrt(np.mean(block * block)))
            cell = min(1.0, max_energy * 0.78 + rms * 0.22)
            energy[ti, fi] = cell
            samples.append(cell)

    sorted_samples = np.sort(np.asarray(samples, dtype=np.float32))
    floor_idx = min(sorted_samples.size - 1, int(sorted_samples.size * 0.18))
    ceil_idx = min(sorted_samples.size - 1, int(sorted_samples.size * 0.985))
    noise_floor = float(sorted_samples[floor_idx])
    peak = max(noise_floor + 0.0001, float(sorted_samples[ceil_idx]))
    normalized = np.clip((energy - noise_floor) / (peak - noise_floor), 0.0, 1.0)
    emphasized = np.power(normalized, 0.42)
    peak_lift = np.where(normalized > 0.72, (normalized - 0.72) * 0.55, 0.0)
    return np.minimum(1.35, emphasized + peak_lift).astype(np.float32)


def _normal(terrain: np.ndarray, ti: int, fi: int, x_scale: float, z_scale: float, height_scale: float) -> list[float]:
    left = terrain[max(0, ti - 1), fi] * height_scale
    right = terrain[min(terrain.shape[0] - 1, ti + 1), fi] * height_scale
    down = terrain[ti, max(0, fi - 1)] * height_scale
    up = terrain[ti, min(terrain.shape[1] - 1, fi + 1)] * height_scale
    vec = np.array([
        -(right - left) / max(0.001, x_scale * 2),
        1.0,
        -(up - down) / max(0.001, z_scale * 2),
    ], dtype=np.float32)
    vec /= np.linalg.norm(vec)
    return [float(vec[0]), float(vec[1]), float(vec[2])]


def _color(energy: float) -> list[float]:
    palette = np.asarray(
        [
            [0.05, 0.10, 0.18],
            [0.04, 0.23, 0.37],
            [0.03, 0.42, 0.49],
            [0.00, 0.58, 0.52],
            [0.40, 0.75, 0.38],
            [0.86, 0.76, 0.25],
            [0.96, 0.49, 0.18],
            [0.90, 0.18, 0.18],
        ],
        dtype=np.float32,
    )
    pos = np.clip((min(1.0, energy / 1.25) ** 0.68) * 1.12, 0.0, 1.0) * (len(palette) - 1)
    lo = int(np.floor(pos))
    hi = min(len(palette) - 1, lo + 1)
    frac = pos - lo
    rgb = (1.0 - frac) * palette[lo] + frac * palette[hi]
    return [float(rgb[0]), float(rgb[1]), float(rgb[2]), 1.0]

import { DEFAULT_SAMPLE_RATE } from './Constants';
import { MelTensor } from './MelTensor';
import { Spectrogram } from './Spectrogram';
import { AudioInputOptions, AudioSampleBuffer, AudioSampleFormat, SpectrogramData } from './Types';

export class AudioInput {
  static normalize(samples: AudioSampleBuffer, format: AudioSampleFormat): number[] {
    const pcm: number[] = [];
    for (let i = 0; i < samples.length; i++) {
      let normalized = 0;
      const value = samples[i];
      if (format === 'pcm16') {
        normalized = value / 32768.0;
      } else if (format === 'uint8') {
        normalized = (value - 128.0) / 128.0;
      } else {
        normalized = value;
      }
      pcm.push(AudioInput.clamp(normalized, -1, 1));
    }
    return pcm;
  }

  static spectrogram(samples: AudioSampleBuffer, options: AudioInputOptions): SpectrogramData {
    const pcm = AudioInput.normalize(samples, options.format);
    return Spectrogram.compute(pcm, options.sampleRate ?? DEFAULT_SAMPLE_RATE);
  }

  static async melTensor(samples: AudioSampleBuffer, options: AudioInputOptions): Promise<Float32Array> {
    const pcm = AudioInput.normalize(samples, options.format);
    return await MelTensor.compute(pcm, options.sampleRate ?? DEFAULT_SAMPLE_RATE);
  }

  private static clamp(value: number, min: number, max: number): number {
    return Math.max(min, Math.min(max, value));
  }
}

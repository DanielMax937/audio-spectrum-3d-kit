import { DEFAULT_SAMPLE_RATE, FFT_SIZE, HOP_SIZE, MAX_FREQ, MIN_FREQ } from './Constants';
import { SpectrogramData } from './Types';

export class Spectrogram {
  static compute(pcmData: number[], sampleRate: number = DEFAULT_SAMPLE_RATE): SpectrogramData {
    const windowSize = FFT_SIZE;
    const hopSize = HOP_SIZE;
    const nFreqBins = windowSize / 2;
    const nTimeBins = Math.max(1, Math.floor((pcmData.length - windowSize) / hopSize) + 1);
    const hamming = new Float64Array(windowSize);
    for (let i = 0; i < windowSize; i++) {
      hamming[i] = 0.54 - 0.46 * Math.cos(2 * Math.PI * i / (windowSize - 1));
    }

    const freqBinMap: number[] = [];
    for (let f = 0; f < nFreqBins; f++) {
      const freq = f * sampleRate / windowSize;
      if (freq >= MIN_FREQ && freq <= MAX_FREQ) {
        freqBinMap.push(f);
      }
    }

    const normalizedMatrix: number[][] = [];
    for (let t = 0; t < nTimeBins; t++) {
      const start = t * hopSize;
      const frame = new Float64Array(windowSize);
      for (let i = 0; i < windowSize; i++) {
        const idx = start + i;
        frame[i] = (idx < pcmData.length ? pcmData[idx] : 0) * hamming[i];
      }

      const fftResult = Spectrogram.fft(frame);
      const re = fftResult[0];
      const im = fftResult[1];
      const row: number[] = [];
      for (const bin of freqBinMap) {
        const mag = Math.sqrt(re[bin] * re[bin] + im[bin] * im[bin]);
        const db = 20 * Math.log10(mag + 1e-10);
        row.push(Math.max(0, Math.min(1, (db + 80) / 80)));
      }
      normalizedMatrix.push(row);
    }

    return {
      timeBins: normalizedMatrix.length,
      freqBins: freqBinMap.length,
      matrix: normalizedMatrix,
      maxFreq: MAX_FREQ,
      maxTime: pcmData.length / sampleRate
    };
  }

  private static fft(input: Float64Array): Float64Array[] {
    const n = input.length;
    const re = new Float64Array(n);
    const im = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      re[i] = input[i];
      im[i] = 0;
    }

    let j = 0;
    for (let i = 1; i < n; i++) {
      let bit = n >> 1;
      while (j & bit) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        const tr = re[i]; re[i] = re[j]; re[j] = tr;
        const ti = im[i]; im[i] = im[j]; im[j] = ti;
      }
    }

    for (let len = 2; len <= n; len <<= 1) {
      const half = len >> 1;
      const wRe = Math.cos(-2 * Math.PI / len);
      const wIm = Math.sin(-2 * Math.PI / len);
      for (let i = 0; i < n; i += len) {
        let curRe = 1;
        let curIm = 0;
        for (let k = 0; k < half; k++) {
          const idx1 = i + k;
          const idx2 = i + k + half;
          const tr = curRe * re[idx2] - curIm * im[idx2];
          const ti = curRe * im[idx2] + curIm * re[idx2];
          re[idx2] = re[idx1] - tr;
          im[idx2] = im[idx1] - ti;
          re[idx1] = re[idx1] + tr;
          im[idx1] = im[idx1] + ti;
          const nwRe = curRe * wRe - curIm * wIm;
          const nwIm = curRe * wIm + curIm * wRe;
          curRe = nwRe;
          curIm = nwIm;
        }
      }
    }

    const result: Float64Array[] = [];
    result.push(re);
    result.push(im);
    return result;
  }
}

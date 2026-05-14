import { DEFAULT_SAMPLE_RATE, MEL_FFT_SIZE, MEL_IMAGE_SIZE } from './Constants';

export class MelTensor {
  static async compute(pcmData: number[], sampleRate: number = DEFAULT_SAMPLE_RATE): Promise<Float32Array> {
    const n = Math.min(pcmData.length, 5 * sampleRate);
    const pcm = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      pcm[i] = pcmData[i] || 0;
    }

    const channels: Float64Array[][] = [];
    channels.push(await MelTensor.computeChannel(pcm, 64, 256, sampleRate));
    channels.push(await MelTensor.computeChannel(pcm, 128, 256, sampleRate));
    channels.push(await MelTensor.computeChannel(pcm, 64, 512, sampleRate));

    const result = new Float32Array(3 * MEL_IMAGE_SIZE * MEL_IMAGE_SIZE);
    for (let c = 0; c < 3; c++) {
      const ch = channels[c];
      let cMin = Infinity;
      let cMax = -Infinity;
      for (let y = 0; y < MEL_IMAGE_SIZE; y++) {
        for (let x = 0; x < MEL_IMAGE_SIZE; x++) {
          const v = ch[y][x];
          if (v < cMin) cMin = v;
          if (v > cMax) cMax = v;
        }
      }
      const range = cMax - cMin || 1;
      const offset = c * MEL_IMAGE_SIZE * MEL_IMAGE_SIZE;
      for (let y = 0; y < MEL_IMAGE_SIZE; y++) {
        for (let x = 0; x < MEL_IMAGE_SIZE; x++) {
          result[offset + y * MEL_IMAGE_SIZE + x] = (ch[y][x] - cMin) / range;
        }
      }
    }
    return result;
  }

  private static async computeChannel(pcm: Float64Array, nMel: number, hopLength: number,
    sampleRate: number): Promise<Float64Array[]> {
    const window = MelTensor.hannWindow(MEL_FFT_SIZE);
    const filters = MelTensor.melFilterbank(nMel, MEL_FFT_SIZE, sampleRate);
    const nFrames = Math.max(1, Math.floor((pcm.length - MEL_FFT_SIZE) / hopLength) + 1);
    const melSpec: Float64Array[] = [];

    for (let t = 0; t < nFrames; t++) {
      const start = t * hopLength;
      const frame = new Float64Array(MEL_FFT_SIZE);
      for (let i = 0; i < MEL_FFT_SIZE; i++) {
        const idx = start + i;
        frame[i] = (idx < pcm.length ? pcm[idx] : 0) * window[i];
      }
      const spec = MelTensor.fft(frame);
      const re = spec[0];
      const im = spec[1];
      const nBins = MEL_FFT_SIZE / 2 + 1;
      const melRow = new Float64Array(nMel);
      for (let m = 0; m < nMel; m++) {
        let sum = 0;
        for (let k = 0; k < nBins; k++) {
          const power = re[k] * re[k] + im[k] * im[k];
          sum += power * filters[m][k];
        }
        melRow[m] = Math.max(1e-10, sum);
      }
      melSpec.push(melRow);
      if (t % 8 === 0) {
        await new Promise<void>(resolve => setTimeout(resolve, 0));
      }
    }

    for (let t = 0; t < melSpec.length; t++) {
      for (let f = 0; f < nMel; f++) {
        melSpec[t][f] = 10 * Math.log10(melSpec[t][f]);
      }
    }
    return MelTensor.resize2D(melSpec, melSpec.length, nMel, MEL_IMAGE_SIZE, MEL_IMAGE_SIZE);
  }

  private static fft(real: Float64Array): Float64Array[] {
    const n = real.length;
    const re = new Float64Array(n);
    const im = new Float64Array(n);
    for (let i = 0; i < n; i++) {
      re[i] = real[i];
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

  private static hannWindow(size: number): Float64Array {
    const w = new Float64Array(size);
    for (let i = 0; i < size; i++) {
      w[i] = 0.5 * (1 - Math.cos(2 * Math.PI * i / (size - 1)));
    }
    return w;
  }

  private static melFilterbank(nMels: number, nFft: number, sampleRate: number): Float64Array[] {
    const fMax = sampleRate / 2;
    const melMax = MelTensor.hzToMel(fMax);
    const melPoints = new Float64Array(nMels + 2);
    for (let i = 0; i < nMels + 2; i++) {
      melPoints[i] = MelTensor.melToHz(melMax * i / (nMels + 1));
    }
    const binPoints = new Float64Array(nMels + 2);
    for (let i = 0; i < nMels + 2; i++) {
      binPoints[i] = Math.floor((nFft + 1) * melPoints[i] / sampleRate);
    }
    const filters: Float64Array[] = [];
    for (let m = 0; m < nMels; m++) {
      const f = new Float64Array(nFft / 2 + 1);
      const lo = binPoints[m];
      const ce = binPoints[m + 1];
      const hi = binPoints[m + 2];
      for (let k = 0; k < f.length; k++) {
        if (k > lo && k < ce) f[k] = (k - lo) / (ce - lo);
        else if (k >= ce && k < hi) f[k] = (hi - k) / (hi - ce);
      }
      filters.push(f);
    }
    return filters;
  }

  private static hzToMel(hz: number): number { return 2595 * Math.log10(1 + hz / 700); }
  private static melToHz(mel: number): number { return 700 * (Math.pow(10, mel / 2595) - 1); }

  private static resize2D(src: Float64Array[], srcH: number, srcW: number, tgtH: number,
    tgtW: number): Float64Array[] {
    const result: Float64Array[] = [];
    for (let y = 0; y < tgtH; y++) {
      const row = new Float64Array(tgtW);
      const sy = y * (srcH - 1) / Math.max(1, tgtH - 1);
      const syLo = Math.floor(sy);
      const syHi = Math.min(srcH - 1, syLo + 1);
      const fy = sy - syLo;
      for (let x = 0; x < tgtW; x++) {
        const sx = x * (srcW - 1) / Math.max(1, tgtW - 1);
        const sxLo = Math.floor(sx);
        const sxHi = Math.min(srcW - 1, sxLo + 1);
        const fx = sx - sxLo;
        row[x] = (1 - fy) * ((1 - fx) * src[syLo][sxLo] + fx * src[syLo][sxHi]) +
          fy * ((1 - fx) * src[syHi][sxLo] + fx * src[syHi][sxHi]);
      }
      result.push(row);
    }
    return result;
  }
}

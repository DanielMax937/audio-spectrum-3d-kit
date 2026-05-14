import { SPECTRUM_COLORS } from './Constants';
import { ColorRGBA, MeshConfig, SpectrogramData, SpectrumMesh, Vec3 } from './Types';

interface Terrain {
  height: number[][];
  timeBins: number;
  freqBins: number;
}

export class SpectrumMeshBuilder {
  static build(spectrogram: SpectrogramData, config?: MeshConfig): SpectrumMesh {
    const cfg: MeshConfig = config ?? {
      timeBins: 72,
      freqBins: 44,
      plotWidth: 7.6,
      plotDepth: 5.0,
      heightScale: 2.0
    };
    const terrain = SpectrumMeshBuilder.buildTerrain(spectrogram, cfg);
    const gT = terrain.timeBins;
    const gF = terrain.freqBins;
    const vertices: Vec3[] = [];
    const normals: Vec3[] = [];
    const colors: ColorRGBA[] = [];
    const indices: number[] = [];
    const xScale = cfg.plotWidth / Math.max(1, gT - 1);
    const zScale = cfg.plotDepth / Math.max(1, gF - 1);

    for (let ti = 0; ti < gT; ti++) {
      for (let fi = 0; fi < gF; fi++) {
        const x = ti * xScale - cfg.plotWidth / 2;
        const z = (gF - 1 - fi) * zScale - cfg.plotDepth / 2;
        const y = terrain.height[ti][fi] * cfg.heightScale;
        vertices.push({ x, y, z });
        normals.push(SpectrumMeshBuilder.normal(terrain, ti, fi, xScale, zScale, cfg.heightScale));
        colors.push(SpectrumMeshBuilder.energyColor(terrain.height[ti][fi]));
      }
    }

    for (let ti = 0; ti < gT - 1; ti++) {
      for (let fi = 0; fi < gF - 1; fi++) {
        const a = ti * gF + fi;
        const b = (ti + 1) * gF + fi;
        const c = ti * gF + fi + 1;
        const d = (ti + 1) * gF + fi + 1;
        indices.push(a, b, c);
        indices.push(c, b, d);
      }
    }

    return {
      vertices,
      normals,
      colors,
      indices,
      stats: {
        timeBins: gT,
        freqBins: gF,
        vertices: vertices.length,
        triangles: indices.length / 3
      }
    };
  }

  private static buildTerrain(spec: SpectrogramData, cfg: MeshConfig): Terrain {
    const gT = Math.max(2, Math.min(spec.timeBins, cfg.timeBins));
    const gF = Math.max(2, Math.min(spec.freqBins, cfg.freqBins));
    const energy: number[][] = [];
    const height: number[][] = [];
    const samples: number[] = [];

    for (let ti = 0; ti < gT; ti++) {
      const energyRow: number[] = [];
      const heightRow: number[] = [];
      const t0 = Math.floor(ti * spec.timeBins / gT);
      const t1 = Math.max(t0 + 1, Math.floor((ti + 1) * spec.timeBins / gT));
      for (let fi = 0; fi < gF; fi++) {
        const f0 = Math.floor(fi * spec.freqBins / gF);
        const f1 = Math.max(f0 + 1, Math.floor((fi + 1) * spec.freqBins / gF));
        let maxEnergy = 0;
        let squareTotal = 0;
        let sampleCount = 0;
        for (let st = t0; st < Math.min(spec.timeBins, t1); st++) {
          const row = spec.matrix[st];
          for (let sf = f0; sf < Math.min(spec.freqBins, f1); sf++) {
            const v = row[sf];
            if (v > maxEnergy) {
              maxEnergy = v;
            }
            squareTotal += v * v;
            sampleCount++;
          }
        }
        const rms = Math.sqrt(squareTotal / Math.max(1, sampleCount));
        const cellEnergy = Math.min(1, maxEnergy * 0.78 + rms * 0.22);
        energyRow.push(cellEnergy);
        heightRow.push(0);
        samples.push(cellEnergy);
      }
      energy.push(energyRow);
      height.push(heightRow);
    }

    samples.sort((a: number, b: number) => a - b);
    const floorIdx = Math.min(samples.length - 1, Math.floor(samples.length * 0.18));
    const ceilingIdx = Math.min(samples.length - 1, Math.floor(samples.length * 0.985));
    const noiseFloor = samples[floorIdx];
    const peakLevel = Math.max(noiseFloor + 0.0001, samples[ceilingIdx]);
    for (let ti = 0; ti < gT; ti++) {
      for (let fi = 0; fi < gF; fi++) {
        const normalized = SpectrumMeshBuilder.clamp01((energy[ti][fi] - noiseFloor) / (peakLevel - noiseFloor));
        const emphasized = Math.pow(normalized, 0.42);
        const peakLift = normalized > 0.72 ? (normalized - 0.72) * 0.55 : 0;
        height[ti][fi] = Math.min(1.35, emphasized + peakLift);
      }
    }
    return { height, timeBins: gT, freqBins: gF };
  }

  private static normal(terrain: Terrain, ti: number, fi: number, xScale: number,
    zScale: number, heightScale: number): Vec3 {
    const left = terrain.height[Math.max(0, ti - 1)][fi] * heightScale;
    const right = terrain.height[Math.min(terrain.timeBins - 1, ti + 1)][fi] * heightScale;
    const down = terrain.height[ti][Math.max(0, fi - 1)] * heightScale;
    const up = terrain.height[ti][Math.min(terrain.freqBins - 1, fi + 1)] * heightScale;
    const nx = -(right - left) / Math.max(0.001, xScale * 2);
    const ny = 1;
    const nz = -(up - down) / Math.max(0.001, zScale * 2);
    const len = Math.sqrt(nx * nx + ny * ny + nz * nz);
    return { x: nx / len, y: ny / len, z: nz / len };
  }

  private static energyColor(energy: number): ColorRGBA {
    const colorEnergy = SpectrumMeshBuilder.clamp01(Math.pow(Math.min(1, energy / 1.25), 0.68) * 1.12);
    const idx = Math.min(SPECTRUM_COLORS.length - 1,
      Math.max(0, Math.floor(colorEnergy * (SPECTRUM_COLORS.length - 1))));
    return SpectrumMeshBuilder.hexToColor(SPECTRUM_COLORS[idx], 1);
  }

  private static clamp01(value: number): number {
    return Math.max(0, Math.min(1, value));
  }

  private static hexToColor(hex: string, alpha: number): ColorRGBA {
    const normalized = hex.replace('#', '');
    const r = parseInt(normalized.substring(0, 2), 16) / 255;
    const g = parseInt(normalized.substring(2, 4), 16) / 255;
    const b = parseInt(normalized.substring(4, 6), 16) / 255;
    return { r, g, b, a: alpha };
  }
}

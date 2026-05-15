export interface SpectrogramData {
  timeBins: number;
  freqBins: number;
  matrix: number[][];
  maxFreq: number;
  maxTime: number;
  errorMsg?: string;
}

export interface Vec3 {
  x: number;
  y: number;
  z: number;
}

export interface ColorRGBA {
  r: number;
  g: number;
  b: number;
  a: number;
}

export interface SpectrumMesh {
  vertices: Vec3[];
  normals: Vec3[];
  colors: ColorRGBA[];
  indices: number[];
  stats: MeshStats;
}

export interface MeshStats {
  timeBins: number;
  freqBins: number;
  vertices: number;
  triangles: number;
}

export interface MeshConfig {
  timeBins: number;
  freqBins: number;
  plotWidth: number;
  plotDepth: number;
  heightScale: number;
}

export type AudioSampleFormat = 'float32' | 'pcm16' | 'uint8';

export type AudioSampleBuffer = number[] | Int16Array | Uint8Array | Float32Array;

export interface AudioInputOptions {
  sampleRate?: number;
  format: AudioSampleFormat;
}

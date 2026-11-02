// Turns a source audio file into the .m4a the app plays
// (docs/backend-design.md §8, step 2).
//
// - Lossless masters (WAV, AIFF, FLAC) are loudness-normalised with ffmpeg's
//   two-pass loudnorm and encoded to AAC-LC: voice to -16 LUFS mono 64 kbps,
//   ambient sounds to -23 LUFS stereo 96 kbps.
// - .m4a files are already AAC and pass through byte for byte.
// - .aac (raw ADTS) is copied into an MP4 container without re-encoding.
// - MP3 is lossy too, but can't be served as audio/mp4 as it is, so it is
//   encoded like a master, with a warning to supply a lossless one.
//
// Results are cached in tools/content/.cache, keyed by the source's sha256
// plus the settings, so a publish only runs ffmpeg for new or changed files.
//
// TODO: seamless loops. Looping sounds should get a crossfaded join
// (§8: "loops get a crossfaded seamless join, checked by ear the first
// time"). Not done yet; loops are encoded like any other ambient sound.
import { execFile } from 'node:child_process';
import { createHash } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs';
import { extname, join } from 'node:path';
import { promisify } from 'node:util';

const run = promisify(execFile);

/// Bump to invalidate every cached transcode (e.g. after changing the
/// ffmpeg arguments in a way the settings don't capture).
export const pipelineVersion = 1;

export type Role = 'voice' | 'ambient';

export type Settings = {
  role: Role;
  /// Integrated loudness target, LUFS.
  I: number;
  /// True-peak ceiling, dBTP.
  TP: number;
  /// Loudness range target. Kept wide for ambient so loudnorm stays linear
  /// (a plain gain change) instead of compressing the sound.
  LRA: number;
  channels: 1 | 2;
  bitrateK: number;
  sampleRate: number;
};

export const voice: Settings = {
  role: 'voice',
  I: -16,
  TP: -1.5,
  LRA: 11,
  channels: 1,
  bitrateK: 64,
  sampleRate: 44100,
};

export const ambient: Settings = {
  role: 'ambient',
  I: -23,
  TP: -1.5,
  LRA: 20,
  channels: 2,
  bitrateK: 96,
  sampleRate: 44100,
};

export const settingsFor = (role: Role): Settings => (role === 'voice' ? voice : ambient);

export type Treatment =
  | { mode: 'passthrough' }
  | { mode: 'remux' }
  | { mode: 'transcode'; settings: Settings; lossySource: boolean };

const lossless = new Set(['.wav', '.wave', '.aif', '.aiff', '.flac']);

/// What to do with a source file, from its extension and role.
export function treatmentFor(path: string, role: Role): Treatment {
  const ext = extname(path).toLowerCase();
  if (ext === '.m4a') return { mode: 'passthrough' };
  if (ext === '.aac') return { mode: 'remux' };
  if (lossless.has(ext)) return { mode: 'transcode', settings: settingsFor(role), lossySource: false };
  if (ext === '.mp3') return { mode: 'transcode', settings: settingsFor(role), lossySource: true };
  throw new Error(`${path}: unsupported audio type "${ext}" (use WAV, AIFF, FLAC, MP3 or M4A)`);
}

const loudnormTarget = (s: Settings) => `I=${s.I}:TP=${s.TP}:LRA=${s.LRA}`;

/// First loudnorm pass: measure only, the numbers come back as JSON on
/// stderr.
export function measureArgs(src: string, s: Settings): string[] {
  return [
    '-hide_banner', '-nostdin', '-nostats',
    '-i', src,
    '-vn',
    '-af', `loudnorm=${loudnormTarget(s)}:print_format=json`,
    '-f', 'null', '-',
  ];
}

export type Loudness = {
  input_i: string;
  input_tp: string;
  input_lra: string;
  input_thresh: string;
  target_offset: string;
};

/// The JSON block loudnorm prints at the end of the first pass.
export function parseLoudnorm(stderr: string): Loudness {
  const start = stderr.lastIndexOf('{');
  const end = stderr.lastIndexOf('}');
  if (start < 0 || end < start) throw new Error('loudnorm printed no measurements');
  const j = JSON.parse(stderr.slice(start, end + 1));
  for (const k of ['input_i', 'input_tp', 'input_lra', 'input_thresh', 'target_offset']) {
    if (typeof j[k] !== 'string' || !Number.isFinite(Number(j[k]))) {
      throw new Error(`loudnorm measurement ${k} is ${JSON.stringify(j[k])}; is the file silent?`);
    }
  }
  return j;
}

/// Second pass: apply the measured correction and encode AAC-LC. The
/// bitexact flags and stripped metadata keep the output stable across runs,
/// which matters because the file is named by its hash.
export function encodeArgs(src: string, out: string, s: Settings, m: Loudness): string[] {
  const loudnorm =
    `loudnorm=${loudnormTarget(s)}` +
    `:measured_I=${m.input_i}:measured_TP=${m.input_tp}:measured_LRA=${m.input_lra}` +
    `:measured_thresh=${m.input_thresh}:offset=${m.target_offset}` +
    ':linear=true:print_format=summary';
  return [
    '-hide_banner', '-nostdin', '-nostats', '-y',
    '-i', src,
    '-vn', '-map_metadata', '-1',
    '-af', loudnorm,
    // loudnorm resamples to 192 kHz internally; bring it back down.
    '-ar', String(s.sampleRate),
    '-ac', String(s.channels),
    '-c:a', 'aac', '-profile:a', 'aac_low', '-b:a', `${s.bitrateK}k`,
    '-movflags', '+faststart',
    '-fflags', '+bitexact', '-flags:a', '+bitexact',
    '-f', 'mp4', out,
  ];
}

/// Raw AAC into an MP4 container, audio copied as is.
export function remuxArgs(src: string, out: string): string[] {
  return [
    '-hide_banner', '-nostdin', '-nostats', '-y',
    '-i', src,
    '-vn', '-map_metadata', '-1',
    '-c:a', 'copy',
    '-movflags', '+faststart',
    '-fflags', '+bitexact',
    '-f', 'mp4', out,
  ];
}

export const sha256 = (b: Uint8Array) => createHash('sha256').update(b).digest('hex');

/// Cache key: the source bytes plus everything that shapes the output.
export function cacheKey(sourceSha: string, t: Treatment): string {
  return sha256(
    new TextEncoder().encode(JSON.stringify({ pipelineVersion, sourceSha, treatment: t })),
  );
}

export type Prepared = { bytes: Uint8Array; note: string };

export type PrepareOptions = {
  cacheDir: string;
  ffmpeg?: string;
  warn?: (msg: string) => void;
};

/// The .m4a to publish for a source file.
export async function prepareFile(
  src: string,
  role: Role,
  { cacheDir, ffmpeg = 'ffmpeg', warn = console.warn }: PrepareOptions,
): Promise<Prepared> {
  const t = treatmentFor(src, role);
  const source = new Uint8Array(readFileSync(src));
  if (t.mode === 'passthrough') return { bytes: source, note: 'as is' };

  const cached = join(cacheDir, `${cacheKey(sha256(source), t)}.m4a`);
  const label = t.mode === 'remux' ? 'remuxed' : `${t.settings.role} ${t.settings.I} LUFS`;
  if (existsSync(cached)) return { bytes: new Uint8Array(readFileSync(cached)), note: `${label}, cached` };

  if (t.mode === 'transcode' && t.lossySource) {
    warn(`${src}: MP3 is lossy, so it is re-encoded. Supply a WAV, AIFF or FLAC master if you can.`);
  }
  mkdirSync(cacheDir, { recursive: true });
  const tmp = `${cached}.${process.pid}.tmp`;
  const opts = { maxBuffer: 64 * 1024 * 1024 };
  if (t.mode === 'remux') {
    await run(ffmpeg, remuxArgs(src, tmp), opts);
  } else {
    const { stderr } = await run(ffmpeg, measureArgs(src, t.settings), opts);
    await run(ffmpeg, encodeArgs(src, tmp, t.settings, parseLoudnorm(stderr)), opts);
  }
  renameSync(tmp, cached);
  return { bytes: new Uint8Array(readFileSync(cached)), note: label };
}

/// For tests: write `seconds` of a sine tone as a 16-bit WAV.
export function writeSineWav(path: string, seconds = 1, hz = 440, rate = 8000) {
  const n = Math.round(seconds * rate);
  const buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write('WAVEfmt ', 8);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20); // PCM
  buf.writeUInt16LE(1, 22); // mono
  buf.writeUInt32LE(rate, 24);
  buf.writeUInt32LE(rate * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    buf.writeInt16LE(Math.round(Math.sin((2 * Math.PI * hz * i) / rate) * 0.3 * 32767), 44 + i * 2);
  }
  writeFileSync(path, buf);
}

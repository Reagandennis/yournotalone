import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import {
  ambient,
  cacheKey,
  encodeArgs,
  measureArgs,
  parseLoudnorm,
  prepareFile,
  remuxArgs,
  treatmentFor,
  voice,
  writeSineWav,
} from './transcode.ts';

const measured = {
  input_i: '-27.61',
  input_tp: '-4.47',
  input_lra: '18.06',
  input_thresh: '-39.20',
  target_offset: '0.58',
};

/// The value after a flag in an ffmpeg argument list.
const arg = (args: string[], flag: string) => args[args.indexOf(flag) + 1];

test('narration is voice, sounds are ambient, and m4a passes through', () => {
  assert.deepEqual(treatmentFor('masters/body_scan.wav', 'voice'), {
    mode: 'transcode',
    settings: voice,
    lossySource: false,
  });
  assert.deepEqual(treatmentFor('masters/rain.AIFF', 'ambient'), {
    mode: 'transcode',
    settings: ambient,
    lossySource: false,
  });
  assert.equal(treatmentFor('masters/rain.aif', 'ambient').mode, 'transcode');
  assert.equal(treatmentFor('masters/rain.flac', 'ambient').mode, 'transcode');
  assert.deepEqual(treatmentFor('assets/sounds/rainfall.m4a', 'ambient'), { mode: 'passthrough' });
  assert.deepEqual(treatmentFor('assets/sounds/rainfall.m4a', 'voice'), { mode: 'passthrough' });
  assert.deepEqual(treatmentFor('x/raw.aac', 'voice'), { mode: 'remux' });
  const mp3 = treatmentFor('x/old.mp3', 'voice');
  assert.equal(mp3.mode === 'transcode' && mp3.lossySource, true);
  assert.throws(() => treatmentFor('x/clip.ogg', 'voice'), /unsupported audio type ".ogg"/);
});

test('voice: -16 LUFS, mono, 64 kbps AAC-LC', () => {
  const a = encodeArgs('in.wav', 'out.m4a', voice, measured);
  assert.equal(arg(a, '-ac'), '1');
  assert.equal(arg(a, '-b:a'), '64k');
  assert.equal(arg(a, '-c:a'), 'aac');
  assert.equal(arg(a, '-profile:a'), 'aac_low');
  assert.equal(arg(a, '-f'), 'mp4');
  assert.equal(a.at(-1), 'out.m4a');
  const af = arg(a, '-af');
  assert.match(af, /^loudnorm=I=-16:TP=-1.5:LRA=11:/);
  assert.match(af, /measured_I=-27.61:measured_TP=-4.47:measured_LRA=18.06:measured_thresh=-39.20:offset=0.58/);
  assert.match(af, /linear=true/);
});

test('ambient: -23 LUFS, stereo, 96 kbps AAC-LC', () => {
  const a = encodeArgs('in.flac', 'out.m4a', ambient, measured);
  assert.equal(arg(a, '-ac'), '2');
  assert.equal(arg(a, '-b:a'), '96k');
  assert.match(arg(a, '-af'), /^loudnorm=I=-23:TP=-1.5:/);
});

test('the first pass only measures', () => {
  const a = measureArgs('in.wav', voice);
  assert.equal(arg(a, '-af'), 'loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json');
  assert.deepEqual(a.slice(-3), ['-f', 'null', '-']);
  assert.equal(remuxArgs('in.aac', 'o.m4a').includes('copy'), true);
});

test('reads loudnorm measurements from ffmpeg output', () => {
  const stderr = `[Parsed_loudnorm_0 @ 0x1] \n{\n\t"input_i" : "-27.61",\n\t"input_tp" : "-4.47",\n\t"input_lra" : "18.06",\n\t"input_thresh" : "-39.20",\n\t"output_i" : "-16.0",\n\t"target_offset" : "0.58"\n}\n`;
  assert.equal(parseLoudnorm(stderr).input_i, '-27.61');
  assert.throws(() => parseLoudnorm('no json here'), /no measurements/);
  assert.throws(() => parseLoudnorm('{"input_i":"-inf","input_tp":"-inf","input_lra":"0","input_thresh":"-70","target_offset":"0"}'), /silent/);
});

test('the cache key changes with the source and with the settings', () => {
  const t = treatmentFor('a.wav', 'voice');
  assert.equal(cacheKey('abc', t), cacheKey('abc', t));
  assert.notEqual(cacheKey('abc', t), cacheKey('abd', t));
  assert.notEqual(cacheKey('abc', t), cacheKey('abc', treatmentFor('a.wav', 'ambient')));
});

test('passthrough returns the file unchanged without ffmpeg', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'content-pass-'));
  try {
    const f = join(dir, 'x.m4a');
    writeFileSync(f, 'not really audio');
    const r = await prepareFile(f, 'ambient', { cacheDir: join(dir, 'cache'), ffmpeg: '/nonexistent' });
    assert.equal(new TextDecoder().decode(r.bytes), 'not really audio');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

let haveFfmpeg = true;
try {
  execFileSync('ffmpeg', ['-version'], { stdio: 'ignore' });
} catch {
  haveFfmpeg = false;
}

test('smoke: ffmpeg encodes a sine WAV to AAC in MP4, and caches it', { skip: !haveFfmpeg && 'no ffmpeg' }, async () => {
  const dir = mkdtempSync(join(tmpdir(), 'content-ffmpeg-'));
  try {
    const src = join(dir, 'tone.wav');
    const cacheDir = join(dir, 'cache');
    writeSineWav(src, 1);
    const first = await prepareFile(src, 'voice', { cacheDir });
    assert.equal(new TextDecoder().decode(first.bytes.subarray(4, 8)), 'ftyp');
    assert.equal(readdirSync(cacheDir).length, 1);
    const again = await prepareFile(src, 'voice', { cacheDir, ffmpeg: '/nonexistent' });
    assert.match(again.note, /cached/);
    assert.deepEqual(again.bytes, first.bytes);
    const cached = join(cacheDir, readdirSync(cacheDir)[0]);
    const probe = execFileSync('ffprobe', [
      '-v', 'error', '-show_entries', 'stream=codec_name,profile,channels', '-of', 'json', cached,
    ]).toString();
    const s = JSON.parse(probe).streams[0];
    assert.equal(s.codec_name, 'aac');
    assert.equal(s.profile, 'LC');
    assert.equal(s.channels, 1);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

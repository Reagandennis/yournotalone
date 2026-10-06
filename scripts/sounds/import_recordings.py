#!/usr/bin/env python3
"""Replaces generated loops in assets/sounds/ with recordings from Sounds/.

Each recording is made to behave like the generated loops it replaces
(see generate_sounds.py):

*Seamless looping.* The tail of the clip is crossfaded (equal power) into
its head, so the end flows straight into the start with no click or gap.

*Consistent loudness.* Normalised to the same RMS as the rest of the
library, with the same peak ceiling, so switching sounds never changes how
loud the app is.

Long recordings are cut to MAX_SECONDS to keep the app download small.
Only the sounds listed in RECORDINGS are replaced; the rest stay generated.

Usage:  python3 scripts/sounds/import_recordings.py [asset_name ...]
Requires numpy, ffmpeg, and macOS `afconvert` for AAC encoding.
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'Sounds'
OUT = ROOT / 'assets' / 'sounds'

SR = 44100
MAX_SECONDS = 180
CROSSFADE_SECONDS = 3.0
# Same as generate_sounds.py.
TARGET_RMS_DBFS = -21.0
PEAK_CEILING = 0.63
BITRATE = 112000

# asset name (in assets/sounds, without .m4a) -> recording in Sounds/
RECORDINGS = {
    'crickets_night': '129342__le_abbaye_noirlac__cricket-fly.aiff',
    'ocean_waves': '156598__rmutt__oceanwaves-10.wav',
    'brown_noise': 'brown noise.wav',
    'deep_focus': 'deep_focus.mp3',
    'distant_storm': 'distant storm.wav',
    'fireside': 'fireside.wav',
    'rainfall': 'rainfaill.wav',
    'mountain_stream': 'stream.wav',
    'white_noise': 'white noise.wav',
}


def decode(path: Path) -> np.ndarray:
    """The recording as float32 stereo at SR, shape (n, 2)."""
    raw = subprocess.run(
        ['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le',
         '-ac', '2', '-ar', str(SR), '-'],
        check=True, capture_output=True,
    ).stdout
    return np.frombuffer(raw, dtype='<f4').reshape(-1, 2).astype(np.float64)


def make_loop(x: np.ndarray) -> np.ndarray:
    x = x[: MAX_SECONDS * SR]
    cf = int(min(CROSSFADE_SECONDS * SR, len(x) * 0.2))
    t = np.linspace(0, np.pi / 2, cf)[:, None]
    head = x[:cf] * np.sin(t) + x[-cf:] * np.cos(t)
    return np.concatenate([head, x[cf:-cf]])


def limit(x: np.ndarray) -> np.ndarray:
    """Holds peaks under PEAK_CEILING with ffmpeg's look-ahead limiter,
    so a crackle or a thunderclap doesn't drag the whole clip down."""
    out = subprocess.run(
        ['ffmpeg', '-v', 'error', '-f', 'f32le', '-ac', '2', '-ar', str(SR),
         '-i', '-', '-af',
         f'alimiter=limit={PEAK_CEILING}:attack=5:release=80:level=false',
         '-f', 'f32le', '-'],
        input=x.astype('<f4').tobytes(), check=True, capture_output=True,
    ).stdout
    y = np.frombuffer(out, dtype='<f4').reshape(-1, 2).astype(np.float64)
    return y[: len(x)]


def rms_dbfs(x: np.ndarray) -> float:
    return 20 * np.log10(np.sqrt(np.mean(x ** 2)))


def level(x: np.ndarray) -> np.ndarray:
    x = x - x.mean(axis=0)
    target = TARGET_RMS_DBFS
    for _ in range(3):
        # Aim a little high each pass: limiting takes some level back off.
        y = limit(x * 10 ** ((target - rms_dbfs(x)) / 20))
        short = TARGET_RMS_DBFS - rms_dbfs(y)
        if short < 0.3:
            break
        target += short
    # The limiter keeps ~1 dB of overshoot on the very sharpest peaks.
    return y * min(1.0, PEAK_CEILING / np.abs(y).max())


def encode(x: np.ndarray, dest: Path) -> None:
    pcm = (np.clip(x, -1, 1) * 32767).astype('<i2')
    with tempfile.TemporaryDirectory() as tmp:
        wav = Path(tmp) / 'loop.wav'
        with wave.open(str(wav), 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(
            ['afconvert', '-f', 'm4af', '-d', 'aac', '-b', str(BITRATE),
             str(wav), str(dest)],
            check=True,
        )


def main(names: list[str]) -> None:
    for name in names or RECORDINGS:
        src = SRC / RECORDINGS[name]
        loop = level(make_loop(decode(src)))
        dest = OUT / f'{name}.m4a'
        encode(loop, dest)
        rms = rms_dbfs(loop)
        print(f'{name:16} {len(loop) / SR:6.1f}s  rms {rms:5.1f} dBFS  '
              f'peak {np.abs(loop).max():.2f}  '
              f'{dest.stat().st_size / 1e6:4.1f} MB  <- {src.name}')


if __name__ == '__main__':
    main(sys.argv[1:])

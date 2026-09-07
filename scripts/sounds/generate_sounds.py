#!/usr/bin/env python3
"""Generates the wellbeing sound loops in assets/sounds/.

Everything here is synthesised from scratch, so the loops carry no
licence or attribution obligations and can ship in the app as-is.

Two properties matter more than anything else for a sound you leave
running while you fall asleep:

*Seamless looping.* Every layer is periodic over the loop length —
noise beds are built in the frequency domain (an inverse FFT is
circular, so its end already flows into its start), modulators use
whole numbers of cycles, and one-shot events (crackles, thunder,
heartbeats) wrap around the end of the buffer. There is no crossfade
and no discontinuity, so the loop point is inaudible.

*Consistent loudness.* Everything is normalised to the same RMS, so
switching sounds never changes how loud the app is.

Usage:  python3 scripts/sounds/generate_sounds.py [name ...]
Requires numpy, and macOS `afconvert` for AAC encoding.
"""

from __future__ import annotations

import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

SR = 44100
OUT = Path(__file__).resolve().parents[2] / 'assets' / 'sounds'

# Matches the loudest of the original loops, so the whole library sits at
# one level and the volume slider means the same thing everywhere.
TARGET_RMS_DBFS = -21.0
# -4 dBFS. AAC overshoots on dense transient material by a couple of dB,
# and this is what keeps crackles and thunder from clipping on playback.
PEAK_CEILING = 0.63

rng = np.random.default_rng(20260907)


# ---------------------------------------------------------------- helpers

def frames(seconds: float) -> int:
    """Loop length in samples, rounded to a whole number of seconds."""
    return int(round(seconds)) * SR


def circular_noise(n: int, shape) -> np.ndarray:
    """Noise with the magnitude spectrum `shape(freq)`, periodic over n.

    Built by shaping a random spectrum and inverse-transforming, so the
    result is mathematically periodic: sample n-1 leads into sample 0.
    """
    bins = n // 2 + 1
    spec = rng.normal(size=bins) + 1j * rng.normal(size=bins)
    freq = np.fft.rfftfreq(n, 1 / SR)
    spec *= shape(freq)
    spec[0] = 0.0  # no DC
    return np.fft.irfft(spec, n)


def slope(freq: np.ndarray, exponent: float) -> np.ndarray:
    """1/f**exponent tilt (0.5 = pink, 1.0 = brown), safe at DC."""
    return 1.0 / np.maximum(freq, 1.0) ** exponent


def highpass(freq: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return 1.0 / np.sqrt(1.0 + (cutoff / np.maximum(freq, 1e-6)) ** (2 * order))


def lowpass(freq: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return 1.0 / np.sqrt(1.0 + (np.maximum(freq, 1e-6) / cutoff) ** (2 * order))


def band(freq, lo, hi, lo_order=2, hi_order=2):
    return highpass(freq, lo, lo_order) * lowpass(freq, hi, hi_order)


def lfo(n: int, cycles: int, phase: float = 0.0) -> np.ndarray:
    """Sine over a whole number of cycles, so it loops exactly."""
    t = np.arange(n) / n
    return np.sin(2 * np.pi * (cycles * t + phase))


def loopable(hz: float, n: int) -> float:
    """Nearest frequency that completes whole cycles in n samples."""
    per_loop = hz * n / SR
    return max(1.0, round(per_loop)) * SR / n


def place(buf: np.ndarray, start: int, sig: np.ndarray) -> None:
    """Adds `sig` at `start`, wrapping past the end into the beginning.

    The last few milliseconds are faded out first: a decaying grain that
    simply stops leaves a step in the waveform, and a few hundred of
    those per loop is exactly the faint tick you hear in cheap loops.
    """
    n = len(buf)
    start %= n
    tail = min(len(sig) // 4, int(0.012 * SR))
    if tail > 1:
        sig = sig.copy()
        sig[-tail:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, tail))
    end = start + len(sig)
    if end <= n:
        buf[start:end] += sig
    else:
        cut = n - start
        buf[start:] += sig[:cut]
        buf[:end - n] += sig[cut:]


def at_rms(sig: np.ndarray, dbfs: float) -> np.ndarray:
    """Scales a layer to a known average level, so mixes are readable."""
    return sig * (10 ** (dbfs / 20)) / np.sqrt((sig ** 2).mean())


def at_peak(sig: np.ndarray, dbfs: float) -> np.ndarray:
    """Same, by peak — the right unit for sparse layers like thunder."""
    return sig * (10 ** (dbfs / 20)) / np.abs(sig).max()


def stereo(mid: np.ndarray, side_l: np.ndarray, side_r: np.ndarray,
           width: float = 0.6) -> np.ndarray:
    """A shared centre plus independent sides — wide but still solid."""
    keep = np.sqrt(1.0 - width ** 2)
    return np.stack([keep * mid + width * side_l,
                     keep * mid + width * side_r], axis=1)


def finalise(sig: np.ndarray) -> np.ndarray:
    """Level-match, then tame peaks with a soft knee (no hard clipping).

    Softening the peaks costs a little RMS, so the two steps run a few
    times until the level settles — otherwise the crackly sounds land
    several dB quieter than the smooth ones.
    """
    sig = sig - sig.mean(axis=0, keepdims=True)
    target = 10 ** (TARGET_RMS_DBFS / 20)
    knee = 0.42
    head = PEAK_CEILING - knee
    for _ in range(6):
        sig *= target / np.sqrt((sig ** 2).mean())
        over = np.abs(sig) > knee
        if not over.any():
            break
        sig[over] = np.sign(sig[over]) * (
            knee + head * np.tanh((np.abs(sig[over]) - knee) / head))
    peak = np.abs(sig).max()
    if peak > PEAK_CEILING:
        sig *= PEAK_CEILING / peak
    return sig


def write_wav(path: Path, sig: np.ndarray) -> None:
    pcm = (np.clip(sig, -1.0, 1.0) * 32767).astype('<i2').tobytes()
    hdr = b'RIFF' + struct.pack('<I', 36 + len(pcm)) + b'WAVEfmt '
    hdr += struct.pack('<IHHIIHH', 16, 1, 2, SR, SR * 4, 4, 16)
    hdr += b'data' + struct.pack('<I', len(pcm))
    path.write_bytes(hdr + pcm)


def encode(name: str, sig: np.ndarray) -> None:
    wav = OUT / f'{name}.wav'
    m4a = OUT / f'{name}.m4a'
    write_wav(wav, sig)
    subprocess.run(
        ['afconvert', '-f', 'm4af', '-d', 'aac', '-b', '128000',
         '-q', '127', '-s', '2', str(wav), str(m4a)],
        check=True, capture_output=True)
    wav.unlink()
    rms = 20 * np.log10(np.sqrt((sig ** 2).mean()))
    print(f'{name:18s} {len(sig)/SR:5.0f}s  rms {rms:5.1f} dBFS  '
          f'peak {20*np.log10(np.abs(sig).max()):5.1f} dBFS  '
          f'seam {seam_ratio(sig):4.2f}x  {m4a.stat().st_size/1024:5.0f} KB')


def seam_ratio(sig: np.ndarray) -> float:
    """How the loop point compares with an ordinary sample step.

    The jump from the last sample back to the first, over the typical
    step inside the loop. Around 1 means the seam is indistinguishable
    from anywhere else in the file; a click would read as tens or
    hundreds.
    """
    steps = np.diff(sig, axis=0)
    typical = np.sqrt((steps ** 2).mean())
    return float(np.abs(sig[0] - sig[-1]).max() / typical)


# ----------------------------------------------------------------- sounds

def pink_noise():
    """Steady 1/f hiss — the noise colour sleep studies tend to use."""
    n = frames(60)
    shape = lambda f: slope(f, 0.5) * highpass(f, 22, 3) * lowpass(f, 11000, 1)
    mid, l, r = (circular_noise(n, shape) for _ in range(3))
    return stereo(mid, l, r, width=0.55)


def brown_noise():
    """Deep 1/f^2 rumble — heavier than white, easy to work through."""
    n = frames(60)
    shape = lambda f: slope(f, 1.0) * highpass(f, 32, 3) * lowpass(f, 5200, 1)
    mid, l, r = (circular_noise(n, shape) for _ in range(3))
    return stereo(mid, l, r, width=0.45)


def fireside():
    """A low roar with crackles and the occasional pop."""
    n = frames(75)
    bed_shape = lambda f: slope(f, 0.9) * band(f, 70, 900, 2, 1)
    bed = circular_noise(n, bed_shape)
    bed *= 1.0 + 0.34 * lfo(n, 7) + 0.22 * lfo(n, 11, 0.3) \
        + 0.14 * lfo(n, 19, 0.7)
    bed = at_rms(bed, -20)

    left = np.zeros(n)
    right = np.zeros(n)
    crackle_shape = lambda f: band(f, 1100, 7500, 2, 1)
    palette = [circular_noise(SR // 4, crackle_shape) for _ in range(24)]
    for _ in range(75 * 7):  # roughly seven crackles a second
        src = palette[rng.integers(len(palette))]
        length = int(rng.uniform(0.006, 0.045) * SR)
        start = rng.integers(0, len(src) - length)
        env = np.exp(-np.linspace(0, rng.uniform(4, 9), length))
        amp = rng.uniform(0.02, 1.0) ** 2.6  # many small, few loud
        grain = src[start:start + length] * env * amp
        pan = rng.uniform(0.15, 0.85)
        at = int(rng.integers(0, n))
        place(left, at, grain * (1 - pan))
        place(right, at, grain * pan)

    for _ in range(14):  # deeper pops, further into the fire
        length = int(rng.uniform(0.05, 0.12) * SR)
        t = np.arange(length) / SR
        thump = np.sin(2 * np.pi * rng.uniform(70, 140) * t) \
            * np.exp(-t * rng.uniform(25, 45))
        snap = circular_noise(length, lambda f: band(f, 400, 3000)) \
            * np.exp(-t * 60)
        pop = at_peak(thump * 1.4 + snap, rng.uniform(-14, -6))
        pan = rng.uniform(0.3, 0.7)
        at = int(rng.integers(0, n))
        place(left, at, pop * (1 - pan))
        place(right, at, pop * pan)

    crackles = at_rms(np.stack([left, right], axis=1), -25)
    return bed[:, None] * np.array([1.0, 0.97]) + crackles


def mountain_stream():
    """Water over rocks: a bright bed with burbles moving through it."""
    n = frames(75)
    bed_shape = lambda f: slope(f, 0.45) * band(f, 500, 11000, 2, 1)
    bed = circular_noise(n, bed_shape)
    bed *= 1.0 + 0.16 * lfo(n, 5) + 0.11 * lfo(n, 13, 0.4)
    bed = at_rms(bed, -20)

    left = np.zeros(n)
    right = np.zeros(n)
    for _ in range(75 * 11):  # burbles: short resonant water notes
        length = int(rng.uniform(0.03, 0.16) * SR)
        t = np.arange(length) / SR
        f0 = rng.uniform(280, 1600)
        env = np.exp(-t * rng.uniform(18, 55))
        tone = np.sin(2 * np.pi * f0 * t + rng.uniform(0, 6.3))
        # a little frequency drift is what makes it read as water
        tone += 0.5 * np.sin(2 * np.pi * f0 * 1.7 * t * (1 + 0.4 * t))
        grain = tone * env * rng.uniform(0.02, 1.0) ** 2.2
        pan = rng.uniform(0.1, 0.9)
        at = int(rng.integers(0, n))
        place(left, at, grain * (1 - pan))
        place(right, at, grain * pan)

    burbles = at_rms(np.stack([left, right], axis=1), -26)
    return bed[:, None] * np.array([1.0, 0.96]) + burbles


def distant_storm():
    """Steady rain with thunder rolling somewhere far off."""
    n = frames(90)
    rain_shape = lambda f: slope(f, 0.75) * band(f, 220, 7000, 2, 2)
    mid, l, r = (circular_noise(n, rain_shape) for _ in range(3))
    rain = stereo(mid, l, r, width=0.5)
    rain *= (1.0 + 0.12 * lfo(n, 3) + 0.08 * lfo(n, 7, 0.2))[:, None]
    rain = at_rms(rain, -20)

    drops = np.zeros((n, 2))
    drop_shape = lambda f: band(f, 1800, 9000)
    palette = [circular_noise(SR // 8, drop_shape) for _ in range(16)]
    for _ in range(90 * 60):  # individual drops, quiet and constant
        src = palette[rng.integers(len(palette))]
        length = int(rng.uniform(0.002, 0.010) * SR)
        start = rng.integers(0, len(src) - length)
        env = np.exp(-np.linspace(0, 6, length))
        grain = src[start:start + length] * env * rng.uniform(0.01, 1.0) ** 3
        pan = rng.uniform(0, 1)
        at = int(rng.integers(0, n))
        place(drops[:, 0], at, grain * (1 - pan))
        place(drops[:, 1], at, grain * pan)

    thunder = np.zeros((n, 2))
    for _ in range(4):  # slow swell, long tail, never sharp
        length = int(rng.uniform(4.5, 7.5) * SR)
        t = np.arange(length) / SR
        rumble = circular_noise(
            length, lambda f: slope(f, 1.1) * band(f, 28, 190, 3, 1))
        swell = np.minimum(t / rng.uniform(0.7, 1.6), 1.0)
        boom = at_peak(rumble * swell * np.exp(-t / rng.uniform(1.6, 3.0)),
                       rng.uniform(-7, -3))
        pan = rng.uniform(0.35, 0.65)
        at = int(rng.integers(0, n))
        place(thunder[:, 0], at, boom * (1 - pan))
        place(thunder[:, 1], at, boom * pan)

    return rain + at_rms(drops, -30) + thunder


def singing_bowl():
    """A struck bowl every twenty seconds over a low, beating shimmer."""
    n = frames(60)
    # Bowl partials are inharmonic; these ratios are typical of a real one.
    ratios = [1.0, 2.72, 5.41, 8.94, 13.3]
    gains = [1.0, 0.42, 0.20, 0.10, 0.05]
    f0 = 138.0

    left = np.zeros(n)
    right = np.zeros(n)
    strike_len = int(24 * SR)
    t = np.arange(strike_len) / SR
    strike = np.zeros(strike_len)
    for ratio, gain in zip(ratios, gains):
        f = loopable(f0 * ratio, n)
        beat = 0.35 + 0.25 * ratio  # each partial beats at its own rate
        decay = np.exp(-t / (11.0 / (1 + 0.7 * (ratio - 1))))
        wobble = 1.0 + 0.5 * np.cos(2 * np.pi * beat * t)
        strike += gain * decay * wobble * np.sin(2 * np.pi * f * t)
    strike *= 1 - np.exp(-t * 260)  # a soft mallet, not a hammer
    strike /= np.abs(strike).max()

    for i in range(3):  # three strikes, twenty seconds apart
        at = i * (n // 3)
        pan = 0.5 + 0.06 * (i - 1)
        place(left, at, strike * (1 - pan))
        place(right, at, strike * pan)

    # Air around the bowl rather than a hum under it, so the strike and
    # its long tail stay the thing you actually hear.
    shimmer_shape = lambda f: slope(f, 0.5) * band(f, 400, 5000, 2, 1)
    shimmer = circular_noise(n, shimmer_shape)
    shimmer *= 1.0 + 0.3 * lfo(n, 2)
    strikes = at_peak(np.stack([left, right], axis=1), -6)
    return strikes + at_rms(shimmer, -34)[:, None] * np.array([1.0, 0.97])


def resting_heartbeat():
    """Sixty beats a minute — the pace a calm body settles toward."""
    n = frames(60)
    beat = np.zeros(n)

    def thump(freq, seconds, decay):
        length = int(seconds * SR)
        t = np.arange(length) / SR
        body = np.sin(2 * np.pi * freq * t) * np.exp(-t * decay)
        knock = circular_noise(length, lambda f: lowpass(f, 220, 2)) \
            * np.exp(-t * decay * 2.2)
        return (body + knock * 0.35) * (1 - np.exp(-t * 110))

    lub = thump(52, 0.30, 13)
    dub = thump(62, 0.22, 17) * 0.62
    for i in range(60):
        at = i * SR
        # a hair of variation so it never feels like a metronome
        swing = 1.0 + 0.06 * np.sin(2 * np.pi * i / 12)
        place(beat, at, lub * swing)
        place(beat, at + int(0.30 * SR), dub * swing)

    warmth = circular_noise(n, lambda f: slope(f, 1.0) * band(f, 40, 700, 2, 1))
    warmth *= 1.0 + 0.2 * lfo(n, 4)
    body = beat + warmth * 0.22
    return np.stack([body, body], axis=1) * np.array([1.0, 0.98])


def breathe_with_me():
    """Six breaths a minute: four seconds in, six out, hands-free."""
    n = frames(60)
    cycles = 6
    cycle = n // cycles
    t = np.arange(cycle) / SR
    inhale, exhale = 4.0, 6.0

    env = np.where(
        t < inhale,
        0.5 - 0.5 * np.cos(np.pi * t / inhale),               # rise
        0.5 + 0.5 * np.cos(np.pi * (t - inhale) / exhale))    # fall
    env = np.tile(env, cycles)

    # The pad brightens as you breathe in and darkens as you let go.
    bright = circular_noise(n, lambda f: slope(f, 0.5) * band(f, 500, 7000, 2, 1))
    dark = circular_noise(n, lambda f: slope(f, 0.9) * band(f, 90, 900, 2, 1))
    pad = bright * env + dark * (1.0 - 0.45 * env)

    drone = np.zeros(n)
    tt = np.arange(n) / SR
    for freq, gain in [(98.0, 1.0), (147.0, 0.45), (196.0, 0.22)]:
        drone += gain * np.sin(2 * np.pi * loopable(freq, n) * tt)
    drone *= 0.06 * (0.75 + 0.25 * env)

    bell_len = int(2.4 * SR)
    bt = np.arange(bell_len) / SR
    bell = np.zeros(bell_len)
    for freq, gain in [(784.0, 1.0), (1176.0, 0.3), (1568.0, 0.12)]:
        bell += gain * np.sin(2 * np.pi * freq * bt) * np.exp(-bt * 3.4)
    bell *= (1 - np.exp(-bt * 300)) * 0.10
    for i in range(cycles):  # one soft cue at the top of each inhale
        place(pad, i * cycle, bell)

    mix = pad * 0.9 + drone
    wide = circular_noise(n, lambda f: band(f, 400, 6000)) * env * 0.25
    return np.stack([mix + wide * 0.5, mix - wide * 0.5], axis=1)


SOUNDS = {
    'pink_noise': pink_noise,
    'brown_noise': brown_noise,
    'fireside': fireside,
    'mountain_stream': mountain_stream,
    'distant_storm': distant_storm,
    'singing_bowl': singing_bowl,
    'resting_heartbeat': resting_heartbeat,
    'breathe_with_me': breathe_with_me,
}


def main(argv: list[str]) -> int:
    wanted = argv or list(SOUNDS)
    unknown = [name for name in wanted if name not in SOUNDS]
    if unknown:
        print(f'unknown sound(s): {", ".join(unknown)}', file=sys.stderr)
        print(f'available: {", ".join(SOUNDS)}', file=sys.stderr)
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    for name in wanted:
        encode(name, finalise(SOUNDS[name]()))
    return 0


if __name__ == '__main__':
    raise SystemExit(main(sys.argv[1:]))

"""Procedural, seamlessly looping ambient sounds (no recordings, no licensing).

Noise is shaped in the frequency domain over the full loop length, so the
inverse FFT is periodic and the loop point is inaudible.
"""
import os
import sys
import wave

import numpy as np

OUT = sys.argv[1]
SR = 22050
SECONDS = 12
N = SR * SECONDS
rng = np.random.default_rng(7)


def shaped_noise(exponent, low_cut=20.0, high_cut=None):
    freqs = np.fft.rfftfreq(N, 1 / SR)
    amp = np.zeros_like(freqs)
    band = freqs >= low_cut
    if high_cut:
        band &= freqs <= high_cut
    amp[band] = 1.0 / np.power(freqs[band], exponent / 2)
    phase = rng.uniform(0, 2 * np.pi, len(freqs))
    spectrum = amp * np.exp(1j * phase)
    sig = np.fft.irfft(spectrum, n=N)
    return sig / np.max(np.abs(sig))


def lowpass(sig, cutoff):
    spec = np.fft.rfft(sig)
    freqs = np.fft.rfftfreq(N, 1 / SR)
    spec *= 1 / np.sqrt(1 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spec, n=N)


def save(name, sig, level=0.5):
    sig = sig / np.max(np.abs(sig)) * level
    data = (sig * 32767).astype('<i2')
    path = os.path.join(OUT, f'{name}.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(name, os.path.getsize(path) // 1024, 'KB')


os.makedirs(OUT, exist_ok=True)

save('white', lowpass(shaped_noise(0), 9000), 0.35)
save('pink', shaped_noise(1), 0.5)
save('brown', shaped_noise(2, low_cut=30), 0.6)

# Rain: soft pink bed plus many tiny droplets placed on the circular timeline.
rain = 0.6 * lowpass(shaped_noise(1, low_cut=200), 7000)
t = np.arange(int(SR * 0.03))
for _ in range(1400):
    start = rng.integers(0, N)
    drop = rng.normal(0, 1, len(t)) * np.exp(-t / (SR * rng.uniform(0.002, 0.008)))
    drop *= rng.uniform(0.05, 0.4)
    idx = (start + t) % N
    rain[idx] += drop
save('rain', lowpass(rain, 8000), 0.5)

# Ocean: brown noise swelling in waves; the period divides the loop length.
waves = shaped_noise(2, low_cut=40)
phase = 2 * np.pi * np.arange(N) / N * 2  # two waves per loop
swell = 0.25 + 0.75 * (0.5 - 0.5 * np.cos(phase)) ** 2
save('ocean', lowpass(waves * swell, 2500), 0.6)

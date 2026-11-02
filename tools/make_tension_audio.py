"""Create original, non-verbal game sounds; no downloaded recordings required."""
import array
import math
import random
import wave
from pathlib import Path

RATE = 22050
DEST = Path(__file__).resolve().parents[1] / 'flutter_app' / 'assets' / 'audio'


def save(name, samples):
    peak = max(abs(s) for s in samples) or 1
    pcm = array.array('h', (int(s / peak * 25000) for s in samples))
    with wave.open(str(DEST / name), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())


def howl():
    rng = random.Random(483)
    phase = 0.0
    low_noise = 0.0
    data = []
    length = 2.65
    for n in range(int(RATE * length)):
        t = n / RATE
        progress = t / length
        freq = 125 + 185 * math.sin(math.pi * progress) - 42 * progress
        freq += 8 * math.sin(2 * math.pi * 5.5 * t)
        phase += 2 * math.pi * freq / RATE
        low_noise += .16 * (rng.uniform(-1, 1) - low_noise)
        throat = math.sin(phase) + .48 * math.sin(2 * phase + .3) + .18 * math.sin(3 * phase)
        rasp = low_noise * (1 + .5 * math.sin(2 * math.pi * 21 * t))
        envelope = math.sin(math.pi * progress) ** 1.4
        tremolo = .88 + .12 * math.sin(2 * math.pi * 3.6 * t)
        data.append(envelope * tremolo * (throat * .65 + rasp * .65))
    # Short echoes stay in the same finite asset, so pause stops the whole cue.
    original = data[:]
    for delay, gain in [(.13, .2), (.27, .1)]:
        offset = int(delay * RATE)
        for n in range(offset, len(data)):
            data[n] += original[n - offset] * gain
    return data


def heartbeat():
    data = []
    for n in range(int(RATE * .95)):
        t = n / RATE
        value = 0.0
        for start, gain in [(.08, 1), (.26, .65)]:
            u = t - start
            if u >= 0:
                value += gain * math.sin(2 * math.pi * 64 * u) * math.exp(-u * 26) * min(1, u * 350)
        data.append(value)
    return data


if __name__ == '__main__':
    save('creature_howl.wav', howl())
    save('heartbeat.wav', heartbeat())
    print('Created creature_howl.wav and heartbeat.wav')

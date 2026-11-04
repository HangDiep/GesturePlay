"""Original finite spell cues, generated locally without recordings."""
import math
import random
from make_tension_audio import RATE, save


def cue(kind, seconds):
    rng = random.Random(194 + kind)
    data = []
    phase = 0
    noise = 0
    for n in range(round(seconds * RATE)):
        t = n / RATE
        p = t / seconds
        noise += .2 * (rng.uniform(-1, 1) - noise)
        if kind == 0:
            phase += 2 * math.pi * (110 + 390 * p * p) / RATE
            value = (.5 * math.sin(phase) + .22 * math.sin(phase * 1.498) + noise * .7)
            envelope = math.sin(math.pi * p) ** .6
        elif kind == 1:
            phase += 2 * math.pi * (420 * (1 - p) + 75) / RATE
            value = .4 * math.sin(phase) + noise * 2
            envelope = math.exp(-p * 4) * min(1, p * 70)
        else:
            phase += 2 * math.pi * (90 + 120 * (1 - p)) / RATE
            value = math.sin(phase) * .6 + noise * 2.4
            envelope = math.exp(-p * 6) * min(1, p * 120)
        data.append(value * envelope * min(1, (1-p)*80))
    return data


if __name__ == '__main__':
    for kind, name, length in [(0, 'magic_charge.wav', .8), (1, 'magic_cast.wav', .35), (2, 'magic_hit.wav', .28)]:
        save(name, cue(kind, length))
        print(name)

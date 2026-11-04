"""Keep hand roles independent of result order; reject ambiguous crossings."""

import math


class HandRoles:
    def __init__(self):
        self.previous = {}
        self.timestamp = -1000

    @staticmethod
    def distance(a, b):
        return math.hypot(a[0] - b[0], a[1] - b[1])

    def assign(self, candidates, timestamp):
        if timestamp <= self.timestamp:
            return {}
        recent = 0 <= timestamp - self.timestamp <= 500
        result = {}
        if recent and len(self.previous) == 2 and len(candidates) == 2:
            a, b = candidates
            left, right = self.previous['left'], self.previous['right']
            straight = self.distance(left, a[1]) + self.distance(right, b[1])
            reverse = self.distance(left, b[1]) + self.distance(right, a[1])
            if abs(straight - reverse) < .04:
                return {}  # Hands overlap: pause instead of swapping controls.
            a, b = (a, b) if straight < reverse else (b, a)
            if max(self.distance(left, a[1]), self.distance(right, b[1])) > .25:
                return {}
            result = {'left': a, 'right': b}
        else:
            for c in candidates:
                side = c[0]
                if side not in ('left', 'right') or side in result:
                    return {}
                if recent and side in self.previous and self.distance(self.previous[side], c[1]) > .25:
                    continue
                result[side] = c
        if result:
            self.previous = {side: c[1] for side, c in result.items()}
            self.timestamp = timestamp
        return result

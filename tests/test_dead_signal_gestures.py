"""Fist recognition must not turn a closed hand into a click/jump."""
import unittest
from types import SimpleNamespace
from config import AppConfig
from core.hand_tracker import is_fist
from core.shared_state import HandResult
from core.gestures import GestureController


class DeadSignalGestures(unittest.TestCase):
    def test_folded_fingers_are_rotation_independent(self):
        points = [SimpleNamespace(x=.5, y=.9) for _ in range(21)]
        for tip, pip in ((8, 6), (12, 10), (16, 14), (20, 18)):
            points[pip] = SimpleNamespace(x=.5, y=.5)
            points[tip] = SimpleNamespace(x=.5, y=.7)
        self.assertTrue(is_fist(points))
        rotated = [SimpleNamespace(x=1-p.y, y=p.x) for p in points]
        self.assertTrue(is_fist(rotated, 1))
        points[8] = SimpleNamespace(x=.5, y=.2)
        self.assertFalse(is_fist(points))

    def test_fist_requires_stability_and_never_fires_pinch_command(self):
        c = GestureController(AppConfig())
        def feed(ms, fist=False, ratio=.7):
            ns = ms * 1_000_000
            return c.update(HandResult(ms, ms, ns, ns, .5, .5, ratio, fist=fist), ns)
        feed(1000)
        self.assertFalse(feed(1050, True, .1).fist)
        self.assertFalse(feed(1100, True, .1).jump_pressed)
        self.assertTrue(feed(1200, True, .1).fist)
        self.assertTrue(feed(1250).fist)
        self.assertFalse(feed(1350).fist)
        self.assertTrue(feed(1400, False, .1).jump_pressed)
        self.assertFalse(c.update(None, 1_450_000_000).fist)


if __name__ == '__main__':
    unittest.main()

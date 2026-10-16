"""Cử chỉ theo cạnh, hysteresis, mất tín hiệu và giữ ổn định trước khi chơi."""

import math
from types import SimpleNamespace
import unittest

from config import AppConfig
from core.hand_tracker import HandTracker, pinch_ratio
from core.shared_state import CameraFrame, HandResult, SharedState
from client.core.gesture_controller import GestureController
from client.games.runner import RunnerGame


def sample(timestamp, ratio=.7, has_hand=True):
    now = timestamp * 1_000_000
    return HandResult(timestamp, timestamp, now, now + 5_000_000,
                      .5 if has_hand else None, .5 if has_hand else None, ratio)


class GestureTests(unittest.TestCase):
    def setUp(self):
        self.controller = GestureController(AppConfig())

    def update(self, timestamp, ratio=.7):
        return self.controller.update(sample(timestamp, ratio), timestamp * 1_000_000)

    def test_pinch_must_be_released_before_first_jump(self):
        self.assertFalse(self.update(1000, .1).jump_pressed)
        self.assertFalse(self.update(1050, .1).jump_pressed)
        self.update(1100, .7)
        self.assertTrue(self.update(1150, .1).jump_pressed)
        self.assertFalse(self.update(1200, .1).jump_pressed)

    def test_hysteresis_avoids_repeated_events_from_noise(self):
        self.update(1000, .7)
        self.assertTrue(self.update(1050, .2).jump_pressed)
        for timestamp, ratio in ((1100, .29), (1150, .4), (1200, .27)):
            self.assertFalse(self.update(timestamp, ratio).jump_pressed)
        self.update(1250, .6)
        self.assertTrue(self.update(1300, .2).jump_pressed)

    def test_same_callback_is_never_reused_as_a_jump(self):
        self.update(1000)
        result = sample(1050, .1)
        self.assertTrue(self.controller.update(result, 1_050_000_000).jump_pressed)
        for now in (1_060_000_000, 1_070_000_000):
            self.assertFalse(self.controller.update(result, now).jump_pressed)

    def test_lost_hand_requires_release_and_reacquisition_stability(self):
        self.update(1000)
        self.controller.update(sample(1050, has_hand=False), 1_050_000_000)
        self.assertFalse(self.update(1100, .1).jump_pressed)
        self.assertFalse(self.update(1150, .7).ready)
        for timestamp in range(1200, 1751, 50):
            latest = self.update(timestamp)
        self.assertTrue(latest.ready)

    def test_old_image_and_invalid_geometry_disable_input(self):
        self.assertFalse(self.controller.update(sample(1000), 1_251_000_000).valid)
        self.assertFalse(self.update(1100, math.nan).valid)
        self.assertFalse(self.update(1150, -1).valid)

    def test_pinch_measurement_is_relative_to_palm_size(self):
        points = [SimpleNamespace(x=.5, y=.5) for _ in range(21)]
        points[5] = SimpleNamespace(x=.3, y=.5)
        points[17] = SimpleNamespace(x=.7, y=.5)
        points[4] = SimpleNamespace(x=.48, y=.5)
        points[8] = SimpleNamespace(x=.52, y=.5)
        first = pinch_ratio(points)
        larger = [SimpleNamespace(x=p.x * 2, y=p.y * 2) for p in points]
        self.assertAlmostEqual(first, pinch_ratio(larger))
        self.assertAlmostEqual(first, .1)

    def test_callback_publishes_pinch_measurement_to_shared_state(self):
        state = SharedState()
        tracker = HandTracker(AppConfig(), state)
        points = [SimpleNamespace(x=.5, y=.5) for _ in range(21)]
        points[5] = SimpleNamespace(x=.3, y=.5)
        points[17] = SimpleNamespace(x=.7, y=.5)
        points[4] = SimpleNamespace(x=.48, y=.5)
        points[8] = SimpleNamespace(x=.52, y=.5)
        timestamp = tracker._remember(CameraFrame(1, 1_000_000_000, None))
        tracker._on_result(SimpleNamespace(hand_landmarks=[points]), None, timestamp)
        self.assertAlmostEqual(state.snapshot().hand.pinch_ratio, .1)
        self.assertEqual(state.snapshot().hand.pinch_points, ((.48, .5), (.52, .5)))

    def feed(self, start, end, ratio):
        for timestamp in range(start, end + 1, 50):
            result = self.update(timestamp, ratio)
        return result

    def test_calibration_recognizes_pinch_above_old_threshold_and_jumps(self):
        self.feed(1000, 1500, 1.2)
        self.assertFalse(self.update(1550, .55).jump_pressed)
        self.feed(1600, 2100, 1.2)
        self.assertTrue(self.controller.calibrate_open(2_100_000_000))
        self.feed(2150, 2700, .55)
        self.assertTrue(self.controller.calibrate_closed(2_700_000_000))
        self.assertGreater(self.controller.press_threshold, .55)
        self.assertLess(self.controller.press_threshold, self.controller.release_threshold)
        self.assertFalse(self.update(2750, .55).jump_pressed)
        self.update(2800, 1.2)
        gesture = self.update(2850, .55)
        self.assertTrue(gesture.jump_pressed)
        game = RunnerGame(seed=1)
        game.start()
        game.update(1 / 60, jump_pressed=gesture.jump_pressed)
        self.assertLess(game.player_y, game.ground_y)
        self.assertFalse(self.update(2900, .55).jump_pressed)

    def test_calibration_needs_distinct_stable_fresh_poses(self):
        self.assertFalse(self.controller.calibrate_closed(1_000_000_000))
        self.update(1000, 1.2)
        self.assertFalse(self.controller.calibrate_open(1_000_000_000))
        self.feed(1050, 1500, 1.2)
        self.assertTrue(self.controller.calibrate_open(1_500_000_000))
        self.feed(1550, 2100, 1.1)
        self.assertFalse(self.controller.calibrate_closed(2_100_000_000))
        self.assertEqual(self.controller.calibration_stage, "opened")
        self.assertFalse(self.controller.calibrate_open(3_000_000_000))

    def test_lost_hand_clears_calibration_samples(self):
        self.feed(1000, 1500, 1.2)
        self.controller.update(sample(1550, has_hand=False), 1_550_000_000)
        self.assertFalse(self.controller.calibrate_open(1_550_000_000))

    def test_runtime_reset_keeps_calibration_but_default_button_restores_it(self):
        self.feed(1000, 1500, 1.2)
        self.controller.calibrate_open(1_500_000_000)
        self.feed(1550, 2100, .55)
        self.controller.calibrate_closed(2_100_000_000)
        threshold = self.controller.press_threshold
        self.controller.reset()
        self.assertEqual(self.controller.press_threshold, threshold)
        self.assertFalse(self.update(2150, .55).jump_pressed)
        self.controller.reset_calibration()
        self.assertEqual(self.controller.press_threshold, .28)
        self.assertEqual(self.controller.calibration_stage, "none")

    def test_unstable_samples_are_not_used_for_calibration(self):
        for timestamp in range(1000, 1601, 50):
            self.update(timestamp, .7 if timestamp % 100 == 0 else 1.8)
        self.assertFalse(self.controller.calibrate_open(1_600_000_000))


if __name__ == "__main__":
    unittest.main()

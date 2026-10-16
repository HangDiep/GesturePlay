"""Kiểm tra hành vi mất tay, dữ liệu cũ và trao đổi giữa các luồng."""

from dataclasses import replace
import os
from pathlib import Path
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch

os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
os.environ.setdefault("MPLCONFIGDIR", str(Path(__file__).resolve().parents[1] / ".cache" / "matplotlib"))

import numpy as np

from config import AppConfig
from core.camera import CameraWorker
from core.controller import PaddleController
from core.hand_tracker import HandTracker, palm_center
from core.metrics import Metrics
from core.shared_state import CameraFrame, HandResult, SharedState


def hand(timestamp=1000, x=0.5, y=0.5, captured=1_000_000_000):
    return HandResult(timestamp, timestamp, captured, captured + 10_000_000, x, y)


class ControllerTests(unittest.TestCase):
    def setUp(self):
        self.config = AppConfig()
        self.controller = PaddleController(self.config, play_width=960)

    def test_control_region_reaches_both_edges_and_clamps(self):
        left = self.controller.update(hand(x=0.0), 1_020_000_000)
        self.assertEqual(left.paddle_x, 0)
        self.controller.update(hand(timestamp=1001, x=None, y=None), 1_020_000_000)
        right = self.controller.update(hand(timestamp=1002, x=1.0), 1_020_000_000)
        self.assertEqual(right.paddle_x, 800)

    def test_new_result_smooths_once_even_when_ui_draws_more_often(self):
        self.controller.update(hand(x=0.15), 1_020_000_000)
        sample = hand(timestamp=1001, x=0.85)
        state = self.controller.update(sample, 1_025_000_000)
        self.assertAlmostEqual(state.paddle_x, 480)
        for _ in range(20):
            state = self.controller.update(sample, 1_030_000_000)
        self.assertAlmostEqual(state.paddle_x, 480)

    def test_no_hand_freezes_and_reacquisition_snaps(self):
        initial = self.controller.update(hand(x=0.15), 1_020_000_000)
        lost = self.controller.update(hand(timestamp=1001, x=None, y=None), 1_030_000_000)
        self.assertFalse(lost.active)
        self.assertEqual(lost.paddle_x, initial.paddle_x)
        reacquired = self.controller.update(hand(timestamp=1002, x=0.85), 1_040_000_000)
        self.assertEqual(reacquired.paddle_x, 800)

    def test_old_capture_is_rejected_even_if_callback_has_just_completed(self):
        sample = replace(hand(), completed_at_ns=1_400_000_000)
        result = self.controller.update(sample, 1_410_000_000)
        self.assertFalse(result.active)
        self.assertEqual(result.reason, "stale")
        self.assertEqual(result.paddle_x, 400)

    def test_missing_callbacks_expire_and_next_result_resets_smoothing(self):
        self.controller.update(hand(x=0.15), 1_020_000_000)
        expired = self.controller.update(hand(x=0.15), 1_251_000_000)
        self.assertFalse(expired.active)
        new = self.controller.update(hand(timestamp=1300, x=0.85, captured=1_300_000_000), 1_320_000_000)
        self.assertEqual(new.paddle_x, 800)

    def test_unavailable_worker_disables_control_and_cannot_reactivate_old_result(self):
        sample = hand()
        self.controller.update(sample, 1_020_000_000)
        disabled = self.controller.update(sample, 1_030_000_000, available=False)
        self.assertFalse(disabled.active)
        self.assertFalse(self.controller.update(sample, 1_040_000_000).active)

    def test_invalid_coordinates_do_not_move_paddle(self):
        self.assertFalse(self.controller.update(hand(x=float("nan")), 1_020_000_000).active)


class SharedAndTrackerTests(unittest.TestCase):
    def test_latest_frame_replaces_previous_frame(self):
        state = SharedState()
        for number in range(100):
            state.publish_frame(CameraFrame(number, number, None))
        self.assertEqual(state.latest_frame().frame_id, 99)
        self.assertEqual(state.snapshot().camera_frames, 100)

    def test_out_of_order_callback_cannot_replace_newer_result(self):
        state = SharedState()
        state.publish_hand(hand(timestamp=1002, x=0.8))
        state.publish_hand(hand(timestamp=1001, x=0.2))
        self.assertEqual(state.snapshot().hand.palm_x, 0.8)

    def test_palm_uses_wrist_and_four_bases_only(self):
        points = [SimpleNamespace(x=1.0, y=1.0) for _ in range(21)]
        for index in (0, 5, 9, 13, 17):
            points[index] = SimpleNamespace(x=0.3, y=0.6)
        x, y = palm_center(points)
        self.assertAlmostEqual(x, 0.3)
        self.assertAlmostEqual(y, 0.6)

    def test_timestamps_increase_and_dropped_frame_metadata_is_bounded(self):
        tracker = HandTracker(AppConfig(), SharedState())
        timestamps = [tracker._remember(CameraFrame(n, 1_000_000_000, None)) for n in range(200)]
        self.assertTrue(all(a < b for a, b in zip(timestamps, timestamps[1:])))
        self.assertLessEqual(len(tracker._pending), 64)

    def test_callback_keeps_capture_time_and_no_hand_result(self):
        state = SharedState()
        tracker = HandTracker(AppConfig(), state)
        timestamp = tracker._remember(CameraFrame(5, 1_000_000_000, None))
        tracker._on_result(SimpleNamespace(hand_landmarks=[]), None, timestamp)
        result = state.snapshot().hand
        self.assertEqual(result.frame_id, 5)
        self.assertEqual(result.captured_at_ns, 1_000_000_000)
        self.assertFalse(result.has_hand)
        self.assertFalse(tracker._pending)

    def test_late_callback_after_stop_is_ignored(self):
        state = SharedState()
        tracker = HandTracker(AppConfig(), state)
        timestamp = tracker._remember(CameraFrame(5, 1_000_000_000, None))
        tracker.stop()
        tracker._on_result(SimpleNamespace(hand_landmarks=[]), None, timestamp)
        self.assertIsNone(state.snapshot().hand)


class CameraTests(unittest.TestCase):
    def test_capture_is_released_when_open_fails(self):
        state = SharedState()
        worker = CameraWorker(AppConfig(), state)
        with patch("core.camera.cv2.VideoCapture") as factory, self.assertLogs("core.camera", level="ERROR"):
            factory.return_value.isOpened.return_value = False
            worker._run()
            factory.return_value.release.assert_called_once()
        self.assertEqual(state.snapshot().camera.phase, "error")

    def test_camera_mirrors_once_and_publishes_read_only_frame(self):
        state = SharedState()
        worker = CameraWorker(AppConfig(), state)
        original = np.arange(18, dtype=np.uint8).reshape(2, 3, 3)
        publish = state.publish_frame

        def receive(frame):
            publish(frame)
            worker._stop.set()

        with patch("core.camera.cv2.VideoCapture") as factory, patch.object(state, "publish_frame", side_effect=receive):
            capture = factory.return_value
            capture.isOpened.return_value = True
            capture.get.return_value = 30
            capture.read.return_value = True, original
            worker._run()
            capture.release.assert_called_once()
        frame = state.latest_frame()
        np.testing.assert_array_equal(frame.bgr, original[:, ::-1])
        self.assertFalse(frame.bgr.flags.writeable)


class MetricsTests(unittest.TestCase):
    def test_separate_counts_capture_age_and_one_log_row_per_second(self):
        state = SharedState()
        state.publish_frame(CameraFrame(1, 1_000_000_000, None))
        state.record_submission()
        state.publish_hand(hand())
        with TemporaryDirectory() as directory, patch("core.metrics.time.monotonic_ns", return_value=1_000_000_000):
            path = Path(directory) / "metrics.csv"
            metrics = Metrics(path)
            result = metrics.tick(state.snapshot(), 2_000_000_000)
            self.assertEqual(result.camera_fps, 1)
            self.assertEqual(result.result_fps, 1)
            self.assertEqual(result.result_age_ms, 1000)
            self.assertEqual(result.callback_latency_ms, 10)
            metrics.tick(state.snapshot(), 2_100_000_000)
            metrics.close()
            self.assertEqual(len(path.read_text(encoding="utf-8").splitlines()), 2)


if __name__ == "__main__":
    unittest.main()

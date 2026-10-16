"""Không tạo thêm camera/model khi nhiều frame cùng yêu cầu khởi động."""

import threading
import unittest
from unittest.mock import patch

from config import AppConfig
from client.services.hand_runtime import HandRuntime


class HandRuntimeTests(unittest.TestCase):
    def test_repeated_requests_share_one_camera_and_model_then_close_before_restart(self):
        runtime = HandRuntime(AppConfig())
        self.addCleanup(runtime.shutdown)
        started = threading.Event()
        with patch("core.camera.CameraWorker") as camera, patch("core.hand_tracker.HandTracker") as tracker:
            camera.return_value.stop.return_value = True
            tracker.return_value.stop.return_value = True
            tracker.return_value.start.side_effect = started.set
            runtime.ensure_started()
            self.assertTrue(started.wait(2))
            for _ in range(20):
                runtime.ensure_started()
            camera.assert_called_once()
            tracker.assert_called_once()
            runtime.request_stop()
            self.assertTrue(runtime.shutdown())
            camera.return_value.stop.assert_called_once()
            tracker.return_value.stop.assert_called_once()
            old_state = runtime.state
            started.clear()
            runtime.ensure_started()
            self.assertTrue(started.wait(2))
            self.assertIsNot(runtime.state, old_state)
            self.assertEqual(camera.call_count, 2)
            self.assertEqual(tracker.call_count, 2)
            self.assertTrue(runtime.shutdown())


if __name__ == "__main__":
    unittest.main()

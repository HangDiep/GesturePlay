"""Luồng hoàn chỉnh: camera giả lập 30 FPS → AI thật → giao diện headless."""

import os
from pathlib import Path
from tempfile import TemporaryDirectory
import threading
import time
import unittest
from unittest.mock import patch

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

import numpy as np
import pygame

from config import AppConfig
from core.shared_state import SharedState
from legacy_pygame_main import run_app


class SimulatedCamera:
    def __init__(self):
        self.released = False

    def isOpened(self):
        return True

    def set(self, *_args):
        return True

    def get(self, _property):
        return 30

    def read(self):
        time.sleep(1 / 30)
        return True, np.zeros((480, 640, 3), dtype=np.uint8)

    def release(self):
        self.released = True


class PipelineTests(unittest.TestCase):
    @unittest.skipUnless(AppConfig().model_path.is_file(), "Cần tải model để chạy kiểm tra tích hợp")
    def test_early_exit_while_model_is_loading_still_releases_resources(self):
        state = SharedState()
        camera = SimulatedCamera()
        with patch("core.camera.cv2.VideoCapture", return_value=camera), patch(
            "core.shared_state.SharedState", return_value=state
        ):
            exit_code = run_app(AppConfig(), duration=0.05)
        self.assertEqual(exit_code, 0)
        self.assertEqual(state.snapshot().tracker.phase, "stopped")
        self.assertEqual(state.snapshot().camera.phase, "stopped")
        self.assertTrue(camera.released)

    @unittest.skipUnless(AppConfig().model_path.is_file(), "Cần tải model để chạy kiểm tra tích hợp")
    def test_real_model_callbacks_logging_and_clean_shutdown(self):
        state = SharedState()
        camera = SimulatedCamera()
        finished = threading.Event()

        def close_after_callback():
            started = time.monotonic()
            while not finished.wait(0.01):
                # Chờ model khởi động thật, không giả định luôn xong trong 2 giây.
                if state.snapshot().completed_results > 0 and time.monotonic() - started > 1.2:
                    pygame.event.post(pygame.event.Event(pygame.QUIT))
                    return

        closer = threading.Thread(target=close_after_callback, daemon=True)
        with TemporaryDirectory() as directory:
            log = Path(directory) / "pipeline.csv"
            try:
                with patch("core.camera.cv2.VideoCapture", return_value=camera), patch(
                    "core.shared_state.SharedState", return_value=state
                ):
                    closer.start()
                    exit_code = run_app(AppConfig(preview_enabled=True), duration=15.0, log_path=log)
            finally:
                finished.set()
                closer.join(1)
            self.assertEqual(exit_code, 0)
            self.assertGreaterEqual(len(log.read_text(encoding="utf-8").splitlines()), 2)
        snapshot = state.snapshot()
        self.assertGreater(snapshot.camera_frames, 0)
        self.assertGreater(snapshot.submitted_frames, 0)
        self.assertGreater(snapshot.completed_results, 0)
        self.assertFalse(snapshot.hand.has_hand)
        self.assertEqual(snapshot.camera.phase, "stopped")
        self.assertEqual(snapshot.tracker.phase, "stopped")
        self.assertTrue(camera.released)


if __name__ == "__main__":
    unittest.main()

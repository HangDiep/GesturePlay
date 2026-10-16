"""Vòng sự kiện và vẽ vẫn chạy khi camera/AI không có dữ liệu."""

import os
import time
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

import numpy as np
import pygame

from config import AppConfig
from core.controller import PaddleController
from core.metrics import MetricSnapshot
from core.shared_state import CameraFrame, SharedState
from ui.control_demo import ControlDemo


class InterfaceTests(unittest.TestCase):
    def setUp(self):
        self.config = AppConfig()
        self.ui = ControlDemo(self.config)
        self.state = SharedState()
        self.controller = PaddleController(self.config, self.ui.play_rect.width)

    def tearDown(self):
        self.ui.close()

    def test_draw_without_camera_then_close_with_escape(self):
        now = time.monotonic_ns()
        self.state.set_camera_status("error", "Camera không kết nối; thử --backend msmf.")
        self.ui.draw(self.state.snapshot(), self.controller.update(None, now), MetricSnapshot(0), now)
        pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_ESCAPE))
        self.assertFalse(self.ui.events())

    def test_toggle_preview_and_cache_instead_of_converting_every_ui_frame(self):
        now = time.monotonic_ns()
        self.state.publish_frame(CameraFrame(1, now, np.zeros((480, 640, 3), dtype=np.uint8)))
        pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_p))
        self.assertTrue(self.ui.events())
        self.assertTrue(self.ui.preview_enabled)
        self.ui.draw(self.state.snapshot(), self.controller.update(None, now), MetricSnapshot(0), now)
        first_surface = self.ui._preview
        self.state.publish_frame(CameraFrame(2, now + 1_000_000, np.zeros((480, 640, 3), dtype=np.uint8)))
        self.ui.draw(self.state.snapshot(), self.controller.update(None, now), MetricSnapshot(0), now + 1_000_000)
        self.assertIs(self.ui._preview, first_surface)
        pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_p))
        self.ui.events()
        self.assertIsNone(self.ui._preview)

    def test_window_close_event_is_handled(self):
        pygame.event.post(pygame.event.Event(pygame.QUIT))
        self.assertFalse(self.ui.events())


if __name__ == "__main__":
    unittest.main()

"""Vẽ mọi màn hình và thao tác thật qua hàng đợi sự kiện Pygame."""

import os
from pathlib import Path
from tempfile import TemporaryDirectory
import time
import unittest

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

import pygame
import numpy as np

from config import AppConfig
from core.metrics import MetricSnapshot
from core.shared_state import CameraFrame, HandResult, SharedState
from client.core.gesture_controller import GestureInput
from client.core.scene_manager import Scene, SceneManager
from client.games.runner import Obstacle
from client.screens.runner_screen import RunnerScreen
from client.services.local_scores import LocalScores


class RunnerInterfaceTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.ui = RunnerScreen(AppConfig())
        self.addCleanup(self.ui.close)
        self.manager = SceneManager(LocalScores(Path(self.directory.name) / "scores.json"))
        self.state = SharedState()
        self.gesture = GestureInput(valid=True, ready=True, released=True)

    def draw(self, gesture=None):
        self.ui.draw(self.manager, gesture or self.gesture, self.state.snapshot(),
                     MetricSnapshot(1, 60), time.monotonic_ns())

    def test_menu_click_dispatches_one_game_and_disabled_begin_cannot_click(self):
        self.draw()
        pygame.event.post(pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1,
                                             pos=self.ui.buttons["play_hand"][0].center))
        actions, _ = self.ui.events()
        self.assertEqual(actions, ["play_hand"])
        self.manager.prepare()
        self.draw(GestureInput())
        self.assertFalse(self.ui.buttons["begin"][1])
        pygame.event.post(pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1,
                                             pos=self.ui.buttons["begin"][0].center))
        self.assertEqual(self.ui.events()[0], [])

    def test_camera_failure_has_retry_and_explicit_keyboard_fallback(self):
        self.manager.prepare()
        self.state.set_camera_status("error", "Không mở được camera; kiểm tra kết nối rồi thử lại.")
        self.draw(GestureInput())
        self.assertIn("camera_retry", self.ui.buttons)
        self.assertIn("play_keyboard", self.ui.buttons)

    def test_countdown_play_pause_and_results_render_and_have_expected_actions(self):
        self.manager.prepare("keyboard")
        self.manager.begin(self.gesture)
        self.draw()
        for _ in range(30):
            self.manager.update(.1, self.gesture)
        self.assertEqual(self.manager.scene, Scene.PLAYING)
        self.draw()
        self.assertIn("pause_toggle", self.ui.buttons)
        self.manager.pause()
        self.draw()
        self.assertIn("resume", self.ui.buttons)
        self.manager.resume(self.gesture)
        for _ in range(20):
            self.manager.update(.1, self.gesture)
        game = self.manager.game
        game.obstacles = [Obstacle(game.player_x + 8, 2, 52)]
        self.manager.update(.1, self.gesture)
        self.draw()
        self.assertEqual(self.manager.scene, Scene.RESULT)
        self.assertIn("restart", self.ui.buttons)

    def test_focus_pause_and_keyboard_events_are_preserved(self):
        pygame.event.post(pygame.event.Event(pygame.WINDOWFOCUSLOST))
        pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_SPACE))
        actions, jump = self.ui.events()
        self.assertFalse(self.ui.focused)
        self.assertTrue(jump)
        pygame.event.post(pygame.event.Event(pygame.QUIT))
        self.assertIn("quit", self.ui.events()[0])

    def test_calibration_buttons_show_steps_and_mark_fingertips(self):
        self.manager.prepare()
        now = time.monotonic_ns()
        self.state.publish_frame(CameraFrame(1, now, np.zeros((480, 640, 3), dtype=np.uint8)))
        self.state.publish_hand(HandResult(1, 1, now, now, .5, .5, .7, ((.3, .5), (.7, .5))))
        gesture = GestureInput(valid=True, ready=True, released=True, calibration_stage="opened")
        self.draw(gesture)
        self.assertTrue(self.ui.buttons["calibrate_open"][1])
        self.assertTrue(self.ui.buttons["calibrate_closed"][1])
        pygame.event.post(pygame.event.Event(pygame.MOUSEBUTTONDOWN, button=1,
                                             pos=self.ui.buttons["calibrate_closed"][0].center))
        self.assertEqual(self.ui.events()[0], ["calibrate_closed"])
        # Đầu ngón được vẽ trên ảnh đen, không thay đổi buffer camera.
        self.assertEqual(self.ui.screen.get_at((748, 359))[:3], (127, 230, 192))
        self.assertFalse(np.any(self.state.latest_frame().bgr))

    def test_calibration_is_disabled_until_hand_is_ready(self):
        self.manager.prepare()
        self.draw(GestureInput())
        self.assertFalse(self.ui.buttons["calibrate_open"][1])
        self.assertFalse(self.ui.buttons["calibrate_closed"][1])

    def test_calibration_has_keyboard_shortcuts(self):
        pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_F1))
        pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=pygame.K_F2))
        self.assertEqual(self.ui.events()[0], ["calibrate_open", "calibrate_closed"])


if __name__ == "__main__":
    unittest.main()

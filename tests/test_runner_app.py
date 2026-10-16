"""Đi xuyên luồng bàn phím bằng vòng lặp thật, không khởi động webcam/AI."""

import os
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import json

os.environ.setdefault("SDL_VIDEODRIVER", "dummy")

from config import AppConfig
from core.shared_state import SharedState
from client.app import run_game
from client.core.scene_manager import Scene
from client.screens.runner_screen import RunnerScreen
import pygame


class ScriptedUI:
    def __init__(self, _config):
        self.focused = True
        self.scene = None
        self.seen = set()
        self.playing_frames = 0
        self.closed = False

    def events(self):
        if self.scene is None:
            return [], False
        if self.scene == Scene.MENU:
            return (["quit"] if Scene.PAUSED in self.seen else ["play_keyboard"]), False
        if self.scene == Scene.PREPARING:
            return ["begin"], False
        if self.scene == Scene.PLAYING:
            self.playing_frames += 1
            return (["pause_toggle"] if self.playing_frames >= 3 else []), self.playing_frames == 1
        if self.scene == Scene.PAUSED:
            return ["menu"], False
        return [], False

    def draw(self, manager, *_args):
        self.scene = manager.scene
        self.seen.add(manager.scene)

    def limit_fps(self):
        pass

    def close(self):
        self.closed = True


class RunnerAppTests(unittest.TestCase):
    def test_real_interface_keyboard_round_result_save_and_replay(self):
        class PlayingUI(RunnerScreen):
            def __init__(self, config):
                super().__init__(config)
                self.seen_result = None
                self.replayed_id = None

            def draw(self, manager, *args):
                super().draw(manager, *args)
                key = None
                if manager.scene == Scene.MENU:
                    if self.seen_result is not None:
                        pygame.event.post(pygame.event.Event(pygame.QUIT))
                    else:
                        key = pygame.K_RETURN
                elif manager.scene == Scene.PREPARING:
                    if self.seen_result is not None:
                        self.replayed_id = manager.game.session_id
                        key = pygame.K_ESCAPE
                    else:
                        key = pygame.K_RETURN
                elif manager.scene == Scene.RESULT:
                    self.seen_result = manager.result
                    key = pygame.K_r
                if key is not None:
                    pygame.event.post(pygame.event.Event(pygame.KEYDOWN, key=key))

            def limit_fps(self):
                pass

        ui = PlayingUI(AppConfig())
        clock = iter(index / 10 for index in range(1000))
        with TemporaryDirectory() as directory, patch("client.app.RunnerScreen", return_value=ui), patch(
            "client.app.time.monotonic", side_effect=lambda: next(clock)
        ):
            path = Path(directory) / "scores.json"
            self.assertEqual(run_game(AppConfig(), duration=20, keyboard=True, scores_path=path), 0)
            records = json.loads(path.read_text(encoding="utf-8"))["rounds"]
        self.assertEqual(len(records), 1)
        self.assertEqual(records[0]["outcome"], "lost")
        self.assertEqual(records[0]["control_mode"], "keyboard")
        self.assertNotEqual(ui.seen_result.session_id, ui.replayed_id)

    def test_keyboard_menu_countdown_play_pause_and_exit_never_open_camera(self):
        ui = ScriptedUI(AppConfig())
        clock = iter(index / 10 for index in range(1000))
        with TemporaryDirectory() as directory, patch("client.app.RunnerScreen", return_value=ui), patch(
            "client.app.HandRuntime"
        ) as runtime_factory, patch("client.app.time.monotonic", side_effect=lambda: next(clock)):
            runtime = runtime_factory.return_value
            runtime.state = SharedState()
            runtime.closing = False
            runtime.shutdown.return_value = True
            code = run_game(AppConfig(), duration=20, keyboard=True, scores_path=Path(directory) / "scores.json")
            runtime.ensure_started.assert_not_called()
            runtime.shutdown.assert_called_once()
        self.assertEqual(code, 0)
        self.assertEqual(ui.seen, {Scene.MENU, Scene.PREPARING, Scene.COUNTDOWN, Scene.PLAYING, Scene.PAUSED})
        self.assertTrue(ui.closed)


if __name__ == "__main__":
    unittest.main()

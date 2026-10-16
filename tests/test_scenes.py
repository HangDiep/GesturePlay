"""Chuyển màn hình, mất tay và xác nhận tiếp tục không làm chạy ngầm ván cũ."""

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from client.core.gesture_controller import GestureInput
from client.core.scene_manager import Scene, SceneManager
from client.games.runner import Obstacle
from client.services.local_scores import LocalScores


READY = GestureInput(valid=True, ready=True, released=True)
LOST = GestureInput()


class SceneTests(unittest.TestCase):
    def setUp(self):
        self.directory = TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.manager = SceneManager(LocalScores(Path(self.directory.name) / "scores.json"))

    def play(self, mode="hand"):
        self.manager.prepare(mode)
        self.assertTrue(self.manager.begin(READY))
        for _ in range(30):
            self.manager.update(.1, READY)
        self.assertEqual(self.manager.scene, Scene.PLAYING)

    def test_preparation_requires_stable_open_hand(self):
        self.manager.prepare()
        self.assertFalse(self.manager.begin(LOST))
        self.assertFalse(self.manager.begin(GestureInput(valid=True, ready=True, pinched=True)))
        self.assertTrue(self.manager.begin(READY))
        self.manager.update(.1, LOST)
        self.assertEqual(self.manager.scene, Scene.PREPARING)
        self.assertEqual(self.manager.game.elapsed, 0)

    def test_lost_hand_pauses_immediately_and_does_not_auto_resume(self):
        self.play()
        self.manager.update(.1, READY)
        elapsed = self.manager.game.elapsed
        self.manager.update(.1, LOST)
        self.assertEqual(self.manager.scene, Scene.PAUSED)
        for _ in range(20):
            self.manager.update(.1, READY)
        self.assertEqual(self.manager.scene, Scene.PAUSED)
        self.assertEqual(self.manager.game.elapsed, elapsed)
        self.assertFalse(self.manager.resume(LOST))
        self.assertTrue(self.manager.resume(READY))
        for _ in range(20):
            self.manager.update(.1, READY)
        self.assertEqual(self.manager.scene, Scene.PLAYING)
        self.assertEqual(self.manager.game.elapsed, elapsed)

    def test_keyboard_mode_needs_no_hand_and_focus_loss_still_pauses(self):
        self.play("keyboard")
        self.manager.update(.1, LOST, jump_key=True)
        self.assertEqual(self.manager.scene, Scene.PLAYING)
        self.assertLess(self.manager.game.player_y, self.manager.game.ground_y)
        self.manager.update(.1, LOST, focused=False)
        self.assertEqual(self.manager.scene, Scene.PAUSED)
        self.assertFalse(self.manager.needs_camera)

    def test_finished_round_is_saved_once_and_replay_starts_new_round(self):
        self.play("keyboard")
        game = self.manager.game
        game.obstacles = [Obstacle(game.player_x + 8, 2, 52)]
        with patch.object(self.manager.scores, "save", return_value=True) as save:
            self.manager.update(.1, LOST)
            self.assertEqual(self.manager.scene, Scene.RESULT)
            self.assertTrue(self.manager.saved)
            self.manager.update(.1, LOST)
            save.assert_called_once()
        old_id = game.session_id
        self.manager.prepare()
        self.assertNotEqual(self.manager.game.session_id, old_id)
        self.assertEqual(self.manager.game.score, 0)
        self.assertEqual(self.manager.scene, Scene.PREPARING)

    def test_return_to_menu_removes_active_game_and_camera_demand(self):
        self.play()
        old_game = self.manager.game
        self.manager.to_menu()
        self.manager.update(.25, READY)
        self.assertIsNone(self.manager.game)
        self.assertFalse(self.manager.needs_camera)
        self.assertTrue(old_game.paused)

    def test_unknown_game_code_is_refused(self):
        with self.assertRaises(ValueError):
            self.manager.prepare(game_code="not_a_game")


if __name__ == "__main__":
    unittest.main()

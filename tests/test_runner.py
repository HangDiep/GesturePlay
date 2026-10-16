"""Luật Runner, va chạm thực, độ khó có thể vượt và lưu kết quả local."""

from dataclasses import replace
import json
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from client.games.base_game import GameResult
from client.games.runner import Coin, Obstacle, RULES, RunnerGame, triangle_hits_box
from client.services.local_scores import LocalScores


class RunnerRulesTests(unittest.TestCase):
    def test_jump_only_when_grounded_and_never_double_jumps(self):
        game = RunnerGame(seed=1)
        self.assertFalse(game.jump())
        game.start()
        self.assertTrue(game.jump())
        game.update(.1)
        self.assertFalse(game.jump())
        self.assertLess(game.player_y, game.ground_y)
        game.update(.25)
        game.update(.25)
        game.update(.25)
        self.assertTrue(game.grounded)
        self.assertTrue(game.jump())

    def test_spike_collision_ends_round_and_result_stays_frozen(self):
        game = RunnerGame(seed=1)
        game.obstacles = [Obstacle(game.player_x + 8, 2, 52)]
        game.start()
        game.update(1 / 60)
        self.assertEqual(game.outcome, "lost")
        result = game.get_result()
        game.update(.25, jump_pressed=True)
        self.assertEqual(game.get_result(), result)

    def test_triangle_corners_are_not_solid_rectangles(self):
        triangle = ((0, 40), (20, 0), (40, 40))
        self.assertFalse(triangle_hits_box(triangle, (0, 0, 5, 5)))
        self.assertTrue(triangle_hits_box(triangle, (17, 10, 6, 10)))

    def test_coin_and_obstacle_are_scored_once(self):
        game = RunnerGame(seed=1)
        game.obstacles = [Obstacle(20, 1, 40)]
        game.coins = [Coin(game.player_x + 22, game.ground_y - 28)]
        game.start()
        game.update(1 / 60)
        self.assertEqual(game.score, 30)
        self.assertEqual(game.obstacles_passed, 1)
        self.assertEqual(game.coins_collected, 1)
        game.update(.1)
        self.assertEqual(game.score, 30)

    def test_pause_freezes_everything_including_timer(self):
        game = RunnerGame(seed=1)
        game.start()
        game.jump()
        game.update(.1)
        game.pause()
        before = (game.elapsed, game.distance, game.player_y, game.velocity_y)
        game.update(.25, jump_pressed=True)
        self.assertEqual(before, (game.elapsed, game.distance, game.player_y, game.velocity_y))

    def test_reset_creates_new_round_and_removes_previous_state(self):
        game = RunnerGame(seed=1)
        old_id = game.session_id
        game.start()
        game.coins_collected = 3
        game.update(.1)
        game.reset()
        self.assertNotEqual(game.session_id, old_id)
        self.assertEqual((game.score, game.elapsed, game.distance), (0, 0, 0))
        self.assertFalse(game.started)
        self.assertFalse(game.finished)

    def test_every_difficulty_can_be_completed_and_entities_stay_bounded(self):
        for difficulty in RULES:
            with self.subTest(difficulty=difficulty):
                game = RunnerGame(difficulty, seed=21)
                game.start()
                max_objects = 0
                for _ in range(120 * 60 + 1):
                    ahead = [o for o in game.obstacles if o.x + o.width - game.distance >= game.player_x + 8]
                    nearest = min(ahead, key=lambda o: o.x, default=None)
                    gap = nearest.x - game.distance - (game.player_x + game.player_width) if nearest else 9999
                    game.update(1 / 60, jump_pressed=0 < gap < 95 and game.grounded)
                    max_objects = max(max_objects, len(game.obstacles) + len(game.coins))
                    if game.finished:
                        break
                self.assertEqual(game.outcome, "time_up")
                self.assertEqual(game.get_result().active_duration_ms, 120000)
                self.assertGreater(game.obstacles_passed, 20)
                self.assertLess(max_objects, 45)

    def test_hardest_spacing_leaves_time_to_land_before_next_jump(self):
        airtime = -2 * RunnerGame.jump_velocity / RunnerGame.gravity
        for rules in RULES.values():
            self.assertGreater(rules.min_gap / (rules.speed + 35), airtime + .25)


def report(session_id="round-1", score=40, mode="hand", difficulty="normal"):
    return GameResult(session_id, "runner", difficulty, 1, "lost", score, 1000,
                      {"obstacles_passed": 0, "coins_collected": score // 20, "distance_units": 30}, mode)


class LocalScoreTests(unittest.TestCase):
    def test_retry_does_not_duplicate_and_best_is_separate_per_mode(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "scores.json"
            scores = LocalScores(path)
            self.assertTrue(scores.save(report()))
            self.assertTrue(scores.save(report()))
            self.assertTrue(scores.save(report("keyboard", 200, "keyboard")))
            self.assertEqual(len(scores.records), 2)
            self.assertEqual(scores.best("normal", "hand"), 40)
            self.assertEqual(scores.best("normal", "keyboard"), 200)
            self.assertEqual(LocalScores(path).best("normal", "hand"), 40)

    def test_bad_local_file_does_not_crash_startup(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "scores.json"
            path.write_text("broken json", encoding="utf-8")
            scores = LocalScores(path)
            self.assertIsNotNone(scores.error)
            self.assertEqual(scores.best("normal"), 0)
            path.write_text(json.dumps({"version": 1, "rounds": [{"game_code": "runner", "difficulty": []}]}), encoding="utf-8")
            self.assertEqual(LocalScores(path).records, [])

    def test_disk_failure_can_be_retried(self):
        with TemporaryDirectory() as directory:
            scores = LocalScores(Path(directory) / "scores.json")
            with patch.object(Path, "write_text", side_effect=PermissionError("denied")):
                self.assertFalse(scores.save(report()))
            self.assertEqual(scores.records, [])
            self.assertTrue(scores.save(report()))

    def test_bounded_history_preserves_older_best(self):
        with TemporaryDirectory() as directory:
            scores = LocalScores(Path(directory) / "scores.json")
            self.assertTrue(scores.save(report("best", 1000)))
            base = scores.records[0]
            scores.records += [dict(base, session_id=f"r-{n}", score=20) for n in range(99)]
            self.assertTrue(scores.save(report("latest", 40)))
            self.assertLessEqual(len(scores.records), 100)
            self.assertEqual(scores.best("normal"), 1000)


if __name__ == "__main__":
    unittest.main()

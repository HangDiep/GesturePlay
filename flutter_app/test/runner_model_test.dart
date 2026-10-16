import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/game/runner_model.dart';

void main() {
  test('jump only on ground; held commands cannot double jump', () {
    final game = RunnerModel(seed: 1);
    expect(game.jump(), false);
    game.start();
    expect(game.jump(), true);
    game.update(.1);
    expect(game.feet, lessThan(RunnerModel.ground));
    expect(game.jump(), false);
    for (var i = 0; i < 3; i++) {
      game.update(.25);
    }
    expect(game.grounded, true);
    expect(game.jump(), true);
  });
  test('spike triangle collision ends round and freezes result', () {
    final game = RunnerModel(seed: 1)..start();
    game.obstacles
      ..clear()
      ..add(Obstacle(RunnerModel.playerX + 8, 2, 52));
    game.update(1 / 60);
    expect(game.outcome, 'lost');
    final time = game.elapsed;
    game.update(.25, jumpPressed: true);
    expect(game.elapsed, time);
    expect(
      triangleHitsBox([
        const Offset(0, 40),
        const Offset(20, 0),
        const Offset(40, 40),
      ], const Rect.fromLTWH(0, 0, 5, 5)),
      false,
    );
  });
  test('coin and obstacle count once, score formula matches version one', () {
    final game = RunnerModel(seed: 1)..start();
    game.obstacles
      ..clear()
      ..add(Obstacle(20, 1, 40));
    game.coins
      ..clear()
      ..add(Coin(RunnerModel.playerX + 22, RunnerModel.ground - 28));
    game.update(1 / 60);
    game.update(.1);
    expect(game.score, 30);
  });
  test(
    'pause freezes simulation and replay clears all state with a new ID',
    () {
      final game = RunnerModel(seed: 1)
        ..start()
        ..jump();
      game.update(.1);
      game.pause();
      final before = [game.distance, game.elapsed, game.feet, game.velocity];
      game.update(.25);
      expect([game.distance, game.elapsed, game.feet, game.velocity], before);
      final id = game.id;
      game.reset();
      expect(game.id, isNot(id));
      expect(game.score, 0);
      expect(game.elapsed, 0);
    },
  );
  for (final difficulty in Difficulty.values) {
    test(
      '${difficulty.name}: reachable obstacles, full 120 seconds, bounded objects',
      () {
        final game = RunnerModel(difficulty: difficulty, seed: 21)..start();
        var maxObjects = 0;
        for (var i = 0; i < 7201 && !game.finished; i++) {
          final ahead =
              game.obstacles
                  .where(
                    (o) =>
                        o.x + o.width - game.distance >=
                        RunnerModel.playerX + 8,
                  )
                  .toList()
                ..sort((a, b) => a.x.compareTo(b.x));
          final gap = ahead.isEmpty
              ? 9999
              : ahead.first.x -
                    game.distance -
                    RunnerModel.playerX -
                    RunnerModel.playerWidth;
          game.update(
            1 / 60,
            jumpPressed: gap > 0 && gap < 95 && game.grounded,
          );
          maxObjects = math.max(
            maxObjects,
            game.obstacles.length + game.coins.length,
          );
        }
        expect(game.outcome, 'time_up');
        expect(game.result().durationMs, 120000);
        expect(game.obstaclesPassed, greaterThan(20));
        expect(maxObjects, lessThan(45));
        final airtime = -2 * RunnerModel.jumpVelocity / RunnerModel.gravity;
        expect(
          game.rules.minGap / (game.rules.speed + 35),
          greaterThan(airtime + .25),
        );
      },
    );
  }
}

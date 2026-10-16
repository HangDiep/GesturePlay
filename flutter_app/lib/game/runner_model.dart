import 'dart:math' as math;
import 'dart:ui';

enum Difficulty { easy, normal, hard }

enum ControlMode { hand, keyboard }

extension DifficultyName on Difficulty {
  String get label => switch (this) {
    Difficulty.easy => 'Dễ',
    Difficulty.normal => 'Vừa',
    Difficulty.hard => 'Khó',
  };
}

class RunnerRules {
  const RunnerRules(
    this.speed,
    this.minGap,
    this.maxGap,
    this.maxSpikes,
    this.spikeHeight,
  );
  final double speed, minGap, maxGap, spikeHeight;
  final int maxSpikes;
  static const duration = 120.0;
  static const modes = {
    Difficulty.easy: RunnerRules(290, 650, 850, 1, 44),
    Difficulty.normal: RunnerRules(350, 610, 790, 2, 52),
    Difficulty.hard: RunnerRules(410, 580, 750, 3, 60),
  };
}

class Obstacle {
  Obstacle(this.x, this.spikes, this.height);
  final double x, height;
  final int spikes;
  bool passed = false;
  double get width => spikes * 28.0;
}

class Coin {
  Coin(this.x, this.y);
  final double x, y;
  bool collected = false;
}

class RunnerResult {
  const RunnerResult({
    required this.id,
    required this.difficulty,
    required this.control,
    required this.outcome,
    required this.score,
    required this.durationMs,
    required this.obstacles,
    required this.coins,
    required this.distance,
  });
  final String id, outcome;
  final Difficulty difficulty;
  final ControlMode control;
  final int score, durationMs, obstacles, coins, distance;
  Map<String, dynamic> toJson() => {
    'session_id': id,
    'game_code': 'runner',
    'rules_version': 1,
    'difficulty': difficulty.name,
    'control_mode': control.name,
    'outcome': outcome,
    'score': score,
    'active_duration_ms': durationMs,
    'metrics': {
      'obstacles_passed': obstacles,
      'coins_collected': coins,
      'distance_units': distance,
    },
    'created_at': DateTime.now().toUtc().toIso8601String(),
  };
}

String newLocalId() {
  final random = math.Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final s = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
}

bool triangleHitsBox(List<Offset> triangle, Rect box) {
  final rectangle = [
    box.topLeft,
    box.topRight,
    box.bottomRight,
    box.bottomLeft,
  ];
  final axes = <Offset>[const Offset(1, 0), const Offset(0, 1)];
  for (var i = 0; i < 3; i++) {
    final a = triangle[i], b = triangle[(i + 1) % 3];
    axes.add(Offset(a.dy - b.dy, b.dx - a.dx));
  }
  for (final axis in axes) {
    double project(Offset p) => p.dx * axis.dx + p.dy * axis.dy;
    final a = triangle.map(project), b = rectangle.map(project);
    if (a.reduce(math.max) <= b.reduce(math.min) ||
        b.reduce(math.max) <= a.reduce(math.min)) {
      return false;
    }
  }
  return true;
}

/// All movement, spawning, collision, timing and scoring run in Dart/Flame.
class RunnerModel {
  RunnerModel({
    this.difficulty = Difficulty.normal,
    this.control = ControlMode.hand,
    int? seed,
  }) : random = math.Random(seed),
       rules = RunnerRules.modes[difficulty]! {
    reset();
  }
  final Difficulty difficulty;
  final ControlMode control;
  final math.Random random;
  final RunnerRules rules;
  static const width = 1120.0, ground = 548.0, playerX = 190.0;
  static const playerWidth = 46.0, playerHeight = 64.0;
  static const gravity = 1900.0, jumpVelocity = -720.0;
  late String id;
  double distance = 0,
      elapsed = 0,
      feet = ground,
      velocity = 0,
      nextSpawn = width + 160;
  int obstaclesPassed = 0, coinsCollected = 0;
  bool started = false, paused = false;
  String? outcome;
  final obstacles = <Obstacle>[];
  final coins = <Coin>[];
  int get score => 10 * obstaclesPassed + 20 * coinsCollected;
  bool get grounded => feet >= ground && velocity >= 0;
  bool get finished => outcome != null;
  double get speed => rules.speed + math.min(35, elapsed * .35);
  Rect get hitbox => Rect.fromLTWH(
    playerX + 8,
    feet - playerHeight + 8,
    playerWidth - 16,
    playerHeight - 10,
  );

  void reset() {
    id = newLocalId();
    distance = elapsed = velocity = 0;
    feet = ground;
    obstaclesPassed = coinsCollected = 0;
    started = paused = false;
    outcome = null;
    obstacles.clear();
    coins.clear();
    nextSpawn = width + 160;
    _spawn();
  }

  void start() {
    if (!finished) {
      started = true;
      paused = false;
    }
  }

  void pause() => paused = true;
  bool jump() {
    if (!started || paused || finished || !grounded) return false;
    velocity = jumpVelocity;
    return true;
  }

  void _spawn() {
    while (nextSpawn - distance < width + 260) {
      final o = Obstacle(
        nextSpawn,
        1 + random.nextInt(rules.maxSpikes),
        rules.spikeHeight,
      );
      obstacles.add(o);
      for (var i = 0; i < 5; i++) {
        final t = i / 4;
        coins.add(
          Coin(
            o.x - 125 + t * (250 + o.width),
            ground - 70 - 80 * math.sin(t * math.pi),
          ),
        );
      }
      for (var i = 0; i < 2; i++) {
        coins.add(Coin(o.x + o.width + 210 + i * 46, ground - 28));
      }
      nextSpawn +=
          rules.minGap + random.nextDouble() * (rules.maxGap - rules.minGap);
    }
  }

  void update(double dt, {bool jumpPressed = false}) {
    if (!started || paused || finished) return;
    if (!dt.isFinite || dt < 0) throw ArgumentError('Invalid delta time');
    if (jumpPressed) jump();
    var remaining = math.min(dt, .25);
    while (remaining > 1e-9 && !finished) {
      final step = math.min(
        math.min(remaining, 1 / 120),
        RunnerRules.duration - elapsed,
      );
      if (step <= 1e-9) {
        outcome = 'time_up';
        break;
      }
      elapsed += step;
      distance += speed * step;
      if (!grounded || velocity < 0) {
        feet += velocity * step + .5 * gravity * step * step;
        velocity += gravity * step;
        if (feet >= ground) {
          feet = ground;
          velocity = 0;
        }
      }
      _spawn();
      _collisions();
      if (!finished && elapsed >= RunnerRules.duration - 1e-8) {
        elapsed = RunnerRules.duration;
        outcome = 'time_up';
      }
      remaining -= step;
    }
    obstacles.removeWhere((o) => o.x + o.width - distance < -80);
    coins.removeWhere((c) => c.collected || c.x - distance < -30);
  }

  void _collisions() {
    final box = hitbox;
    for (final o in obstacles) {
      final x = o.x - distance;
      if (x + o.width < box.left) {
        if (!o.passed) {
          o.passed = true;
          obstaclesPassed++;
        }
        continue;
      }
      if (x > box.right) continue;
      for (var i = 0; i < o.spikes; i++) {
        final sx = x + i * 28;
        if (triangleHitsBox([
          Offset(sx, ground),
          Offset(sx + 14, ground - o.height),
          Offset(sx + 28, ground),
        ], box)) {
          outcome = 'lost';
          return;
        }
      }
    }
    for (final c in coins) {
      if (c.collected) continue;
      final x = c.x - distance;
      final dx = x - x.clamp(box.left, box.right),
          dy = c.y - c.y.clamp(box.top, box.bottom);
      if (dx * dx + dy * dy <= 144) {
        c.collected = true;
        coinsCollected++;
      }
    }
  }

  RunnerResult result() {
    if (!finished) throw StateError('Round is still running');
    return RunnerResult(
      id: id,
      difficulty: difficulty,
      control: control,
      outcome: outcome!,
      score: score,
      durationMs: (elapsed * 1000).round(),
      obstacles: obstaclesPassed,
      coins: coinsCollected,
      distance: (distance / 10).floor(),
    );
  }
}

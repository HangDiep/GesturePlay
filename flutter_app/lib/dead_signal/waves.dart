part of 'model.dart';

class WaveSpawn {
  const WaveSpawn(this.kind, {this.delay = 0, this.route = 1});
  final EnemyKind kind;
  final double delay;
  final int route;
}

class SignalWave {
  const SignalWave(this.at, this.title, this.spawns);
  final double at;
  final String title;
  final List<WaveSpawn> spawns;
}

class _PendingSpawn {
  const _PendingSpawn(this.at, this.spawn);
  final double at;
  final WaveSpawn spawn;
}

class SignalWaves {
  static const easy = <SignalWave>[
    SignalWave(3, 'Tín hiệu đầu tiên', [WaveSpawn(EnemyKind.runner)]),
    SignalWave(27, 'Tiếng đập cửa', [WaveSpawn(EnemyKind.breaker, route: 2)]),
    SignalWave(50, 'Hai hướng tiếp cận', [
      WaveSpawn(EnemyKind.runner),
      WaveSpawn(EnemyKind.runner, delay: 2.5, route: 2),
    ]),
    SignalWave(73, 'Mất tín hiệu', [
      WaveSpawn(EnemyKind.jammer, route: 2),
      WaveSpawn(EnemyKind.breaker, delay: 3),
    ]),
    SignalWave(97, 'Vành đai phòng thủ', [
      WaveSpawn(EnemyKind.runner, route: 2),
      WaveSpawn(EnemyKind.breaker, delay: 2),
    ]),
    SignalWave(125, 'Vật chủ thức tỉnh', [
      WaveSpawn(EnemyKind.boss),
      WaveSpawn(EnemyKind.runner, delay: 4, route: 2),
    ]),
    SignalWave(153, 'Giữ vững đến cứu hộ', [
      WaveSpawn(EnemyKind.runner, route: 2),
      WaveSpawn(EnemyKind.breaker, delay: 2),
    ]),
  ];
  static const normal = <SignalWave>[
    SignalWave(3, 'Tín hiệu đầu tiên', [WaveSpawn(EnemyKind.runner, route: 2)]),
    SignalWave(22, 'Áp lực hai phía', [
      WaveSpawn(EnemyKind.runner),
      WaveSpawn(EnemyKind.breaker, delay: 1.5, route: 2),
    ]),
    SignalWave(43, 'Vùng nhiễu', [
      WaveSpawn(EnemyKind.jammer),
      WaveSpawn(EnemyKind.runner, delay: 2, route: 2),
    ]),
    SignalWave(66, 'Đợt tấn công phối hợp', [
      WaveSpawn(EnemyKind.breaker, route: 2),
      WaveSpawn(EnemyKind.runner, delay: 1.5),
      WaveSpawn(EnemyKind.runner, delay: 4, route: 2),
    ]),
    SignalWave(91, 'Phòng tuyến bị ép', [
      WaveSpawn(EnemyKind.jammer, route: 2),
      WaveSpawn(EnemyKind.breaker, delay: 2),
      WaveSpawn(EnemyKind.runner, delay: 4),
    ]),
    SignalWave(118, 'Vật chủ thức tỉnh', [
      WaveSpawn(EnemyKind.boss),
      WaveSpawn(EnemyKind.runner, delay: 3, route: 2),
    ]),
    SignalWave(149, 'Đợt công kích cuối', [
      WaveSpawn(EnemyKind.breaker, route: 2),
      WaveSpawn(EnemyKind.runner, delay: 2),
    ]),
  ];
  static List<SignalWave> plan(
    SignalDifficulty difficulty, {
    required bool advanced,
  }) {
    final source = difficulty == SignalDifficulty.easy ? easy : normal;
    return List.unmodifiable(
      source.map(
        (wave) => SignalWave(
          wave.at,
          !advanced && wave.spawns.any((s) => s.kind == EnemyKind.boss)
              ? 'Đợt công kích lớn'
              : !advanced && wave.spawns.any((s) => s.kind == EnemyKind.jammer)
              ? 'Truy đuổi trong hành lang'
              : wave.title,
          List.unmodifiable(
            wave.spawns.map(
              (spawn) => WaveSpawn(
                advanced
                    ? spawn.kind
                    : switch (spawn.kind) {
                        EnemyKind.jammer => EnemyKind.runner,
                        EnemyKind.boss => EnemyKind.breaker,
                        _ => spawn.kind,
                      },
                delay: spawn.delay,
                route: spawn.route,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

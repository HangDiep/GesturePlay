import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/dead_signal/model.dart';

void runFor(SignalModel m, double seconds) {
  for (var t = 0.0; t < seconds - 1e-8; t += .025) {
    m.update(.025);
  }
}

void main() {
  test('the decoy alone cannot hold fast creatures forever', () {
    final m = SignalModel(difficulty: SignalDifficulty.normal)..start();
    m.spawn(EnemyKind.runner, zone: 0, progress: .7);
    m.selectedZone = 0;
    for (var i = 0; i < 1400 && m.active; i++) {
      if (m.cooldowns[Defense.decoy] == 0) m.activate(Defense.decoy);
      m.update(.025);
    }
    expect(m.phase, RoundPhase.lost);
    expect(m.elapsed, lessThan(30));
  });
  test('an exposed boss only takes full damage on its glowing weak point', () {
    final m = SignalModel()
      ..start()
      ..selectCamera(1);
    final boss = m.spawn(EnemyKind.boss, zone: 1, progress: .8)
      ..weakFor = SignalRules.bossExposure;
    m.toggleGun();
    m.shoot(boss.aimPoint + const Offset(.09, 0));
    expect(boss.health, 285);
    expect(boss.lastHitArmored, true);
    runFor(m, .8);
    m.shoot(boss.weakPoint);
    expect(boss.health, 240);
    expect(boss.lastHitWeak, true);
  });
  test(
    'each difficulty has an explicit seven-wave composition and one boss',
    () {
      final easy = SignalWaves.plan(SignalDifficulty.easy, advanced: true);
      final normal = SignalWaves.plan(SignalDifficulty.normal, advanced: true);
      expect(easy.length, 7);
      expect(normal.length, 7);
      expect(easy.fold<int>(0, (n, w) => n + w.spawns.length), 12);
      expect(normal.fold<int>(0, (n, w) => n + w.spawns.length), 15);
      for (final plan in [easy, normal]) {
        var previous = -1.0;
        final kinds = <EnemyKind>{};
        var bosses = 0;
        for (final wave in plan) {
          expect(wave.at, greaterThan(previous));
          expect(wave.spawns, isNotEmpty);
          for (final spawn in wave.spawns) {
            expect(spawn.delay, greaterThanOrEqualTo(0));
            expect(wave.at + spawn.delay, lessThan(180));
            expect(spawn.route, isIn([1, 2]));
            kinds.add(spawn.kind);
            if (spawn.kind == EnemyKind.boss) bosses++;
          }
          previous = wave.at;
        }
        expect(kinds, containsAll(EnemyKind.values));
        expect(bosses, 1);
      }
      final practice = SignalWaves.plan(
        SignalDifficulty.normal,
        advanced: false,
      );
      expect(
        practice
            .expand((w) => w.spawns)
            .every(
              (s) => s.kind == EnemyKind.runner || s.kind == EnemyKind.breaker,
            ),
        true,
      );
    },
  );
  test('a wave spawns its configured count, timing and preferred routes', () {
    final m = SignalModel(difficulty: SignalDifficulty.normal)..start();
    m.toggleDoor(1);
    runFor(m, 21.9);
    runFor(m, .2);
    expect(m.wave, 2);
    expect(m.enemies.where((e) => e.kind == EnemyKind.breaker), isEmpty);
    final count = m.enemies.length;
    runFor(m, 1.5);
    expect(m.enemies.length, count + 1);
    final breaker = m.enemies.firstWhere((e) => e.kind == EnemyKind.breaker);
    expect(breaker.preferredRoute, 2);
    expect(m.nextWaveIn, closeTo(19.4, .1));
  });
  test('capacity queues encounters instead of silently dropping enemies', () {
    final m = SignalModel()..start();
    for (var i = 0; i < m.rules.maxActive; i++) {
      m.spawn(EnemyKind.breaker, zone: 0, progress: 0);
    }
    runFor(m, 3.1);
    expect(m.aliveCount, m.rules.maxActive);
    expect(m.pendingSpawns, 1);
    m.enemies.first.health = 0;
    runFor(m, .1);
    expect(m.pendingSpawns, 0);
    expect(m.aliveCount, m.rules.maxActive);
  });
  test('boss telegraphs a heavy strike then exposes a timed weak point', () {
    final m = SignalModel()..start();
    m.toggleDoor(0);
    final boss = m.spawn(EnemyKind.boss, zone: 1, progress: 1);
    runFor(m, 1.1);
    expect(boss.charging, true);
    expect(m.doors[0].health, 120);
    runFor(m, 1.1);
    expect(boss.charging, true);
    expect(m.doors[0].health, 120);
    runFor(m, .3);
    expect(boss.strongAttacks, 1);
    expect(m.doors[0].health, 63);
    expect(boss.exposed, true);
    expect(boss.state, EnemyState.recovering);
    m.selectCamera(1);
    m.toggleGun();
    m.shoot(boss.aimPoint);
    expect(boss.health, 255);
    expect(boss.lastHitWeak, true);
    final health = m.doors[0].health;
    runFor(m, 2.5);
    expect(m.doors[0].health, health);
    runFor(m, 1);
    expect(boss.exposed, false);
  });
  test('armor does not cancel a charging boss; stun interrupts its strike', () {
    final m = SignalModel()..start();
    m.toggleDoor(0);
    final boss = m.spawn(EnemyKind.boss, zone: 1, progress: 1);
    runFor(m, 1.05);
    m.selectCamera(1);
    m.toggleGun();
    m.shoot(boss.aimPoint);
    expect(boss.health, 285);
    expect(boss.lastHitArmored, true);
    expect(boss.charging, true);
    m.activate(Defense.flash);
    expect(boss.charging, false);
    expect(boss.stunnedFor, 1.5);
    runFor(m, 1.6);
    expect(m.doors[0].health, 120);
    expect(boss.strongAttacks, 0);
  });
  test(
    'a killed enemy animates but no longer attacks, jams or triggers sensors',
    () {
      final m = SignalModel()..start();
      m.selectCamera(1);
      final e = m.spawn(EnemyKind.runner, zone: 1, progress: 1);
      m.toggleGun();
      m.shoot(e.aimPoint);
      expect(e.alive, false);
      expect(e.deathFor, greaterThan(0));
      expect(m.kills, 1);
      expect(m.visibleEnemies, isEmpty);
      expect(m.renderedEnemies, contains(e));
      expect(m.sensor(1), false);
      runFor(m, .5);
      expect(m.phase, RoundPhase.playing);
      expect(m.kills, 1);
      runFor(m, .5);
      expect(m.enemies, isNot(contains(e)));
      expect(m.kills, 1);
    },
  );
  test(
    'hit feedback and death animation freeze with the rest of a paused round',
    () {
      final m = SignalModel()..start();
      m.selectCamera(1);
      final e = m.spawn(EnemyKind.runner, zone: 1, progress: .5);
      m.toggleGun();
      m.shoot(e.aimPoint);
      final death = e.deathFor, hit = e.hitFor, animation = e.animationTime;
      m.pause();
      runFor(m, 5);
      expect(e.deathFor, death);
      expect(e.hitFor, hit);
      expect(e.animationTime, animation);
    },
  );
  test(
    'stunned jammer stops interference and its corpse never restores it',
    () {
      final m = SignalModel()..start();
      m.selectCamera(1);
      final e = m.spawn(EnemyKind.jammer, zone: 1, progress: .7);
      expect(m.jammed, true);
      m.activate(Defense.flash);
      expect(m.jammed, false);
      m.toggleGun();
      m.shoot(e.aimPoint);
      runFor(m, .8);
      m.shoot(e.aimPoint);
      expect(e.alive, false);
      expect(e.deathFor, greaterThan(0));
      expect(m.jammed, false);
      expect(m.sensor(1), false);
    },
  );
  for (final difficulty in SignalDifficulty.values) {
    test('full four-monster encounter is winnable on ${difficulty.name}', () {
      final m = SignalModel(difficulty: difficulty, advanced: true, seed: 17)
        ..start();
      var maxAlive = 0;
      for (var frame = 0; frame < 7400 && m.active; frame++) {
        for (var door = 0; door < 2; door++) {
          final danger = m.enemies.any(
            (e) => e.alive && e.zone == door + 1 && e.progress > .88,
          );
          if (m.doors[door].locked != danger && !m.doors[door].broken) {
            m.toggleDoor(door);
          }
        }
        final targets =
            m.enemies
                .where(
                  (e) => e.alive && (e.kind != EnemyKind.boss || e.exposed),
                )
                .toList()
              ..sort(
                (a, b) => (b.zone == 0 ? b.progress * .4 : .4 + b.progress * .6)
                    .compareTo(
                      a.zone == 0 ? a.progress * .4 : .4 + a.progress * .6,
                    ),
              );
        if (targets.isNotEmpty && m.gunCooldown <= 0) {
          final e = targets.first;
          if (m.camera != e.zone) m.selectCamera(e.zone);
          if (m.jammed) {
            m.selectedZone = e.zone;
            if (m.cooldowns[Defense.flash] == 0) m.activate(Defense.flash);
          }
          if (!m.gunMode) m.toggleGun();
          m.shoot(e.aimPoint);
        }
        m.update(.025);
        maxAlive = maxAlive < m.aliveCount ? m.aliveCount : maxAlive;
      }
      expect(
        m.phase,
        RoundPhase.won,
        reason:
            'time=${m.elapsed} power=${m.energy} kills=${m.kills} alive=${m.aliveCount}',
      );
      expect(maxAlive, lessThanOrEqualTo(m.rules.maxActive));
      expect(m.energy, greaterThanOrEqualTo(0));
      expect(m.wave, 7);
      expect(m.pendingSpawns, 0);
    });
  }
}

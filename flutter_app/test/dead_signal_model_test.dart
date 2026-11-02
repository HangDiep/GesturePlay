import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/dead_signal/model.dart';

void advance(SignalModel m, double seconds) {
  for (var t = 0.0; t < seconds - 1e-7; t += .05) {
    m.update(.05);
  }
}

void main() {
  for (final difficulty in SignalDifficulty.values) {
    test('a complete 180 second round is winnable on ${difficulty.name}', () {
      final m = SignalModel(difficulty: difficulty, advanced: false, seed: 7)
        ..start();
      for (var frame = 0; frame < 3700 && m.active; frame++) {
        for (var door = 0; door < 2; door++) {
          final danger = m.enemies.any(
            (e) => e.alive && e.zone == door + 1 && e.progress > .87,
          );
          if (m.doors[door].locked != danger && !m.doors[door].broken) {
            m.toggleDoor(door);
          }
        }
        final targets = m.enemies.where((e) => e.alive).toList()
          ..sort(
            (a, b) => (b.zone == 0 ? b.progress * .4 : .4 + b.progress * .6)
                .compareTo(
                  a.zone == 0 ? a.progress * .4 : .4 + a.progress * .6,
                ),
          );
        if (targets.isNotEmpty && m.gunCooldown <= 0) {
          final e = targets.first;
          if (m.camera != e.zone) m.selectCamera(e.zone);
          if (!m.gunMode) m.toggleGun();
          m.shoot(e.aimPoint);
        }
        m.update(.05);
        expect(m.aliveCount, lessThanOrEqualTo(m.rules.maxActive));
        expect(m.energy, greaterThanOrEqualTo(0));
      }
      expect(
        m.phase,
        RoundPhase.won,
        reason: 'time=${m.elapsed}, energy=${m.energy}, kills=${m.kills}',
      );
      expect(m.elapsed, 180);
    });
  }
  test('pause freezes time, enemies, energy and cooldowns', () {
    final m = SignalModel()..start();
    final e = m.spawn(EnemyKind.breaker, zone: 1, progress: .4);
    m.activate(Defense.flash);
    m.pause();
    final energy = m.energy,
        cd = m.cooldowns[Defense.flash],
        progress = e.progress;
    advance(m, 10);
    expect(m.elapsed, 0);
    expect(m.energy, energy);
    expect(e.progress, progress);
    expect(m.cooldowns[Defense.flash], cd);
    m.resume();
    advance(m, 1);
    expect(m.elapsed, closeTo(1, 1e-6));
  });
  test('only a powered, intact door can lock; cutting power releases it', () {
    final m = SignalModel()..start();
    m.toggleDoor(0);
    expect(m.doors[0].locked, true);
    m.power('door0', false);
    expect(m.doors[0].locked, false);
    m.toggleDoor(0, emergency: true);
    expect(m.doors[0].locked, false);
    m.power('door0', true);
    m.doors[0].health = 0;
    m.toggleDoor(0);
    expect(m.doors[0].locked, false);
  });
  test('shots consume energy once, enforce cooldown and kill once', () {
    final m = SignalModel()..start();
    final e = m.spawn(EnemyKind.runner, zone: 1, progress: .7);
    m.selectCamera(1);
    m.toggleGun();
    final energy = m.energy;
    expect(m.shoot(e.aimPoint), true);
    expect(m.shoot(e.aimPoint), false);
    expect(m.energy, energy - 2);
    expect(m.kills, 1);
    expect(m.shots, 1);
    expect(m.hits, 1);
    advance(m, 1);
    expect(m.shoot(e.aimPoint), true);
    expect(m.kills, 1);
  });
  test('last available shot still hits and blackout releases locks', () {
    final m = SignalModel()..start();
    final e = m.spawn(EnemyKind.runner, zone: 1, progress: .5);
    m.selectCamera(1);
    m.toggleDoor(0);
    m.toggleGun();
    m.energy = 2;
    expect(m.shoot(e.aimPoint), true);
    expect(e.alive, false);
    expect(m.energy, 0);
    expect(m.doors[0].locked, false);
    expect(m.phase, RoundPhase.playing);
    m.toggleDoor(0);
    expect(m.doors[0].locked, false);
  });
  test('missed trap costs power and has a cooldown', () {
    final m = SignalModel()..start();
    final energy = m.energy;
    expect(m.activate(Defense.trap), true);
    expect(m.energy, energy - 9);
    expect(m.activate(Defense.trap), false);
    expect(m.energy, energy - 9);
  });
  test(
    'flash and trap affect only enemies in selected region and trap range',
    () {
      final m = SignalModel()..start();
      final a = m.spawn(EnemyKind.runner, zone: 1, progress: .6);
      final b = m.spawn(EnemyKind.breaker, zone: 2, progress: .6);
      final outside = m.spawn(EnemyKind.runner, zone: 1, progress: .1);
      m.selectedZone = 1;
      m.activate(Defense.trap);
      expect(a.stunnedFor, 5);
      expect(b.stunnedFor, 0);
      expect(outside.stunnedFor, 0);
      final before = a.progress;
      advance(m, 1);
      expect(a.progress, before);
    },
  );
  test('jammer hides camera targets until stunned or moved', () {
    final m = SignalModel()..start();
    m.spawn(EnemyKind.jammer, zone: 1, progress: .6);
    m.selectCamera(1);
    expect(m.jammed, true);
    expect(m.visibleEnemies, isEmpty);
    m.activate(Defense.flash);
    expect(m.jammed, false);
    expect(m.visibleEnemies.length, 1);
  });
  test('boss armor reduces damage and weak point takes full damage', () {
    final m = SignalModel()..start();
    final e = m.spawn(EnemyKind.boss, zone: 1, progress: .5);
    m.selectCamera(1);
    m.toggleGun();
    m.shoot(e.aimPoint);
    expect(e.health, 285);
    advance(m, 1);
    e.weakFor = 2;
    m.shoot(e.aimPoint);
    expect(e.health, 240);
  });
  test('unlocked door causes defeat, locked door takes damage first', () {
    final lost = SignalModel()..start();
    lost.spawn(EnemyKind.runner, zone: 1, progress: 1);
    advance(lost, 1.5);
    expect(lost.phase, RoundPhase.lost);
    final defended = SignalModel()..start();
    defended.toggleDoor(0);
    defended.spawn(EnemyKind.breaker, zone: 1, progress: 1);
    advance(defended, 1.7);
    expect(defended.active, true);
    expect(defended.doors[0].health, 93);
  });
  test(
    'limited reinforcement increases durability but cannot repair a broken door',
    () {
      final m = SignalModel()..start();
      m.selectDoor(1);
      expect(m.activate(Defense.reinforce), true);
      expect(m.doors[1].health, 170);
      m.activate(Defense.reinforce);
      expect(m.reinforcements, 0);
      expect(m.activate(Defense.reinforce), false);
      final broken = SignalModel()..start();
      broken.doors[0].health = 0;
      expect(broken.activate(Defense.reinforce), false);
      expect(broken.reinforcements, 2);
    },
  );
  test('silence disables observation and weapon and stops decoy', () {
    final m = SignalModel()..start();
    m.activate(Defense.decoy);
    m.toggleGun();
    m.activate(Defense.silence);
    expect(m.cameraOnline, false);
    expect(m.gunMode, false);
    expect(m.decoyFor, 0);
    m.toggleGun();
    expect(m.gunMode, false);
    expect(m.activate(Defense.decoy), false);
    m.activate(Defense.silence);
    expect(m.cameraOnline, true);
  });
  test(
    'decoy draws approaching enemies away and cannot distract an attacker',
    () {
      final m = SignalModel()..start();
      final e = m.spawn(EnemyKind.breaker, zone: 1, progress: .6);
      m.selectedZone = 0;
      m.activate(Defense.decoy);
      advance(m, 1);
      expect(e.progress, lessThan(.6));
      final attack = m.spawn(EnemyKind.breaker, zone: 2, progress: 1)
        ..state = EnemyState.attacking;
      m.toggleDoor(1);
      advance(m, .5);
      expect(attack.zone, 2);
      expect(attack.progress, 1);
    },
  );
  test('barrier reroutes an approaching creature and refuses central zone', () {
    final m = SignalModel()..start();
    m.selectedZone = 0;
    final energy = m.energy;
    expect(m.activate(Defense.barrier), false);
    expect(m.energy, energy);
    m.selectedZone = 1;
    m.activate(Defense.barrier);
    final e = m.spawn(EnemyKind.runner, zone: 1, progress: .7);
    advance(m, .1);
    expect(e.zone, 1);
    expect(e.progress, lessThan(.7));
    advance(m, 12);
    expect(e.zone, 2);
  });
  test(
    'winning stops at exactly 180 active seconds; abandoned is not a victory',
    () {
      final m = SignalModel()..start();
      m.elapsed = 179.9;
      // Every existing enemy is held in the central hall by a decoy.
      m.selectedZone = 0;
      m.activate(Defense.decoy);
      advance(m, 1);
      expect(m.phase, RoundPhase.won);
      expect(m.elapsed, 180);
      final energy = m.energy;
      advance(m, 2);
      expect(m.energy, energy);
      expect(m.result().outcome, RoundPhase.won);
      final abandoned = SignalModel()
        ..start()
        ..abandon();
      expect(abandoned.result().outcome, RoundPhase.abandoned);
    },
  );
  test(
    'advanced waves contain jammer and boss, basic waves stay at two kinds',
    () {
      for (final advanced in [false, true]) {
        final m = SignalModel(advanced: advanced)..start();
        final kinds = <EnemyKind>{};
        for (var i = 0; i < 1300; i++) {
          m.enemies.clear();
          m.update(.1);
          kinds.addAll(m.enemies.map((e) => e.kind));
        }
        expect(kinds.contains(EnemyKind.runner), true);
        expect(kinds.contains(EnemyKind.breaker), true);
        expect(kinds.contains(EnemyKind.jammer), advanced);
        expect(kinds.contains(EnemyKind.boss), advanced);
      }
    },
  );
  test('actions after pause or finish cannot spend resources', () {
    final m = SignalModel()
      ..start()
      ..pause();
    final energy = m.energy;
    m.toggleDoor(0);
    m.activate(Defense.trap);
    m.shoot(const Offset(.5, .5));
    expect(m.energy, energy);
    expect(m.doors[0].locked, false);
    m.resume();
    expect(() => m.update(double.nan), throwsArgumentError);
  });
}

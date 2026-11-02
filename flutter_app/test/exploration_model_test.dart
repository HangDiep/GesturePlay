import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/exploration/painter.dart';
import 'package:gestureplay/exploration/hand_input.dart';
import 'package:gestureplay/services/hand_bridge.dart';

void advance(ExplorationModel m, double seconds) {
  for (var t = 0.0; t < seconds - 1e-8; t += .025) {
    m.update(.025);
  }
}

void main() {
  for (final id in FieldMap.values) {
    test(
      '${id.name}: a full three-minute mission can be completed with normal resources',
      () {
        final m = ExplorationModel(id, seed: 17)..start();
        final goals = [...m.world.cores, FieldWorld.extraction];
        var goal = 0, step = 0;
        var path = m.world.route(m.player, goals.first);
        for (var frame = 0; frame < 7600 && m.active; frame++) {
          if (goal < goals.length) {
            if ((m.player - goals[goal]).distance < 30) {
              goal++;
              step = 0;
              path = goal < goals.length
                  ? m.world.route(m.player, goals[goal])
                  : [];
            }
            if (goal < goals.length) {
              while (step < path.length &&
                  (path[step] - m.player).distance < 8) {
                step++;
              }
              final target = step < path.length ? path[step] : goals[goal];
              final direction = target - m.player;
              m.movement = direction.distance < 1
                  ? Offset.zero
                  : direction / direction.distance;
            } else {
              m.movement = Offset.zero;
            }
          }
          final targets =
              m.enemies
                  .where(
                    (e) =>
                        e.alive &&
                        (e.position - m.player).distance < 350 &&
                        m.world.clearLine(m.player, e.position),
                  )
                  .toList()
                ..sort(
                  (a, b) => (a.position - m.player).distance.compareTo(
                    (b.position - m.player).distance,
                  ),
                );
          if (targets.isNotEmpty) {
            m.aim = targets.first.position;
            m.shoot(m.aim);
            if (targets.any(
              (e) =>
                  (e.charge > 0 || e.kind == CreatureKind.jammer) &&
                  (e.position - m.player).distance < 230,
            )) {
              m.flash();
            }
          } else if (m.ammo < 24) {
            m.reload();
          }
          m.update(.025);
        }
        expect(
          m.phase,
          FieldPhase.won,
          reason:
              'elapsed=${m.elapsed} health=${m.health} cores=${m.cores} kills=${m.kills} ammo=${m.ammo}/${m.reserve} player=${m.player} goal=$goal',
        );
        expect(m.wave, 5);
        expect(m.cores, 3);
        expect(m.elapsed, greaterThanOrEqualTo(180));
        expect(m.ammo + m.reserve, greaterThanOrEqualTo(0));
      },
    );
  }
  for (final id in FieldMap.values) {
    test(
      '${id.name}: objectives and supplies are reachable through real map obstacles',
      () {
        final w = FieldWorld(id);
        expect(w.walkable(FieldWorld.spawn), true);
        expect(w.walkable(FieldWorld.extraction), true);
        for (final target in [...w.cores, ...w.supplies]) {
          final path = w.route(FieldWorld.spawn, target);
          expect(path, isNotEmpty, reason: 'No route to $target in ${id.name}');
          expect((path.last - target).distance, lessThan(40));
          var previous = FieldWorld.spawn;
          for (final point in path) {
            expect(w.walkable(point, 23), true);
            expect(
              w.clearLine(previous, point, 16),
              true,
              reason: '$previous -> $point',
            );
            previous = point;
          }
        }
      },
    );
  }
  test(
    'diagonal motion is normalized and solid houses stop walking and rolling',
    () {
      final straight = ExplorationModel(FieldMap.town)
        ..start()
        ..movement = const Offset(1, 0);
      final diagonal = ExplorationModel(FieldMap.town)
        ..start()
        ..movement = const Offset(1, 1);
      advance(straight, .5);
      advance(diagonal, .5);
      expect(
        (straight.player - FieldWorld.spawn).distance,
        closeTo((diagonal.player - FieldWorld.spawn).distance, .01),
      );
      final m = ExplorationModel(FieldMap.town)
        ..start()
        ..player = const Offset(230, 600)
        ..movement = const Offset(1, 0);
      advance(m, 1);
      expect(m.player.dx, lessThan(245));
      m.roll();
      advance(m, .5);
      expect(m.world.walkable(m.player), true);
      expect(m.player.dx, lessThan(245));
    },
  );
  test(
    'continuous bullet collision hits the target once and walls block damage',
    () {
      final clear = ExplorationModel(FieldMap.town)
        ..start()
        ..player = const Offset(1100, 1500);
      final enemy = clear.spawn(
        CreatureKind.runner,
        at: const Offset(1100, 1350),
      )..stun = 3;
      expect(clear.shoot(enemy.position), true);
      advance(clear, .2);
      expect(enemy.health, 17);
      expect(clear.hits, 1);
      expect(clear.ammo, 23);
      final blocked = ExplorationModel(FieldMap.town)
        ..start()
        ..player = const Offset(550, 950);
      final behind = blocked.spawn(
        CreatureKind.runner,
        at: const Offset(950, 950),
      )..stun = 3;
      blocked.shoot(behind.position);
      advance(blocked, .5);
      expect(behind.health, 45);
      expect(blocked.hits, 0);
    },
  );
  test(
    'reload waits and transfers available reserve without creating rounds',
    () {
      final m = ExplorationModel(FieldMap.forest)
        ..start()
        ..ammo = 3
        ..reserve = 8;
      m.reload();
      expect(m.shoot(m.player - const Offset(0, 100)), false);
      advance(m, 1);
      expect(m.ammo, 3);
      advance(m, .7);
      expect(m.ammo, 11);
      expect(m.reserve, 0);
    },
  );
  test(
    'boss announces a strike and exposes weakness; stun interrupts charging',
    () {
      final m = ExplorationModel(FieldMap.town)..start();
      final boss = m.spawn(
        CreatureKind.boss,
        at: m.player - const Offset(0, 90),
      );
      advance(m, .1);
      expect(boss.charge, greaterThan(1));
      expect(m.health, 100);
      expect(m.hit(boss, 30), 10);
      expect(boss.charge, greaterThan(0));
      advance(m, 1.4);
      expect(m.health, 68);
      expect(boss.weak, greaterThan(3));
      expect(m.hit(boss, 30), 30);
      boss.weak = 0;
      boss.attack = 0;
      advance(m, .1);
      expect(boss.charge, greaterThan(0));
      m.flash();
      expect(boss.charge, 0);
      expect(boss.stun, greaterThan(1));
    },
  );
  test('enemy paths go around buildings and cannot attack through cover', () {
    final m = ExplorationModel(FieldMap.town)
      ..start()
      ..player = const Offset(950, 950);
    final enemy = m.spawn(CreatureKind.runner, at: const Offset(550, 950));
    advance(m, 6);
    expect(m.world.walkable(enemy.position, enemy.radius), true);
    expect((enemy.position - m.player).distance, lessThan(150));
    expect(enemy.position.dx, greaterThan(850));
    final cover = ExplorationModel(FieldMap.town)
      ..start()
      ..player = const Offset(590, 950);
    cover.spawn(CreatureKind.heavy, at: const Offset(860, 950));
    advance(cover, 1);
    expect(cover.health, 100);
  });
  test(
    'jammer dies immediately for gameplay, then finishes a timed death animation',
    () {
      final m = ExplorationModel(FieldMap.town)..start();
      final jammer = m.spawn(
        CreatureKind.jammer,
        at: m.player + const Offset(80, 0),
      );
      expect(m.jammed, true);
      m.hit(jammer, 100);
      expect(m.jammed, false);
      expect(m.kills, 1);
      expect(jammer.death, greaterThan(0));
      m.hit(jammer, 100);
      expect(m.kills, 1);
      advance(m, 1);
      expect(m.enemies, isNot(contains(jammer)));
    },
  );
  test('trap stuns pursuers and cannot bypass inventory or cooldown', () {
    final m = ExplorationModel(FieldMap.town)..start();
    final runner = m.spawn(
      CreatureKind.runner,
      at: m.player + const Offset(50, 0),
    );
    expect(m.trap(), true);
    expect(m.trap(), false);
    advance(m, .1);
    expect(runner.stun, greaterThan(3));
    expect(m.traps, 2);
    expect(m.effects.where((e) => e.kind == 'trap'), isEmpty);
  });
  test('pause freezes movement, rounds, timers and visual effects', () {
    final m = ExplorationModel(FieldMap.forest)
      ..start()
      ..movement = const Offset(0, -1);
    m.trap();
    m.shoot(m.player - const Offset(0, 200));
    m.reload();
    advance(m, .1);
    m.pause();
    final position = m.player,
        elapsed = m.elapsed,
        reload = m.reloadFor,
        effect = m.effects.first.life;
    advance(m, 10);
    expect(m.player, position);
    expect(m.elapsed, elapsed);
    expect(m.reloadFor, reload);
    expect(m.effects.first.life, effect);
    m.resume();
    advance(m, .1);
    expect(m.elapsed, greaterThan(elapsed));
  });
  for (final id in FieldMap.values) {
    test(
      '${id.name}: three real pickups and return to extraction win the round',
      () {
        final m = ExplorationModel(id)..start();
        m.player = FieldWorld.extraction;
        advance(m, .1);
        expect(m.phase, FieldPhase.playing);
        for (final core in m.items.where((i) => i.kind == 'core')) {
          m.player = core.position;
          advance(m, .1);
        }
        expect(m.cores, 3);
        m.player = FieldWorld.extraction;
        advance(m, .1);
        expect(m.phase, FieldPhase.playing);
        m.elapsed = ExplorationModel.rescueAt;
        advance(m, .1);
        expect(m.phase, FieldPhase.won);
      },
    );
  }
  test(
    'factory contamination damages player; other maps have no contamination',
    () {
      final m = ExplorationModel(FieldMap.factory)
        ..start()
        ..player = const Offset(630, 650);
      advance(m, 1);
      expect(m.health, closeTo(91, .01));
      expect(FieldWorld(FieldMap.forest).hazards, isEmpty);
    },
  );
  test(
    'enemy cap queues later waves instead of dropping configured creatures',
    () {
      final m = ExplorationModel(FieldMap.forest)
        ..start()
        ..elapsed = 89;
      advance(m, .3);
      expect(m.wave, 4);
      expect(m.aliveCount, 9);
      m.elapsed = 121;
      advance(m, .1);
      expect(m.pending.length, 3);
      m.hit(m.enemies.first, 1000);
      advance(m, .1);
      expect(m.aliveCount, 9);
      expect(m.pending.length, 2);
    },
  );
  test(
    'world/screen projection stays reversible while the view follows the player',
    () {
      final a = FieldViewport(const Offset(1100, 1000), const Size(1280, 600));
      final b = FieldViewport(const Offset(1100, 700), const Size(1280, 600));
      expect(
        a.unproject(a.project(const Offset(1400, 650))),
        const Offset(1400, 650),
      );
      expect(a.origin.dy, greaterThan(b.origin.dy));
    },
  );
  test(
    'hand movement, pinch aim, fist reload and lost tracking drive the new game',
    () {
      var time = 0;
      final hand = HandBridge(autoLaunch: false, clock: () => time);
      addTearDown(hand.dispose);
      var sequence = 0;
      void packet(
        double x,
        double y, {
        bool pinched = false,
        bool fist = false,
      }) {
        hand.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'test',
          'seq': ++sequence,
          'jump_id': 0,
          'age_ms': 0,
          'valid': true,
          'ready': true,
          'released': !pinched,
          'pinched': pinched,
          'fist': fist,
          'palm_x': x,
          'palm_y': y,
        });
      }

      final m = ExplorationModel(FieldMap.forest)
        ..start()
        ..ammo = 10;
      final input = FieldHandInput();
      packet(.5, .5);
      input.apply(m, hand);
      packet(.7, .5);
      input.apply(m, hand);
      expect(m.movement.dx, greaterThan(0));
      packet(.5, .3, pinched: true);
      input.apply(m, hand);
      expect(m.firing, true);
      expect(m.movement, Offset.zero);
      expect(m.aim.dy, lessThan(m.player.dy));
      packet(.5, .5, fist: true);
      input.apply(m, hand);
      expect(m.firing, false);
      expect(m.reloadFor, greaterThan(0));
      time += 300;
      input.apply(m, hand);
      expect(m.phase, FieldPhase.paused);
      expect(m.firing, false);
      expect(m.movement, Offset.zero);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/hand_input.dart';

ExplorationModel town() =>
    ExplorationModel(FieldMap.town, seed: 17, survival: true)..start();

void main() {
  test(
    'pinch jump packets never roll; an open palm flick rolls once until neutral',
    () {
      final m = town();
      final hand = HandBridge(autoLaunch: false, clock: () => 0);
      addTearDown(hand.dispose);
      final input = TownHandInput();
      var seq = 0;
      void packet(double y, {bool pinch = false, int jump = 0}) {
        hand.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'flick',
          'seq': ++seq,
          'jump_id': jump,
          'valid': true,
          'ready': true,
          'age_ms': 0,
          'released': !pinch,
          'pinched': pinch,
          'palm_x': .5,
          'palm_y': y,
        });
        input.apply(m, hand, .1);
      }

      packet(.5);
      packet(.3, pinch: true, jump: 1);
      expect(m.firing, true);
      expect(m.rollFor, 0);
      packet(.5);
      packet(.3);
      expect(m.rollFor, greaterThan(0));
      m.rollFor = m.rollCooldown = 0;
      packet(.25);
      input.apply(m, hand, .1);
      expect(m.rollFor, 0);
      packet(.5);
      packet(.3);
      expect(m.rollFor, greaterThan(0));
    },
  );
  test('all town supplies and optional cores have navigable routes', () {
    final m = town();
    expect(m.world.walkable(m.player), true);
    for (final item in m.items) {
      expect(
        m.world.walkable(item.position, 24),
        true,
        reason: '${item.kind} ${item.position}',
      );
      final path = m.world.route(m.player, item.position);
      expect(path, isNotEmpty, reason: '${item.kind} ${item.position}');
      var last = m.player;
      for (final p in path) {
        expect(m.world.clearLine(last, p, 16), true, reason: '$last -> $p');
        last = p;
      }
    }
  });

  test('survival wins on time without cores or returning to extraction', () {
    final m = town()
      ..elapsed = 179.99
      ..wave = 5;
    m.update(.025);
    expect(m.phase, FieldPhase.won);
    expect(m.cores, 0);
    expect(m.elapsed, 180);
    final score = m.score;
    m.update(1);
    expect(m.score, score);
  });

  test(
    'fatal attack at the deadline defeats time completion and freezes combat',
    () {
      final m = town()
        ..elapsed = 179.99
        ..wave = 5
        ..health = 5
        ..firing = true;
      m.spawn(CreatureKind.runner, at: m.player + const Offset(25, 0))
        ..windup = .01
        ..attackId = 1;
      m.update(.025);
      expect(m.phase, FieldPhase.lost);
      expect(m.health, 0);
      expect(m.firing, false);
      expect(m.movement, Offset.zero);
      expect(m.dyingFor, greaterThan(0));
      final time = m.elapsed;
      final ammo = m.ammo;
      for (var i = 0; i < 10; i++) {
        m.update(.1);
      }
      expect(m.dyingFor, 0);
      expect(m.elapsed, time);
      expect(m.ammo, ammo);
      expect(m.shoot(m.player + const Offset(100, 0)), false);
    },
  );

  test('bullets kill a creature once and dead creatures cannot attack', () {
    final m = town();
    final enemy = m.spawn(
      CreatureKind.runner,
      at: m.player + const Offset(110, 0),
    )..stun = 3;
    m.shoot(enemy.position);
    for (var i = 0; i < 9; i++) {
      m.update(.025);
    }
    expect(enemy.health, 17);
    m.shoot(enemy.position);
    for (var i = 0; i < 9; i++) {
      m.update(.025);
    }
    expect(enemy.alive, false);
    expect(m.kills, 1);
    expect(m.hit(enemy, 100), 0);
    expect(m.kills, 1);
    final hp = m.health;
    enemy.position = m.player;
    m.update(.1);
    expect(m.health, hp);
  });

  test(
    'damage IDs deduplicate attacks and rolling does not ignore hazards',
    () {
      final m = town();
      m.hurt(8, sourceId: 1, attackId: 1);
      m.invulnerableFor = 0;
      m.hurt(8, sourceId: 1, attackId: 1);
      expect(m.health, 92);
      m.hurt(8, sourceId: 1, attackId: 2);
      expect(m.health, 84);
      m.roll();
      m.hurt(8);
      expect(m.health, 84);
      m.hurt(9, isHazard: true);
      expect(m.health, 75);
    },
  );

  test(
    'pause freezes countdown, telegraphs, reload and temporary immunity',
    () {
      final m = town()..ammo = 10;
      m.reload();
      m.hurt(8);
      final e = m.spawn(CreatureKind.runner, at: m.player + const Offset(25, 0))
        ..windup = .25;
      final reload = m.reloadFor;
      m.pause();
      m.update(.25);
      expect(m.elapsed, 0);
      expect(e.windup, .25);
      expect(m.reloadFor, reload);
      expect(m.invulnerableFor, .45);
    },
  );

  test(
    'a complete town run is winnable using only the gun, normal supplies and movement',
    () {
      final m = town();
      final goals = [...m.world.cores, ...m.world.supplies, FieldWorld.spawn];
      var goal = 0, step = 0;
      var path = m.world.route(m.player, goals.first);
      for (var frame = 0; frame < 7400 && m.active; frame++) {
        if (goal < goals.length) {
          if ((m.player - goals[goal]).distance < 30) {
            goal++;
            if (goal == goals.length) goal = 0;
            step = 0;
            path = goal < goals.length
                ? m.world.route(m.player, goals[goal])
                : [];
          }
          if (goal < goals.length) {
            while (step < path.length && (m.player - path[step]).distance < 8) {
              step++;
            }
            final delta =
                (step < path.length ? path[step] : goals[goal]) - m.player;
            m.movement = delta.distance < 1
                ? Offset.zero
                : delta / delta.distance;
          } else {
            m.movement = Offset.zero;
          }
        }
        final enemies =
            m.enemies
                .where(
                  (e) =>
                      e.alive &&
                      (e.position - m.player).distance < 420 &&
                      m.world.clearLine(m.player, e.position),
                )
                .toList()
              ..sort(
                (a, b) => (a.position - m.player).distance.compareTo(
                  (b.position - m.player).distance,
                ),
              );
        if (enemies.isNotEmpty) {
          m.shoot(enemies.first.position);
        } else if (m.ammo < 24) {
          m.reload();
        }
        m.update(.025);
      }
      expect(
        m.phase,
        FieldPhase.won,
        reason:
            'hp=${m.health}, time=${m.elapsed}, kills=${m.kills}, ammo=${m.ammo}/${m.reserve}',
      );
      expect(m.wave, 5);
      expect(m.health, greaterThan(0));
      expect(m.kills, greaterThan(8));
    },
  );

  test(
    'short fist reloads on release; long fist only selects a skill; stale tracking pauses',
    () {
      var time = 0, seq = 0;
      final bridge = HandBridge(autoLaunch: false, clock: () => time);
      addTearDown(bridge.dispose);
      final input = TownHandInput();
      final m = town()..ammo = 10;
      void packet({bool fist = false, bool pinch = false, double x = .5}) {
        bridge.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'town',
          'seq': ++seq,
          'jump_id': 0,
          'valid': true,
          'ready': true,
          'age_ms': 0,
          'released': !fist && !pinch,
          'fist': fist,
          'pinched': pinch,
          'palm_x': x,
          'palm_y': .5,
        });
      }

      packet();
      input.apply(m, bridge, .1);
      packet(fist: true);
      input.apply(m, bridge, .2);
      expect(m.reloadFor, 0);
      packet();
      input.apply(m, bridge, .1);
      expect(m.reloadFor, 1.65);
      m.reloadFor = 0;
      for (var i = 0; i < 9; i++) {
        packet(fist: true);
        input.apply(m, bridge, .1);
      }
      expect(input.wheelOpen, true);
      expect(m.phase, FieldPhase.paused);
      expect(m.reloadFor, 0);
      packet(pinch: true, x: .4);
      input.apply(m, bridge, .1);
      packet(x: .4);
      input.apply(m, bridge, .1);
      expect(input.waitingRelease, true);
      input.apply(m, bridge, .1);
      expect(m.phase, FieldPhase.playing);
      expect(m.flashes, 0);
      expect(m.reloadFor, 1.65);
      expect(m.firing, false);
      input.apply(m, bridge, .1);
      expect(m.movement, Offset.zero);
      expect(m.firing, false);
      time = 300;
      input.apply(m, bridge, .1);
      expect(m.phase, FieldPhase.paused);
      packet();
      input.apply(m, bridge, .1);
      expect(m.phase, FieldPhase.paused);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/hand_input.dart';

ExplorationModel town() =>
    ExplorationModel(FieldMap.town, survival: true, seed: 27)
      ..start()
      ..wave = 5;
void advance(ExplorationModel m, double seconds) {
  for (var n = 0; n < (seconds / .025).ceil(); n++) {
    m.update(.025);
  }
}

void main() {
  test(
    'standing, crouch and prone have different movement speeds and only standing can sprint',
    () {
      final distances = <double>[];
      for (final pose in PlayerStance.values) {
        final m = town();
        if (pose != PlayerStance.standing) {
          m.setStance(pose);
          advance(m, .6);
        }
        final start = m.player;
        m.movement = const Offset(0, -1);
        m.sprinting = true;
        advance(m, .5);
        distances.add((m.player - start).distance);
        expect(m.running, pose == PlayerStance.standing);
      }
      expect(distances[0], closeTo(140, .1));
      expect(distances[1], closeTo(52.5, .1));
      expect(distances[2], closeTo(27.5, .1));
    },
  );

  for (final pose in PlayerStance.values) {
    test('${pose.name} can aim, fire and reload without changing posture', () {
      final m = town();
      if (pose != PlayerStance.standing) {
        m.setStance(pose);
        advance(m, .6);
      }
      final e = m.spawn(
        CreatureKind.runner,
        at: m.player - const Offset(0, 120),
      )..stun = 4;
      expect(m.shoot(e.position), true);
      advance(m, .2);
      expect(e.health, 17);
      expect(m.ammo, 23);
      expect(m.stance, pose);
      m.reload();
      advance(m, 1.7);
      expect(m.ammo, 24);
      expect(m.reserve, 119);
      expect(m.stance, pose);
    });
  }

  test('crouch reduces sight range and prone is less visible still', () {
    HuntState detect(PlayerStance pose, double distance) {
      final m = town();
      if (pose != PlayerStance.standing) {
        m.setStance(pose);
        advance(m, .6);
      }
      final e = m.spawn(
        CreatureKind.runner,
        at: m.player - Offset(0, distance),
      );
      m.update(.025);
      return e.huntState;
    }

    expect(detect(PlayerStance.standing, 420), HuntState.chase);
    expect(detect(PlayerStance.crouching, 420), HuntState.patrol);
    expect(detect(PlayerStance.crouching, 290), HuntState.chase);
    expect(detect(PlayerStance.prone, 290), HuntState.patrol);
  });

  test(
    'crouching behind a low wall conceals the body, firing peeks over it',
    () {
      final m = town()..player = const Offset(480, 510);
      final enemyAt = const Offset(480, 360);
      expect(m.world.clearSight(enemyAt, m.player, lowProfile: false), true);
      expect(m.world.clearSight(enemyAt, m.player, lowProfile: true), false);
      m.setStance(PlayerStance.crouching);
      advance(m, .3);
      final e = m.spawn(CreatureKind.runner, at: enemyAt);
      m.update(.025);
      expect(m.usingLowCover, true);
      expect(e.huntState, HuntState.patrol);
      e.stun = 4;
      expect(m.shoot(e.position), true);
      expect(m.lowProfile, false);
      advance(m, .2);
      expect(e.health, 17);
      expect(m.stance, PlayerStance.crouching);
      expect(
        m.world.clearLine(enemyAt, m.player),
        false,
        reason: 'Cover still blocks walking/melee',
      );
    },
  );

  test('low obstacles stop a prone shot but do not stop a standing shot', () {
    for (final pose in [PlayerStance.prone, PlayerStance.standing]) {
      final m = town()..player = const Offset(480, 510);
      if (pose != PlayerStance.standing) {
        m.setStance(pose);
        advance(m, .6);
      }
      final e = m.spawn(CreatureKind.runner, at: const Offset(480, 360))
        ..stun = 4;
      m.shoot(e.position);
      advance(m, .25);
      expect(e.health, pose == PlayerStance.prone ? 45 : 17);
      expect(m.ammo, 23);
    }
  });

  test(
    'prone blends into vegetation, but close creatures and gunshots expose the player',
    () {
      final m = town();
      m.player = m.world.hidingSpots.first.center;
      m.setStance(PlayerStance.prone);
      advance(m, .6);
      expect(m.inVegetation, true);
      final e = m.spawn(
        CreatureKind.runner,
        at: m.player - const Offset(0, 180),
      );
      m.update(.025);
      expect(e.huntState, HuntState.patrol);
      expect(
        m.hidden,
        false,
        reason: 'A stance is distinct from explicit hiding',
      );
      m.shoot(m.player + const Offset(120, 0));
      m.update(.025);
      expect(e.huntState, HuntState.chase);
      expect(m.visionMultiplier, 1);
      m.hurt(8);
      expect(m.health, 92);
    },
  );

  test(
    'prone must get up before rolling and is vulnerable during that delay',
    () {
      final m = town();
      m.setStance(PlayerStance.prone);
      advance(m, .6);
      expect(m.roll(), false);
      expect(m.stance, PlayerStance.standing);
      expect(m.stanceFor, greaterThan(.5));
      expect(m.rollFor, 0);
      expect(m.roll(), false);
      m.hurt(8);
      expect(m.health, 92);
      advance(m, .6);
      expect(m.roll(), true);
    },
  );

  test('posture transitions freeze on pause and cannot change after death', () {
    final m = town();
    m.setStance(PlayerStance.prone);
    m.pause();
    final transition = m.stanceFor;
    m.update(.25);
    expect(m.stanceFor, transition);
    expect(m.setStance(PlayerStance.standing), false);
    m.resume();
    advance(m, .6);
    m.hurt(1000);
    expect(m.setStance(PlayerStance.standing), false);
    expect(m.shoot(m.player + const Offset(100, 0)), false);
  });

  test(
    'one-hand skill wheel selects a posture without firing or moving on resume',
    () {
      final m = town();
      final bridge = HandBridge(autoLaunch: false, clock: () => 0);
      addTearDown(bridge.dispose);
      final input = TownHandInput();
      var seq = 0;
      void sample({double y = .5, bool fist = false, bool pinch = false}) {
        bridge.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'posture',
          'seq': ++seq,
          'jump_id': 0,
          'age_ms': 0,
          'valid': true,
          'ready': true,
          'released': !fist && !pinch,
          'pinched': pinch,
          'fist': fist,
          'palm_x': .5,
          'palm_y': y,
        });
        input.apply(m, bridge, .1);
      }

      sample();
      for (var i = 0; i < 9; i++) {
        sample(fist: true);
      }
      expect(input.wheelOpen, true);
      sample(y: .65);
      expect(input.selection, 4);
      sample(y: .65, pinch: true);
      sample(y: .65);
      sample(y: .65);
      expect(m.active, true);
      expect(m.stance, PlayerStance.crouching);
      expect(m.firing, false);
      expect(m.movement, Offset.zero);
      expect(m.ammo, 24);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/survival/rules.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/hand_input.dart';

ExplorationModel town() => ExplorationModel(FieldMap.town, survival: true)
  ..start()
  ..wave = 5;
void advance(ExplorationModel m, double seconds) {
  for (var t = 0.0; t < seconds - 1e-8; t += .025) {
    m.update(.025);
  }
}

Creature caster(ExplorationModel m, {bool boss = false}) => m.spawn(
  boss ? CreatureKind.boss : CreatureKind.jammer,
  at: m.player - const Offset(0, 300),
);

void main() {
  test(
    'different attacks still hurt if an older projectile arrives after a newer attack',
    () {
      final m = town();
      for (final id in [2, 1, 2]) {
        m.invulnerableFor = 0;
        m.enemyBolts.add(
          EnemyMagicBolt(
            m.player - const Offset(0, 20),
            const Offset(0, 1),
            sourceId: 5,
            attackId: id,
            boss: false,
          ),
        );
        m.update(.025);
      }
      expect(m.health, 72);
    },
  );
  test(
    'the hand wheel selects a physical dodge, with no magic or accidental shot',
    () {
      final m = town(), hand = HandBridge(autoLaunch: false, clock: () => 0);
      addTearDown(hand.dispose);
      final input = TownHandInput();
      var seq = 0;
      void sample({double x = .5, bool fist = false, bool pinch = false}) {
        hand.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'gun-only',
          'seq': ++seq,
          'jump_id': 0,
          'age_ms': 0,
          'valid': true,
          'ready': true,
          'released': !fist && !pinch,
          'fist': fist,
          'pinched': pinch,
          'palm_x': x,
          'palm_y': .5,
        });
        input.apply(m, hand, .1);
      }

      sample();
      for (var i = 0; i < 9; i++) {
        sample(fist: true);
      }
      expect(input.wheelOpen, true);
      sample(x: .65, pinch: true);
      sample(x: .65);
      sample(x: .65);
      expect(m.active, true);
      expect(m.rollFor, greaterThan(0));
      expect(m.firing, false);
      expect(m.ammo, 24);
      expect(m.flashes, 0);
      expect(m.traps, 0);
      expect(
        m.effects.where((e) => e.kind == 'trap' || e.kind == 'flash'),
        isEmpty,
      );
    },
  );

  test(
    'humans only have the gun; old defensive abilities cannot be activated',
    () {
      final m = town();
      expect(m.flashes, 0);
      expect(m.traps, 0);
      m.flashes = m.traps = 9;
      expect(m.flash(), false);
      expect(m.trap(), false);
      expect(m.effects, isEmpty);
      final e = caster(m);
      m.shoot(e.position);
      advance(m, .4);
      expect(m.ammo, 23);
      expect(e.health, 42);
    },
  );

  test(
    'caster warns first then shoots a visible, damaging projectile from range',
    () {
      final m = town(), e = caster(m);
      m.update(.025);
      expect(e.casting, true);
      expect(e.castTarget, m.player);
      expect(m.magicThreat, true);
      expect(m.enemyBolts, isEmpty);
      expect(m.health, 100);
      advance(m, .7);
      expect(m.enemyBolts, isEmpty);
      expect(m.health, 100);
      advance(m, .3);
      expect(m.enemyBolts, hasLength(1));
      expect(m.health, 100);
      expect(e.magicCooldown, greaterThan(4));
      advance(m, 1.1);
      expect(m.health, 86);
      expect(m.enemyBolts, isEmpty);
      expect(m.magicSound, 'magic_hit');
      expect(e.casting, false);
    },
  );

  test('locked aim does not follow a player who sidesteps during charging', () {
    final m = town(), e = caster(m);
    m.update(.025);
    final target = e.castTarget;
    m.player += const Offset(180, 0);
    expect(m.world.walkable(m.player), true);
    advance(m, 1);
    expect(target, FieldWorld.spawn);
    expect(m.enemyBolts.single.direction.dx, closeTo(0, .00001));
    expect(m.enemyBolts.single.direction.dy, closeTo(1, .00001));
    advance(m, 1.3);
    expect(m.health, 100);
  });

  test(
    'shooting interrupts a regular caster; killing stops unfinished spells',
    () {
      final m = town(), e = caster(m);
      m.update(.025);
      expect(e.casting, true);
      m.shoot(e.position);
      advance(m, .4);
      expect(e.casting, false);
      expect(e.magicCooldown, greaterThan(1));
      advance(m, .8);
      expect(m.enemyBolts, isEmpty);
      e.magicCooldown = 0;
      m.update(.025);
      expect(e.casting, true);
      m.hit(e, 1000);
      expect(e.alive, false);
      expect(e.casting, false);
      advance(m, 1.5);
      expect(m.enemyBolts, isEmpty);
      expect(m.kills, 1);
    },
  );

  test(
    'boss armor resists interruption and a three-bolt volley opens its weak point',
    () {
      final m = town(), e = caster(m, boss: true);
      m.update(.025);
      expect(e.casting, true);
      expect(m.hit(e, 30), 10);
      expect(e.casting, true);
      advance(m, 1.3);
      expect(m.enemyBolts, hasLength(3));
      expect(m.enemyBolts.map((b) => b.attackId).toSet(), hasLength(1));
      expect(e.weak, greaterThan(2));
      expect(m.hit(e, 28), 28);
      expect(
        m.enemyBolts.map((b) => b.direction.dx).reduce((a, b) => a + b),
        closeTo(0, .00001),
      );
    },
  );

  test(
    'one volley only damages once even if its bolts arrive after immunity ends',
    () {
      final m = town();
      for (final gap in [20.0, 100.0, 180.0]) {
        m.enemyBolts.add(
          EnemyMagicBolt(
            m.player - Offset(0, gap),
            const Offset(0, 1),
            sourceId: 19,
            attackId: 4,
            boss: true,
          ),
        );
      }
      for (var i = 0; i < 32; i++) {
        m.invulnerableFor = 0;
        m.update(.025);
      }
      expect(m.health, 80);
      expect(m.enemyBolts, isEmpty);
    },
  );

  test('solid cover blocks mana before it reaches the player', () {
    final m = town()..player = const Offset(1250, 1140);
    expect(m.world.walkable(m.player), true);
    m.enemyBolts.add(
      EnemyMagicBolt(
        const Offset(1450, 1140),
        const Offset(-1, 0),
        sourceId: 1,
        attackId: 1,
        boss: false,
      ),
    );
    advance(m, 1);
    expect(m.health, 100);
    expect(m.enemyBolts, isEmpty);
  });

  test(
    'hidden targets and targets behind buildings cannot start a new cast',
    () {
      final m = town()..player = const Offset(1250, 1530);
      expect(m.toggleHide(), true);
      final e = caster(m);
      m.update(.025);
      expect(m.hidden, true);
      expect(e.casting, false);
      expect(m.enemyBolts, isEmpty);
      final wallTown = town()..player = const Offset(1250, 1140);
      final other = wallTown.spawn(
        CreatureKind.jammer,
        at: const Offset(1450, 1140),
      );
      advance(wallTown, .4);
      expect(other.casting, false);
      expect(wallTown.enemyBolts, isEmpty);
    },
  );

  test(
    'rolls evade mana, and flight is bounded without homing or repeated hits',
    () {
      final m = town();
      m.enemyBolts.add(
        EnemyMagicBolt(
          m.player - const Offset(0, 35),
          const Offset(0, 1),
          sourceId: 7,
          attackId: 1,
          boss: false,
        ),
      );
      expect(m.roll(), true);
      advance(m, .1);
      expect(m.health, 100);
      expect(m.enemyBolts, isEmpty);
      m.enemyBolts.add(
        EnemyMagicBolt(
          const Offset(1100, 1800),
          const Offset(0, 1),
          sourceId: 7,
          attackId: 2,
          boss: false,
        ),
      );
      advance(m, 2.2);
      expect(m.enemyBolts, isEmpty);
      expect(m.health, 100);
    },
  );

  test(
    'pause freezes casting and projectiles, resume continues from the same state',
    () {
      final m = town(), e = caster(m);
      m.update(.025);
      final b = EnemyMagicBolt(
        m.player - const Offset(0, 160),
        const Offset(0, 1),
        sourceId: 8,
        attackId: 1,
        boss: false,
      );
      m.enemyBolts.add(b);
      final at = b.position, cast = e.castFor;
      m.pause();
      m.update(2);
      expect(b.position, at);
      expect(e.castFor, cast);
      expect(m.health, 100);
      m.resume();
      m.update(.1);
      expect(b.position.dy, greaterThan(at.dy));
      expect(e.castFor, lessThan(cast));
    },
  );

  test(
    'fatal magic at the deadline defeats rescue and freezes the remaining bolts',
    () {
      final m = town()
        ..elapsed = 179.99
        ..health = 5;
      final b = EnemyMagicBolt(
        m.player - const Offset(0, 20),
        const Offset(0, 1),
        sourceId: 9,
        attackId: 1,
        boss: true,
      );
      m.enemyBolts.add(b);
      m.update(.025);
      expect(m.phase, FieldPhase.lost);
      expect(m.health, 0);
      expect(m.deathReason, contains('ma lực'));
      final position = b.position, clock = m.elapsed;
      m.update(.1);
      expect(b.position, position);
      expect(m.elapsed, clock);
    },
  );

  test('concurrent casters and live projectiles are capped', () {
    final m = town();
    for (final p in const [
      Offset(1100, 1200),
      Offset(1200, 1200),
      Offset(1000, 1200),
      Offset(1050, 1100),
    ]) {
      m.spawn(CreatureKind.jammer, at: p);
    }
    for (var i = 0; i < 80; i++) {
      m.update(.025);
      expect(
        m.enemies.where((e) => e.casting).length,
        lessThanOrEqualTo(TownRules.maxCastingEnemies),
      );
      expect(m.enemyBolts.length, lessThanOrEqualTo(TownRules.maxEnemyBolts));
    }
  });
}

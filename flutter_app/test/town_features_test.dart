import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/hand_input.dart';

ExplorationModel town() =>
    ExplorationModel(FieldMap.town, survival: true, seed: 17)
      ..start()
      ..wave = 5;
void advance(ExplorationModel m, double seconds) {
  for (var t = 0.0; t < seconds - 1e-8; t += .025) {
    m.update(.025);
  }
}

Creature angryBoss(ExplorationModel m) {
  final boss = m.spawn(CreatureKind.boss, at: m.player - const Offset(0, 300));
  m.hit(boss, 450);
  return boss;
}

void main() {
  test(
    'world pickups unlock guns and switching preserves separate magazines',
    () {
      final m = town();
      expect(m.owns(GunKind.pistol), false);
      expect(m.switchWeapon(GunKind.pistol), false);
      m.player = m.items.firstWhere((i) => i.kind == 'gun_pistol').position;
      m.update(.025);
      expect(m.owns(GunKind.pistol), true);
      expect(m.weapon, GunKind.rifle);
      m.ammo = 7;
      m.reserve = 50;
      m.switchWeapon(GunKind.pistol);
      expect(m.ammo, 12);
      expect(m.reserve, 36);
      advance(m, .21);
      m.shoot(m.player - const Offset(0, 150));
      expect(m.ammo, 11);
      m.switchWeapon(GunKind.rifle);
      expect(m.ammo, 7);
      expect(m.reserve, 50);
      m.switchWeapon(GunKind.pistol);
      expect(m.ammo, 11);
      expect(m.reserve, 36);
      expect(m.shoot(m.player - const Offset(0, 150)), false);
    },
  );
  test('switching cancels reload and does not refill a stowed gun', () {
    final m = town();
    m.pickupGun(GunKind.shotgun);
    m.ammo = 0;
    m.reserve = 25;
    m.reload();
    advance(m, 1);
    m.switchWeapon(GunKind.shotgun);
    advance(m, 1);
    expect(m.ammo, 6);
    m.switchWeapon(GunKind.rifle);
    expect(m.ammo, 0);
    expect(m.reserve, 25);
    m.reload();
    advance(m, 1.7);
    expect(m.ammo, 24);
    expect(m.reserve, 1);
  });
  test(
    'shotgun consumes one shell, fires a short fan, and accuracy counts a trigger once',
    () {
      final m = town();
      m.pickupGun(GunKind.shotgun);
      m.switchWeapon(GunKind.shotgun);
      advance(m, .21);
      final e = m.spawn(CreatureKind.heavy, at: m.player - const Offset(0, 75))
        ..stun = 5;
      m.shoot(e.position);
      expect(m.bullets, hasLength(8));
      expect(m.ammo, 5);
      expect(m.bullets.map((b) => b.damage).toSet(), {10.0});
      m.switchWeapon(GunKind.rifle);
      advance(m, .15);
      expect(e.health, 55);
      expect(m.hits, 1);
      expect(m.shots, 1);
      advance(m, .4);
      expect(m.bullets, isEmpty);
    },
  );
  test(
    'pistol, rifle and shotgun have distinct range, rate and ammunition',
    () {
      final specs = GunKind.values.map(GunSpec.of).toList();
      expect(specs.map((s) => s.magazine).toSet(), {12, 24, 6});
      expect(specs.map((s) => s.interval).toSet(), hasLength(3));
      expect(specs[1].range, greaterThan(specs[0].range));
      expect(specs[0].range, greaterThan(specs[2].range));
      final m = town();
      m.pickupGun(GunKind.pistol);
      m.switchWeapon(GunKind.pistol);
      m.reserve = 95;
      expect(m.addAmmo(GunKind.pistol, 24), 1);
      expect(m.reserve, 96);
    },
  );
  test(
    'medkits are stored, capped and consumed only after completed bandaging',
    () {
      final m = town()
        ..health = 40
        ..medkits = 3;
      final item = m.items.firstWhere((i) => i.kind == 'health');
      m.player = item.position;
      m.update(.025);
      expect(item.taken, false);
      expect(m.health, 40);
      m.medkits = 2;
      m.update(.025);
      expect(item.taken, true);
      expect(m.medkits, 3);
      expect(m.health, 40);
      expect(m.useMedkit(), true);
      advance(m, 2.7);
      expect(m.health, 40);
      expect(m.medkits, 3);
      advance(m, .2);
      expect(m.health, 80);
      expect(m.medkits, 2);
      expect(m.healing, false);
    },
  );
  test(
    'pausing freezes a heal and resuming finishes it without consuming twice',
    () {
      final m = town()..health = 35;
      m.useMedkit();
      advance(m, 1);
      m.pause();
      final remaining = m.healFor;
      advance(m, 2);
      expect(m.healFor, remaining);
      expect(m.medkits, 1);
      m.resume();
      advance(m, 1.9);
      expect(m.health, 75);
      expect(m.medkits, 0);
      advance(m, 1);
      expect(m.health, 75);
    },
  );
  for (final interruption in [
    'move',
    'shot',
    'damage',
    'switch',
    'roll',
    'reload',
    'stance',
  ]) {
    test('$interruption interrupts healing without losing a medkit', () {
      final m = town()
        ..health = 40
        ..ammo = 10;
      m.pickupGun(GunKind.pistol);
      m.useMedkit();
      advance(m, .5);
      switch (interruption) {
        case 'move':
          m.movement = const Offset(1, 0);
        case 'shot':
          m.shoot(m.player - const Offset(0, 200));
        case 'damage':
          m.hurt(1);
        case 'switch':
          m.switchWeapon(GunKind.pistol);
        case 'roll':
          m.roll();
        case 'reload':
          m.reload();
        case 'stance':
          m.setStance(PlayerStance.crouching);
      }
      advance(m, .1);
      m.movement = Offset.zero;
      advance(m, 3);
      expect(m.healing, false);
      expect(m.medkits, 1);
      expect(m.health, interruption == 'damage' ? 39 : 40);
    });
  }
  test('fatal damage on the last heal frame defeats completion', () {
    final m = town()..health = 5;
    m.useMedkit();
    m.healFor = .01;
    m.spawn(CreatureKind.runner, at: m.player + const Offset(20, 0))
      ..windup = .01
      ..attackId = 1;
    m.update(.025);
    expect(m.phase, FieldPhase.lost);
    expect(m.medkits, 1);
    expect(m.health, 0);
  });
  test(
    'doors update collision, sight and cached routes in both directions',
    () {
      final m = town();
      final door = m.world.doors.first;
      m.player = door.outside;
      expect(m.world.walkable(m.player), true);
      expect(door.open, true);
      expect(m.world.route(m.player, door.room.center), isNotEmpty);
      expect(m.interact(), true);
      expect(door.open, false);
      expect(m.world.walkable(door.rect.center), false);
      expect(m.world.route(m.player, door.room.center), isEmpty);
      expect(m.world.clearLine(m.player, door.room.center), false);
      expect(m.interact(), true);
      expect(m.world.walkable(door.rect.center), true);
      expect(m.world.route(m.player, door.room.center), isNotEmpty);
      expect(m.world.navigationVersion, 2);
    },
  );
  test('doors cannot close on a player or creature', () {
    final m = town();
    final d = m.world.doors.first;
    m.player = d.rect.center;
    expect(m.interact(), false);
    expect(d.open, true);
    m.player = d.outside;
    m.spawn(CreatureKind.runner, at: d.rect.center);
    expect(m.interact(), false);
    expect(d.open, true);
    expect(m.health, 100);
  });
  test('closed doors stop enemy mana while open doors let it through', () {
    final m = town();
    final door = m.world.doors.first;
    m.player = door.outside;
    m.interact();
    m.enemyBolts.add(
      EnemyMagicBolt(
        const Offset(600, 1900),
        const Offset(0, 1),
        sourceId: 1,
        attackId: 1,
        boss: false,
      ),
    );
    advance(m, 1);
    expect(m.health, 100);
    m.interact();
    m.enemyBolts.add(
      EnemyMagicBolt(
        const Offset(600, 1900),
        const Offset(0, 1),
        sourceId: 1,
        attackId: 2,
        boss: false,
      ),
    );
    advance(m, .8);
    expect(m.health, 86);
  });
  test(
    'a key opens the armory once and both door and key reset for a new run',
    () {
      final m = town();
      final d = m.world.doors.last;
      m.player = d.outside;
      expect(m.interact(), false);
      expect(d.locked, true);
      m.player = m.items.firstWhere((i) => i.kind == 'key_armory').position;
      m.update(.025);
      expect(m.keys.contains('armory'), true);
      m.player = d.outside;
      expect(m.interact(), true);
      expect(d.open, true);
      expect(d.locked, false);
      expect(m.keys, isEmpty);
      expect(m.world.route(m.player, d.room.center), isNotEmpty);
      expect(m.interact(), true);
      expect(m.interact(), true);
      final fresh = town();
      expect(fresh.keys, isEmpty);
      expect(fresh.world.doors.last.locked, true);
      expect(fresh.world.doors.last.open, false);
    },
  );
  test('a full bag leaves excess supply in the chest for a later visit', () {
    final m = town();
    m.pickupGun(GunKind.pistol);
    m.pickupGun(GunKind.shotgun);
    m.reserve = 180;
    m.gunSlots[GunKind.pistol]!.reserve = 96;
    m.gunSlots[GunKind.shotgun]!.reserve = 36;
    m.medkits = 3;
    final s = m.world.stashes.last;
    m.player = s.position + const Offset(0, 55);
    expect(m.interact(), false);
    expect(s.medStock, 2);
    expect(s.rifleRounds, 48);
    expect(s.shotgunAvailable, true);
    m.reserve = 170;
    m.medkits = 2;
    expect(m.interact(), true);
    expect(m.reserve, 180);
    expect(m.medkits, 3);
    expect(s.medStock, 1);
    expect(s.rifleRounds, 38);
    expect(s.shotgunAvailable, true);
  });
  test('a heavy pursuer reaches and breaks a closed refuge door', () {
    final m = town();
    final d = m.world.doors.first;
    m.player = d.outside;
    m.interact();
    m.player = d.room.center;
    m.spawn(CreatureKind.heavy, at: d.outside)
      ..investigate = m.player
      ..noiseFor = 30;
    advance(m, 10);
    expect(d.broken, true);
    expect(d.open, true);
    m.player = d.outside;
    expect(m.interact(), false);
  });
  test(
    'boss phase two starts once at half health, warns and locks ground zones',
    () {
      final m = town();
      final e = angryBoss(m);
      expect(e.enraged, true);
      expect(e.bossPhase, 2);
      expect(e.phaseFor, 1.2);
      m.hit(e, 3);
      advance(m, 1.3);
      expect(m.bossRifts, hasLength(2));
      expect(m.health, 100);
      final target = m.bossRifts.first.position;
      m.player += const Offset(180, 0);
      advance(m, 1.5);
      expect(target, FieldWorld.spawn);
      expect(m.health, 100);
      expect(e.weak, greaterThan(0));
    },
  );
  test(
    'overlapping rifts from one attack do not stack damage after immunity expires',
    () {
      final m = town();
      final e = m.spawn(CreatureKind.boss, at: m.player - const Offset(0, 300))
        ..stun = 10;
      m.bossRifts.add(BossRift(m.player, e.id, 70)..warning = .01);
      m.bossRifts.add(BossRift(m.player, e.id, 70)..warning = .65);
      m.update(.025);
      expect(m.health, 76);
      m.invulnerableFor = 0;
      advance(m, .7);
      expect(m.health, 76);
    },
  );
  test('cover blocks a rift and killing its owner cancels pending zones', () {
    final m = town();
    final d = m.world.doors.first;
    m.player = d.outside;
    m.interact();
    m.player = const Offset(600, 1950);
    final e = m.spawn(CreatureKind.boss, at: const Offset(1100, 1500))
      ..stun = 10;
    m.bossRifts.add(BossRift(const Offset(600, 2025), e.id, 80)..warning = .01);
    m.update(.025);
    expect(m.health, 100);
    m.interact();
    m.bossRifts.add(BossRift(const Offset(600, 2025), e.id, 81)..warning = .01);
    m.update(.025);
    expect(m.health, 76);
    m.bossRifts.add(BossRift(m.player, e.id, 82)..warning = .1);
    m.hit(e, 1000);
    advance(m, .2);
    expect(m.health, 76);
    expect(m.bossRifts, isEmpty);
  });
  test('rifts pause with the game and fatal detonation wins over rescue', () {
    final m = town()..health = 20;
    final e = m.spawn(CreatureKind.boss, at: m.player - const Offset(0, 300))
      ..stun = 10;
    final r = BossRift(m.player, e.id, 90)..warning = .01;
    m.bossRifts.add(r);
    m.pause();
    advance(m, 1);
    expect(r.warning, .01);
    expect(m.health, 20);
    m.resume();
    m.elapsed = 179.99;
    m.update(.025);
    expect(m.phase, FieldPhase.lost);
    expect(m.deathReason, contains('giai đoạn hai'));
  });
  for (final selection in [6, 7, 8]) {
    test(
      'third hand-wheel row can select action $selection without firing on resume',
      () {
        final m = town()..health = 50;
        m.pickupGun(GunKind.pistol);
        final d = m.world.doors.first;
        if (selection == 8) m.player = d.outside;
        final bridge = HandBridge(autoLaunch: false, clock: () => 0);
        addTearDown(bridge.dispose);
        final input = TownHandInput();
        var seq = 0;
        void sample({
          double x = .5,
          double y = .5,
          bool fist = false,
          bool pinch = false,
        }) {
          bridge.acceptPacket({
            'type': 'hand',
            'protocol': 1,
            'epoch': 'equipment',
            'seq': ++seq,
            'valid': true,
            'ready': true,
            'age_ms': 0,
            'released': !fist && !pinch,
            'fist': fist,
            'pinched': pinch,
            'palm_x': x,
            'palm_y': y,
            'jump_id': 0,
          });
          input.apply(m, bridge, .1);
        }

        sample();
        for (var i = 0; i < 9; i++) {
          sample(fist: true);
        }
        final x = selection == 6
            ? .4
            : selection == 8
            ? .6
            : .5;
        sample(x: x, y: .77);
        expect(input.selection, selection);
        sample(x: x, y: .77, pinch: true);
        sample(x: x, y: .77);
        sample(x: x, y: .77);
        expect(m.active, true);
        expect(m.firing, false);
        expect(m.movement, Offset.zero);
        if (selection == 6) expect(m.healing, true);
        if (selection == 7) expect(m.weapon, GunKind.pistol);
        if (selection == 8) expect(d.open, false);
      },
    );
  }
}

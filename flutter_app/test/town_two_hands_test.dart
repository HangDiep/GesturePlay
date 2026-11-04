import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/hand_input.dart';

class DualRig {
  DualRig() {
    sample();
  }
  final m = ExplorationModel(FieldMap.town, survival: true, seed: 17)
    ..start()
    ..wave = 5;
  final input = TownHandInput()..twoHands = true;
  late final bridge = HandBridge(autoLaunch: false, clock: () => clock);
  int clock = 0, seq = 0;
  void dispose() => bridge.dispose();
  void sample({
    Offset left = const Offset(.25, .5),
    Offset right = const Offset(.75, .4),
    bool lf = false,
    bool rf = false,
    bool lp = false,
    bool rp = false,
    bool missing = false,
    double dt = .1,
  }) {
    clock += (dt * 1000).round();
    Map<String, dynamic> hand(Offset p, bool fist, bool pinch) => {
      'valid': true,
      'ready': true,
      'released': !pinch && !fist,
      'pinched': pinch || fist,
      'fist': fist,
      'palm_x': p.dx,
      'palm_y': p.dy,
    };
    bridge.acceptPacket({
      'type': 'hand',
      'protocol': 1,
      'epoch': 'dual',
      'seq': ++seq,
      'jump_id': 0,
      'valid': true,
      'ready': true,
      'released': !rp && !rf,
      'age_ms': 0,
      'hands': {
        'left': hand(left, lf, lp),
        if (!missing) 'right': hand(right, rf, rp),
      },
    });
    input.apply(m, bridge, dt);
    m.update(dt);
  }

  void hold(
    int frames, {
    bool lf = false,
    bool rf = false,
    bool lp = false,
    bool rp = false,
  }) {
    for (var i = 0; i < frames; i++) {
      sample(lf: lf, rf: rf, lp: lp, rp: rp);
    }
  }

  void wheel(int action) {
    hold(9, lf: true);
    expect(input.wheelOpen, true);
    const rows = [
      [0, 2, 1],
      [3, 4, 5],
      [6, 7, 8],
      [9, 10, 11],
    ];
    final row = rows.indexWhere((r) => r.contains(action)),
        col = rows.expand((r) => r).toList().indexOf(action) % 3;
    final p = Offset([.65, .75, .85][col], [.4, .55, .69, .82][row]);
    sample(right: p);
    sample(right: p, rp: true);
    sample(right: p, rp: true);
    sample(right: p);
    sample(right: p);
  }
}

void main() {
  for (final swap in [false, true]) {
    test(
      'physical right fist starts once without the left hand, swapped=$swap',
      () {
        var clock = 0, seq = 0;
        final bridge = HandBridge(autoLaunch: false, clock: () => clock);
        addTearDown(bridge.dispose);
        final input = TownHandInput()
          ..twoHands = true
          ..swapHands = swap;
        bool sample({
          bool fist = true,
          bool present = true,
          bool valid = true,
          bool pinch = false,
        }) {
          clock += 100;
          bridge.acceptPacket({
            'type': 'hand',
            'protocol': 1,
            'epoch': 'start',
            'seq': ++seq,
            'jump_id': 0,
            'age_ms': 0,
            'hands': {
              if (present)
                'right': {
                  'valid': valid,
                  'ready': true,
                  'palm_x': .75,
                  'palm_y': .4,
                  'fist': fist,
                  'pinched': pinch || fist,
                  'released': !fist && !pinch,
                },
            },
          });
          return input.startConfirm(bridge, .1);
        }

        for (var i = 0; i < 4; i++) {
          expect(sample(), false);
        }
        expect(input.startFistProgress, greaterThan(.8));
        expect(sample(), true);
        for (var i = 0; i < 10; i++) {
          expect(sample(), false);
        }
        expect(sample(fist: false), false);
        for (var i = 0; i < 4; i++) {
          expect(sample(), false);
        }
        expect(sample(), true);
        input.reset();
        for (var i = 0; i < 8; i++) {
          expect(sample(fist: false, pinch: true), false);
        }
        for (var i = 0; i < 3; i++) {
          expect(sample(), false);
        }
        expect(sample(present: false), false);
        expect(input.startFistProgress, 0);
        for (var i = 0; i < 3; i++) {
          expect(sample(), false);
        }
        clock += 300;
        expect(input.startConfirm(bridge, .1), false);
        expect(input.startFistProgress, 0);
        expect(sample(valid: false), false);
        input.blockHeldFist(bridge);
        for (var i = 0; i < 10; i++) {
          expect(sample(), false);
        }
        expect(sample(fist: false), false);
        for (var i = 0; i < 4; i++) {
          expect(sample(), false);
        }
        expect(sample(), true);
      },
    );
  }

  test(
    'movement and aim/fire are independent and left gestures never shoot',
    () {
      final r = DualRig();
      addTearDown(r.dispose);
      final start = r.m.player;
      r.sample(
        left: const Offset(.35, .5),
        right: const Offset(.9, .4),
        rp: true,
      );
      expect(r.m.movement.distance, greaterThan(0));
      expect((r.m.player - start).distance, greaterThan(0));
      expect(r.m.ammo, 23);
      expect(r.m.aim.dx, greaterThan(r.m.player.dx));
      r.sample();
      final ammo = r.m.ammo;
      r.hold(3, lp: true);
      r.sample();
      expect(r.m.ammo, ammo);
      expect(r.m.shots, 1);
    },
  );
  test('short movement fist cycles all stances once per release', () {
    final r = DualRig();
    addTearDown(r.dispose);
    for (final pose in [
      PlayerStance.crouching,
      PlayerStance.prone,
      PlayerStance.standing,
    ]) {
      r.hold(3, lf: true);
      r.sample();
      r.hold(6);
      expect(r.m.stance, pose);
    }
    expect(r.m.ammo, 24);
    expect(r.m.reloadFor, 0);
  });
  test(
    'aim fist reloads on a short release and switches guns on a long release',
    () {
      final r = DualRig();
      addTearDown(r.dispose);
      r.m.pickupGun(GunKind.pistol);
      r.m.ammo = 5;
      r.hold(3, rf: true);
      r.sample();
      expect(r.m.reloadFor, greaterThan(0));
      r.hold(18);
      expect(r.m.ammo, 24);
      r.hold(10, rf: true);
      expect(r.m.weapon, GunKind.rifle);
      r.sample();
      expect(r.m.weapon, GunKind.pistol);
      r.hold(10);
      expect(r.m.weapon, GunKind.pistol);
      expect(r.m.shots, 0);
    },
  );
  test('short movement pinch opens doors and enters/leaves hiding', () {
    final r = DualRig();
    addTearDown(r.dispose);
    final door = r.m.world.doors.first;
    r.m.player = door.outside;
    r.hold(3, lp: true);
    r.sample();
    expect(door.open, false);
    r.hold(3, lp: true);
    r.sample();
    expect(door.open, true);
    r.m.player = r.m.world.hidingSpots.first.center;
    r.hold(3, lp: true);
    r.sample();
    expect(r.m.hidden, true);
    r.hold(3, lp: true);
    r.sample();
    expect(r.m.hidden, false);
    expect(r.m.shots, 0);
  });
  test('long movement pinch heals only on release and consumes once', () {
    final r = DualRig();
    addTearDown(r.dispose);
    r.m.health = 40;
    r.hold(12, lp: true);
    expect(r.m.healing, false);
    r.sample();
    expect(r.m.healing, true);
    r.hold(29);
    expect(r.m.health, 80);
    expect(r.m.medkits, 0);
    expect(r.m.shots, 0);
  });
  for (final action in [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]) {
    test('hand-only wheel action $action resumes without firing or drift', () {
      final r = DualRig();
      addTearDown(r.dispose);
      r.m.health = 50;
      r.m.pickupGun(GunKind.pistol);
      if (action == 2) r.m.player = r.m.world.hidingSpots.first.center;
      if (action == 8) r.m.player = r.m.world.doors.first.outside;
      r.wheel(action);
      expect(r.m.active, true);
      expect(r.m.firing, false);
      expect(r.m.movement, Offset.zero);
      expect(r.m.shots, 0);
      switch (action) {
        case 2:
          expect(r.m.hidden, true);
        case 3 || 4 || 5:
          expect(r.m.stance, PlayerStance.values[action - 3]);
        case 6:
          expect(r.m.healing, true);
        case 7:
          expect(r.m.weapon, GunKind.pistol);
        case 8:
          expect(r.m.world.doors.first.open, false);
        case 9 || 10 || 11:
          expect(r.input.takeUiAction(), action);
      }
    });
  }
  test('both fists pause and a lost/stale hand cancels held actions', () {
    final r = DualRig();
    addTearDown(r.dispose);
    r.hold(9, lf: true, rf: true);
    expect(r.m.phase, FieldPhase.paused);
    expect(r.input.wheelOpen, false);
    r.m.resume();
    r.sample();
    r.hold(6, lp: true);
    r.sample(missing: true);
    expect(r.m.phase, FieldPhase.paused);
    r.m.resume();
    r.sample();
    expect(r.m.healing, false);
    expect(r.m.stance, PlayerStance.standing);
    r.clock += 300;
    r.input.apply(r.m, r.bridge, .1);
    expect(r.m.phase, FieldPhase.paused);
    expect(r.m.firing, false);
  });
  test(
    'menu needs a clean open-pinch-open sequence and never auto resumes on reacquisition',
    () {
      final r = DualRig();
      addTearDown(r.dispose);
      r.m.pause();
      r.sample(rp: true);
      expect(r.input.menuConfirm(r.bridge, .2), false);
      r.sample();
      expect(r.input.menuConfirm(r.bridge, .1), false);
      r.sample(rp: true);
      expect(r.input.menuConfirm(r.bridge, .2), false);
      r.sample();
      expect(r.input.menuConfirm(r.bridge, .1), true);
      expect(r.m.active, false);
      r.sample(missing: true);
      expect(r.input.menuConfirm(r.bridge, .1), false);
      r.sample();
      expect(r.input.menuConfirm(r.bridge, .1), false);
    },
  );
  test('swapping roles keeps movement and fire on the configured hands', () {
    final r = DualRig();
    addTearDown(r.dispose);
    r.input
      ..swapHands = true
      ..reset();
    r.sample();
    r.sample(
      right: const Offset(.85, .4),
      left: const Offset(.35, .5),
      lp: true,
    );
    expect(r.m.movement.distance, greaterThan(0));
    expect(r.m.firing, true);
    expect(r.m.ammo, 23);
  });
  test(
    'missing, malformed and non-finite side positions cannot control the game',
    () {
      final r = DualRig();
      addTearDown(r.dispose);
      for (final p in [const Offset(double.nan, .5), const Offset(2, .5)]) {
        r.m.resume();
        r.sample(right: p, rp: true);
        expect(r.m.active, false);
        expect(r.m.ammo, 24);
      }
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/dead_signal/settings.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/app.dart';
import 'package:gestureplay/survival/art.dart';
import 'package:gestureplay/survival/painter.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['WRITE_TOWN_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('town-canvas')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(
      '../.cache/town-$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

ExplorationModel model(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((w) => w.painter)
    .whereType<TownPainter>()
    .first
    .model;

class LocalHandBridge extends HandBridge {
  LocalHandBridge() : super(autoLaunch: false, clock: () => 0);
  @override
  Future<void> start() async {}
  @override
  void stop() {}
}

Future<void> tickFor(WidgetTester tester, int milliseconds) async {
  for (var elapsed = 0; elapsed < milliseconds; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    final icons = File(
      'C:/Users/Admin/Downloads/flutter_windows_3.47.0-stable/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      await (FontLoader('Segoe UI')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
  });

  for (final size in [
    const Size(1280, 800),
    const Size(844, 390),
    const Size(390, 844),
  ]) {
    testWidgets(
      'two hands start, fight, use direct gestures and menus without keys at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final art = (await tester.runAsync(TownArt.load))!;
        final hand = LocalHandBridge();
        addTearDown(() {
          art.dispose();
          hand.dispose();
        });
        var sequence = 0;
        Future<void> sample({
          Offset left = const Offset(.25, .5),
          Offset right = const Offset(.75, .4),
          bool lf = false,
          bool rf = false,
          bool lp = false,
          bool rp = false,
          bool missing = false,
          bool missingLeft = false,
        }) async {
          Map<String, dynamic> side(Offset p, bool fist, bool pinch) => {
            'valid': true,
            'ready': true,
            'released': !pinch && !fist,
            'pinched': pinch || fist,
            'fist': fist,
            'palm_x': p.dx,
            'palm_y': p.dy,
            'pinch_points': [
              [p.dx - .03, p.dy],
              [p.dx + .03, p.dy],
            ],
          };
          hand.acceptPacket({
            'type': 'hand',
            'protocol': 1,
            'epoch': 'widget-dual',
            'seq': ++sequence,
            'jump_id': 0,
            'valid': true,
            'ready': true,
            'released': !rf && !rp,
            'age_ms': 0,
            'hands': {
              if (!missingLeft) 'left': side(left, lf, lp),
              if (!missing) 'right': side(right, rf, rp),
            },
          });
          await tester.pump(const Duration(milliseconds: 100));
        }

        Future<void> hold(
          int frames, {
          bool lf = false,
          bool rf = false,
          bool lp = false,
          bool rp = false,
        }) async {
          for (var i = 0; i < frames; i++) {
            await sample(lf: lf, rf: rf, lp: lp, rp: rp);
          }
        }

        Future<void> confirm() async {
          await sample();
          await sample(rp: true);
          await sample(rp: true);
          await sample();
        }

        Future<void> wheel(int row, int col) async {
          await hold(9, lf: true);
          expect(find.byKey(const ValueKey('wheel-action-11')), findsOneWidget);
          final p = Offset([.65, .75, .85][col], [.4, .55, .69, .82][row]);
          await sample(right: p);
          await sample(right: p, rp: true);
          await sample(right: p, rp: true);
          await sample(right: p);
          await sample(right: p);
        }

        await tester.pumpWidget(
          SurvivalApp(
            art: art,
            bridge: hand,
            settings: SignalSettings(),
            audioEnabled: false,
          ),
        );
        await tester.ensureVisible(find.text('Hai tay / Webcam'));
        await tester.tap(find.text('Hai tay / Webcam'));
        await tester.pump();
        for (var i = 0; i < 5; i++) {
          await sample(rf: true, missingLeft: true);
        }
        expect(find.byKey(const ValueKey('town-game')), findsOneWidget);
        final m = model(tester)..wave = 5;
        expect(
          find.byKey(const ValueKey('two-hands-start-wait')),
          findsOneWidget,
        );
        await capture(tester, 'right-fist-start-${size.width.toInt()}');
        for (var i = 0; i < 10; i++) {
          await sample(rf: true, missingLeft: true);
        }
        expect(model(tester), same(m));
        expect(m.elapsed, 0);
        expect(m.health, 100);
        expect(m.ammo, 24);
        await sample(missing: true);
        expect(m.active, false);
        await sample();
        expect(m.active, true);
        expect(
          find.byKey(const ValueKey('two-hands-start-wait')),
          findsNothing,
        );
        expect(m.reloadFor, 0);
        expect(m.shots, 0);
        m.pickupGun(GunKind.pistol);
        final start = m.player;
        await sample(
          left: const Offset(.35, .5),
          right: const Offset(.85, .4),
          rp: true,
        );
        expect(m.ammo, lessThan(24));
        expect((m.player - start).distance, greaterThan(0));
        await sample();
        await hold(3, lf: true);
        await sample();
        await hold(6);
        expect(m.stance, PlayerStance.crouching);
        await hold(9, rf: true);
        await sample();
        expect(m.weapon, GunKind.pistol);
        m.health = 40;
        await hold(9, lp: true);
        await sample();
        expect(m.healing, true);
        await hold(29);
        expect(m.health, 80);
        m.player = m.world.doors.first.outside;
        await hold(3, lp: true);
        await sample();
        expect(m.world.doors.first.open, false);
        await hold(9, lf: true);
        await capture(tester, 'two-hands-wheel-${size.width.toInt()}');
        for (var i = 0; i < 12; i++) {
          final r = tester.getRect(find.byKey(ValueKey('wheel-action-$i')));
          expect(r.top, greaterThanOrEqualTo(0));
          expect(r.bottom, lessThanOrEqualTo(size.height));
        }
        // Cancel the wheel by pinching the movement hand, without a screen tap.
        await sample(lp: true);
        await sample();
        expect(m.active, true);
        await wheel(3, 0);
        expect(find.byKey(const ValueKey('inventory-panel')), findsOneWidget);
        await capture(tester, 'two-hands-bag-${size.width.toInt()}');
        await confirm();
        expect(m.active, true);
        await wheel(3, 1);
        expect(find.byKey(const ValueKey('full-town-map')), findsOneWidget);
        await confirm();
        expect(m.active, true);
        await hold(20, lf: true, rf: true);
        expect(m.active, false);
        expect(
          find.byKey(const ValueKey('two-hands-resume-wait')),
          findsNothing,
        );
        await sample();
        expect(m.active, false);
        expect(
          find.byKey(const ValueKey('resume-fist-progress')),
          findsOneWidget,
        );
        await capture(tester, 'right-fist-pause-${size.width.toInt()}');
        await confirm();
        expect(m.active, false); // Pinching no longer presses Continue.
        final pausedTime = m.elapsed, pausedHealth = m.health;
        final pausedAmmo = m.ammo, pausedReserve = m.reserve;
        final pausedWeapon = m.weapon;
        for (var i = 0; i < 5; i++) {
          await sample(rf: true, missingLeft: true);
        }
        expect(
          find.byKey(const ValueKey('two-hands-resume-wait')),
          findsOneWidget,
        );
        await capture(tester, 'right-fist-resume-${size.width.toInt()}');
        for (var i = 0; i < 10; i++) {
          await sample(rf: true, missingLeft: true);
        }
        expect(m.active, false);
        expect(m.elapsed, pausedTime);
        expect(m.health, pausedHealth);
        expect(m.ammo, pausedAmmo);
        expect(m.reserve, pausedReserve);
        expect(m.weapon, pausedWeapon);
        await sample(missing: true);
        expect(m.active, false);
        await sample();
        expect(m.active, true);
        expect(m.shotCooldown, 0);
        expect(m.reloadFor, 0);
        expect(m.weapon, pausedWeapon);
        expect(m.ammo, pausedAmmo);
        expect(m.movement, Offset.zero);
        await sample(missing: true);
        expect(m.active, false);
        await sample();
        expect(m.active, false);
        await hold(5, rf: true);
        expect(m.active, false);
        await sample();
        expect(m.active, true);
        expect(m.firing, false);
        await capture(tester, 'two-hands-play-${size.width.toInt()}');
        m.hurt(100);
        await confirm();
        expect(model(tester), isNot(same(m)));
        expect(model(tester).health, 100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('gear, bag, bandaging, doors and phase two work at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final art = (await tester.runAsync(TownArt.load))!;
      final hand = HandBridge(autoLaunch: false);
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      await tester.pumpWidget(
        SurvivalApp(
          art: art,
          bridge: hand,
          settings: SignalSettings(),
          audioEnabled: false,
        ),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('town-start')));
      await tester.tap(find.byKey(const ValueKey('town-start')));
      await tester.pump();
      final m = model(tester)..wave = 5;
      for (final kind in ['gun_pistol', 'gun_shotgun']) {
        m.player = m.items.firstWhere((i) => i.kind == kind).position;
        await tickFor(tester, 100);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      expect(m.weapon, GunKind.pistol);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
      await tester.pump();
      expect(find.byKey(const ValueKey('inventory-panel')), findsOneWidget);
      final time = m.elapsed;
      await tickFor(tester, 300);
      expect(m.elapsed, time);
      await capture(tester, 'inventory-${size.width.toInt()}');
      await tester.ensureVisible(
        find.byKey(const ValueKey('inventory-gun-shotgun')),
      );
      await tester.tap(find.byKey(const ValueKey('inventory-gun-shotgun')));
      await tester.pump();
      expect(m.active, true);
      expect(m.weapon, GunKind.shotgun);
      await tickFor(tester, 300);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.pump(const Duration(milliseconds: 25));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      expect(m.bullets, hasLength(8));
      expect(m.ammo, 5);
      m.health = 35;
      m.medkits = 2;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      expect(find.byKey(const ValueKey('healing-progress')), findsOneWidget);
      await capture(tester, 'bandaging-${size.width.toInt()}');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await tickFor(tester, 100);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
      expect(m.healing, false);
      expect(m.medkits, 2);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyH);
      await tickFor(tester, 2900);
      expect(m.health, 75);
      expect(m.medkits, 1);
      final door = m.world.doors.first;
      m.player = door.outside;
      await tester.pump();
      expect(find.byKey(const ValueKey('interact-button')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('interact-button')));
      await tester.pump();
      expect(door.open, false);
      await capture(tester, 'refuge-${size.width.toInt()}');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      expect(door.open, true);
      m.player = m.items.firstWhere((i) => i.kind == 'key_armory').position;
      await tickFor(tester, 100);
      m.player = m.world.doors.last.outside;
      await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
      expect(m.world.doors.last.locked, false);
      m.player = FieldWorld.spawn;
      final boss = m.spawn(
        CreatureKind.boss,
        at: m.player - const Offset(0, 300),
      );
      m.hit(boss, 450);
      await tickFor(tester, 1300);
      expect(m.bossRifts, hasLength(2));
      expect(find.byKey(const ValueKey('magic-warning')), findsOneWidget);
      await capture(tester, 'boss-phase-two-${size.width.toInt()}');
      m.hit(boss, 1000);
      await tickFor(tester, 100);
      expect(m.bossRifts, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });

    testWidgets(
      'nine hand actions fit and gun choice resumes safely at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final art = (await tester.runAsync(TownArt.load))!;
        final hand = LocalHandBridge();
        addTearDown(() {
          art.dispose();
          hand.dispose();
        });
        var sequence = 0;
        void sample({bool fist = false}) => hand.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'widget-equipment',
          'seq': ++sequence,
          'valid': true,
          'ready': true,
          'age_ms': 0,
          'released': !fist,
          'fist': fist,
          'pinched': false,
          'palm_x': .5,
          'palm_y': .5,
          'jump_id': 0,
        });
        sample();
        await tester.pumpWidget(
          SurvivalApp(
            art: art,
            bridge: hand,
            settings: SignalSettings(),
            audioEnabled: false,
          ),
        );
        await tester.ensureVisible(find.text('Bàn tay / Webcam'));
        await tester.tap(find.text('Bàn tay / Webcam'));
        await tester.pump();
        await tester.ensureVisible(find.byKey(const ValueKey('town-start')));
        await tester.tap(find.byKey(const ValueKey('town-start')));
        await tester.pump();
        final m = model(tester)..wave = 5;
        m.pickupGun(GunKind.pistol);
        for (var i = 0; i < 9; i++) {
          sample(fist: true);
          await tickFor(tester, 100);
        }
        expect(m.active, false);
        for (var i = 0; i < 9; i++) {
          expect(find.byKey(ValueKey('wheel-action-$i')), findsOneWidget);
          expect(
            tester.getRect(find.byKey(ValueKey('wheel-action-$i'))).bottom,
            lessThanOrEqualTo(size.height),
          );
        }
        await capture(tester, 'hand-equipment-${size.width.toInt()}');
        await tester.tap(find.byKey(const ValueKey('wheel-action-7')));
        sample();
        await tickFor(tester, 100);
        expect(m.active, true);
        expect(m.weapon, GunKind.pistol);
        expect(m.firing, false);
        expect(m.movement, Offset.zero);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'ranged magic is visible and the player has only gun controls at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final art = (await tester.runAsync(TownArt.load))!;
        final hand = HandBridge(autoLaunch: false);
        addTearDown(() {
          art.dispose();
          hand.dispose();
        });
        await tester.pumpWidget(
          SurvivalApp(
            art: art,
            bridge: hand,
            settings: SignalSettings(),
            audioEnabled: false,
          ),
        );
        await tester.ensureVisible(find.byKey(const ValueKey('town-start')));
        await tester.tap(find.byKey(const ValueKey('town-start')));
        await tester.pump();
        final m = model(tester)
          ..wave = 5
          ..elapsed = 30;
        m.spawn(CreatureKind.jammer, at: m.player - const Offset(0, 300));
        m.spawn(CreatureKind.boss, at: m.player + const Offset(75, -300));
        await tester.pump(const Duration(milliseconds: 25));
        expect(find.byKey(const ValueKey('magic-warning')), findsOneWidget);
        expect(find.byTooltip('Đèn chớp — choáng quái'), findsNothing);
        expect(find.byTooltip('Đặt bẫy điện'), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
        expect(
          m.effects.where((e) => e.kind == 'flash' || e.kind == 'trap'),
          isEmpty,
        );
        await capture(tester, 'magic-charge-${size.width.toInt()}');
        for (var i = 0; i < 17; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(m.enemyBolts, hasLength(4));
        await capture(tester, 'magic-volley-${size.width.toInt()}');
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
        expect(m.ammo, lessThan(24));
        final b = m.enemyBolts.first;
        m.pause();
        await tester.pump();
        final at = b.position;
        await tester.pump(const Duration(seconds: 1));
        expect(b.position, at);
        m.resume();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(m.health, lessThan(100));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets('single town loads, moves, fires, pauses and retries at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final art = (await tester.runAsync(TownArt.load))!;
      final hand = HandBridge(autoLaunch: false);
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      await tester.pumpWidget(
        SurvivalApp(
          art: art,
          bridge: hand,
          settings: SignalSettings(),
          audioEnabled: false,
        ),
      );
      await tester.pump();
      expect(find.text('DEAD\nSIGNAL'), findsOneWidget);
      expect(find.text('BẮT ĐẦU SINH TỒN'), findsOneWidget);
      await capture(tester, 'menu-${size.width.toInt()}');
      await tester.ensureVisible(find.byKey(const ValueKey('town-start')));
      await tester.tap(find.byKey(const ValueKey('town-start')));
      await tester.pump();
      expect(find.byKey(const ValueKey('town-game')), findsOneWidget);
      final m = model(tester);
      final start = m.player;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      expect(m.player.dy, lessThan(start.dy));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      expect(m.ammo, lessThan(24));
      if (size.width < 900) {
        expect(find.byKey(const ValueKey('town-move')), findsOneWidget);
        expect(find.byKey(const ValueKey('town-aim')), findsOneWidget);
        final before = m.ammo;
        await tester.tap(find.byKey(const ValueKey('town-aim')));
        await tester.pump(const Duration(milliseconds: 200));
        // Hold the touch aim pad long enough for the simulation to consume it.
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('town-aim'))),
        );
        await tester.pump(const Duration(milliseconds: 200));
        await gesture.up();
        expect(m.ammo, lessThan(before));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.keyX);
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(m.stance, PlayerStance.crouching);
      m.aim = m.player + const Offset(200, 0);
      final crouchAmmo = m.ammo;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.pump(const Duration(milliseconds: 100));
      await capture(tester, 'crouch-fire-${size.width.toInt()}');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      expect(m.ammo, lessThan(crouchAmmo));
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(m.stance, PlayerStance.prone);
      m.aim = m.player + const Offset(200, 0);
      final proneAmmo = m.ammo;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
      await tester.pump(const Duration(milliseconds: 100));
      await capture(tester, 'prone-fire-${size.width.toInt()}');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
      expect(m.ammo, lessThan(proneAmmo));
      await tester.tap(find.byKey(const ValueKey('stance-standing')));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(m.stance, PlayerStance.standing);
      m.spawn(CreatureKind.runner, at: m.player + const Offset(125, -90));
      await tester.pump();
      await capture(tester, 'game-${size.width.toInt()}');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(find.byKey(const ValueKey('full-town-map')), findsOneWidget);
      final mapTime = m.elapsed;
      await tester.pump(const Duration(seconds: 1));
      expect(m.elapsed, mapTime);
      await capture(tester, 'map-${size.width.toInt()}');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.pump();
      expect(m.active, true);
      m.player = m.world.hidingSpots.first.center;
      await tester.pump();
      expect(find.byKey(const ValueKey('hide-button')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      expect(m.hidden, true);
      await capture(tester, 'hiding-${size.width.toInt()}');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyG);
      await tester.pump();
      expect(m.hidden, false);
      m.hurt(75);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('critical-health-warning')),
        findsOneWidget,
      );
      await capture(tester, 'critical-${size.width.toInt()}');
      await tester.tap(find.byTooltip('Tạm dừng'));
      await tester.pump();
      expect(find.text('TIẾP TỤC'), findsOneWidget);
      final frozen = m.elapsed;
      await tester.pump(const Duration(seconds: 2));
      expect(m.elapsed, frozen);
      await tester.tap(find.text('TIẾP TỤC'));
      await tester.pump();
      m.hurt(1000, isHazard: true);
      for (var i = 0; i < 11; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('TÍN HIỆU ĐÃ MẤT'), findsOneWidget);
      await capture(tester, 'death-${size.width.toInt()}');
      await tester.ensureVisible(find.text('CHƠI LẠI MAP'));
      await tester.tap(find.text('CHƠI LẠI MAP'));
      await tester.pump();
      final fresh = model(tester);
      expect(fresh, isNot(same(m)));
      expect(fresh.health, 100);
      expect(fresh.ammo, 24);
      expect(fresh.reserve, 120);
      expect(fresh.kills, 0);
      expect(fresh.cores, 0);
      expect(fresh.stance, PlayerStance.standing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }

  testWidgets(
    'one session renders every district and mouse aim follows the tilted view in all stances',
    (tester) async {
      const size = Size(1280, 800);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final art = (await tester.runAsync(TownArt.load))!;
      final hand = HandBridge(autoLaunch: false);
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      await tester.pumpWidget(
        SurvivalApp(
          art: art,
          bridge: hand,
          settings: SignalSettings(),
          audioEnabled: false,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('town-start')));
      await tester.pump();
      final m = model(tester), world = model(tester).world;
      m.wave = 5;
      m.elapsed = 12;
      final mouse = await tester.createGesture(
        kind: ui.PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(880, 410));
      addTearDown(mouse.removePointer);
      for (final district in const {
        'old-town': FieldWorld.spawn,
        'market': Offset(1100, 2780),
        'temple': Offset(3400, 1180),
        'garden': Offset(3450, 2980),
      }.entries) {
        m.player = district.value;
        m.enemies.clear();
        m.stance = PlayerStance.standing;
        expect(world.walkable(m.player), true);
        if ((m.player - FieldWorld.spawn).distance > FieldWorld.grid) {
          final path = world.route(FieldWorld.spawn, m.player);
          expect(path, isNotEmpty);
        }
        for (var i = 0; i < 3; i++) {
          final p =
              m.player +
              const [Offset(-180, -230), Offset(200, 90), Offset(320, -160)][i];
          if (world.walkable(p, 24)) {
            m.spawn(CreatureKind.values[i], at: p).spawnFor = 0;
          }
        }
        for (final stance in PlayerStance.values) {
          m.stance = stance;
          m.stanceFor = 0;
          await mouse.moveTo(const Offset(881, 411));
          await tester.pump(const Duration(milliseconds: 16));
          final at = TownView(
            m.player,
            size,
            world: world,
          ).projectShot(m.aim, TownView.muzzleHeight(stance.index));
          expect((at - const Offset(881, 411)).distance, lessThan(.01));
          expect(m.world, same(world));
        }
        m.stance = PlayerStance.standing;
        await tester.pump();
        await capture(tester, 'v2-${district.key}');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

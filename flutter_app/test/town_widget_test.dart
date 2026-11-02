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

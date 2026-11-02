import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/dead_signal/app.dart';
import 'package:gestureplay/dead_signal/settings.dart';
import 'package:gestureplay/services/hand_bridge.dart';

Future<void> snapshot(WidgetTester tester, String name) async {
  if (Platform.environment['WRITE_SIGNAL_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final dialog = find.byKey(const ValueKey('wave-plan-preview'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      dialog.evaluate().isNotEmpty
          ? dialog
          : find.byKey(const ValueKey('dead-signal-canvas')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('../.cache/dead-signal-$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  compactTests();
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      await (FontLoader('Segoe UI')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
    final icons = File(
      'C:/Users/Admin/Downloads/flutter_windows_3.47.0-stable/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  });
  testWidgets(
    'mission flow, shooting controls, pause, abandon confirmation and settings',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        DeadSignalApp(
          bridge: HandBridge(autoLaunch: false),
          settings: SignalSettings(),
          audioEnabled: false,
        ),
      );
      await tester.pump();
      expect(find.text('DEAD\nSIGNAL'), findsOneWidget);
      await snapshot(tester, 'home');
      await tester.tap(find.text('Bắt đầu ca trực'));
      await tester.pump();
      expect(find.text('Chuẩn bị ca trực'), findsOneWidget);
      await snapshot(tester, 'setup');
      await tester.tap(find.text('Xem các đợt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Kế hoạch các đợt'), findsOneWidget);
      expect(find.textContaining('Đủ bốn loại'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'wave-plan');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Vào ca trực'));
      await tester.pump();
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Tạm dừng'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'game');
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await snapshot(tester, 'threat');
      await tester.tap(find.text('Khóa cửa').first);
      await tester.pump();
      expect(find.text('ĐÃ KHÓA'), findsOneWidget);
      await tester.tap(find.text('Ngắm bắn'));
      await tester.pump();
      expect(find.text('Thoát ngắm'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      expect(find.text('CAM 02 / HÀNH LANG TRÁI'), findsOneWidget);
      await tester.tap(find.text('Tạm dừng'));
      await tester.pump();
      await snapshot(tester, 'pause');
      expect(find.text('Tiếp tục'), findsOneWidget);
      await tester.tap(find.text('Tiếp tục'));
      await tester.pump();
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Tạm dừng'));
      await tester.pump();
      await tester.tap(find.text('Rời ca trực'));
      await tester.pump();
      expect(find.text('Rời ca trực?'), findsOneWidget);
      await tester.tap(find.text('Ở lại'));
      await tester.pump();
      expect(find.text('Tiếp tục'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  testWidgets('tutorial drag target and settings render at smaller viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 768));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      DeadSignalApp(
        bridge: HandBridge(autoLaunch: false),
        settings: SignalSettings(),
        audioEnabled: false,
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Thực hành'));
    await tester.pump();
    expect(find.text('Hướng dẫn và thực hành'), findsOneWidget);
    await tester.tap(find.text('1. Chọn mục tiêu'));
    await tester.pump();
    expect(find.text('Đã chọn mục tiêu ✓'), findsOneWidget);
    final start = tester.getCenter(find.text('NGUỒN'));
    final end = tester.getCenter(find.text('2. Thả nguồn điện vào đây'));
    await tester.dragFrom(start, end - start);
    await tester.pump();
    expect(find.text('Đã cấp điện ✓'), findsOneWidget);
    await snapshot(tester, 'tutorial');
    await tester.tap(find.byTooltip('Cài đặt'));
    await tester.pump();
    expect(find.text('Cài đặt'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await snapshot(tester, 'settings');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
  testWidgets(
    'hand packets click a real button and drag a power token without an extra click',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bridge = PracticeBridge();
      await tester.pumpWidget(
        DeadSignalApp(
          bridge: bridge,
          settings: SignalSettings(),
          audioEnabled: false,
        ),
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Thực hành'));
      await tester.pump();
      await tester.tap(find.text('Dùng bàn tay'));
      await tester.pump();
      var sequence = 0;
      Future<void> feed(Offset position, {bool pinch = false}) async {
        final x = (position.dx / 1360 - .5) * .8 + .5,
            y = (position.dy / 860 - .5) * .8 + .5;
        bridge.acceptPacket({
          'type': 'hand',
          'protocol': 1,
          'epoch': 'practice',
          'seq': ++sequence,
          'jump_id': 0,
          'valid': true,
          'ready': true,
          'pinched': pinch,
          'released': !pinch,
          'fist': false,
          'age_ms': 0,
          'palm_x': x,
          'palm_y': y,
          'pinch_points': [
            [x - .08, y + .1],
            [pinch ? x - .08 : x, pinch ? y + .1 : y],
          ],
        });
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump();
      }

      final button = tester.getCenter(find.text('1. Chọn mục tiêu'));
      for (var i = 0; i < 12; i++) {
        await feed(button);
      }
      await feed(button, pinch: true);
      await feed(button);
      expect(find.text('Đã chọn mục tiêu ✓'), findsOneWidget);
      final source = tester.getCenter(find.text('NGUỒN')),
          target = tester.getCenter(find.text('2. Thả nguồn điện vào đây'));
      for (var i = 0; i < 12; i++) {
        await feed(source);
      }
      await feed(source, pinch: true);
      for (var i = 1; i <= 20; i++) {
        await feed(Offset.lerp(source, target, i / 20)!, pinch: true);
      }
      for (var i = 0; i < 10; i++) {
        await feed(target, pinch: true);
      }
      await feed(target);
      expect(find.text('Đã cấp điện ✓'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

class PracticeBridge extends HandBridge {
  PracticeBridge() : super(autoLaunch: false, clock: () => 0);
  @override
  Future<void> start() async {}
}

void compactTests() {
  for (final size in [const Size(844, 390), const Size(551, 668)]) {
    testWidgets('touch layout at ${size.width} by ${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        DeadSignalApp(
          bridge: HandBridge(autoLaunch: false),
          settings: SignalSettings(),
          audioEnabled: false,
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Bắt đầu ca trực'));
      await tester.pump();
      await tester.tap(find.text('Bắt đầu ca trực'));
      await tester.pump();
      await tester.ensureVisible(find.text('Vào ca trực'));
      await tester.pump();
      await tester.tap(find.text('Vào ca trực'));
      await tester.pump();
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await snapshot(tester, 'compact-${size.width.toInt()}');
      await tester.tap(find.text('Thiết bị'));
      await tester.pump();
      expect(find.text('PHÒNG THỦ CHIẾN THUẬT'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      await tester.tap(find.text('Tạm dừng'));
      await tester.pump();
      expect(find.text('Tiếp tục'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}

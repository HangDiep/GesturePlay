import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/app.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/dead_signal/settings.dart';

Future<void> capture(WidgetTester tester, String name) async {
  if (Platform.environment['WRITE_FIELD_PREVIEW'] != '1') return;
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('exploration-canvas')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final path = File('../.cache/flutter-2d-$name.png');
    await path.parent.create(recursive: true);
    await path.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Widget app() => ExplorationApp(
  bridge: HandBridge(autoLaunch: false),
  settings: SignalSettings(),
  audioEnabled: false,
);

void main() {
  setUpAll(() async {
    final fonts = {
      'Segoe UI': 'C:/Windows/Fonts/segoeui.ttf',
      'MaterialIcons':
          'C:/Users/Admin/Downloads/flutter_windows_3.47.0-stable/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    };
    for (final entry in fonts.entries) {
      final file = File(entry.value);
      if (file.existsSync()) {
        await (FontLoader(entry.key)..addFont(
              Future.value(ByteData.sublistView(file.readAsBytesSync())),
            ))
            .load();
      }
    }
  });
  testWidgets(
    'four Flutter maps enter gameplay, move, fire, pause and return to selection',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1360, 860));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      await tester.pump();
      expect(find.text('DEAD SIGNAL'), findsOneWidget);
      await capture(tester, 'menu');
      for (final map in FieldMap.values) {
        await tester.ensureVisible(find.byKey(ValueKey('map-${map.name}')));
        await tester.tap(find.byKey(ValueKey('map-${map.name}')));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.ensureVisible(
          find.byKey(const ValueKey('start-exploration')),
        );
        await tester.tap(find.byKey(const ValueKey('start-exploration')));
        await tester.pump();
        expect(find.text('LÕI 0/3'), findsOneWidget);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
        await tester.pump();
        await capture(tester, map.name);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
        await tester.pump();
        expect(find.text('ĐẠN 24 / 120'), findsNothing);
        await tester.tap(find.text('Tạm dừng'));
        await tester.pump();
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Chọn bản đồ khác'));
        await tester.pump();
        expect(find.text('DEAD SIGNAL'), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
  for (final size in [const Size(844, 390), const Size(390, 844)]) {
    testWidgets(
      'map menu and touch gameplay fit ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(app());
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('start-exploration')),
        );
        await tester.tap(find.byKey(const ValueKey('start-exploration')));
        await tester.pump();
        expect(find.byKey(const ValueKey('move-pad')), findsOneWidget);
        expect(find.byKey(const ValueKey('fire-pad')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('fire-pad')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('ĐẠN 24 / 120'), findsNothing);
        await capture(tester, 'touch-${size.width.toInt()}');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byTooltip('Tạm dừng'));
        await tester.pump();
        expect(find.text('Tiếp tục'), findsOneWidget);
        await tester.tap(find.text('Tiếp tục'));
        await tester.pump();
        expect(find.text('Tiếp tục'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }
}

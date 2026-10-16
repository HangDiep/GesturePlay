import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/services/local_scores.dart';
import 'package:gestureplay/ui/runner_app.dart';

void main() {
  setUpAll(() async {
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      await (FontLoader('Segoe UI')..addFont(
            Future.value(ByteData.sublistView(font.readAsBytesSync())),
          ))
          .load();
    }
  });
  testWidgets('Flutter menu -> keyboard preparation -> Flame game -> pause', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('gestureplay_widget_');
    addTearDown(() => dir.deleteSync(recursive: true));
    await tester.binding.setSurfaceSize(const Size(1120, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      GesturePlayApp(
        bridge: HandBridge(autoLaunch: false),
        scores: LocalScores(File('${dir.path}/scores.json')),
      ),
    );
    await tester.pump();
    expect(find.text('GesturePlay'), findsOneWidget);
    if (Platform.environment['WRITE_GESTUREPLAY_PREVIEW'] == '1') {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('gestureplay-canvas')),
        );
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        File(
          '../.cache/flutter-menu.png',
        ).writeAsBytesSync(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.tap(find.text('Luyện bằng bàn phím'));
    await tester.pump();
    expect(find.text('Sẵn sàng xuất phát'), findsOneWidget);
    await tester.tap(find.text('Bắt đầu'));
    await tester.pump();
    for (var i = 0; i < 35; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Tạm dừng'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Tạm dừng'));
    await tester.pump();
    expect(find.text('Tiếp tục'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

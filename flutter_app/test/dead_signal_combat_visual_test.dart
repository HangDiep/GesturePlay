import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/dead_signal/model.dart';
import 'package:gestureplay/dead_signal/scene.dart';

void main() {
  setUpAll(() async {
    final file = File('C:/Windows/Fonts/segoeui.ttf');
    if (file.existsSync()) {
      await (FontLoader('Segoe UI')..addFont(
            Future.value(ByteData.sublistView(file.readAsBytesSync())),
          ))
          .load();
    }
  });
  testWidgets(
    'four enemy designs, hit, stun, charge, weak point and death render and pause correctly',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(960, 540));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final m = SignalModel()
        ..start()
        ..selectCamera(1);
      m.spawn(EnemyKind.runner, zone: 1, progress: .25)
        ..health = 30
        ..hitFor = .35
        ..lastDamage = 15;
      m.spawn(EnemyKind.breaker, zone: 1, progress: .52)
        ..health = 0
        ..deathFor = .65
        ..state = EnemyState.dead;
      m.spawn(EnemyKind.jammer, zone: 1, progress: .75).stunnedFor = 5;
      final boss = m.spawn(EnemyKind.boss, zone: 1, progress: 1)
        ..windupFor = 1.2
        ..state = EnemyState.windingUp;
      m.toggleDoor(0);
      const key = ValueKey('combat-preview');
      Future<Uint8List> render(String name) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              backgroundColor: signalBg,
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox(
                    width: 960,
                    height: 540,
                    child: CustomPaint(painter: SecurityScene(model: m)),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        return tester
            .runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(key),
              );
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final bytes = data!.buffer.asUint8List();
              image.dispose();
              if (Platform.environment['WRITE_SIGNAL_PREVIEW'] == '1') {
                final file = File('../.cache/dead-signal-combat-$name.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes);
              }
              return bytes;
            })
            .then((value) => value!);
      }

      final charging = await render('charging');
      m.pause();
      for (var i = 0; i < 20; i++) {
        m.update(.1);
      }
      final paused = await render('paused');
      expect(listEquals(charging, paused), true);
      m.resume();
      m.update(.1);
      final moving = await render('hit');
      expect(listEquals(charging, moving), false);
      boss.windupFor = 0;
      boss.weakFor = SignalRules.bossExposure;
      boss.state = EnemyState.recovering;
      final exposed = await render('weak-point');
      expect(listEquals(exposed, moving), false);
      boss.health = 45;
      m.gunCooldown = 0;
      m.toggleGun();
      m.shoot(boss.aimPoint);
      m.update(.1);
      expect(boss.alive, false);
      await render('death');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestureplay/account/app.dart';
import 'package:gestureplay/account/auth_screen.dart';
import 'package:gestureplay/account/connection_page.dart';
import 'package:gestureplay/account/models.dart';
import 'package:gestureplay/account/player_pages.dart';
import 'package:gestureplay/account/ui.dart';
import 'package:gestureplay/dead_signal/settings.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/art.dart';
import 'package:gestureplay/survival/app.dart';
import 'package:gestureplay/survival/painter.dart';

class PreviewBridge extends HandBridge {
  PreviewBridge() : super(autoLaunch: false, clock: () => 0);
  int starts = 0, retries = 0, stops = 0;
  final commands = <String>[];
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  Future<void> retry() async {
    retries++;
  }

  @override
  void stop() {
    stops++;
  }

  @override
  Future<void> configure(int index, String cameraBackend) async {
    cameraIndex = index;
    backend = cameraBackend;
    starts++;
  }

  @override
  void calibrateOpen({bool both = false}) {
    commands.add('open:$both');
  }

  @override
  void calibrateClosed({bool both = false}) {
    commands.add('closed:$both');
  }
}

Future<void> click(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> keyed(WidgetTester t, String key) =>
    click(t, find.byKey(ValueKey(key)));
Future<void> back(WidgetTester t) async {
  await t.pageBack();
  await t.pump();
  await t.pump(const Duration(milliseconds: 800));
}

Future<void> capture(WidgetTester t, String name) async {
  if (Platform.environment['WRITE_PORTAL_PREVIEW'] != '1') return;
  await t.runAsync(() async {
    final boundary = t.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('portal-capture')),
    );
    final shot = await boundary.toImage();
    final png = await shot.toByteData(format: ui.ImageByteFormat.png);
    File(
      '../.cache/portal-$name.png',
    ).writeAsBytesSync(png!.buffer.asUint8List());
    shot.dispose();
  });
}

Widget framed(Widget app) =>
    RepaintBoundary(key: const ValueKey('portal-capture'), child: app);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    final fonts = {
      'MaterialIcons':
          'D:/android/flutter_windows_3.44.9-stable/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      'Segoe UI': 'C:/Windows/Fonts/segoeui.ttf',
    };
    for (final entry in fonts.entries) {
      final f = File(entry.value);
      if (!f.existsSync()) continue;
      await (FontLoader(entry.key)
            ..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync()))))
          .load();
    }
  });
  for (final size in [
    const Size(1280, 800),
    const Size(844, 390),
    const Size(390, 844),
  ]) {
    testWidgets('practice menu and feedback fit at $size', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      final art = (await t.runAsync(TownArt.load))!;
      final hand = PreviewBridge();
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      await t.pumpWidget(
        framed(
          SurvivalApp(
            art: art,
            bridge: hand,
            settings: SignalSettings(),
            practice: true,
            audioEnabled: false,
          ),
        ),
      );
      await t.pump();
      await capture(t, 'practice-menu-${size.width.toInt()}');
      expect(find.text('BÀI THỰC HÀNH'), findsOneWidget);
      await keyed(t, 'town-start');
      expect(find.textContaining('Bài 1/11'), findsOneWidget);
      await capture(t, 'practice-${size.width.toInt()}');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
    testWidgets(
      'login and registration validate, remain honest without a server at $size',
      (t) async {
        await t.binding.setSurfaceSize(size);
        addTearDown(() => t.binding.setSurfaceSize(null));
        var entered = 0, preview = 0;
        await t.pumpWidget(
          framed(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: portalTheme(),
              home: AuthScreen(
                gateway: const PendingAccountGateway(),
                onAuthenticated: (_) async {
                  entered++;
                },
                onPreview: () async {
                  preview++;
                },
              ),
            ),
          ),
        );
        await t.pump();
        await capture(t, 'login-${size.width.toInt()}');
        await keyed(t, 'auth-submit');
        expect(find.text('Nhập email hợp lệ.'), findsOneWidget);
        await keyed(t, 'auth-toggle');
        await t.enterText(find.byKey(const ValueKey('auth-name')), 'Mai');
        await t.enterText(
          find.byKey(const ValueKey('auth-email')),
          'mai@example.com',
        );
        await t.enterText(
          find.byKey(const ValueKey('auth-password')),
          'example-password',
        );
        await t.enterText(
          find.byKey(const ValueKey('auth-confirm')),
          'different',
        );
        await keyed(t, 'auth-submit');
        expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
        await t.enterText(
          find.byKey(const ValueKey('auth-confirm')),
          'example-password',
        );
        await keyed(t, 'auth-submit');
        expect(entered, 0);
        expect(find.textContaining('Chưa kết nối'), findsWidgets);
        await capture(t, 'register-${size.width.toInt()}');
        await keyed(t, 'auth-preview');
        expect(preview, 1);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      },
    );
    testWidgets('profile, history and connection fit at $size', (t) async {
      await t.binding.setSurfaceSize(size);
      addTearDown(() => t.binding.setSurfaceSize(null));
      const p = PlayerProfile(id: 'preview', displayName: 'Mai', preview: true);
      String? saved;
      await t.pumpWidget(
        framed(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: portalTheme(),
            home: ProfilePage(
              profile: p,
              records: const [],
              onRename: (name) async {
                saved = name;
                return p.renamed(name);
              },
            ),
          ),
        ),
      );
      await t.pump();
      await capture(t, 'profile-${size.width.toInt()}');
      await t.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Người sống sót',
      );
      await keyed(t, 'profile-save');
      expect(saved, 'Người sống sót');
      await t.pumpWidget(
        framed(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: portalTheme(),
            home: const HistoryPage(records: [], preview: true),
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('history-empty')), findsOneWidget);
      await capture(t, 'empty-${size.width.toInt()}');
      final hand = PreviewBridge();
      addTearDown(hand.dispose);
      final settings = SignalSettings();
      await t.pumpWidget(
        framed(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: portalTheme(),
            home: ConnectionPage(hand: hand, settings: settings),
          ),
        ),
      );
      await t.pump();
      await capture(t, 'connection-${size.width.toInt()}');
      await keyed(t, 'connection-connect');
      expect(hand.starts, 1);
      expect(settings.controlMode, 'twoHands');
      await keyed(t, 'connection-retry');
      expect(hand.retries, 1);
      Map<String, dynamic> side(double x) => {
        'valid': true,
        'ready': true,
        'released': true,
        'palm_x': x,
        'palm_y': .5,
        'calibration_message': 'Đã ghi tay mở.',
      };
      hand.acceptPacket({
        'type': 'hand',
        'protocol': 1,
        'epoch': 'portal',
        'seq': 1,
        'jump_id': 0,
        'age_ms': 0,
        'valid': true,
        'ready': true,
        'camera_phase': 'running',
        'tracker_phase': 'running',
        'hands': {'left': side(.25), 'right': side(.75)},
      });
      await t.pump();
      await click(t, find.text('1. Ghi tay mở'));
      await click(t, find.text('2. Ghi tay chụm'));
      expect(hand.commands, ['open:true', 'closed:true']);
      expect(find.text('Tay trái: Đã ghi tay mở.'), findsOneWidget);
      await capture(t, 'calibrate-${size.width.toInt()}');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    });
  }

  testWidgets(
    'preview portal routes, real results, practice isolation and logout',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final art = (await t.runAsync(TownArt.load))!;
      final hand = PreviewBridge();
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      await t.pumpWidget(
        framed(GesturePlayApp(art: art, bridge: hand, audioEnabled: false)),
      );
      await keyed(t, 'auth-preview');
      await t.pump();
      expect(find.byKey(const ValueKey('town-menu')), findsOneWidget);
      await capture(t, 'home');
      await keyed(t, 'menu-connection');
      await keyed(t, 'connection-connect');
      Map<String, dynamic> side(double x, bool fist) => {
        'valid': true,
        'ready': true,
        'released': !fist,
        'pinched': fist,
        'fist': fist,
        'palm_x': x,
        'palm_y': .5,
      };
      hand.acceptPacket({
        'type': 'hand',
        'protocol': 1,
        'epoch': 'connection-route',
        'seq': 1,
        'jump_id': 0,
        'valid': true,
        'ready': true,
        'age_ms': 0,
        'hands': {'left': side(.25, false), 'right': side(.75, true)},
      });
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await back(t);
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.byKey(const ValueKey('town-menu')), findsOneWidget);
      await click(t, find.text('Bàn phím / Cảm ứng'));
      await keyed(t, 'menu-profile');
      await t.enterText(
        find.byKey(const ValueKey('profile-name')),
        'Mai trong đêm',
      );
      await keyed(t, 'profile-save');
      await back(t);
      expect(find.text('Xin chào, Mai trong đêm'), findsOneWidget);
      await keyed(t, 'menu-history');
      expect(find.byKey(const ValueKey('history-empty')), findsOneWidget);
      await back(t);
      await keyed(t, 'difficulty-easy');
      await keyed(t, 'town-start');
      ExplorationModel game() => t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<TownPainter>()
          .first
          .model;
      final run = game();
      run.hurt(1000, isHazard: true, reason: 'Lượt thử giao diện');
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      await click(t, find.text('Về trang chủ'));
      await keyed(t, 'menu-history');
      expect(find.text('TÍN HIỆU ĐÃ MẤT'), findsOneWidget);
      expect(find.textContaining('Dễ · Bàn phím'), findsOneWidget);
      expect(find.text('Lượt thử giao diện'), findsOneWidget);
      await capture(t, 'history');
      await back(t);
      await keyed(t, 'menu-practice');
      await keyed(t, 'town-start');
      expect(game().practice, true);
      expect(game().score, 0);
      await capture(t, 'practice');
      await t.sendKeyEvent(LogicalKeyboardKey.escape);
      await t.pump();
      await click(t, find.text('Về trang chủ'));
      await t.pump(const Duration(milliseconds: 350));
      await keyed(t, 'menu-history');
      expect(find.text('TÍN HIỆU ĐÃ MẤT'), findsOneWidget);
      await back(t);
      await keyed(t, 'menu-logout');
      expect(find.byKey(const ValueKey('auth-submit')), findsOneWidget);
      await keyed(t, 'auth-preview');
      await keyed(t, 'menu-history');
      expect(find.byKey(const ValueKey('history-empty')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestureplay/account/app.dart';
import 'package:gestureplay/account/history_page.dart';
import 'package:gestureplay/account/result_journal.dart';
import 'package:gestureplay/account/result_widgets.dart';
import 'package:gestureplay/account/ui.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/survival/app.dart';
import 'package:gestureplay/survival/art.dart';
import 'package:gestureplay/survival/painter.dart';
import 'package:gestureplay/survival/round_result.dart';
import 'package:gestureplay/dead_signal/settings.dart';
import 'portal_widget_test.dart'
    show PreviewBridge, click, keyed, back, framed, capture;
import 'result_journal_test.dart'
    show sampleRound, TestAccountGateway, MemoryResultStorage;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  setUpAll(() async {
    for (final entry in {
      'MaterialIcons':
          'D:/android/flutter_windows_3.44.9-stable/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
      'Segoe UI': 'C:/Windows/Fonts/segoeui.ttf',
    }.entries) {
      final font = File(entry.value);
      if (!font.existsSync()) continue;
      await (FontLoader(entry.key)..addFont(
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
      'history sorts, filters difficulty and opens the saved resources at $size',
      (t) async {
        await t.binding.setSurfaceSize(size);
        addTearDown(() => t.binding.setSurfaceSize(null));
        final old = sampleRound(
          'older',
          won: false,
          difficulty: 'Dễ',
          score: 400,
          day: 5,
        );
        final easy = sampleRound('easy', difficulty: 'Dễ', score: 2200, day: 6);
        final newest = sampleRound('newest', score: 1800, day: 7);
        await t.pumpWidget(
          framed(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: portalTheme(),
              home: HistoryPage(
                records: [old, newest, easy, newest],
                preview: true,
              ),
            ),
          ),
        );
        await t.pump();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('stats-easy-completed')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('stats-normal-best')),
            matching: find.text('1800'),
          ),
          findsOneWidget,
        );
        final cards = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('history-card-'),
        );
        expect(
          t.widgetList(cards).map((w) => (w.key as ValueKey<String>).value),
          ['history-card-newest', 'history-card-easy', 'history-card-older'],
        );
        await capture(t, 'results-history-${size.width.toInt()}');
        await keyed(t, 'history-difficulty-easy');
        expect(find.byKey(const ValueKey('history-card-newest')), findsNothing);
        await click(t, find.widgetWithText(ChoiceChip, 'Thất bại'));
        expect(find.byKey(const ValueKey('history-card-easy')), findsNothing);
        await keyed(t, 'result-detail-older');
        expect(find.text('Chi tiết lượt chơi'), findsOneWidget);
        expect(find.text('Trúng ma lực'), findsOneWidget);
        expect(find.text('0/100 HP'), findsOneWidget);
        expect(find.text('63'), findsOneWidget);
        expect(find.text('2/3'), findsOneWidget);
        expect(find.text('Điện còn lại'), findsNothing);
        await capture(t, 'results-detail-${size.width.toInt()}');
        await t.ensureVisible(find.byKey(const ValueKey('round-id')));
        await t.pump();
        expect(
          t.widget<SelectableText>(find.byKey(const ValueKey('round-id'))).data,
          'older',
        );
        await capture(t, 'results-resources-${size.width.toInt()}');
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump();
      },
    );
  }
  testWidgets(
    'save status updates while viewing details, retries the same ID and then reports success',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final gateway = TestAccountGateway()..offline = true;
      final journal = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: MemoryResultStorage(),
      );
      addTearDown(journal.dispose);
      final result = sampleRound('retry-me');
      await journal.load();
      await journal.add(result);
      await t.pumpWidget(
        framed(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: portalTheme(),
            home: RoundDetailPage(result: result, journal: journal),
          ),
        ),
      );
      await t.pump();
      expect(find.byKey(const ValueKey('result-save-failed')), findsOneWidget);
      await t.ensureVisible(
        find.byKey(const ValueKey('retry-result-retry-me')),
      );
      await t.pump();
      await capture(t, 'results-save-failed');
      gateway
        ..offline = false
        ..barrier = Completer<void>();
      await keyed(t, 'retry-result-retry-me');
      expect(find.byKey(const ValueKey('result-save-saving')), findsOneWidget);
      expect(find.byKey(const ValueKey('retry-result-retry-me')), findsNothing);
      gateway.barrier!.complete();
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('result-save-saved')), findsOneWidget);
      expect(gateway.sentIds, ['retry-me', 'retry-me']);
      expect(gateway.server['p1'], hasLength(1));
      await capture(t, 'results-save-success');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets(
    'ending each actual run captures resources once and every replay gets a new ID',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final art = (await t.runAsync(TownArt.load))!, hand = PreviewBridge();
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      final records = <RoundResult>[];
      await t.pumpWidget(
        framed(
          SurvivalApp(
            art: art,
            bridge: hand,
            settings: SignalSettings(),
            audioEnabled: false,
            onResult: records.add,
          ),
        ),
      );
      await keyed(t, 'town-start');
      ExplorationModel game() => t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<TownPainter>()
          .first
          .model;
      final first = game()
        ..ammo = 7
        ..reserve = 63
        ..medkits = 2
        ..wave = 5;
      first.hurt(1000, isHazard: true, reason: 'Trúng ma lực');
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(records, hasLength(1));
      expect(records.single.ammo, 7);
      expect(records.single.reserve, 63);
      expect(records.single.medkits, 2);
      expect(records.single.won, false);
      await capture(t, 'results-gameover');
      await click(t, find.text('CHƠI LẠI MAP'));
      expect(game().active, true);
      game()
        ..wave = 5
        ..elapsed = 179.99;
      await t.pump(const Duration(milliseconds: 100));
      await t.pump(const Duration(milliseconds: 100));
      expect(records, hasLength(2));
      expect(records.last.won, true);
      expect(records.first.id, isNot(records.last.id));
      await t.pump(const Duration(seconds: 1));
      expect(records, hasLength(2));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
  testWidgets(
    'latest result details and history refer to one session record without claiming online save',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final art = (await t.runAsync(TownArt.load))!, hand = PreviewBridge();
      addTearDown(() {
        art.dispose();
        hand.dispose();
      });
      await t.pumpWidget(
        framed(GesturePlayApp(art: art, bridge: hand, audioEnabled: false)),
      );
      await keyed(t, 'auth-preview');
      await keyed(t, 'town-start');
      final game = t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<TownPainter>()
          .first
          .model;
      game.hurt(1000, isHazard: true);
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byKey(const ValueKey('result-save-sessionOnly')),
        findsOneWidget,
      );
      await capture(t, 'results-session');
      await keyed(t, 'last-result-detail');
      final id = t
          .widget<SelectableText>(find.byKey(const ValueKey('round-id')))
          .data;
      await back(t);
      await click(t, find.text('Về trang chủ'));
      await keyed(t, 'menu-history');
      expect(find.byKey(ValueKey('history-card-$id')), findsOneWidget);
      await keyed(t, 'result-detail-$id');
      expect(
        t.widget<SelectableText>(find.byKey(const ValueKey('round-id'))).data,
        id,
      );
      expect(find.byKey(const ValueKey('result-save-saved')), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox.shrink());
      await t.pump();
    },
  );
}

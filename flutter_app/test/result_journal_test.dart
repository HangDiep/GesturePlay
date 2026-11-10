import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gestureplay/account/models.dart';
import 'package:gestureplay/account/result_journal.dart';
import 'package:gestureplay/survival/round_result.dart';

RoundResult sampleRound(
  String id, {
  bool won = true,
  String difficulty = 'Thường',
  int score = 900,
  int day = 7,
}) => RoundResult(
  id: id,
  playedAt: DateTime(2026, 11, day, 10, 20),
  endedAt: DateTime(2026, 11, day, 10, 23),
  won: won,
  seconds: won ? 180 : 54.5,
  score: score,
  kills: 6,
  cores: 1,
  shots: 20,
  hits: 12,
  health: won ? 37 : 0,
  difficulty: difficulty,
  controls: 'Hai tay',
  reason: won ? '' : 'Trúng ma lực',
  weapon: 'SÚNG TRƯỜNG',
  ammo: 7,
  reserve: 63,
  medkits: 2,
);

class MemoryResultStorage implements ResultStorage {
  List<Map<String, dynamic>> rows = [];
  int writes = 0;
  bool fail = false;
  @override
  Future<List<Map<String, dynamic>>> read() async => rows
      .map((e) => Map<String, dynamic>.from(jsonDecode(jsonEncode(e)) as Map))
      .toList();
  @override
  Future<void> write(List<Map<String, dynamic>> entries) async {
    writes++;
    if (fail) throw StateError('Device storage unavailable');
    rows = entries
        .map((e) => Map<String, dynamic>.from(jsonDecode(jsonEncode(e)) as Map))
        .toList();
  }
}

class TestAccountGateway implements AccountGateway {
  bool offline = false, commitThenFail = false;
  String owner = 'p1';
  int calls = 0;
  final sentIds = <String>[];
  final server = <String, Map<String, RoundResult>>{};
  Completer<void>? barrier;
  @override
  bool get configured => true;
  @override
  Future<PlayerProfile> signIn(String email, String password) async =>
      PlayerProfile(id: owner, displayName: 'Người thử', email: email);
  @override
  Future<PlayerProfile> signUp(
    String name,
    String email,
    String password,
  ) async => PlayerProfile(id: owner, displayName: name, email: email);
  @override
  Future<void> signOut() async {}
  @override
  Future<PlayerProfile> rename(String name) async =>
      PlayerProfile(id: owner, displayName: name);
  @override
  Future<List<RoundResult>> history() async {
    if (offline) throw StateError('Offline');
    return server[owner]?.values.toList() ?? [];
  }

  @override
  Future<void> saveResult(
    RoundResult result, {
    required String playerId,
  }) async {
    calls++;
    sentIds.add(result.id);
    if (playerId != owner) throw StateError('Wrong owner');
    if (offline && !commitThenFail) throw StateError('Offline');
    (server[playerId] ??= <String, RoundResult>{}).putIfAbsent(
      result.id,
      () => result,
    );
    await barrier?.future;
    if (offline || commitThenFail) throw StateError('Acknowledgement lost');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'a stalled request times out, then retry keeps the committed ID',
    () async {
      final barrier = Completer<void>();
      final gateway = TestAccountGateway()..barrier = barrier;
      final journal = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: MemoryResultStorage(),
        requestTimeout: const Duration(milliseconds: 20),
      );
      addTearDown(journal.dispose);
      await journal.load();
      await journal.add(sampleRound('timeout'));
      expect(journal.entry('timeout')!.state, ResultSaveState.failed);
      gateway.barrier = null;
      await journal.retry('timeout');
      barrier.complete();
      expect(journal.entry('timeout')!.state, ResultSaveState.saved);
      expect(gateway.server['p1'], hasLength(1));
    },
  );
  test(
    'refresh merges newly available history and retains unsent device results',
    () async {
      final gateway = TestAccountGateway()..offline = true;
      final journal = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: MemoryResultStorage(),
      );
      addTearDown(journal.dispose);
      await journal.load();
      await journal.add(sampleRound('pending'));
      gateway
        ..offline = false
        ..server['p1'] = {'remote': sampleRound('remote')};
      await journal.refresh();
      expect(journal.historyUnavailable, false);
      expect(journal.records, hasLength(2));
      expect(journal.entry('remote')!.state, ResultSaveState.saved);
      expect(journal.entry('pending')!.state, ResultSaveState.failed);
      await journal.retryPending();
      expect(journal.pendingCount, 0);
      expect(gateway.server['p1'], hasLength(2));
    },
  );
  test(
    'unreadable device cache is reported and is not silently overwritten',
    () async {
      SharedPreferences.setMockInitialValues({
        'player.p1.rounds.v1': 'unreadable cache',
      });
      final journal = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: TestAccountGateway()..offline = true,
      );
      addTearDown(journal.dispose);
      await journal.load();
      await journal.add(sampleRound('memory-only'));
      expect(journal.cacheUnreadable, true);
      expect(journal.entry('memory-only')!.state, ResultSaveState.failed);
      expect(
        (await SharedPreferences.getInstance()).getString(
          'player.p1.rounds.v1',
        ),
        'unreadable cache',
      );
    },
  );
  test(
    'UUIDs identify rounds independently of retry seed and serialize all result fields',
    () {
      final ids = List.generate(500, (_) => RoundResult.newId());
      expect(ids.toSet().length, 500);
      expect(
        ids.every(
          (id) => RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id),
        ),
        true,
      );
      final r = sampleRound(ids.first, difficulty: 'Dễ');
      final restored = RoundResult.fromJson(
        jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), r.toJson());
      expect(restored.accuracy, 60);
      expect(restored.ammo, 7);
      expect(restored.medkits, 2);
      final legacy = r.toJson()
        ..remove('ammo')
        ..remove('reserve')
        ..remove('medkits')
        ..remove('weapon');
      expect(RoundResult.fromJson(legacy).ammo, isNull);
      expect(
        () => RoundResult.fromJson(r.toJson()..['score'] = -1),
        throwsFormatException,
      );
    },
  );
  test(
    'statistics deduplicate rounds and separate all finished wins/losses by difficulty',
    () {
      final a = sampleRound('a', difficulty: 'Dễ', score: 2200),
          b = sampleRound('b', won: false, difficulty: 'Dễ', score: 400),
          c = sampleRound('c', score: 1800);
      final all = PersonalStats([a, b, c, a]);
      expect(all.completed, 3);
      expect(all.wins, 2);
      expect(all.best, 2200);
      final easy = PersonalStats([a, b, c, a], difficulty: 'easy');
      expect(easy.completed, 2);
      expect(easy.wins, 1);
      expect(easy.best, 2200);
      expect(PersonalStats([a, b, c], difficulty: 'normal').best, 1800);
    },
  );
  test(
    'preview cannot claim a server save or persist account history',
    () async {
      final gateway = TestAccountGateway(), storage = MemoryResultStorage();
      final journal = ResultJournal(
        playerId: 'preview',
        preview: true,
        gateway: gateway,
        storage: storage,
      );
      addTearDown(journal.dispose);
      await journal.load();
      await journal.add(sampleRound('trial'));
      await journal.retry('trial');
      expect(journal.entry('trial')!.state, ResultSaveState.sessionOnly);
      expect(gateway.calls, 0);
      expect(storage.writes, 0);
    },
  );
  test(
    'same finished result is added once and retry calls share one in-flight save',
    () async {
      final gateway = TestAccountGateway()..barrier = Completer<void>();
      final storage = MemoryResultStorage();
      final journal = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: storage,
      );
      addTearDown(journal.dispose);
      await journal.load();
      final adding = journal.add(sampleRound('once'));
      await Future<void>.delayed(Duration.zero);
      expect(journal.entry('once')!.state, ResultSaveState.saving);
      final first = journal.retry('once'), second = journal.retry('once');
      expect(identical(first, second), true);
      await journal.add(sampleRound('once', score: 9999));
      gateway.barrier!.complete();
      await adding;
      await first;
      expect(journal.records, hasLength(1));
      expect(gateway.calls, 1);
      expect(journal.records.single.score, 900);
      expect(journal.entry('once')!.state, ResultSaveState.saved);
      await journal.retry('once');
      expect(gateway.calls, 1);
    },
  );
  test(
    'offline queue survives reopening and a lost acknowledgement cannot duplicate a committed result',
    () async {
      final gateway = TestAccountGateway()
        ..offline = true
        ..commitThenFail = true;
      final storage = MemoryResultStorage();
      final first = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: storage,
      );
      await first.load();
      await first.add(sampleRound('stable-id'));
      expect(first.entry('stable-id')!.state, ResultSaveState.failed);
      expect(first.cacheFailed, false);
      expect(gateway.server['p1'], hasLength(1));
      first.dispose();
      final restored = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: storage,
      );
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.historyUnavailable, true);
      expect(restored.entry('stable-id')!.state, ResultSaveState.pending);
      gateway
        ..offline = false
        ..commitThenFail = false;
      await restored.retryPending();
      expect(restored.entry('stable-id')!.state, ResultSaveState.saved);
      expect(gateway.sentIds, ['stable-id', 'stable-id']);
      expect(gateway.server['p1'], hasLength(1));
      expect(restored.records, hasLength(1));
    },
  );
  test(
    'remote history reconciles pending committed IDs without uploading them again',
    () async {
      final gateway = TestAccountGateway()..commitThenFail = true;
      final storage = MemoryResultStorage();
      final a = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: storage,
      );
      await a.load();
      await a.add(sampleRound('committed'));
      a.dispose();
      gateway.commitThenFail = false;
      final b = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: storage,
      );
      addTearDown(b.dispose);
      await b.load();
      await b.retryPending();
      expect(b.entry('committed')!.state, ResultSaveState.saved);
      expect(gateway.calls, 1);
    },
  );
  test(
    'device write failure is visible and a later retry recovers without another server insert',
    () async {
      final gateway = TestAccountGateway()..offline = true;
      final storage = MemoryResultStorage()..fail = true;
      final journal = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
        storage: storage,
      );
      addTearDown(journal.dispose);
      await journal.load();
      await journal.add(sampleRound('disk-error'));
      expect(journal.cacheFailed, true);
      expect(journal.entry('disk-error')!.state, ResultSaveState.failed);
      storage.fail = false;
      gateway.offline = false;
      await journal.retry('disk-error');
      expect(journal.cacheFailed, false);
      expect(journal.entry('disk-error')!.state, ResultSaveState.saved);
      expect(storage.rows, hasLength(1));
    },
  );
  test(
    'persistent queues and late acknowledgements remain isolated by account',
    () async {
      final gateway = TestAccountGateway()..barrier = Completer<void>();
      final a = ResultJournal(playerId: 'p1', preview: false, gateway: gateway);
      await a.load();
      final saving = a.add(sampleRound('same-id'));
      await Future<void>.delayed(Duration.zero);
      a.dispose();
      gateway.owner = 'p2';
      final b = ResultJournal(playerId: 'p2', preview: false, gateway: gateway);
      addTearDown(b.dispose);
      await b.load();
      expect(b.records, isEmpty);
      gateway.barrier!.complete();
      await saving;
      final cacheA = await PreferenceResultStorage('p1').read(),
          cacheB = await PreferenceResultStorage('p2').read();
      expect(cacheA.single['saved'], true);
      expect(cacheB, isEmpty);
      expect(b.records, isEmpty);
      gateway
        ..owner = 'p1'
        ..offline = true;
      final again = ResultJournal(
        playerId: 'p1',
        preview: false,
        gateway: gateway,
      );
      addTearDown(again.dispose);
      await again.load();
      expect(again.records.single.id, 'same-id');
    },
  );
}

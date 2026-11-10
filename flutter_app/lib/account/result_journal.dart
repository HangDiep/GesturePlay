import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../survival/round_result.dart';
import 'models.dart';

enum ResultSaveState { sessionOnly, pending, saving, saved, failed }

class ResultEntry {
  ResultEntry(this.result, this.state);
  final RoundResult result;
  ResultSaveState state;
}

abstract interface class ResultStorage {
  Future<List<Map<String, dynamic>>> read();
  Future<void> write(List<Map<String, dynamic>> entries);
}

class PreferenceResultStorage implements ResultStorage {
  PreferenceResultStorage(this.playerId);
  final String playerId;
  String get _key => 'player.${Uri.encodeComponent(playerId)}.rounds.v1';
  @override
  Future<List<Map<String, dynamic>>> read() async {
    final text = (await SharedPreferences.getInstance()).getString(_key);
    if (text == null) return [];
    final data = jsonDecode(text);
    if (data is! Map ||
        data['version'] != 1 ||
        data['owner'] != playerId ||
        data['entries'] is! List) {
      throw const FormatException('Invalid result cache');
    }
    return (data['entries'] as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> write(List<Map<String, dynamic>> entries) async {
    final saved = await (await SharedPreferences.getInstance()).setString(
      _key,
      jsonEncode({'version': 1, 'owner': playerId, 'entries': entries}),
    );
    if (!saved) throw StateError('Result cache was not written');
  }
}

/// One journal belongs to one signed-in player. Preview stays session-only.
class ResultJournal extends ChangeNotifier {
  ResultJournal({
    required this.playerId,
    required this.preview,
    required this.gateway,
    ResultStorage? storage,
    this.requestTimeout = const Duration(seconds: 12),
  }) : storage = storage ?? PreferenceResultStorage(playerId);
  final String playerId;
  final bool preview;
  final AccountGateway gateway;
  final ResultStorage storage;
  final Duration requestTimeout;
  final _entries = <String, ResultEntry>{};
  final _inFlight = <String, Future<void>>{};
  Future<void> _writes = Future.value();
  Future<void>? _batch;
  Future<void>? _refresh;
  bool _disposed = false,
      cacheFailed = false,
      historyUnavailable = false,
      cacheUnreadable = false;
  bool get refreshing => _refresh != null;
  bool get canSync => !preview && gateway.configured;
  List<RoundResult> get records =>
      _entries.values.map((e) => e.result).toList()
        ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
  ResultEntry? entry(String id) => _entries[id];
  int get pendingCount => _entries.values
      .where(
        (e) =>
            e.state != ResultSaveState.saved &&
            e.state != ResultSaveState.sessionOnly,
      )
      .length;
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    if (!canSync) return;
    try {
      for (final row in await storage.read()) {
        final result = RoundResult.fromJson(
          Map<String, dynamic>.from(row['result'] as Map),
        );
        _entries[result.id] = ResultEntry(
          result,
          row['saved'] == true
              ? ResultSaveState.saved
              : ResultSaveState.pending,
        );
      }
    } catch (_) {
      cacheUnreadable = true;
    }
    if (!_disposed) await refresh();
  }

  Future<void> refresh() {
    if (_disposed || !canSync) return Future.value();
    if (_refresh != null) return _refresh!;
    final task = _fetchRemote();
    _refresh = task;
    task.whenComplete(() {
      _refresh = null;
      _changed();
    });
    return task;
  }

  Future<void> _fetchRemote() async {
    _changed();
    try {
      final remote = await gateway.history().timeout(requestTimeout);
      if (_disposed) return;
      for (final result in remote) {
        _entries[result.id] = ResultEntry(result, ResultSaveState.saved);
      }
      historyUnavailable = false;
    } catch (_) {
      historyUnavailable = true;
    }
    if (!_disposed) {
      if (!cacheUnreadable) await _persist();
      _changed();
    }
  }

  Future<void> _persist() {
    if (!canSync || cacheUnreadable) return Future.value();
    final snapshot = _entries.values
        .map(
          (e) => <String, dynamic>{
            'result': e.result.toJson(),
            'saved': e.state == ResultSaveState.saved,
          },
        )
        .toList();
    _writes = _writes.then((_) async {
      try {
        await storage.write(snapshot);
        cacheFailed = false;
      } catch (_) {
        cacheFailed = true;
      }
    });
    return _writes;
  }

  Future<void> add(RoundResult result) async {
    if (_disposed || _entries.containsKey(result.id)) return;
    _entries[result.id] = ResultEntry(
      result,
      canSync ? ResultSaveState.pending : ResultSaveState.sessionOnly,
    );
    _changed();
    await _persist();
    if (!_disposed) {
      _changed();
      await retry(result.id);
    }
  }

  Future<void> retry(String id) {
    if (_disposed || !canSync || !_entries.containsKey(id)) {
      return Future.value();
    }
    final active = _inFlight[id];
    if (active != null) return active;
    final task = _upload(id);
    _inFlight[id] = task;
    task.whenComplete(() => _inFlight.remove(id));
    return task;
  }

  Future<void> _upload(String id) async {
    final item = _entries[id]!;
    if (item.state == ResultSaveState.saved) {
      await _persist();
      _changed();
      return;
    }
    item.state = ResultSaveState.saving;
    _changed();
    await _persist();
    if (_disposed) return;
    try {
      await gateway
          .saveResult(item.result, playerId: playerId)
          .timeout(requestTimeout);
      item.state = ResultSaveState.saved;
    } catch (_) {
      item.state = ResultSaveState.failed;
    }
    // Even an acknowledgement arriving after logout updates only this owner's cache.
    await _persist();
    _changed();
  }

  Future<void> retryPending() {
    if (_batch != null) return _batch!;
    final ids = _entries.values
        .where((e) => e.state != ResultSaveState.saved)
        .map((e) => e.result.id)
        .toList();
    final task = () async {
      for (final id in ids) {
        if (_disposed) return;
        await retry(id);
      }
    }();
    _batch = task;
    task.whenComplete(() => _batch = null);
    return task;
  }
}

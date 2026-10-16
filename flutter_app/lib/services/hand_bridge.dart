import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'project_paths.dart';

class HandPacket {
  HandPacket(this.data);
  final Map<String, dynamic> data;
  bool flag(String key) => data[key] == true;
  double? number(String key) => data[key] is num && (data[key] as num).isFinite
      ? (data[key] as num).toDouble()
      : null;
  String text(String key, [String fallback = '']) =>
      data[key] is String ? data[key] as String : fallback;
  int get sequence => (data['seq'] as num?)?.toInt() ?? 0;
  int get jumpId => (data['jump_id'] as num?)?.toInt() ?? 0;
  String get epoch => text('epoch');
  List<Offset> get points {
    final value = data['pinch_points'];
    if (value is! List || value.length != 2) return [];
    final result = <Offset>[];
    for (final point in value) {
      if (point is! List ||
          point.length != 2 ||
          point.any((v) => v is! num || !v.isFinite)) {
        return [];
      }
      result.add(
        Offset((point[0] as num).toDouble(), (point[1] as num).toDouble()),
      );
    }
    return result;
  }
}

/// Only small local hand packets enter Dart; no Python game code is executed.
class HandBridge extends ChangeNotifier {
  HandBridge({this.autoLaunch = true, Uri? uri, int Function()? clock})
    : uri = uri ?? Uri.parse('ws://127.0.0.1:8765') {
    _watch.start();
    _clock = clock ?? () => _watch.elapsedMilliseconds;
  }
  final bool autoLaunch;
  final Uri uri;
  final _watch = Stopwatch();
  late final int Function() _clock;
  final preview = ValueNotifier<Uint8List?>(null);
  HandPacket? latest;
  WebSocket? _socket;
  Process? _process;
  StreamSubscription<dynamic>? _subscription;
  bool connected = false,
      connecting = false,
      _disposed = false,
      _wanted = false,
      _previewWanted = false;
  String? error;
  int _receivedAt = -100000, _seenJump = 0, _generation = 0;
  double _transportAge = 0;
  String _seenEpoch = '';
  int cameraIndex = 0;
  String backend = 'dshow';
  double get ageMs =>
      (_clock() - _receivedAt) +
      _transportAge +
      (latest?.number('age_ms') ?? 100000);
  bool get valid => connected && latest?.flag('valid') == true && ageMs <= 250;
  bool get ready => valid && latest?.flag('ready') == true;
  bool get released => valid && latest?.flag('released') == true;
  bool get pinched => valid && latest?.flag('pinched') == true;

  void acceptPacket(Map<String, dynamic> json) {
    if (json['type'] == 'error') {
      error = json['message'] as String?;
      _notify();
      return;
    }
    if (json['type'] != 'hand' ||
        json['protocol'] != 1 ||
        json['epoch'] is! String ||
        json['seq'] is! int ||
        json['jump_id'] is! int) {
      return;
    }
    final packet = HandPacket(json);
    if (latest?.epoch == packet.epoch && packet.sequence <= latest!.sequence) {
      return;
    }
    latest = packet;
    _receivedAt = _clock();
    final sentAt = packet.number('sent_at_ms');
    _transportAge = sentAt == null
        ? 0
        : (DateTime.now().millisecondsSinceEpoch - sentAt)
              .clamp(0, 100000)
              .toDouble();
    connected = true;
    error = null;
    _notify();
  }

  bool consumeJump() {
    final packet = latest;
    if (packet == null) return false;
    if (_seenEpoch != packet.epoch) {
      discardJumps();
      return false;
    }
    final eventAge =
        (packet.number('jump_age_ms') ?? 0) +
        _transportAge +
        _clock() -
        _receivedAt;
    final pressed = valid && packet.jumpId > _seenJump && eventAge <= 250;
    _seenJump = packet.jumpId;
    return pressed;
  }

  void discardJumps() {
    _seenEpoch = latest?.epoch ?? '';
    _seenJump = latest?.jumpId ?? 0;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    _wanted = true;
    await connect();
    if (_wanted && connected) {
      send('start', {'camera_index': cameraIndex, 'backend': backend});
      setPreview(_previewWanted);
    }
  }

  Future<void> connect() async {
    if (connected || connecting || _disposed) return;
    connecting = true;
    error = null;
    _notify();
    final generation = ++_generation;
    var launched = false;
    try {
      for (
        var attempt = 0;
        attempt < 40 && !_disposed && generation == _generation;
        attempt++
      ) {
        try {
          final pending = WebSocket.connect(uri.toString());
          final socket = await pending.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              // A timeout doesn't cancel the underlying handshake. Close a
              // late connection so it cannot keep Python's single owner slot.
              unawaited(
                pending.then<void>(
                  (lateSocket) => unawaited(lateSocket.close()),
                  onError: (Object _) {},
                ),
              );
              throw TimeoutException('Hand service handshake timed out');
            },
          );
          if (_disposed || generation != _generation) {
            await socket.close();
            return;
          }
          _socket = socket;
          connected = true;
          _subscription = socket.listen(
            (message) {
              if (_disposed || generation != _generation) return;
              if (message is String) {
                try {
                  final json = jsonDecode(message);
                  if (json is Map<String, dynamic>) acceptPacket(json);
                } on FormatException {
                  error = 'Dữ liệu nhận diện chưa hợp lệ.';
                  _notify();
                }
              } else if (message is List<int>) {
                final old = preview.value;
                if (old != null) unawaited(MemoryImage(old).evict());
                preview.value = Uint8List.fromList(message);
              }
            },
            onDone: () => _disconnected(generation),
            onError: (_) => _disconnected(generation),
          );
          return;
        } on Object catch (connectionError) {
          if (kDebugMode && attempt == 0) {
            debugPrint('Hand service connection: $connectionError');
          }
          if (autoLaunch && !launched && _process == null) {
            launched = true;
            if (!File(ProjectPaths.python).existsSync() ||
                !File(ProjectPaths.service).existsSync()) {
              throw StateError(
                'Chưa tìm thấy phần nhận diện. Hãy mở từ thư mục dự án.',
              );
            }
            final process = await Process.start(
              ProjectPaths.python,
              [
                '-u',
                ProjectPaths.service,
                '--port',
                '${uri.port}',
                '--idle-timeout',
                '5',
              ],
              workingDirectory: ProjectPaths.locateRoot(),
              environment: {'PYTHONIOENCODING': 'utf-8'},
            );
            _process = process;
            process.stdout.drain<void>();
            process.stderr.drain<void>();
            unawaited(
              process.exitCode.then((_) {
                if (identical(_process, process)) _process = null;
              }),
            );
          }
          if (!autoLaunch || attempt == 39) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
      }
    } on Object {
      error =
          'Chưa kết nối được phần nhận diện. Kiểm tra Python hoặc bấm Thử lại.';
    } finally {
      connecting = false;
      _notify();
    }
  }

  void _disconnected(int generation) {
    if (_disposed || generation != _generation) return;
    connected = false;
    _socket = null;
    error = 'Mất kết nối nhận diện. Ván chơi sẽ tạm dừng.';
    _notify();
  }

  void send(String action, [Map<String, dynamic> values = const {}]) {
    if (_socket?.readyState == WebSocket.open) {
      _socket!.add(
        jsonEncode({'type': 'command', 'action': action, ...values}),
      );
    }
  }

  void setPreview(bool enabled) {
    _previewWanted = enabled;
    send('preview', {'enabled': enabled});
    if (!enabled) _clearPreview();
  }

  void stop() {
    _wanted = false;
    send('stop');
    setPreview(false);
    discardJumps();
  }

  Future<void> retry() async {
    if (connected) {
      send('restart');
    } else {
      await start();
    }
  }

  Future<void> configure(int index, String cameraBackend) async {
    if (_disposed ||
        index < 0 ||
        index > 20 ||
        !['dshow', 'msmf', 'auto'].contains(cameraBackend)) {
      return;
    }
    if (connected) {
      send('stop');
      var idle = false;
      for (var i = 0; i < 150 && !_disposed; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (latest?.flag('idle') == true) {
          idle = true;
          break;
        }
      }
      if (!idle) {
        error = 'Camera cũ chưa đóng. Hãy chờ rồi thử lại.';
        _notify();
        return;
      }
    }
    cameraIndex = index;
    backend = cameraBackend;
    await start();
  }

  void calibrateOpen() => send('calibrate_open');
  void calibrateClosed() => send('calibrate_closed');
  void resetCalibration() => send('calibrate_reset');
  void _clearPreview() {
    final old = preview.value;
    if (old != null) unawaited(MemoryImage(old).evict());
    preview.value = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    if (_process != null) {
      send('shutdown');
    } else {
      send('stop');
    }
    unawaited(_subscription?.cancel());
    unawaited(_socket?.close());
    _clearPreview();
    preview.dispose();
    // On OS window close the socket disappears; Python also exits after its idle timeout.
    super.dispose();
  }
}

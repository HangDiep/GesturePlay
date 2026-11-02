import 'dart:async';
import 'dart:io';
import 'project_paths_io.dart';

class HandSocket {
  HandSocket._(this._socket);
  final WebSocket _socket;
  static Future<HandSocket> connect(Uri uri) async =>
      HandSocket._(await WebSocket.connect(uri.toString()));
  Stream<dynamic> get stream => _socket;
  bool get isOpen => _socket.readyState == WebSocket.open;
  void add(String data) => _socket.add(data);
  Future<void> close() async => _socket.close();
}

class HandHost {
  Process? _process;
  bool get canLaunch => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  bool get ownsProcess => _process != null;

  Future<void> launch(int port) async {
    if (!File(ProjectPaths.python).existsSync() ||
        !File(ProjectPaths.service).existsSync()) {
      throw StateError('Chưa tìm thấy phần nhận diện trong thư mục dự án.');
    }
    final process = await Process.start(
      ProjectPaths.python,
      ['-u', ProjectPaths.service, '--port', '$port', '--idle-timeout', '5'],
      workingDirectory: ProjectPaths.locateRoot(),
      environment: {'PYTHONIOENCODING': 'utf-8'},
    );
    _process = process;
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    unawaited(
      process.exitCode.then((_) {
        if (identical(_process, process)) _process = null;
      }),
    );
  }
}

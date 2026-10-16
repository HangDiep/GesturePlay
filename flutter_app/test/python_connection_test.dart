import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/services/project_paths.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Flutter connects to real Python service without opening the camera',
    () async {
      // This test intentionally uses loopback networking instead of Flutter's
      // default HTTP stub, which returns 400 for every request in widget tests.
      final previousHttpOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      final reservation = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = reservation.port;
      await reservation.close();
      final process = await Process.start(
        ProjectPaths.python,
        ['-u', ProjectPaths.service, '--port', '$port', '--idle-timeout', '5'],
        workingDirectory: ProjectPaths.locateRoot(),
        environment: {'PYTHONIOENCODING': 'utf-8'},
      );
      final serviceLog = StringBuffer();
      process.stdout.transform(utf8.decoder).listen(serviceLog.write);
      process.stderr.transform(utf8.decoder).listen(serviceLog.write);
      final hand = HandBridge(
        autoLaunch: false,
        uri: Uri.parse('ws://127.0.0.1:$port'),
      );
      try {
        for (var i = 0; i < 100 && hand.latest == null; i++) {
          if (!hand.connected) await hand.connect();
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(hand.connected, true, reason: serviceLog.toString());
        expect(hand.latest, isNotNull);
        expect(hand.latest!.data['protocol'], 1);
        expect(hand.latest!.flag('active'), false);
        expect(hand.valid, false);
        expect(hand.latest!.text('camera_phase'), 'starting');
        hand.send('shutdown');
        expect(await process.exitCode.timeout(const Duration(seconds: 15)), 0);
      } finally {
        hand.dispose();
        process.kill();
      }
    },
    skip: !File(ProjectPaths.python).existsSync()
        ? 'Python .venv is required for cross-language test'
        : false,
  );

  test('a late handshake is closed instead of occupying the service', () async {
    final previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = previousHttpOverrides);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final disconnected = Completer<void>();
    final listener = server.listen((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 2300));
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {}, onDone: disconnected.complete);
    });
    final hand = HandBridge(
      autoLaunch: false,
      uri: Uri.parse('ws://127.0.0.1:${server.port}'),
    );
    try {
      await hand.connect();
      expect(hand.connected, false);
      expect(hand.error, isNotNull);
      await disconnected.future.timeout(const Duration(seconds: 5));
    } finally {
      hand.dispose();
      await listener.cancel();
      await server.close(force: true);
    }
  });
}

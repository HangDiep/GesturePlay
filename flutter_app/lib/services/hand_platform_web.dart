import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

class HandSocket {
  HandSocket._(this._socket);
  final web.WebSocket _socket;
  final _messages = StreamController<dynamic>();

  static Future<HandSocket> connect(Uri uri) {
    final socket = web.WebSocket(uri.toString())..binaryType = 'arraybuffer';
    final connection = HandSocket._(socket);
    final ready = Completer<HandSocket>();
    socket.addEventListener(
      'open',
      ((web.Event _) {
        if (!ready.isCompleted) ready.complete(connection);
      }).toJS,
    );
    socket.addEventListener(
      'message',
      ((web.MessageEvent event) {
        final data = event.data;
        if (data.isA<JSString>()) {
          connection._messages.add((data as JSString).toDart);
        } else if (data.isA<JSArrayBuffer>()) {
          connection._messages.add(
            (data as JSArrayBuffer).toDart.asUint8List(),
          );
        }
      }).toJS,
    );
    socket.addEventListener(
      'error',
      ((web.Event _) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('Không kết nối được nhận diện tay.'));
        }
      }).toJS,
    );
    socket.addEventListener(
      'close',
      ((web.Event _) {
        if (!ready.isCompleted) {
          ready.completeError(StateError('Kết nối nhận diện tay đã đóng.'));
        }
        unawaited(connection._messages.close());
      }).toJS,
    );
    return ready.future;
  }

  Stream<dynamic> get stream => _messages.stream;
  bool get isOpen => _socket.readyState == web.WebSocket.OPEN;
  void add(String data) => _socket.send(data.toJS);
  Future<void> close() async => _socket.close();
}

// The npm launcher owns Python on web; browsers cannot start local processes.
class HandHost {
  bool get canLaunch => false;
  bool get ownsProcess => false;
  Future<void> launch(int port) async =>
      throw UnsupportedError('Mở ứng dụng bằng npm run web.');
}

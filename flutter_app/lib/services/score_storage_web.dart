import 'package:web/web.dart' as web;
import 'score_storage.dart';

class BrowserScoreStorage implements ScoreStorage {
  BrowserScoreStorage(this.key);
  final String key;

  @override
  Future<String?> read() async => web.window.localStorage.getItem(key);

  @override
  Future<void> write(String contents) async =>
      web.window.localStorage.setItem(key, contents);
}

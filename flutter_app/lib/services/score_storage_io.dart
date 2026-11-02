import 'dart:io';
import 'score_storage.dart';

class FileScoreStorage implements ScoreStorage {
  FileScoreStorage(this.file);
  final File file;

  @override
  Future<String?> read() async =>
      await file.exists() ? await file.readAsString() : null;

  @override
  Future<void> write(String contents) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}

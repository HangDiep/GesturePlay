import 'dart:convert';
import 'dart:io';
import '../game/runner_model.dart';

class LocalScores {
  LocalScores(this.file);
  final File file;
  List<Map<String, dynamic>> records = [];
  String? error;
  Future<void> _pending = Future<void>.value();
  static bool valid(Map<String, dynamic> row) =>
      row['game_code'] == 'runner' &&
      row['rules_version'] == 1 &&
      row['session_id'] is String &&
      row['score'] is int &&
      (row['score'] as int) >= 0 &&
      Difficulty.values.any((v) => v.name == row['difficulty']) &&
      ControlMode.values.any((v) => v.name == row['control_mode']);

  Future<void> load() async {
    try {
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map || json['version'] != 1 || json['rounds'] is! List) {
        throw const FormatException();
      }
      records = (json['rounds'] as List)
          .whereType<Map<String, dynamic>>()
          .where(valid)
          .toList();
      if (records.length > 100) records = records.sublist(records.length - 100);
    } on Object {
      error = 'Không đọc được thành tích cũ trên máy.';
    }
  }

  int best(Difficulty difficulty, ControlMode control) => records
      .where(
        (r) =>
            r['difficulty'] == difficulty.name &&
            r['control_mode'] == control.name,
      )
      .fold(
        0,
        (best, row) =>
            (row['score'] as int) > best ? row['score'] as int : best,
      );

  Future<bool> save(RunnerResult result) {
    var success = false;
    final operation = _pending.then((_) async {
      if (records.any((r) => r['session_id'] == result.id)) {
        success = true;
        return;
      }
      var updated = [...records, result.toJson()];
      if (updated.length > 100) {
        final keep = updated
            .skip(updated.length - 94)
            .map((r) => r['session_id'])
            .toSet();
        for (final difficulty in Difficulty.values) {
          for (final control in ControlMode.values) {
            final group = updated
                .where(
                  (r) =>
                      r['difficulty'] == difficulty.name &&
                      r['control_mode'] == control.name,
                )
                .toList();
            if (group.isNotEmpty) {
              group.sort(
                (a, b) => (b['score'] as int).compareTo(a['score'] as int),
              );
              keep.add(group.first['session_id']);
            }
          }
        }
        updated = updated.where((r) => keep.contains(r['session_id'])).toList();
      }
      try {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({'version': 1, 'rounds': updated}),
          flush: true,
        );
        await temporary.rename(file.path);
        records = updated;
        error = null;
        success = true;
      } on Object {
        error = 'Chưa lưu được kết quả trên máy. Bạn có thể thử lại.';
      }
    });
    _pending = operation;
    return operation.then((_) => success);
  }
}

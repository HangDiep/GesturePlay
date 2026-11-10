import 'dart:math';

class RoundResult {
  const RoundResult({
    required this.id,
    required this.playedAt,
    required this.won,
    required this.seconds,
    required this.score,
    required this.kills,
    required this.cores,
    required this.shots,
    required this.hits,
    required this.health,
    required this.difficulty,
    required this.controls,
    required this.reason,
    this.endedAt,
    this.weapon = '',
    this.ammo,
    this.reserve,
    this.medkits,
  });
  final String id, difficulty, controls, reason, weapon;
  final DateTime playedAt;
  final DateTime? endedAt;
  final bool won;
  final double seconds, health;
  final int score, kills, cores, shots, hits;
  final int? ammo, reserve, medkits;
  int get accuracy =>
      shots == 0 ? 0 : (hits / shots * 100).round().clamp(0, 100);
  String get difficultyKey =>
      difficulty == 'Dễ' || difficulty == 'easy' ? 'easy' : 'normal';
  String get difficultyLabel => difficultyKey == 'easy' ? 'Dễ' : 'Thường';

  /// Allocate once when a round starts. Retransmissions keep this same UUID.
  static String newId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'played_at': playedAt.toUtc().toIso8601String(),
    'ended_at': endedAt?.toUtc().toIso8601String(),
    'won': won,
    'seconds': seconds,
    'score': score,
    'kills': kills,
    'cores': cores,
    'shots': shots,
    'hits': hits,
    'health': health,
    'difficulty': difficultyKey,
    'controls': controls,
    'reason': reason,
    'weapon': weapon,
    'ammo': ammo,
    'reserve': reserve,
    'medkits': medkits,
  };

  factory RoundResult.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String) throw FormatException('Invalid result $key');
      return value;
    }

    num number(String key) {
      final value = json[key];
      if (value is! num || !value.isFinite || value < 0) {
        throw FormatException('Invalid result $key');
      }
      return value;
    }

    int integer(String key) {
      final value = number(key);
      if (value != value.roundToDouble()) {
        throw FormatException('Invalid result $key');
      }
      return value.toInt();
    }

    final id = text('id'), difficulty = text('difficulty');
    if (id.isEmpty ||
        json['won'] is! bool ||
        !['easy', 'normal', 'Dễ', 'Thường'].contains(difficulty)) {
      throw const FormatException('Invalid round identity');
    }
    return RoundResult(
      id: id,
      playedAt: DateTime.parse(text('played_at')),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(text('ended_at')),
      won: json['won'] as bool,
      seconds: number('seconds').toDouble(),
      score: integer('score'),
      kills: integer('kills'),
      cores: integer('cores'),
      shots: integer('shots'),
      hits: integer('hits'),
      health: number('health').toDouble(),
      difficulty: difficulty == 'easy'
          ? 'Dễ'
          : difficulty == 'normal'
          ? 'Thường'
          : difficulty,
      controls: text('controls'),
      reason: text('reason'),
      weapon: json['weapon'] == null ? '' : text('weapon'),
      ammo: json['ammo'] == null ? null : integer('ammo'),
      reserve: json['reserve'] == null ? null : integer('reserve'),
      medkits: json['medkits'] == null ? null : integer('medkits'),
    );
  }
}

class PersonalStats {
  PersonalStats(Iterable<RoundResult> records, {String? difficulty}) {
    final ids = <String>{};
    for (final result in records) {
      if (!ids.add(result.id) ||
          difficulty != null && result.difficultyKey != difficulty) {
        continue;
      }
      completed++;
      if (result.won) wins++;
      best = max(best, result.score);
    }
  }
  int completed = 0, wins = 0, best = 0;
}

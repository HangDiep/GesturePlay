import 'dart:math' as math;
import 'dart:ui';

part 'waves.dart';

enum SignalDifficulty { easy, normal }

enum RoundPhase { ready, playing, paused, won, lost, abandoned }

enum EnemyKind { runner, breaker, jammer, boss }

enum EnemyState {
  patrol,
  investigating,
  approaching,
  attacking,
  windingUp,
  recovering,
  repelled,
  stunned,
  dead,
}

enum Defense { decoy, flash, trap, barrier, silence, reinforce }

extension EnemyName on EnemyKind {
  String get label => switch (this) {
    EnemyKind.runner => 'Kẻ săn đuổi',
    EnemyKind.breaker => 'Kẻ phá cửa',
    EnemyKind.jammer => 'Kẻ gây nhiễu',
    EnemyKind.boss => 'Vật chủ',
  };
}

class SignalRules {
  const SignalRules(this.capacity, this.speedMultiplier, this.maxActive);
  final double capacity, speedMultiplier;
  final int maxActive;
  static const duration = 180.0;
  static const shotCost = 2.0, shotDamage = 45.0, shotCooldown = .75;
  static const bossWindup = 1.4, bossExposure = 3.2, deathDuration = .85;
  static const easy = SignalRules(130, .78, 6);
  static const normal = SignalRules(100, 1, 8);
}

class SecurityDoor {
  bool powered = true, locked = false;
  double health = 120, maxHealth = 120;
  bool get broken => health <= 0;
}

class Intruder {
  Intruder(this.id, this.kind, {this.zone = 0, this.progress = 0}) {
    health = maxHealth;
  }
  final int id;
  final EnemyKind kind;
  int zone;
  double progress, health = 0, stunnedFor = 0, attackTimer = 0;
  double weakFor = 0, repelledFor = 0;
  double windupFor = 0, breachFor = 0, hitFor = 0, deathFor = 0;
  double animationTime = 0, lastDamage = 0;
  bool lastHitArmored = false, lastHitWeak = false;
  int strongAttacks = 0;
  int? preferredRoute, rerouteTo;
  EnemyState state = EnemyState.patrol;
  bool get alive => health > 0;
  bool get charging => alive && kind == EnemyKind.boss && windupFor > 0;
  bool get exposed => alive && kind == EnemyKind.boss && weakFor > 0;
  bool get committedToDoor =>
      state == EnemyState.attacking || charging || exposed;
  String get status => !alive
      ? 'ĐÃ TIÊU DIỆT'
      : stunnedFor > 0
      ? 'CHOÁNG ${stunnedFor.toStringAsFixed(1)}s'
      : charging
      ? 'NẠP ĐÒN ${windupFor.toStringAsFixed(1)}s'
      : exposed
      ? 'ĐIỂM YẾU ${weakFor.toStringAsFixed(1)}s'
      : kind == EnemyKind.boss
      ? 'GIÁP ĐANG BẬT'
      : state == EnemyState.attacking
      ? 'ĐANG PHÁ CỬA'
      : repelledFor > 0
      ? 'BỊ ĐẨY LÙI'
      : state == EnemyState.investigating
      ? 'ĐIỀU TRA TIẾNG ĐỘNG'
      : 'ĐANG TIẾP CẬN';
  double get maxHealth => switch (kind) {
    EnemyKind.runner => 45,
    EnemyKind.breaker => 135,
    EnemyKind.jammer => 70,
    EnemyKind.boss => 300,
  };
  double get speed => switch (kind) {
    EnemyKind.runner => .085,
    EnemyKind.breaker => .047,
    EnemyKind.jammer => .062,
    EnemyKind.boss => .060,
  };
  double get damage => switch (kind) {
    EnemyKind.runner => 12,
    EnemyKind.breaker => 27,
    EnemyKind.jammer => 16,
    EnemyKind.boss => 38,
  };
  // Same normalized projection is used for painting and hit testing.
  Offset get aimPoint => Offset(
    .5 + math.sin(id * 2.4) * .22 * (.4 + progress * .6),
    .35 + progress * .43,
  );
  Offset get weakPoint => aimPoint - const Offset(0, .02);
}

class SignalResult {
  SignalResult(
    this.id,
    this.outcome,
    this.difficulty,
    this.elapsed,
    this.energy,
    this.score,
    this.kills,
    this.shots,
    this.hits,
    this.createdAt,
  );
  final String id;
  final RoundPhase outcome;
  final SignalDifficulty difficulty;
  final double elapsed, energy;
  final int score, kills, shots, hits;
  final DateTime createdAt;
}

/// Simulation owns all rules. UI and hand recognition only issue actions.
class SignalModel {
  SignalModel({
    this.difficulty = SignalDifficulty.easy,
    this.advanced = true,
    int seed = 42,
  }) : random = math.Random(seed),
       rules = difficulty == SignalDifficulty.easy
           ? SignalRules.easy
           : SignalRules.normal {
    energy = rules.capacity;
    waves = SignalWaves.plan(difficulty, advanced: advanced);
  }
  final SignalDifficulty difficulty;
  final bool advanced;
  final math.Random random;
  final SignalRules rules;
  late final List<SignalWave> waves;
  final _pending = <_PendingSpawn>[];
  int _nextWave = 0;
  final String id =
      '${DateTime.now().microsecondsSinceEpoch}-${math.Random.secure().nextInt(1 << 30)}';
  final DateTime createdAt = DateTime.now();
  RoundPhase phase = RoundPhase.ready;
  final doors = [SecurityDoor(), SecurityDoor()];
  final enemies = <Intruder>[];
  final cameraPower = [true, true, true];
  final cooldowns = {for (final d in Defense.values) d: 0.0};
  final List<String> events = [];
  double energy = 0, elapsed = 0, gunCooldown = 0, flashFor = 0;
  double barrierFor = 0, decoyFor = 0, shotFor = 0;
  double noiseFor = 0;
  double impactFor = 0;
  int impactZone = 0;
  int noiseZone = 0;
  int camera = 0, selectedDoor = 0, selectedZone = 1, barrierZone = 1;
  int decoyZone = 0, kills = 0, shots = 0, hits = 0, reinforcements = 2;
  int wave = 0, soundSerial = 0;
  String sound = '',
      message = 'Quan sát hành lang. Giữ phòng điều khiển an toàn.';
  bool gunMode = false, gunPowered = true, silent = false;
  bool lastShotHit = false, lastShotArmored = false;
  bool hasSelectedDoor = false;
  Offset lastShot = const Offset(.5, .5);
  bool get active => phase == RoundPhase.playing;
  bool get finished =>
      [RoundPhase.won, RoundPhase.lost, RoundPhase.abandoned].contains(phase);
  double get remaining => math.max(0, SignalRules.duration - elapsed);
  double get battery => (energy / rules.capacity).clamp(0, 1);
  int get score =>
      (elapsed * 5).floor() +
      kills * 100 +
      (phase == RoundPhase.won ? 1000 + energy.floor() * 5 : 0);
  int get aliveCount => enemies.where((e) => e.alive).length;
  int get totalWaves => waves.length;
  int get totalEnemies =>
      waves.fold(0, (sum, wave) => sum + wave.spawns.length);
  int get pendingSpawns => _pending.length;
  double? get nextWaveIn => _nextWave < waves.length
      ? math.max(0, waves[_nextWave].at - elapsed)
      : null;
  String get waveTitle => wave > 0 ? waves[wave - 1].title : 'Chuẩn bị đợt đầu';
  String get waveStatus =>
      'ĐỢT $wave/$totalWaves${nextWaveIn != null ? ' · ĐỢT SAU ${nextWaveIn!.ceil()}s' : ' · ĐỢT CUỐI'}';
  bool get cameraOnline => energy > 0 && cameraPower[camera] && !silent;
  bool get jammed =>
      cameraOnline &&
      enemies.any(
        (e) =>
            e.alive &&
            e.zone == camera &&
            e.kind == EnemyKind.jammer &&
            e.stunnedFor <= 0,
      );
  Iterable<Intruder> get visibleEnemies => cameraOnline && !jammed
      ? enemies.where((e) => e.alive && e.zone == camera)
      : const <Intruder>[];
  Iterable<Intruder> get renderedEnemies => cameraOnline && !jammed
      ? enemies.where((e) => e.zone == camera && (e.alive || e.deathFor > 0))
      : const <Intruder>[];
  double get drain => energy <= 0
      ? 0
      : .025 +
            (!silent && cameraPower[camera] ? .075 : 0) +
            doors.where((d) => d.powered && d.locked && !d.broken).length * .19;
  Intruder? get observedBoss {
    for (final e in visibleEnemies) {
      if (e.kind == EnemyKind.boss) return e;
    }
    return null;
  }

  bool sensor(int zone) => enemies.any((e) => e.alive && e.zone == zone);

  void notify(String text, [String effect = 'click']) {
    message = text;
    events.insert(0, '${elapsed.floor()}s · $text');
    if (events.length > 6) events.removeLast();
    sound = effect;
    soundSerial++;
  }

  void start() {
    if (phase == RoundPhase.ready) {
      phase = RoundPhase.playing;
      notify('Ca trực bắt đầu. Cứu hộ đến sau 03:00.');
    }
  }

  void pause() {
    if (active) phase = RoundPhase.paused;
  }

  void resume() {
    if (phase == RoundPhase.paused) phase = RoundPhase.playing;
  }

  void abandon() {
    if (!finished) phase = RoundPhase.abandoned;
  }

  bool _spend(double cost) {
    if (energy + 1e-8 < cost) {
      notify('Không đủ điện để thực hiện.', 'denied');
      return false;
    }
    energy = math.max(0, energy - cost);
    if (energy == 0) _blackout();
    return true;
  }

  void _blackout() {
    for (final d in doors) {
      d.locked = false;
    }
    gunMode = false;
  }

  void selectCamera(int index) {
    if (!active || index < 0 || index > 2) return;
    camera = index;
    selectedZone = index;
    gunMode = false;
    notify('Đang xem CAM 0${index + 1}.');
  }

  void selectDoor(int index) {
    if (!active || index < 0 || index > 1) return;
    selectedDoor = index;
    hasSelectedDoor = true;
    selectedZone = index + 1;
    gunMode = false;
  }

  void toggleDoor(int index, {bool emergency = false}) {
    if (!active || index < 0 || index > 1) return;
    selectDoor(index);
    final d = doors[index];
    if (d.broken) {
      notify('Cửa đã bị phá. Hãy đẩy lùi hoặc tiêu diệt mục tiêu.', 'denied');
      return;
    }
    if ((!d.powered || energy <= 0) && (!d.locked || emergency)) {
      notify('Cửa chưa được cấp điện.', 'denied');
      return;
    }
    d.locked = emergency || !d.locked;
    notify(
      '${index == 0 ? 'Cửa trái' : 'Cửa phải'} ${d.locked ? 'đã khóa' : 'đã mở'}.',
      'door',
    );
  }

  void power(String device, bool value) {
    if (!active) return;
    if (device.startsWith('camera')) {
      final i = int.tryParse(device.substring(6));
      if (i == null || i < 0 || i > 2) return;
      cameraPower[i] = value;
    } else if (device.startsWith('door')) {
      final i = int.tryParse(device.substring(4));
      if (i == null || i < 0 || i > 1) return;
      doors[i].powered = value;
      if (!value) doors[i].locked = false;
    } else if (device == 'gun') {
      gunPowered = value;
      if (!value) gunMode = false;
    } else {
      return;
    }
    notify(value ? 'Đã cấp điện cho thiết bị.' : 'Đã ngắt điện thiết bị.');
  }

  void toggleGun() {
    if (!active) return;
    if (!gunPowered ||
        energy < SignalRules.shotCost ||
        silent ||
        !cameraOnline ||
        jammed) {
      notify('Súng cần điện, hình ảnh camera và chế độ thường.', 'denied');
      return;
    }
    gunMode = !gunMode;
    notify(
      gunMode
          ? 'Chế độ súng: ngắm mục tiêu rồi chọn để bắn.'
          : 'Đã trở lại điều khiển thiết bị.',
    );
  }

  bool shoot(Offset aim) {
    if (!active ||
        !gunMode ||
        !gunPowered ||
        silent ||
        !cameraOnline ||
        jammed ||
        gunCooldown > 0) {
      return false;
    }
    final candidates = visibleEnemies.toList();
    if (!aim.dx.isFinite || !aim.dy.isFinite || !_spend(SignalRules.shotCost)) {
      return false;
    }
    shots++;
    gunCooldown = SignalRules.shotCooldown;
    shotFor = .18;
    lastShot = aim;
    lastShotHit = lastShotArmored = false;
    final targets =
        candidates.where((e) => (e.aimPoint - aim).distance <= .105).toList()
          ..sort(
            (a, b) => (a.aimPoint - aim).distance.compareTo(
              (b.aimPoint - aim).distance,
            ),
          );
    if (targets.isNotEmpty) {
      final e = targets.first;
      hits++;
      lastShotHit = true;
      e.lastHitWeak = e.exposed && (aim - e.weakPoint).distance <= .045;
      e.lastHitArmored = e.kind == EnemyKind.boss && !e.lastHitWeak;
      lastShotArmored = e.lastHitArmored;
      e.lastDamage = e.lastHitArmored
          ? SignalRules.shotDamage / 3
          : SignalRules.shotDamage;
      e.hitFor = .4;
      e.health = math.max(0, e.health - e.lastDamage);
      if (e.alive) {
        if (e.kind != EnemyKind.boss) {
          e.progress = math.max(0, e.progress - .11);
          e.repelledFor = .8;
          e.state = EnemyState.repelled;
          e.attackTimer = e.breachFor = 0;
        }
        notify(
          e.lastHitArmored
              ? e.exposed
                    ? 'Bắn trúng giáp. Ngắm vào lõi sáng để gây đủ sát thương!'
                    : 'Giáp boss chặn phần lớn sát thương. Chờ điểm yếu lộ ra!'
              : e.lastHitWeak
              ? 'Bắn trúng điểm yếu của Vật chủ!'
              : '${e.kind.label} trúng đạn và bị đẩy lùi.',
          e.lastHitArmored ? 'armor' : 'shot',
        );
      } else {
        e.state = EnemyState.dead;
        e.deathFor = SignalRules.deathDuration;
        e.windupFor = e.weakFor = e.stunnedFor = e.attackTimer = e.breachFor =
            0;
        kills++;
        notify('Đã tiêu diệt ${e.kind.label.toLowerCase()}.', 'kill');
      }
    } else {
      notify('Bắn trượt. Tiếng súng gây chú ý trong khu vực.', 'shot');
    }
    _noise(camera);
    return true;
  }

  void _noise(int zone) {
    noiseZone = zone;
    noiseFor = 4;
    for (final e in enemies.where(
      (e) => e.alive && !e.committedToDoor && e.state != EnemyState.stunned,
    )) {
      if (e.zone != zone && e.repelledFor <= 0) {
        e.state = EnemyState.investigating;
      }
    }
  }

  double cost(Defense d) => switch (d) {
    Defense.decoy => 4,
    Defense.flash => 5,
    Defense.trap => 9,
    Defense.barrier => 5,
    Defense.silence => 0,
    Defense.reinforce => 0,
  };
  bool activate(Defense d) {
    if (!active) return false;
    if (cooldowns[d]! > 0) {
      notify('Thiết bị đang hồi. Hãy chờ.', 'denied');
      return false;
    }
    if (d == Defense.reinforce &&
        (reinforcements <= 0 || doors[selectedDoor].broken)) {
      notify(
        reinforcements <= 0
            ? 'Đã hết vật phẩm gia cố.'
            : 'Không thể gia cố cửa đã vỡ.',
        'denied',
      );
      return false;
    }
    if (d == Defense.decoy && silent) {
      notify('Tắt chế độ im lặng trước khi bật loa.', 'denied');
      return false;
    }
    if (d == Defense.barrier && selectedZone == 0) {
      notify('Chọn hành lang trái hoặc phải trên sơ đồ.', 'denied');
      return false;
    }
    if (energy <= 0 && d != Defense.silence && d != Defense.reinforce) {
      notify('Thiết bị đã hết điện.', 'denied');
      return false;
    }
    if (!_spend(cost(d))) return false;
    switch (d) {
      case Defense.decoy:
        decoyZone = selectedZone;
        decoyFor = 8;
        cooldowns[d] = 24;
        _noise(decoyZone);
        notify('Loa đang phát ở khu vực ${selectedZone + 1}.', 'decoy');
      case Defense.flash:
        flashFor = .3;
        cooldowns[d] = 14;
        for (final e in enemies.where(
          (e) => e.alive && e.zone == selectedZone,
        )) {
          _stun(e, e.kind == EnemyKind.boss ? 1.5 : 3.5);
        }
        notify(
          'Đèn chớp đã kích hoạt tại khu vực ${selectedZone + 1}.',
          'flash',
        );
      case Defense.trap:
        cooldowns[d] = 20;
        var count = 0;
        for (final e in enemies.where(
          (e) =>
              e.alive &&
              e.zone == selectedZone &&
              e.progress >= .35 &&
              e.progress <= .9,
        )) {
          _stun(e, e.kind == EnemyKind.boss ? 2.5 : 5);
          count++;
        }
        notify(
          count > 0
              ? 'Bẫy điện làm choáng $count mục tiêu.'
              : 'Bẫy kích hoạt nhưng không có mục tiêu trong vùng.',
          'flash',
        );
      case Defense.barrier:
        barrierZone = selectedZone;
        barrierFor = 7;
        cooldowns[d] = 22;
        notify(
          'Cửa hành lang ${barrierZone == 1 ? 'trái' : 'phải'} chặn trong 7 giây.',
          'door',
        );
      case Defense.silence:
        silent = !silent;
        gunMode = false;
        if (silent) decoyFor = 0;
        notify(
          silent
              ? 'Im lặng: camera, súng và loa tạm ngừng.'
              : 'Đã trở lại chế độ thường.',
        );
      case Defense.reinforce:
        reinforcements--;
        final door = doors[selectedDoor];
        door.maxHealth += 50;
        door.health = math.min(door.maxHealth, door.health + 70);
        notify('Đã gia cố cửa ${selectedDoor == 0 ? 'trái' : 'phải'}.', 'door');
    }
    return true;
  }

  void update(double dt) {
    if (!active) return;
    if (!dt.isFinite || dt < 0) throw ArgumentError('Invalid delta time');
    var rest = math.min(dt, .25);
    while (rest > 1e-8 && active) {
      final step = math.min(rest, math.min(.025, remaining));
      if (step <= 1e-8) {
        _win();
        break;
      }
      _step(step);
      rest -= step;
    }
  }

  void _step(double dt) {
    elapsed += dt;
    gunCooldown = math.max(0, gunCooldown - dt);
    flashFor = math.max(0, flashFor - dt);
    shotFor = math.max(0, shotFor - dt);
    impactFor = math.max(0, impactFor - dt);
    decoyFor = math.max(0, decoyFor - dt);
    noiseFor = math.max(0, noiseFor - dt);
    barrierFor = math.max(0, barrierFor - dt);
    for (final d in Defense.values) {
      cooldowns[d] = math.max(0, cooldowns[d]! - dt);
    }
    final previous = energy;
    energy = math.max(0, energy - drain * dt);
    if (previous > 0 && energy == 0) {
      _blackout();
      notify('Hết điện. Cửa mở, camera và súng ngừng hoạt động.', 'alarm');
    } else if (previous > rules.capacity * .2 &&
        energy <= rules.capacity * .2) {
      notify('Cảnh báo: điện dưới 20%.', 'alarm');
    }
    while (_nextWave < waves.length && elapsed + 1e-8 >= waves[_nextWave].at) {
      final definition = waves[_nextWave++];
      wave = _nextWave;
      for (final entry in definition.spawns) {
        _pending.add(_PendingSpawn(definition.at + entry.delay, entry));
      }
      _pending.sort((a, b) => a.at.compareTo(b.at));
      notify(
        'Đợt $wave/$totalWaves: ${definition.title} · ${definition.spawns.length} sinh vật.',
        'alarm',
      );
    }
    while (_pending.isNotEmpty &&
        _pending.first.at <= elapsed + 1e-8 &&
        aliveCount < rules.maxActive) {
      final entry = _pending.removeAt(0).spawn;
      spawn(entry.kind).preferredRoute = entry.route;
      if (entry.kind == EnemyKind.boss) {
        notify(
          'Vật chủ xuất hiện! Chờ đòn đánh mạnh để bắn điểm yếu.',
          'alarm',
        );
      }
    }
    for (final e in enemies) {
      e.animationTime += dt;
      e.hitFor = math.max(0, e.hitFor - dt);
      e.deathFor = math.max(0, e.deathFor - dt);
    }
    for (final e in enemies.where((e) => e.alive)) {
      _move(e, dt);
      if (!active) break;
    }
    enemies.removeWhere((e) => !e.alive && e.deathFor <= 0);
    if (active && remaining <= 1e-8) _win();
  }

  Intruder spawn(EnemyKind kind, {int zone = 0, double progress = 0}) {
    if (zone < 0 ||
        zone > 2 ||
        !progress.isFinite ||
        progress < 0 ||
        progress > 1) {
      throw ArgumentError('Invalid enemy route or progress');
    }
    final e = Intruder(++_enemyId, kind, zone: zone, progress: progress);
    enemies.add(e);
    return e;
  }

  int _enemyId = 0;
  void _stun(Intruder e, double duration) {
    if (!e.alive) return;
    e.stunnedFor = math.max(e.stunnedFor, duration);
    e.windupFor = e.attackTimer = e.breachFor = 0;
    e.state = EnemyState.stunned;
  }

  double _towards(double value, double target, double distance) =>
      value < target
      ? math.min(target, value + distance)
      : math.max(target, value - distance);

  void _move(Intruder e, double dt) {
    e.weakFor = math.max(0, e.weakFor - dt);
    if (e.stunnedFor > 0) {
      e.stunnedFor = math.max(0, e.stunnedFor - dt);
      e.state = EnemyState.stunned;
      return;
    }
    if (e.repelledFor > 0) {
      e.repelledFor = math.max(0, e.repelledFor - dt);
      e.state = EnemyState.repelled;
      return;
    }
    if (e.exposed) {
      e.state = EnemyState.recovering;
      return;
    }
    final speed = e.speed * rules.speedMultiplier * (silent ? .68 : 1);
    final attracting = decoyFor > 0 || (!silent && noiseFor > 0);
    final targetZone = decoyFor > 0 ? decoyZone : noiseZone;
    // A decoy cannot interrupt a creature already attacking a door.
    if (e.rerouteTo != null && e.zone != 0) {
      e.state = EnemyState.investigating;
      e.progress = math.max(0, e.progress - speed * dt * 1.5);
      if (e.progress <= 0) {
        e.zone = 0;
        e.progress = .65;
      }
      return;
    }
    if (attracting &&
        e.zone != targetZone &&
        !e.committedToDoor &&
        e.rerouteTo == null) {
      e.state = EnemyState.investigating;
      if (e.zone != 0) {
        e.progress -= speed * dt * 1.5;
        if (e.progress <= 0) {
          e.zone = 0;
          e.progress = .6;
        }
        return;
      }
    }
    if (e.zone == 0) {
      e.state = attracting ? EnemyState.investigating : EnemyState.patrol;
      if (attracting && targetZone == 0) {
        e.progress = _towards(e.progress, .7, speed * dt);
        return;
      }
      e.progress += speed * dt * 2;
      if (e.progress >= 1) {
        var route =
            e.rerouteTo ??
            (attracting && targetZone != 0
                ? targetZone
                : e.preferredRoute ?? (random.nextBool() ? 1 : 2));
        if (barrierFor > 0 && route == barrierZone) route = route == 1 ? 2 : 1;
        e.zone = route;
        e.preferredRoute = e.rerouteTo = null;
        e.progress = 0;
      }
      return;
    }
    if (decoyFor > 0 && e.zone == decoyZone && !e.committedToDoor) {
      e.state = EnemyState.investigating;
      e.progress = _towards(e.progress, .55, speed * dt);
      return;
    }
    if (barrierFor > 0 &&
        e.zone == barrierZone &&
        e.progress >= .62 &&
        e.progress < .85) {
      e.rerouteTo = barrierZone == 1 ? 2 : 1;
      e.progress = math.max(0, e.progress - speed * dt * 1.5);
      e.state = EnemyState.investigating;
      return;
    }
    if (e.progress < 1) {
      e.breachFor = 0;
      e.state = EnemyState.approaching;
      e.progress = math.min(1, e.progress + speed * dt);
      return;
    }
    final door = doors[e.zone - 1];
    if (!door.locked || !door.powered || door.broken || energy <= 0) {
      e.state = EnemyState.attacking;
      e.windupFor = 0;
      e.breachFor += dt;
      if (e.breachFor >= 1.35) {
        phase = RoundPhase.lost;
        notify('Sinh vật đã xâm nhập phòng điều khiển.', 'alarm');
      }
      return;
    }
    e.breachFor = 0;
    if (e.kind == EnemyKind.boss) {
      if (e.windupFor > 0) {
        e.state = EnemyState.windingUp;
        e.windupFor = math.max(0, e.windupFor - dt);
        if (e.windupFor <= 1e-8) {
          e.windupFor = 0;
          e.strongAttacks++;
          _damageDoor(e, door, e.damage * 1.5);
          e.weakFor = SignalRules.bossExposure;
          e.state = EnemyState.recovering;
          e.attackTimer = 0;
          notify(
            'Vật chủ vừa đánh mạnh! Điểm yếu lộ trong ${SignalRules.bossExposure}s.',
            'boss_slam',
          );
        }
      } else {
        e.state = EnemyState.attacking;
        e.attackTimer += dt;
        if (e.attackTimer >= 1) {
          e.attackTimer = 0;
          e.windupFor = SignalRules.bossWindup;
          e.state = EnemyState.windingUp;
          notify(
            'Cảnh báo: Vật chủ đang nạp đòn ở cửa ${e.zone == 1 ? 'trái' : 'phải'}!',
            'boss_charge',
          );
        }
      }
      return;
    }
    e.state = EnemyState.attacking;
    e.attackTimer += dt;
    if (e.attackTimer >= 1.6) {
      e.attackTimer = 0;
      _damageDoor(e, door, e.damage);
    }
  }

  void _damageDoor(Intruder e, SecurityDoor door, double damage) {
    door.health = math.max(0, door.health - damage);
    impactZone = e.zone;
    impactFor = e.kind == EnemyKind.boss ? .55 : .25;
    if (door.broken) {
      door.locked = false;
      notify('Cửa ${e.zone == 1 ? 'trái' : 'phải'} đã bị phá!', 'alarm');
    } else {
      notify('Cửa ${e.zone == 1 ? 'trái' : 'phải'} đang bị tấn công!', 'alarm');
    }
  }

  void _win() {
    elapsed = SignalRules.duration;
    phase = RoundPhase.won;
    notify('Tín hiệu cứu hộ đã đến. Bạn sống sót!', 'win');
  }

  SignalResult result() {
    if (!finished) throw StateError('Round is not finished');
    return SignalResult(
      id,
      phase,
      difficulty,
      elapsed,
      energy,
      score,
      kills,
      shots,
      hits,
      createdAt,
    );
  }
}

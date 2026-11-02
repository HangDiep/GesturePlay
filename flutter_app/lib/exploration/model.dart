import 'dart:math' as math;
import 'dart:ui';
import 'world.dart';
import '../survival/rules.dart';

enum FieldPhase { ready, playing, paused, won, lost }

enum CreatureKind { runner, heavy, jammer, boss }

enum HuntState { patrol, investigate, chase, search }

enum PlayerStance { standing, crouching, prone }

class Creature {
  Creature(this.id, this.kind, this.position)
    : home = position,
      health = [45, 135, 70, 300][kind.index].toDouble();
  final int id;
  final CreatureKind kind;
  Offset position;
  final Offset home;
  Offset? lastKnown, patrolTarget;
  HuntState huntState = HuntState.patrol;
  double memoryFor = 0, spawnFor = 0;
  double health,
      stun = 0,
      weak = 0,
      charge = 0,
      attack = 0,
      hit = 0,
      death = 0,
      pathTimer = 0;
  double animation = 0, facing = 0;
  double windup = 0, strikeFor = 0;
  int attackId = 0;
  int pathStep = 0;
  List<Offset> path = [];
  Offset? investigate;
  double noiseFor = 0;
  bool get alive => health > 0;
  double get maxHealth => [45, 135, 70, 300][kind.index].toDouble();
  double get speed => [125, 69, 96, 78][kind.index].toDouble();
  double get damage => [8, 17, 10, 32][kind.index].toDouble();
  double get radius => kind == CreatureKind.boss
      ? 23
      : kind == CreatureKind.heavy
      ? 19
      : 15;
  String get name =>
      ['Kẻ săn đuổi', 'Kẻ bọc giáp', 'Kẻ gây nhiễu', 'Vật chủ'][kind.index];
}

class FieldBullet {
  FieldBullet(this.position, this.direction, {this.lowShot = true});
  Offset position, direction;
  final bool lowShot;
  double life = .85;
}

class FieldEffect {
  FieldEffect(
    this.position,
    this.kind,
    this.life, {
    this.text = '',
    this.direction = Offset.zero,
  }) : maxLife = life;
  Offset position, direction;
  final String kind, text;
  double life;
  final double maxLife;
}

class FieldItem {
  FieldItem(this.position, this.kind, {this.unlockAt = 0});
  final Offset position;
  final String kind;
  final double unlockAt;
  bool taken = false;
}

class ExplorationModel {
  ExplorationModel(FieldMap map, {int seed = 42, this.survival = false})
    : world = FieldWorld(map, quarantine: survival),
      random = math.Random(seed) {
    items.addAll(world.cores.map((p) => FieldItem(p, 'core')));
    for (var i = 0; i < world.supplies.length; i++) {
      items.add(FieldItem(world.supplies[i], i == 0 ? 'health' : 'ammo'));
    }
    if (survival) {
      message = 'Giữ tín hiệu 180 giây. Lõi tín hiệu là mục tiêu phụ.';
      items.addAll([
        FieldItem(const Offset(1250, 1440), 'health', unlockAt: 105),
        FieldItem(const Offset(840, 520), 'ammo', unlockAt: 105),
        FieldItem(const Offset(3110, 910), 'health'),
        FieldItem(const Offset(2850, 2800), 'health'),
        FieldItem(const Offset(1240, 2570), 'ammo'),
        FieldItem(const Offset(3440, 2500), 'ammo'),
      ]);
    }
  }
  final bool survival;
  final FieldWorld world;
  final math.Random random;
  static const waveTimes = [3.0, 27.0, 55.0, 88.0, 120.0];
  static const rescueAt = 180.0;
  static const waveKinds = [
    [0, 0],
    [1, 0],
    [2, 0, 0],
    [3, 0],
    [1, 2, 0],
  ];
  FieldPhase phase = FieldPhase.ready;
  Offset player = FieldWorld.spawn,
      aim = FieldWorld.spawn - const Offset(0, 200),
      movement = Offset.zero;
  Offset lastMove = const Offset(0, -1), rollDirection = Offset.zero;
  double health = 100,
      stamina = 100,
      elapsed = 0,
      facing = -math.pi / 2,
      walkTime = 0;
  double shotCooldown = 0,
      reloadFor = 0,
      flashCooldown = 0,
      trapCooldown = 0,
      flashFor = 0;
  double rollFor = 0,
      rollCooldown = 0,
      hurtFor = 0,
      invulnerableFor = 0,
      dyingFor = 0;
  String deathReason = '';
  int ammo = 24,
      reserve = 120,
      cores = 0,
      kills = 0,
      wave = 0,
      flashes = 3,
      traps = 3;
  int shots = 0, hits = 0, soundSerial = 0, _id = 0;
  bool firing = false, sprinting = false;
  String sound = '',
      message = 'Tìm 3 lõi tín hiệu. Sống sót 3 phút để chờ cứu hộ.';
  double messageFor = 4;
  HidingSpot? hiding;
  double hideFor = 0,
      hideCooldown = 0,
      howlCooldown = 0,
      howlFor = 0,
      howlGain = 1,
      blackoutFor = 0,
      _footstepCooldown = 0;
  int howlSerial = 0, _blackouts = 0;
  bool running = false;
  PlayerStance stance = PlayerStance.standing,
      previousStance = PlayerStance.standing;
  double stanceFor = 0, exposedFor = 0;
  String get stanceName => const ['ĐỨNG', 'NGỒI XỔM', 'NẰM SẤP'][stance.index];
  bool get inVegetation => survival && world.inVegetation(player);
  bool get usingLowCover =>
      survival &&
      stance != PlayerStance.standing &&
      exposedFor <= 0 &&
      world.nearLowCover(player);
  bool get lowProfile =>
      stance == PlayerStance.prone ||
      stance == PlayerStance.crouching && exposedFor <= 0;
  double get visionMultiplier => !survival || exposedFor > 0
      ? 1
      : TownRules.stanceVisibility[stance.index] *
            (stance == PlayerStance.prone && inVegetation ? .55 : 1);
  double get walkingSpeed =>
      survival ? TownRules.stanceSpeeds[stance.index] : 190;

  bool setStance(PlayerStance value) {
    if (!active ||
        !survival ||
        stanceFor > 0 ||
        rollFor > 0 ||
        value == stance) {
      return false;
    }
    previousStance = stance;
    stance = value;
    stanceFor =
        value == PlayerStance.prone || previousStance == PlayerStance.prone
        ? .55
        : .22;
    running = sprinting = false;
    return true;
  }

  bool get hidden => hiding != null;
  bool get lowHealth => health > 0 && health <= TownRules.criticalHealth;
  HidingSpot? get nearbyHiding {
    for (final spot in world.hidingSpots) {
      if ((spot.center - player).distance <= 72) return spot;
    }
    return null;
  }

  Creature? get nearestThreat {
    Creature? nearest;
    var distance = 650.0;
    for (final e in enemies) {
      if (!e.alive || e.stun > 0 || e.spawnFor > 0) continue;
      final d = (e.position - player).distance;
      if (d < distance) {
        nearest = e;
        distance = d;
      }
    }
    return nearest;
  }

  double get threatDistance => nearestThreat == null
      ? double.infinity
      : (nearestThreat!.position - player).distance;
  final enemies = <Creature>[],
      bullets = <FieldBullet>[],
      effects = <FieldEffect>[],
      items = <FieldItem>[];
  final pending = <CreatureKind>[];
  final _lastDamageAttack = <int, int>{};
  bool get active => phase == FieldPhase.playing;
  double get rescueIn =>
      math.max(0, (survival ? TownRules.duration : rescueAt) - elapsed);
  String get objective => survival
      ? 'Sống sót ${rescueIn.ceil()} giây • Lõi tín hiệu tùy chọn $cores/3'
      : cores < 3
      ? 'Tìm 3 lõi tín hiệu. Cứu hộ đến sau 3 phút.'
      : rescueIn > 0
      ? 'Đã đủ lõi • Chờ cứu hộ ${rescueIn.ceil()}s'
      : 'Cứu hộ đã tới! Trở về vòng sáng xanh.';
  bool get finished => phase == FieldPhase.won || phase == FieldPhase.lost;
  int get aliveCount => enemies.where((e) => e.alive).length;
  bool get jammed => enemies.any(
    (e) =>
        e.alive &&
        e.kind == CreatureKind.jammer &&
        e.stun <= 0 &&
        (e.position - player).distance < 310,
  );
  int get score =>
      cores * 300 +
      kills * 100 +
      (phase == FieldPhase.won
          ? (survival ? 1500 : 1000) + health.floor() * 5
          : 0);

  void notice(String value, [String effect = 'click']) {
    message = value;
    messageFor = 3.5;
    sound = effect;
    soundSerial++;
  }

  void start() {
    if (phase == FieldPhase.ready) phase = FieldPhase.playing;
  }

  void pause() {
    if (active) {
      phase = FieldPhase.paused;
      firing = false;
      movement = Offset.zero;
    }
  }

  void resume() {
    if (phase == FieldPhase.paused) phase = FieldPhase.playing;
  }

  void update(double dt) {
    if (!dt.isFinite || dt < 0) throw ArgumentError('Invalid frame time');
    if (phase == FieldPhase.lost && dyingFor > 0) {
      dyingFor = math.max(0, dyingFor - math.min(dt, .1));
      return;
    }
    if (!active) return;
    var rest = math.min(dt, .25);
    while (rest > 1e-8 && active) {
      final step = math.min(rest, .025);
      _step(step);
      rest -= step;
    }
  }

  void _step(double dt) {
    final awaitingRescue = rescueIn > 0;
    elapsed += dt;
    if (!survival && awaitingRescue && rescueIn == 0) {
      notice('Cứu hộ đã tới! Mang đủ 3 lõi trở về vòng xanh.', 'alarm');
    }
    shotCooldown = math.max(0, shotCooldown - dt);
    flashCooldown = math.max(0, flashCooldown - dt);
    trapCooldown = math.max(0, trapCooldown - dt);
    flashFor = math.max(0, flashFor - dt);
    rollCooldown = math.max(0, rollCooldown - dt);
    hurtFor = math.max(0, hurtFor - dt);
    invulnerableFor = math.max(0, invulnerableFor - dt);
    dyingFor = math.max(0, dyingFor - dt);
    messageFor = math.max(0, messageFor - dt);
    stanceFor = math.max(0, stanceFor - dt);
    exposedFor = math.max(0, exposedFor - dt);
    if (survival) {
      hideCooldown = math.max(0, hideCooldown - dt);
      howlCooldown = math.max(0, howlCooldown - dt);
      howlFor = math.max(0, howlFor - dt);
      blackoutFor = math.max(0, blackoutFor - dt);
      _footstepCooldown = math.max(0, _footstepCooldown - dt);
      if (hidden) {
        hideFor = math.max(0, hideFor - dt);
        if (hideFor == 0) {
          leaveHiding();
          _emitNoise(950);
          notice('Bạn phải rời chỗ ẩn để lấy hơi! Đổi vị trí ngay.', 'alarm');
        }
      }
      if (_blackouts < 2 && elapsed >= (_blackouts == 0 ? 52 : 128)) {
        _blackouts++;
        blackoutFor = 14;
        notice(
          'Mất điện! Giữ bình tĩnh, tìm vật chắn và lắng nghe tiếng hú.',
          'alarm',
        );
      }
    }
    if (reloadFor > 0) {
      reloadFor = math.max(0, reloadFor - dt);
      if (reloadFor == 0) {
        final count = math.min(24 - ammo, reserve);
        ammo += count;
        reserve -= count;
      }
    }
    var direction = movement.distance > 1
        ? movement / movement.distance
        : movement;
    if (!direction.dx.isFinite || !direction.dy.isFinite) {
      direction = Offset.zero;
    }
    if (hidden && (direction.distance > .15 || firing || sprinting)) {
      leaveHiding();
    }
    running =
        sprinting &&
        direction.distance > .1 &&
        stamina > 0 &&
        !hidden &&
        stance == PlayerStance.standing &&
        stanceFor == 0;
    if (survival &&
        !hidden &&
        direction.distance > .1 &&
        _footstepCooldown == 0) {
      _footstepCooldown = stance == PlayerStance.prone ? 1.2 : .75;
      _emitNoise(running ? 520 : TownRules.stanceNoise[stance.index]);
    }
    stamina = (stamina + (running ? -22 : 16) * dt).clamp(0, 100);
    if (rollFor > 0) {
      rollFor = math.max(0, rollFor - dt);
      player = world.move(player, rollDirection * 520 * dt);
    } else {
      player = world.move(
        player,
        direction *
            (running ? 280 : walkingSpeed) *
            dt *
            (stanceFor > 0 ? .5 : 1),
      );
    }
    if (direction.distance > .1) {
      lastMove = direction / direction.distance;
      walkTime += dt * (running ? 14 : 9);
    }
    if ((aim - player).distance > 1) {
      facing = math.atan2(aim.dy - player.dy, aim.dx - player.dx);
    }
    if (firing) shoot(aim);
    final times = survival ? TownRules.waveTimes : waveTimes;
    final kinds = survival ? TownRules.waveKinds : waveKinds;
    while (wave < times.length && elapsed >= times[wave]) {
      pending.addAll(kinds[wave].map((i) => CreatureKind.values[i]));
      wave++;
      notice('Đợt $wave/5 — sinh vật đang truy tìm bạn.', 'alarm');
    }
    if (pending.isNotEmpty &&
        aliveCount < (survival ? TownRules.maxAlive : 9)) {
      spawn(pending.removeAt(0));
    }
    for (final enemy in enemies) {
      _enemy(enemy, dt);
      if (!active) return;
    }
    _bullets(dt);
    _effects(dt);
    enemies.removeWhere((e) => !e.alive && e.death <= 0);
    if (survival) _updateTension();
    for (final item in items.where((i) => !i.taken && elapsed >= i.unlockAt)) {
      if ((item.position - player).distance > 35 ||
          item.kind == 'health' && health >= 100 ||
          survival && item.kind == 'ammo' && reserve >= TownRules.reserveCap) {
        continue;
      }
      item.taken = true;
      switch (item.kind) {
        case 'core':
          cores++;
          notice('Đã thu hồi lõi $cores/3.', 'click');
        case 'health':
          health = math.min(100, health + 40);
          notice('Đã hồi 40 máu.');
        case 'ammo':
          reserve = survival
              ? math.min(TownRules.reserveCap, reserve + 48)
              : reserve + 48;
          notice('Nhặt được 48 viên đạn.');
      }
    }
    if (world.hazards.any((r) => r.contains(player))) {
      hurt(9 * dt, isHazard: true, reason: 'Nhiễm độc môi trường');
    }
    if (survival && active && elapsed >= TownRules.duration) {
      elapsed = TownRules.duration;
      phase = FieldPhase.won;
      _stopCombatInput();
      pending.clear();
      notice('Tín hiệu đã được giữ. Bạn sống sót!', 'win');
    } else if (!survival &&
        active &&
        rescueIn == 0 &&
        cores >= 3 &&
        (player - FieldWorld.extraction).distance < 55) {
      phase = FieldPhase.won;
      firing = false;
      notice('Đã sơ tán an toàn!', 'win');
    }
  }

  Creature spawn(CreatureKind kind, {Offset? at}) {
    var position = at ?? const Offset(1100, 130);
    if (at == null) {
      for (var attempt = 0; attempt < 80; attempt++) {
        final angle = survival ? random.nextDouble() * math.pi * 2 : 0.0;
        final radius = survival ? 650 + random.nextDouble() * 230 : 0.0;
        final candidate = survival
            ? player + Offset(math.cos(angle), math.sin(angle)) * radius
            : attempt.isEven
            ? Offset(100 + random.nextDouble() * 2000, 120)
            : Offset(
                attempt % 4 == 1 ? 115 : 2085,
                200 + random.nextDouble() * 1150,
              );
        if (world.walkable(candidate, 25) &&
            (candidate - player).distance > 450) {
          position = candidate;
          break;
        }
      }
    }
    final e = Creature(++_id, kind, position);
    if (survival && at == null) {
      e.spawnFor = 1.2;
      if (!hidden) {
        e.investigate = player;
        e.noiseFor = 6;
      }
    }
    enemies.add(e);
    return e;
  }

  void _enemy(Creature e, double dt) {
    e.hit = math.max(0, e.hit - dt);
    e.animation += dt;
    e.strikeFor = math.max(0, e.strikeFor - dt);
    if (!e.alive) {
      e.death = math.max(0, e.death - dt);
      return;
    }
    if (e.spawnFor > 0) {
      e.spawnFor = math.max(0, e.spawnFor - dt);
      return;
    }
    e.memoryFor = math.max(0, e.memoryFor - dt);
    e.stun = math.max(0, e.stun - dt);
    e.weak = math.max(0, e.weak - dt);
    e.attack = math.max(0, e.attack - dt);
    e.noiseFor = math.max(0, e.noiseFor - dt);
    if (e.stun > 0 || e.weak > 0) return;
    final distance = (player - e.position).distance;
    final clear = world.clearLine(e.position, player, 2);
    final sight = survival
        ? world.clearSight(e.position, player, lowProfile: lowProfile)
        : clear;
    final sensedTarget = survival ? _huntTarget(e, distance, sight) : player;
    if (e.windup > 0) {
      e.windup = math.max(0, e.windup - dt);
      if (e.windup == 0) {
        if (clear && distance < e.radius + 40) {
          hurt(
            e.damage,
            reason: 'Bị ${e.name} tấn công',
            sourceId: e.id,
            attackId: e.attackId,
          );
        }
        e.strikeFor = .22;
        e.attack = 1.3;
      }
      return;
    }
    if (e.charge > 0) {
      e.charge = math.max(0, e.charge - dt);
      if (e.charge == 0) {
        if (distance < 130 && clear) {
          hurt(
            e.damage,
            reason: 'Bị đòn nện của Vật Chủ nghiền nát',
            sourceId: e.id,
            attackId: e.attackId,
          );
        }
        e.weak = 3.2;
        e.attack = 4.2;
        effects.add(FieldEffect(e.position, 'slam', .55));
        notice('Boss lộ điểm yếu! Bắn khi vòng vàng đang sáng.', 'boss_slam');
      }
      return;
    }
    if ((!survival || e.huntState == HuntState.chase) &&
        clear &&
        distance < (e.kind == CreatureKind.boss ? 105 : e.radius + 24)) {
      if (e.attack == 0) {
        if (e.kind == CreatureKind.boss) {
          e.attackId++;
          e.charge = 1.4;
          notice('Boss đang nạp đòn — lùi ra khỏi vòng đỏ!', 'boss_charge');
        } else if (survival) {
          e.attackId++;
          e.windup = TownRules.windup[e.kind.index];
        } else {
          hurt(e.damage, reason: 'Bị ${e.name} tấn công');
          e.attack = 1.3;
        }
      }
      return;
    }
    var target = sensedTarget;
    if (!survival &&
        e.noiseFor > 0 &&
        distance > 250 &&
        e.investigate != null) {
      target = e.investigate!;
    }
    e.pathTimer -= dt;
    if (!world.clearLine(e.position, target, e.radius + 2)) {
      if (e.pathTimer <= 0) {
        e.path = world.route(e.position, target);
        e.pathStep = 0;
        e.pathTimer = .85 + e.id % 3 * .12;
      }
      while (e.pathStep < e.path.length &&
          (e.position - e.path[e.pathStep]).distance < 12) {
        e.pathStep++;
      }
      if (e.pathStep < e.path.length) target = e.path[e.pathStep];
    }
    final delta = target - e.position;
    if (delta.distance > .1) {
      e.facing = math.atan2(delta.dy, delta.dx);
      e.position = world.move(
        e.position,
        delta / delta.distance * math.min(delta.distance, e.speed * dt),
        e.radius,
      );
    }
  }

  Offset _huntTarget(Creature e, double distance, bool clear) {
    final sees =
        clear &&
        (distance < 78 ||
            !hidden &&
                distance <
                    (e.kind == CreatureKind.boss
                            ? 620
                            : TownRules.visionRange) *
                        visionMultiplier);
    if (sees) {
      if (hidden) {
        leaveHiding();
        notice('Bạn bị phát hiện! Rời chỗ ẩn ngay.', 'alarm');
      }
      e.huntState = HuntState.chase;
      e.lastKnown = player;
      e.memoryFor = TownRules.memorySeconds;
      return player;
    }
    if (e.noiseFor > 0 && e.investigate != null) {
      e.lastKnown = e.investigate;
      e.memoryFor = math.max(e.memoryFor, e.noiseFor + 1);
    }
    if (e.lastKnown != null && e.memoryFor > 0) {
      if ((e.position - e.lastKnown!).distance > 45) {
        e.huntState = HuntState.investigate;
        return e.lastKnown!;
      }
      e.huntState = HuntState.search;
      const offsets = [
        Offset(65, 0),
        Offset(0, -65),
        Offset(-65, 0),
        Offset(0, 65),
      ];
      final target =
          e.lastKnown! +
          offsets[((TownRules.memorySeconds - e.memoryFor) / 1.2)
                  .floor()
                  .abs() %
              4];
      return world.walkable(target, 25) ? target : e.lastKnown!;
    }
    e.lastKnown = null;
    e.huntState = HuntState.patrol;
    if (e.patrolTarget == null ||
        (e.patrolTarget! - e.position).distance < 25) {
      e.patrolTarget = e.home;
      for (var attempt = 0; attempt < 12; attempt++) {
        final p =
            e.home +
            Offset(
              random.nextDouble() * 500 - 250,
              random.nextDouble() * 500 - 250,
            );
        if (world.walkable(p, 25)) {
          e.patrolTarget = p;
          break;
        }
      }
    }
    return e.patrolTarget!;
  }

  void _emitNoise(double range) {
    for (final e in enemies.where((e) => e.alive)) {
      final audible = world.clearLine(e.position, player) ? range : range * .6;
      if ((e.position - player).distance < audible) {
        e.investigate = player;
        e.noiseFor = 5;
        e.pathTimer = 0;
      }
    }
  }

  bool toggleHide() {
    if (!active || !survival) return false;
    if (hidden) {
      leaveHiding();
      return true;
    }
    final spot = nearbyHiding;
    if (spot == null || hideCooldown > 0) {
      notice(
        spot == null
            ? 'Tìm bụi cây có biểu tượng ẩn nấp, rồi bấm G.'
            : 'Chờ ${hideCooldown.ceil()} giây trước khi ẩn tiếp.',
      );
      return false;
    }
    hiding = spot;
    hideFor = TownRules.hideDuration;
    _stopCombatInput();
    notice('Đang ẩn: ${spot.name}. Giữ yên; bắn hoặc di chuyển sẽ lộ vị trí.');
    return true;
  }

  void leaveHiding() {
    if (!hidden) return;
    hiding = null;
    hideFor = 0;
    hideCooldown = TownRules.hideCooldown;
    if (message.startsWith('Đang ẩn:')) {
      message = 'Đã rời chỗ ẩn. Đi nhẹ và dùng vật chắn để cắt đuôi.';
      messageFor = 2.5;
    }
  }

  void _updateTension() {
    final e = nearestThreat;
    if (e != null &&
        (e.position - player).distance < TownRules.howlDistance &&
        howlCooldown == 0) {
      howlSerial++;
      howlFor = 2.8;
      howlCooldown = TownRules.howlCooldown;
      howlGain = world.clearLine(e.position, player) ? 1 : .5;
    }
  }

  void reload() {
    if (!active || reloadFor > 0 || ammo >= 24 || reserve <= 0) return;
    reloadFor = 1.65;
    notice('Đang thay đạn…');
  }

  bool roll() {
    if (!active || rollCooldown > 0 || stamina < 25) return false;
    if (stanceFor > 0) return false;
    if (survival && stance == PlayerStance.prone) {
      setStance(PlayerStance.standing);
      notice('Đang đứng dậy. Bấm Space lần nữa để lướt khi đã đứng.');
      return false;
    }
    if (survival && stance == PlayerStance.crouching) {
      previousStance = stance;
      stance = PlayerStance.standing;
    }
    leaveHiding();
    rollDirection = lastMove;
    rollFor = .22;
    rollCooldown = 3;
    stamina -= 25;
    return true;
  }

  bool shoot(Offset target) {
    if (!active ||
        stanceFor > 0 ||
        shotCooldown > 0 ||
        reloadFor > 0 ||
        !target.dx.isFinite ||
        !target.dy.isFinite) {
      return false;
    }
    if (ammo == 0) {
      reload();
      return false;
    }
    final direction = target - player;
    if (direction.distance < 1) return false;
    final unit = direction / direction.distance;
    leaveHiding();
    ammo--;
    shots++;
    shotCooldown = .18;
    // Start inside the player's circle so walls next to the muzzle also block bullets.
    bullets.add(
      FieldBullet(
        player + unit * 10,
        unit,
        lowShot: !survival || stance == PlayerStance.prone,
      ),
    );
    if (survival) exposedFor = .6;
    effects.add(
      FieldEffect(player + unit * 28, 'muzzle', .07, direction: unit),
    );
    if (survival) {
      _emitNoise(1000);
    } else {
      for (final e in enemies.where(
        (e) => e.alive && (e.position - player).distance < 650,
      )) {
        e.investigate = player;
        e.noiseFor = 4;
      }
    }
    sound = 'shot';
    soundSerial++;
    return true;
  }

  void _bullets(double dt) {
    for (final bullet in bullets) {
      final next = bullet.position + bullet.direction * 950 * dt;
      var nearest = 1.0;
      Creature? target;
      var blocked = false;
      for (final obstacle
          in survival
              ? world.shotObstacles(lowShot: bullet.lowShot)
              : world.obstacles) {
        final t = segmentRect(bullet.position, next, obstacle.inflate(2));
        if (t != null && t <= nearest) {
          nearest = t;
          blocked = true;
        }
      }
      for (final e in enemies.where((e) => e.alive)) {
        final t = _circleHit(bullet.position, next, e.position, e.radius + 3);
        if (t != null && t < nearest) {
          nearest = t;
          target = e;
          blocked = false;
        }
      }
      bullet.position += (next - bullet.position) * nearest;
      bullet.life -= dt;
      if (target != null && !blocked) {
        hit(target, 28);
        hits++;
        bullet.life = 0;
      } else if (blocked) {
        effects.add(FieldEffect(bullet.position, 'spark', .2));
        bullet.life = 0;
      }
    }
    bullets.removeWhere((b) => b.life <= 0);
  }

  double hit(Creature e, double amount) {
    if (!active || !e.alive) return 0;
    final armored = e.kind == CreatureKind.boss && e.weak <= 0;
    final damage = armored ? amount / 3 : amount;
    e.health = math.max(0, e.health - damage);
    e.hit = .25;
    effects.add(
      FieldEffect(
        e.position - const Offset(0, 25),
        'damage',
        .7,
        text: '−${damage.ceil()}${armored ? ' GIÁP' : ''}',
      ),
    );
    if (!e.alive) {
      e.death = .85;
      e.charge = e.stun = e.weak = e.windup = 0;
      kills++;
      sound = 'kill';
      soundSerial++;
    }
    return damage;
  }

  bool flash() {
    if (!active || flashes <= 0 || flashCooldown > 0) return false;
    flashes--;
    flashCooldown = 6;
    flashFor = .22;
    for (final e in enemies.where(
      (e) => e.alive && (e.position - player).distance < 250,
    )) {
      stun(e, e.kind == CreatureKind.boss ? 1.5 : 3.5);
    }
    effects.add(FieldEffect(player, 'flash', .5));
    notice('Đèn chớp đã kích hoạt.', 'flash');
    return true;
  }

  void stun(Creature e, double seconds) {
    if (!e.alive) return;
    e.stun = math.max(e.stun, seconds);
    e.charge = 0;
    e.windup = 0;
    e.attack = math.max(e.attack, 1);
  }

  bool trap() {
    if (!active || traps <= 0 || trapCooldown > 0) return false;
    traps--;
    trapCooldown = 3;
    effects.add(FieldEffect(player, 'trap', 20));
    notice('Đã đặt bẫy điện. Dụ quái vào vòng sáng.');
    return true;
  }

  void _effects(double dt) {
    for (final effect in effects) {
      effect.life -= dt;
      if (effect.kind == 'damage') effect.position -= Offset(0, dt * 35);
      if (effect.kind == 'trap') {
        for (final e in enemies.where(
          (e) => e.alive && (e.position - effect.position).distance < 65,
        )) {
          stun(e, e.kind == CreatureKind.boss ? 2 : 4);
          effect.life = 0;
          break;
        }
      }
    }
    effects.removeWhere((e) => e.life <= 0);
  }

  void _stopCombatInput() {
    firing = sprinting = false;
    movement = Offset.zero;
    reloadFor = rollFor = 0;
  }

  void hurt(
    double amount, {
    bool isHazard = false,
    String reason = 'Bị tấn công',
    int? sourceId,
    int? attackId,
  }) {
    if (!active || !amount.isFinite || amount <= 0) return;
    if (sourceId != null && attackId != null) {
      if ((_lastDamageAttack[sourceId] ?? -1) >= attackId) return;
      _lastDamageAttack[sourceId] = attackId;
    }
    if (!isHazard && rollFor > 0) return;
    if (!isHazard && invulnerableFor > 0) return;
    health = math.max(0, health - amount);
    if (hidden) leaveHiding();
    hurtFor = .35;
    if (!isHazard) invulnerableFor = 0.45;
    if (health == 0) {
      phase = FieldPhase.lost;
      _stopCombatInput();
      deathReason = reason;
      dyingFor = 0.85;
      notice('Nhiệm vụ thất bại: $deathReason', 'alarm');
    }
  }
}

double? _circleHit(Offset a, Offset b, Offset center, double radius) {
  final d = b - a, f = a - center;
  final length = d.dx * d.dx + d.dy * d.dy;
  if (length < 1e-10) return f.distance <= radius ? 0 : null;
  if (f.distance <= radius) return 0;
  final dot = f.dx * d.dx + f.dy * d.dy;
  final discriminant =
      dot * dot - length * (f.dx * f.dx + f.dy * f.dy - radius * radius);
  if (discriminant < 0) return null;
  final t = (-dot - math.sqrt(discriminant)) / length;
  return t >= 0 && t <= 1 ? t : null;
}

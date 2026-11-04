import 'dart:math' as math;
import 'dart:ui';
import 'world.dart';
import '../survival/rules.dart';
import '../survival/gear.dart';
export '../survival/gear.dart';

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
  double castFor = 0, magicCooldown = 0;
  bool enraged = false;
  double phaseFor = 0, zoneCooldown = 0;
  int get bossPhase => enraged ? 2 : 1;
  double get castDuration => kind == CreatureKind.boss && enraged
      ? 1.05
      : TownRules.magicWindup[magicTier];
  Offset? castTarget;
  int attackId = 0;
  bool get usesMagic =>
      kind == CreatureKind.jammer || kind == CreatureKind.boss;
  bool get casting => castFor > 0 && castTarget != null;
  int get magicTier => kind == CreatureKind.boss ? 1 : 0;
  int pathStep = 0;
  List<Offset> path = [];
  Offset? investigate;
  double noiseFor = 0;
  bool get alive => health > 0;
  double get maxHealth => [45, 135, 70, 300][kind.index].toDouble();
  double get speed =>
      [125, 69, 96, 78][kind.index].toDouble() * (enraged ? 1.18 : 1);
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
  FieldBullet(
    this.position,
    this.direction, {
    this.lowShot = true,
    this.damage = 28,
    this.speed = 950,
    this.life = .85,
    this.shotId = 0,
  });
  Offset position, direction;
  final bool lowShot;
  final double damage, speed;
  final int shotId;
  double life;
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

/// Enemy-only projectile. Direction and damage are fixed at release; a volley
/// shares one attack ID, so its three bolts cannot stack damage on one player.
class EnemyMagicBolt {
  EnemyMagicBolt(
    this.position,
    this.direction, {
    required this.sourceId,
    required this.attackId,
    required this.boss,
  }) : remaining = TownRules.magicRange[boss ? 1 : 0] + 60;
  Offset position;
  final Offset direction;
  final int sourceId, attackId;
  final bool boss;
  double remaining;
  double get radius => boss ? 12 : 9;
  double get speed => TownRules.magicSpeed[boss ? 1 : 0];
  double get damage => TownRules.magicDamage[boss ? 1 : 0];
}

class FieldItem {
  FieldItem(this.position, this.kind, {this.unlockAt = 0});
  final Offset position;
  final String kind;
  final double unlockAt;
  bool taken = false;
}

class BossRift {
  BossRift(this.position, this.sourceId, this.attackId);
  final Offset position;
  final int sourceId, attackId;
  double warning = 1.4, fade = .5;
  bool detonated = false;
  static const radius = 90.0;
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
      flashes = traps = 0;
      message = 'Giữ tín hiệu 180 giây. Lõi tín hiệu là mục tiêu phụ.';
      items.addAll([
        FieldItem(const Offset(1190, 1460), 'gun_pistol'),
        FieldItem(const Offset(1200, 2070), 'gun_shotgun'),
        FieldItem(const Offset(1260, 1670), 'key_armory'),
        FieldItem(const Offset(1250, 1440), 'health', unlockAt: 105),
        FieldItem(const Offset(840, 520), 'ammo', unlockAt: 105),
        FieldItem(const Offset(3110, 910), 'health'),
        FieldItem(const Offset(2850, 2800), 'health'),
        FieldItem(const Offset(1240, 2570), 'ammo'),
        FieldItem(const Offset(3440, 2500), 'ammo'),
      ]);
      world.stashes.first.rifleRounds = 24;
      world.stashes.first.pistolRounds = 12;
      world.stashes.first.shells = 0;
      world.stashes.last.shotgunAvailable = true;
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
  GunKind weapon = GunKind.rifle;
  final gunSlots = <GunKind, GunSlot>{
    GunKind.pistol: GunSlot(),
    GunKind.rifle: GunSlot(owned: true, ammo: 24, reserve: 120),
    GunKind.shotgun: GunSlot(),
  };
  GunSpec get gun => GunSpec.of(weapon);
  bool owns(GunKind kind) => gunSlots[kind]!.owned;
  int magazineOf(GunKind kind) => kind == weapon ? ammo : gunSlots[kind]!.ammo;
  int reserveOf(GunKind kind) =>
      kind == weapon ? reserve : gunSlots[kind]!.reserve;
  int medkits = 1;
  static const medkitCapacity = 3, healDuration = 2.8;
  double healFor = 0;
  bool _healing = false;
  bool get healing => _healing;
  final keys = <String>{};
  final _landedShots = <int>{};
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
  int magicSerial = 0;
  String magicSound = '';
  final enemyBolts = <EnemyMagicBolt>[];
  final bossRifts = <BossRift>[];
  bool get magicThreat =>
      enemies.any((e) => e.alive && e.casting) ||
      enemyBolts.any((b) => (b.position - player).distance < 300) ||
      bossRifts.any((r) => !r.detonated);
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
    cancelHealing();
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
  // Ranged volleys can arrive out of order relative to later melee attacks.
  // Remember individual IDs, not only the highest ID seen for each source.
  final _damageAttacks = <(int, int)>{};
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
        final count = math.min((survival ? gun.magazine : 24) - ammo, reserve);
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
    if (healing && (direction.distance > .1 || firing || rollFor > 0)) {
      cancelHealing();
    }
    if (healing) healFor = math.max(0, healFor - dt);
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
    if (survival) _enemyMagic(dt);
    if (survival && active) _updateRifts(dt);
    if (!active) return;
    _effects(dt);
    enemies.removeWhere((e) => !e.alive && e.death <= 0);
    if (survival) _updateTension();
    for (final item in items.where((i) => !i.taken && elapsed >= i.unlockAt)) {
      if ((item.position - player).distance > 35 ||
          item.kind == 'health' &&
              (survival ? medkits >= medkitCapacity : health >= 100) ||
          survival && item.kind == 'ammo' && reserve >= gun.reserveCap) {
        continue;
      }
      if (item.kind.startsWith('gun_')) {
        item.taken = pickupGun(
          item.kind == 'gun_pistol' ? GunKind.pistol : GunKind.shotgun,
        );
        continue;
      }
      item.taken = true;
      switch (item.kind) {
        case 'core':
          cores++;
          notice('Đã thu hồi lõi $cores/3.', 'click');
        case 'health':
          if (survival) {
            medkits++;
            notice('Đã cất túi máu. H để băng bó trong 2,8 giây.');
          } else {
            health = math.min(100, health + 40);
            notice('Đã hồi 40 máu.');
          }
        case 'ammo':
          reserve = survival
              ? math.min(gun.reserveCap, reserve + ammoBundle(weapon))
              : reserve + 48;
          notice(
            survival
                ? 'Nhặt đạn cho ${gun.name.toLowerCase()}.'
                : 'Nhặt được 48 viên đạn.',
          );
        case 'key_armory':
          keys.add('armory');
          notice('Nhặt chìa kho tiếp tế. Xem bản đồ để tìm kho.');
      }
    }
    if (world.hazards.any((r) => r.contains(player))) {
      hurt(9 * dt, isHazard: true, reason: 'Nhiễm độc môi trường');
    }
    if (active && healing && healFor == 0) {
      _healing = false;
      medkits--;
      health = math.min(100, health + 40);
      notice('Băng bó xong: +40 máu.');
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
    e.magicCooldown = math.max(0, e.magicCooldown - dt);
    e.zoneCooldown = math.max(0, e.zoneCooldown - dt);
    e.phaseFor = math.max(0, e.phaseFor - dt);
    if (e.phaseFor > 0) return;
    if (e.stun > 0 || e.weak > 0) return;
    final distance = (player - e.position).distance;
    final clear = world.clearLine(e.position, player, 2);
    final sight = survival
        ? world.clearSight(e.position, player, lowProfile: lowProfile)
        : clear;
    var sensedTarget = survival ? _huntTarget(e, distance, sight) : player;
    if (survival && e.casting) {
      e.castFor = math.max(0, e.castFor - dt);
      if (e.castFor == 0) _releaseMagic(e);
      return;
    }
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
    if (survival) {
      for (final door in world.doors.where((d) => !d.open)) {
        final inside = door.room.contains(e.position);
        if (inside == door.room.contains(sensedTarget)) continue;
        sensedTarget = door.rect.center + Offset(0, inside ? -85 : 85);
        if ((e.position - door.rect.center).distance < e.radius + 74) {
          if (e.attack == 0) {
            door.health = math.max(0, door.health - e.damage);
            e.attack = 1.3;
            e.strikeFor = .25;
            effects.add(FieldEffect(door.rect.center, 'door_hit', .25));
            if (door.broken) {
              world.setDoorOpen(door, true);
              _refreshPaths();
              notice('Cửa ${door.name.toLowerCase()} đã bị phá!', 'boss_slam');
            }
          }
          return;
        }
        break;
      }
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
    if (survival &&
        e.kind == CreatureKind.boss &&
        e.enraged &&
        e.zoneCooldown == 0 &&
        !e.casting &&
        e.huntState == HuntState.chase &&
        !hidden &&
        clear &&
        sight &&
        distance < 620 &&
        bossRifts.length <= 2) {
      e.attackId++;
      for (final p in [player, player + lastMove * 140]) {
        if (world.walkable(p, 10) && world.clearLine(e.position, p, 2)) {
          bossRifts.add(BossRift(p, e.id, e.attackId));
        }
      }
      e.zoneCooldown = 6;
      e.magicCooldown = math.max(e.magicCooldown, 1.6);
      e.strikeFor = .35;
      message = 'VẾT NỨT MA LỰC! Rời hai vòng đỏ trước khi chúng nổ.';
      messageFor = 2;
      _magicCue('magic_charge');
      return;
    }
    if (survival &&
        e.usesMagic &&
        e.huntState == HuntState.chase &&
        !hidden &&
        clear &&
        sight &&
        distance >= 140 &&
        distance <= TownRules.magicRange[e.magicTier]) {
      if (e.magicCooldown == 0 &&
          enemyBolts.length <= TownRules.maxEnemyBolts - 3 &&
          enemies.where((e) => e.casting).length <
              TownRules.maxCastingEnemies) {
        e.attackId++;
        e.castTarget = player;
        e.castFor = e.castDuration;
        e.facing = (player - e.position).direction;
        message = e.kind == CreatureKind.boss
            ? 'Vật chủ tụ ma lực — né loạt ba cầu tím!'
            : 'Quái đang tụ ma lực — di chuyển ngang hoặc nấp sau vật chắn!';
        messageFor = 1.7;
        _magicCue('magic_charge');
        return;
      }
      // The ranged creature keeps a firing distance between casts. It still
      // approaches when too far away and can strike in melee when cornered.
      if (e.kind == CreatureKind.jammer && distance < 365) {
        final toward = (player - e.position) / distance;
        final delta = distance < 220
            ? -toward
            : Offset(-toward.dy, toward.dx) * (e.id.isEven ? 1 : -1) * .32;
        e.facing = toward.direction;
        e.position = world.move(e.position, delta * e.speed * dt, e.radius);
        return;
      }
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

  void _magicCue(String name) {
    magicSound = name;
    magicSerial++;
  }

  void _cancelMagic(Creature e, {double cooldown = 1.5}) {
    e.castFor = 0;
    e.castTarget = null;
    e.magicCooldown = math.max(e.magicCooldown, cooldown);
  }

  void _releaseMagic(Creature e) {
    final target = e.castTarget;
    e.castTarget = null;
    final boss = e.kind == CreatureKind.boss;
    final count = boss ? 3 : 1;
    if (!active ||
        !e.alive ||
        e.stun > 0 ||
        target == null ||
        (target - e.position).distance < 1 ||
        !world.clearLine(e.position, target, 12) ||
        enemyBolts.length + count > TownRules.maxEnemyBolts) {
      _cancelMagic(e);
      return;
    }
    final angle = (target - e.position).direction;
    for (final spread in boss ? const [-.19, 0.0, .19] : const [0.0]) {
      final direction = Offset(
        math.cos(angle + spread),
        math.sin(angle + spread),
      );
      enemyBolts.add(
        EnemyMagicBolt(
          e.position + direction * 8,
          direction,
          sourceId: e.id,
          attackId: e.attackId,
          boss: boss,
        ),
      );
    }
    e.magicCooldown =
        (e.enraged ? 4.8 : TownRules.magicCooldown[e.magicTier]) +
        (e.id % 3) * .15;
    e.strikeFor = .3;
    if (boss) {
      e.weak = 2.4;
      message = 'Boss vừa tung phép, giáp đã hở — bắn ngay!';
      messageFor = 2.4;
    }
    effects.add(FieldEffect(e.position, 'magic_release', .35));
    _magicCue('magic_cast');
  }

  void _enemyMagic(double dt) {
    for (final bolt in enemyBolts) {
      final travel = math.min(bolt.remaining, bolt.speed * dt);
      final next = bolt.position + bolt.direction * travel;
      var nearest = 1.0;
      var blocked = false;
      for (final wall in world.obstacles) {
        final t = segmentRect(bolt.position, next, wall.inflate(bolt.radius));
        if (t != null && t <= nearest) {
          nearest = t;
          blocked = true;
        }
      }
      final hit = _circleHit(bolt.position, next, player, 16 + bolt.radius);
      final hitsPlayer =
          hit != null && (!blocked ? hit <= nearest : hit < nearest);
      if (hitsPlayer) nearest = hit;
      bolt.position += (next - bolt.position) * nearest;
      bolt.remaining -= travel;
      if (hitsPlayer || blocked) {
        bolt.remaining = 0;
        effects.add(FieldEffect(bolt.position, 'magic_impact', .35));
        if (hitsPlayer) {
          final before = health;
          hurt(
            bolt.damage,
            sourceId: bolt.sourceId,
            attackId: bolt.attackId,
            reason: bolt.boss
                ? 'Trúng ma lực của Vật chủ'
                : 'Trúng cầu ma lực của Kẻ gây nhiễu',
          );
          if (health < before) _magicCue('magic_hit');
          if (!active) return;
        }
      }
    }
    enemyBolts.removeWhere((b) => b.remaining <= 0);
  }

  void _updateRifts(double dt) {
    for (final rift in bossRifts) {
      Creature? owner;
      for (final e in enemies) {
        if (e.id == rift.sourceId && e.alive) owner = e;
      }
      if (owner == null) {
        rift.fade = 0;
        continue;
      }
      if (rift.detonated) {
        rift.fade = math.max(0, rift.fade - dt);
        continue;
      }
      rift.warning = math.max(0, rift.warning - dt);
      if (rift.warning == 0) {
        rift.detonated = true;
        owner.weak = math.max(owner.weak, 1.5);
        effects.add(FieldEffect(rift.position, 'rift_blast', .5));
        if ((player - rift.position).distance <= BossRift.radius &&
            world.clearLine(rift.position, player, 2)) {
          hurt(
            24,
            sourceId: rift.sourceId,
            attackId: rift.attackId,
            reason: 'Bị vùng nổ ma lực giai đoạn hai của Vật chủ',
          );
          if (!active) return;
        }
        _magicCue('magic_hit');
      }
    }
    bossRifts.removeWhere((r) => r.fade <= 0);
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

  static int ammoBundle(GunKind kind) => const [24, 48, 8][kind.index];

  int addAmmo(GunKind kind, int amount) {
    if (!owns(kind) || amount <= 0) return 0;
    final count = math.min(
      amount,
      math.max(0, GunSpec.of(kind).reserveCap - reserveOf(kind)),
    );
    if (kind == weapon) {
      reserve += count;
    } else {
      gunSlots[kind]!.reserve += count;
    }
    return count;
  }

  bool pickupGun(GunKind kind) {
    if (!survival || !active) return false;
    final slot = gunSlots[kind]!;
    if (slot.owned) {
      final count = addAmmo(kind, ammoBundle(kind));
      if (count == 0) return false;
    } else {
      slot.owned = true;
      slot.ammo = GunSpec.of(kind).magazine;
      slot.reserve = const [36, 72, 12][kind.index];
    }
    notice(
      'Nhặt ${GunSpec.of(kind).name.toLowerCase()}. Phím ${kind.index + 1} để trang bị.',
    );
    return true;
  }

  bool switchWeapon(GunKind kind) {
    if (!survival || !active || !owns(kind) || weapon == kind) return false;
    cancelHealing();
    gunSlots[weapon]!
      ..ammo = ammo
      ..reserve = reserve;
    weapon = kind;
    ammo = gunSlots[kind]!.ammo;
    reserve = gunSlots[kind]!.reserve;
    reloadFor = 0;
    shotCooldown = math.max(shotCooldown, .2);
    notice('Trang bị ${gun.name.toLowerCase()}.');
    return true;
  }

  bool cycleWeapon() {
    for (var i = 1; i < 3; i++) {
      final next = GunKind.values[(weapon.index + i) % 3];
      if (owns(next)) return switchWeapon(next);
    }
    notice('Nhặt thêm súng để đổi vũ khí.');
    return false;
  }

  bool useMedkit() {
    if (!survival ||
        !active ||
        healing ||
        medkits <= 0 ||
        health >= 100 ||
        rollFor > 0 ||
        stanceFor > 0) {
      return false;
    }
    movement = Offset.zero;
    firing = sprinting = false;
    reloadFor = 0;
    _healing = true;
    healFor = healDuration;
    notice('Đang băng bó. Giữ yên; di chuyển, bắn hoặc trúng đòn sẽ ngắt.');
    return true;
  }

  void cancelHealing() {
    _healing = false;
    healFor = 0;
  }

  TownDoor? get nearbyDoor {
    TownDoor? nearest;
    var distance = 105.0;
    for (final d in world.doors) {
      final dd = (d.rect.center - player).distance;
      if (dd < distance &&
          !world.obstacles
              .where((r) => r != d.rect)
              .any(
                (r) => segmentRect(player, d.rect.center, r.inflate(1)) != null,
              )) {
        nearest = d;
        distance = dd;
      }
    }
    return nearest;
  }

  TownStash? get nearbyStash {
    for (final s in world.stashes) {
      if (!s.empty &&
          (s.position - player).distance < 80 &&
          world.clearLine(player, s.position, 2)) {
        return s;
      }
    }
    return null;
  }

  String? get interactionLabel {
    final s = nearbyStash;
    if (s != null) {
      return 'E · ${s.opened ? 'NHẶT TIẾP' : 'MỞ'} ${s.name.toUpperCase()}';
    }
    final d = nearbyDoor;
    if (d == null) return null;
    return d.broken
        ? 'CỬA ĐÃ VỠ'
        : d.locked
        ? (keys.contains('armory') ? 'E · MỞ KHÓA KHO' : 'E · CẦN CHÌA KHO')
        : 'E · ${d.open ? 'ĐÓNG' : 'MỞ'} CỬA ${d.name}';
  }

  void _refreshPaths() {
    for (final e in enemies) {
      e.path.clear();
      e.pathStep = 0;
      e.pathTimer = 0;
    }
  }

  bool interact() {
    if (!survival || !active) return false;
    final stash = nearbyStash;
    if (stash != null) {
      cancelHealing();
      var taken = 0;
      if (stash.shotgunAvailable && !owns(GunKind.shotgun)) {
        pickupGun(GunKind.shotgun);
        stash.shotgunAvailable = false;
        taken++;
      }
      if (stash.shotgunAvailable && owns(GunKind.shotgun)) {
        final rounds = addAmmo(GunKind.shotgun, 6);
        if (rounds > 0) {
          stash.shotgunAvailable = false;
          taken++;
        }
      }
      final meds = math.min(
        math.max(0, medkitCapacity - medkits),
        stash.medStock,
      );
      medkits += meds;
      stash.medStock -= meds;
      taken += meds;
      var count = addAmmo(GunKind.rifle, stash.rifleRounds);
      stash.rifleRounds -= count;
      taken += count;
      count = addAmmo(GunKind.pistol, stash.pistolRounds);
      stash.pistolRounds -= count;
      taken += count;
      count = addAmmo(GunKind.shotgun, stash.shells);
      stash.shells -= count;
      taken += count;
      if (taken == 0) {
        notice('Túi đang đầy. Phần tiếp tế còn lại được giữ trong hòm.');
        return false;
      }
      stash.opened = true;
      notice('Đã lấy tiếp tế. Đạn/túi máu còn dư vẫn ở trong hòm.');
      return true;
    }
    final door = nearbyDoor;
    if (door == null) return false;
    if (door.broken) {
      notice('Cửa đã vỡ, không thể đóng lại.');
      return false;
    }
    if (door.locked) {
      if (!keys.remove('armory')) {
        notice('Cần chìa kho tiếp tế: tìm ở phố cổ.');
        return false;
      }
      door.locked = false;
    }
    if (door.open &&
        (door.rect.inflate(23).contains(player) ||
            enemies.any(
              (e) =>
                  e.alive &&
                  door.rect.inflate(e.radius + 3).contains(e.position),
            ))) {
      notice('Lối cửa đang có người/quái. Lùi ra trước khi đóng.');
      return false;
    }
    cancelHealing();
    world.setDoorOpen(door, !door.open);
    _refreshPaths();
    notice(
      '${door.open ? 'Đã mở' : 'Đã đóng'} cửa ${door.name.toLowerCase()}.',
    );
    return true;
  }

  void reload() {
    if (!active ||
        reloadFor > 0 ||
        ammo >= (survival ? gun.magazine : 24) ||
        reserve <= 0) {
      return;
    }
    cancelHealing();
    reloadFor = survival ? gun.reloadSeconds : 1.65;
    notice('Đang thay đạn…');
  }

  bool roll() {
    if (!active || rollCooldown > 0 || stamina < 25) return false;
    if (stanceFor > 0) return false;
    cancelHealing();
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
    cancelHealing();
    final unit = direction / direction.distance;
    leaveHiding();
    ammo--;
    shots++;
    shotCooldown = survival ? gun.interval : .18;
    // Start inside the player's circle so walls next to the muzzle also block bullets.
    final pellets = survival ? gun.pellets : 1;
    for (var i = 0; i < pellets; i++) {
      final angle =
          unit.direction +
          (pellets == 1 ? 0 : (i / (pellets - 1) * 2 - 1) * gun.spread);
      final ray = Offset(math.cos(angle), math.sin(angle));
      bullets.add(
        FieldBullet(
          player + ray * 10,
          ray,
          lowShot: !survival || stance == PlayerStance.prone,
          damage: survival ? gun.damage : 28,
          speed: survival ? gun.speed : 950,
          life: survival ? gun.range / gun.speed : .85,
          shotId: shots,
        ),
      );
    }
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
      final flight = math.min(dt, bullet.life);
      final next = bullet.position + bullet.direction * bullet.speed * flight;
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
        hit(target, bullet.damage);
        if (bullet.shotId == 0 || _landedShots.add(bullet.shotId)) hits++;
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
    if (survival &&
        e.alive &&
        e.kind == CreatureKind.boss &&
        !e.enraged &&
        e.health <= e.maxHealth * .5) {
      e.enraged = true;
      e.phaseFor = 1.2;
      e.zoneCooldown = .8;
      e.castFor = e.charge = e.windup = 0;
      e.castTarget = null;
      e.magicCooldown = math.max(e.magicCooldown, 1);
      notice(
        'BOSS GIAI ĐOẠN 2! Canh vòng đỏ, né rồi phản công.',
        'boss_charge',
      );
    }
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
      e.castFor = 0;
      e.castTarget = null;
      kills++;
      sound = 'kill';
      soundSerial++;
    } else if (survival && e.casting && e.kind != CreatureKind.boss) {
      _cancelMagic(e, cooldown: 2);
      effects.add(FieldEffect(e.position, 'magic_impact', .25));
    }
    return damage;
  }

  bool flash() {
    if (survival || !active || flashes <= 0 || flashCooldown > 0) return false;
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
    _cancelMagic(e);
    e.attack = math.max(e.attack, 1);
  }

  bool trap() {
    if (survival || !active || traps <= 0 || trapCooldown > 0) return false;
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
    cancelHealing();
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
      if (!_damageAttacks.add((sourceId, attackId))) return;
    }
    if (!isHazard && rollFor > 0) return;
    if (!isHazard && invulnerableFor > 0) return;
    cancelHealing();
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

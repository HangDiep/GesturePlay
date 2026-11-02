import 'dart:math' as math;
import 'dart:ui';
import 'world.dart';

enum FieldPhase { ready, playing, paused, won, lost }

enum CreatureKind { runner, heavy, jammer, boss }

class Creature {
  Creature(this.id, this.kind, this.position)
    : health = [45, 135, 70, 300][kind.index].toDouble();
  final int id;
  final CreatureKind kind;
  Offset position;
  double health,
      stun = 0,
      weak = 0,
      charge = 0,
      attack = 0,
      hit = 0,
      death = 0,
      pathTimer = 0;
  double animation = 0, facing = 0;
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
  FieldBullet(this.position, this.direction);
  Offset position, direction;
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
  FieldItem(this.position, this.kind);
  final Offset position;
  final String kind;
  bool taken = false;
}

class ExplorationModel {
  ExplorationModel(FieldMap map, {int seed = 42})
    : world = FieldWorld(map),
      random = math.Random(seed) {
    items.addAll(world.cores.map((p) => FieldItem(p, 'core')));
    for (var i = 0; i < world.supplies.length; i++) {
      items.add(FieldItem(world.supplies[i], i == 0 ? 'health' : 'ammo'));
    }
  }
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
  double rollFor = 0, rollCooldown = 0, hurtFor = 0;
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
  final enemies = <Creature>[],
      bullets = <FieldBullet>[],
      effects = <FieldEffect>[],
      items = <FieldItem>[];
  final pending = <CreatureKind>[];
  bool get active => phase == FieldPhase.playing;
  double get rescueIn => math.max(0, rescueAt - elapsed);
  String get objective => cores < 3
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
      (phase == FieldPhase.won ? 1000 + health.floor() * 5 : 0);

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
    if (!active) return;
    if (!dt.isFinite || dt < 0) throw ArgumentError('Invalid frame time');
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
    if (awaitingRescue && rescueIn == 0) {
      notice('Cứu hộ đã tới! Mang đủ 3 lõi trở về vòng xanh.', 'alarm');
    }
    shotCooldown = math.max(0, shotCooldown - dt);
    flashCooldown = math.max(0, flashCooldown - dt);
    trapCooldown = math.max(0, trapCooldown - dt);
    flashFor = math.max(0, flashFor - dt);
    rollCooldown = math.max(0, rollCooldown - dt);
    hurtFor = math.max(0, hurtFor - dt);
    messageFor = math.max(0, messageFor - dt);
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
    final running = sprinting && direction.distance > .1 && stamina > 0;
    stamina = (stamina + (running ? -22 : 16) * dt).clamp(0, 100);
    if (rollFor > 0) {
      rollFor = math.max(0, rollFor - dt);
      player = world.move(player, rollDirection * 520 * dt);
    } else {
      player = world.move(player, direction * (running ? 280 : 190) * dt);
    }
    if (direction.distance > .1) {
      lastMove = direction / direction.distance;
      walkTime += dt * (running ? 14 : 9);
    }
    if ((aim - player).distance > 1) {
      facing = math.atan2(aim.dy - player.dy, aim.dx - player.dx);
    }
    if (firing) shoot(aim);
    while (wave < waveTimes.length && elapsed >= waveTimes[wave]) {
      pending.addAll(waveKinds[wave].map((i) => CreatureKind.values[i]));
      wave++;
      notice('Đợt $wave/5 — sinh vật đang truy tìm bạn.', 'alarm');
    }
    if (pending.isNotEmpty && aliveCount < 9) spawn(pending.removeAt(0));
    for (final enemy in enemies) {
      _enemy(enemy, dt);
      if (!active) return;
    }
    _bullets(dt);
    _effects(dt);
    enemies.removeWhere((e) => !e.alive && e.death <= 0);
    for (final item in items.where((i) => !i.taken)) {
      if ((item.position - player).distance > 35 ||
          item.kind == 'health' && health >= 100) {
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
          reserve += 48;
          notice('Nhặt được 48 viên đạn.');
      }
    }
    if (world.hazards.any((r) => r.contains(player))) hurt(9 * dt);
    if (active &&
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
        final candidate = attempt.isEven
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
    enemies.add(e);
    return e;
  }

  void _enemy(Creature e, double dt) {
    e.hit = math.max(0, e.hit - dt);
    e.animation += dt;
    if (!e.alive) {
      e.death = math.max(0, e.death - dt);
      return;
    }
    e.stun = math.max(0, e.stun - dt);
    e.weak = math.max(0, e.weak - dt);
    e.attack = math.max(0, e.attack - dt);
    e.noiseFor = math.max(0, e.noiseFor - dt);
    if (e.stun > 0 || e.weak > 0) return;
    final distance = (player - e.position).distance;
    final clear = world.clearLine(e.position, player, 2);
    if (e.charge > 0) {
      e.charge = math.max(0, e.charge - dt);
      if (e.charge == 0) {
        if (distance < 130 && clear) hurt(e.damage);
        e.weak = 3.2;
        e.attack = 4.2;
        effects.add(FieldEffect(e.position, 'slam', .55));
        notice('Boss lộ điểm yếu! Bắn khi vòng vàng đang sáng.', 'boss_slam');
      }
      return;
    }
    if (clear &&
        distance < (e.kind == CreatureKind.boss ? 105 : e.radius + 24)) {
      if (e.attack == 0) {
        if (e.kind == CreatureKind.boss) {
          e.charge = 1.4;
          notice('Boss đang nạp đòn — lùi ra khỏi vòng đỏ!', 'boss_charge');
        } else {
          hurt(e.damage);
          e.attack = 1.3;
        }
      }
      return;
    }
    var target = player;
    if (e.noiseFor > 0 && distance > 250 && e.investigate != null) {
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

  void reload() {
    if (!active || reloadFor > 0 || ammo >= 24 || reserve <= 0) return;
    reloadFor = 1.65;
    notice('Đang thay đạn…');
  }

  bool roll() {
    if (!active || rollCooldown > 0 || stamina < 25) return false;
    rollDirection = lastMove;
    rollFor = .22;
    rollCooldown = 3;
    stamina -= 25;
    return true;
  }

  bool shoot(Offset target) {
    if (!active ||
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
    ammo--;
    shots++;
    shotCooldown = .18;
    // Start inside the player's circle so walls next to the muzzle also block bullets.
    bullets.add(FieldBullet(player + unit * 10, unit));
    effects.add(
      FieldEffect(player + unit * 28, 'muzzle', .07, direction: unit),
    );
    for (final e in enemies.where(
      (e) => e.alive && (e.position - player).distance < 650,
    )) {
      e.investigate = player;
      e.noiseFor = 4;
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
      for (final obstacle in world.obstacles) {
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
      e.charge = e.stun = e.weak = 0;
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

  void hurt(double amount) {
    if (!active || rollFor > 0) return;
    health = math.max(0, health - amount);
    hurtFor = .35;
    if (health == 0) {
      phase = FieldPhase.lost;
      firing = false;
      notice('Nhiệm vụ thất bại.', 'alarm');
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

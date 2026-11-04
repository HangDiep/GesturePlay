import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../exploration/model.dart';
import '../exploration/world.dart';
import 'art.dart';
import 'scenery.dart';
import 'view.dart';

class TownPainter extends CustomPainter {
  TownPainter(
    this.model,
    this.art, {
    this.showcase = false,
    this.clock = 0,
    this.reducedEffects = false,
    this.reticle = true,
  });
  final ExplorationModel model;
  final TownArt art;
  final bool showcase, reducedEffects, reticle;
  final double clock;
  static const amber = Color(0xffe7b96d), cyan = Color(0xff6bd3ce);
  static const violet = Color(0xffc28bff);
  double get _time => showcase ? clock : model.elapsed;
  double get _shotHeight => TownView.muzzleHeight(model.stance.index);
  Offset _floor(Offset p) => TownView.floor(p);

  @override
  void paint(Canvas c, Size size) {
    final view = TownView(model.player, size, world: model.world);
    c.save();
    c.clipRect(Offset.zero & size);
    c.drawColor(const Color(0xff101c24), BlendMode.src);
    c.scale(view.zoom);
    c.translate(-view.origin.dx, -view.origin.dy);
    _ground(c, view);
    _roomFloors(c, view);
    _lamps(c, view);
    _magicTelegraphs(c, view);
    _riftWarnings(c, view);
    for (final item in model.items.where(
      (i) => !i.taken && i.unlockAt <= model.elapsed,
    )) {
      if (view.bounds.inflate(100).contains(item.position)) _item(c, item);
    }
    for (final effect in model.effects.where((e) => e.kind == 'trap')) {
      _groundRing(c, effect.position, 57, cyan.withValues(alpha: .7), 1.5);
      final p = _floor(effect.position);
      for (var j = 0; j < 6; j++) {
        final a = j * math.pi / 3 + _time;
        c.drawLine(
          p + Offset(math.cos(a) * 30, math.sin(a) * 18),
          p + Offset(math.cos(a + .3) * 48, math.sin(a + .3) * 29),
          Paint()
            ..color = cyan.withValues(alpha: .7)
            ..strokeWidth = 1.5,
        );
      }
    }
    for (final e in model.enemies.where(
      (e) => e.alive && view.bounds.inflate(180).contains(e.position),
    )) {
      if (e.charge > 0) {
        _groundRing(c, e.position, 130, const Color(0xfff08761), 2.5);
        _groundRing(
          c,
          e.position,
          130 * (1 - e.charge / 1.4),
          const Color(0xfff08761),
          2,
        );
      } else if (e.windup > 0) {
        _groundRing(c, e.position, e.radius + 40, const Color(0xfff08761), 2);
      }
      if (e.weak > 0) {
        _glow(c, _floor(e.position) - const Offset(0, 55), 65, amber, .3);
      }
    }

    // Billboard art stays upright. Occlusion order follows projected feet,
    // rather than world Y, so a diagonal street has correct front/back overlap.
    final draws =
        <
            ({
              double depth,
              FieldProp? prop,
              TownDoor? door,
              Creature? enemy,
              TownDecoration? detail,
              bool player,
            })
          >[
            for (final p in model.world.props)
              if (view.bounds.inflate(490).overlaps(p.rect))
                (
                  depth: _floor(p.rect.center).dy,
                  prop: p,
                  door: null,
                  enemy: null,
                  detail: null,
                  player: false,
                ),
            for (final d in TownScenery.of(model.world).decorations)
              if (view.bounds.inflate(420).contains(d.position))
                (
                  depth: _floor(d.position).dy,
                  prop: null,
                  enemy: null,
                  detail: d,
                  door: null,
                  player: false,
                ),
            for (final e in model.enemies)
              if (view.bounds.inflate(210).contains(e.position))
                (
                  depth: _floor(e.position).dy,
                  prop: null,
                  enemy: e,
                  door: null,
                  detail: null,
                  player: false,
                ),
            (
              depth: _floor(model.player).dy,
              prop: null,
              enemy: null,
              detail: null,
              player: true,
              door: null,
            ),
            for (final d in model.world.doors)
              (
                depth: _floor(d.rect.center).dy,
                prop: null,
                door: d,
                enemy: null,
                detail: null,
                player: false,
              ),
          ]
          ..sort((a, b) => a.depth.compareTo(b.depth));
    for (final draw in draws) {
      if (draw.prop case final p?) {
        _prop(c, p);
      } else if (draw.door case final door?) {
        _door(c, door);
      } else if (draw.detail case final d?) {
        _detail(c, d);
      } else if (draw.enemy case final e?) {
        _enemy(c, e);
      } else if (draw.player) {
        _player(c);
      }
    }
    _wires(c, view);
    _magicBolts(c, view);
    for (final b in model.bullets) {
      final p = _floor(b.position) - Offset(0, _shotHeight);
      c.drawLine(
        _floor(b.position - b.direction * 25) - Offset(0, _shotHeight),
        p,
        Paint()
          ..color = const Color(0xffffdfab)
          ..strokeWidth = 1.9
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final spot in model.world.hidingSpots) {
      if (!view.bounds.inflate(70).contains(spot.center)) continue;
      final near = (spot.center - model.player).distance < 115;
      _groundRing(
        c,
        spot.center,
        40,
        cyan.withValues(alpha: near ? .55 : .13),
        1,
      );
      if (near || model.hiding == spot) {
        _label(
          c,
          model.hiding == spot ? 'ĐANG ẨN' : 'G · ẨN NẤP',
          _floor(spot.center) + const Offset(0, 36),
          cyan,
          10,
        );
      }
    }
    _combatEffects(c, view);
    if (!showcase && reticle && model.active) {
      final at = _floor(model.aim) - Offset(0, _shotHeight);
      _ring(c, at, 8, const Color(0xccd9e9df), 1);
      for (final d in const [
        Offset(0, -1),
        Offset(0, 1),
        Offset(1, 0),
        Offset(-1, 0),
      ]) {
        c.drawLine(
          at + d * 12,
          at + d * 17,
          Paint()
            ..color = const Color(0xa6d9e9df)
            ..strokeWidth = 1,
        );
      }
    }
    c.restore();
    _atmosphere(c, size, view);
  }

  void _ground(Canvas c, TownView view) {
    c.save();
    c.transform(TownView.matrix);
    final visible = view.bounds.inflate(120);
    c.drawRect(visible, Paint()..shader = art.groundShader);
    c.drawRect(visible, Paint()..color = const Color(0x3a08111a));
    // Fine stone kerbs follow the same tilted plane as paths and collisions.
    for (final road in model.world.roads.where((r) => r.overlaps(visible))) {
      c.drawRect(road, Paint()..color = const Color(0x128ab4c4));
      if (road.height > road.width) {
        for (final x in [road.left, road.right]) {
          c.drawLine(
            Offset(x, road.top),
            Offset(x, road.bottom),
            Paint()
              ..color = const Color(0x44050f16)
              ..strokeWidth = 7,
          );
          for (double y = road.top; y < road.bottom; y += 36) {
            if (!visible.inflate(10).contains(Offset(x, y))) continue;
            c.drawLine(
              Offset(x - 3, y),
              Offset(x + 3, y),
              Paint()
                ..color = const Color(0x5e89948a)
                ..strokeWidth = 2,
            );
          }
        }
      } else {
        for (final y in [road.top, road.bottom]) {
          c.drawLine(
            Offset(road.left, y),
            Offset(road.right, y),
            Paint()
              ..color = const Color(0x44050f16)
              ..strokeWidth = 7,
          );
          for (double x = road.left; x < road.right; x += 36) {
            if (!visible.inflate(10).contains(Offset(x, y))) continue;
            c.drawLine(
              Offset(x, y - 3),
              Offset(x, y + 3),
              Paint()
                ..color = const Color(0x5e89948a)
                ..strokeWidth = 2,
            );
          }
        }
      }
    }
    // Scattered moonlit water follows the walkable lanes. A single atlas and
    // short reflected strokes give wet streets without real-time reflections.
    for (var roadIndex = 0; roadIndex < model.world.roads.length; roadIndex++) {
      final road = model.world.roads[roadIndex];
      final vertical = road.height > road.width;
      final length = vertical ? road.height : road.width;
      for (double along = 85; along < length; along += 235) {
        final wobble = math.sin(along * .034 + roadIndex) * 46;
        final p = vertical
            ? Offset(road.center.dx + wobble, road.top + along)
            : Offset(road.left + along, road.center.dy + wobble);
        if (!visible.inflate(180).contains(p)) continue;
        final width = 80 + (along.toInt() % 61).toDouble();
        final r = Rect.fromCenter(center: p, width: width, height: width * .8);
        c.drawImageRect(
          art.details,
          art.detailFrames[10],
          r,
          Paint()
            ..filterQuality = FilterQuality.low
            ..color = const Color(0x9affffff),
        );
        if (!reducedEffects) {
          final pulse = (.45 + .1 * math.sin(_time * 1.6 + along));
          c.drawOval(
            Rect.fromCenter(center: p, width: width * .3, height: 2),
            Paint()
              ..color = const Color(0xffaac8da).withValues(alpha: pulse * .3),
          );
        }
      }
    }
    // Broad dark damp areas break up repeated texture without full-screen blur.
    for (var i = 0; i < 160; i++) {
      final p = Offset(
        80 + (i * 317 % (model.world.mapWidth - 160)).toDouble(),
        90 + (i * 593 % (model.world.mapHeight - 180)).toDouble(),
      );
      if (!visible.inflate(180).contains(p)) continue;
      final r = Rect.fromCenter(
        center: p,
        width: 90.0 + i % 115,
        height: 40.0 + i % 60,
      );
      _stamp(c, art.lighting.damp, r, .37);
      if (i % 3 == 0) {
        c.drawImageRect(
          art.details,
          art.detailFrames[10],
          r,
          Paint()
            ..filterQuality = FilterQuality.low
            ..color = const Color(0x447eacc1),
        );
      }
    }
    for (final p in model.world.props.where(
      (p) => p.solid && visible.inflate(170).overlaps(p.rect),
    )) {
      _groundShadow(c, p.rect.center, p.rect.width * .66, p.rect.height * .65);
      // A thin foundation ties each building to its actual collision footprint.
      if (p.sprite == 0 || p.sprite == 5) {
        c.drawRect(p.rect.inflate(7), Paint()..color = const Color(0x55061115));
        c.drawRect(
          p.rect.inflate(5),
          Paint()
            ..color = const Color(0x385f7476)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      }
    }
    c.restore();
  }

  void _lamps(Canvas c, TownView view) {
    for (final p in model.world.props) {
      if (!const [0, 5, 6].contains(p.sprite) ||
          !view.bounds.inflate(250).overlaps(p.rect)) {
        continue;
      }
      final at = _floor(p.rect.bottomCenter);
      final flicker = reducedEffects
          ? 1.0
          : .94 + math.sin(_time * 3.7 + p.rect.left) * .04;
      final strength = (model.blackoutFor > 0 ? .055 : .36) * flicker;
      c.save();
      c.translate(at.dx, at.dy);
      c.scale(1, .44);
      _glow(c, Offset.zero, p.sprite == 0 ? 155 : 110, amber, strength);
      // Ripples of reflected lantern light; no expensive reflection passes.
      for (var j = 0; j < 8; j++) {
        final yy = 14.0 + j * 8;
        final half = 3.0 + (8 - j) * 1.5;
        c.drawLine(
          Offset(-half, yy),
          Offset(half, yy),
          Paint()
            ..color = amber.withValues(alpha: strength * (1 - j / 9))
            ..strokeWidth = 1.4,
        );
      }
      c.restore();
    }
  }

  void _prop(Canvas c, FieldProp p) {
    if (p.sprite == 12) {
      _wall(c, p.rect);
      return;
    }
    var image = art.props;
    var src = TownArt.propFrames[p.sprite!];
    var width = p.artSize!.width, height = p.artSize!.height;
    if (p.sprite == 0) {
      image = art.architecture;
      final variant = (p.rect.center.dx ~/ 130 + p.rect.center.dy ~/ 170) % 3;
      final market = p.rect.center.dx < 2200 && p.rect.center.dy > 1800;
      src = art.architectureFrames[market && variant == 1 ? 3 : variant];
      width *= market && variant == 1 ? 1.13 : 1.22;
      height = width * src.height / src.width;
    } else if (p.sprite == 5) {
      image = art.architecture;
      src =
          art.architectureFrames[p.rect.center.dy > 1800
              ? (p.rect.center.dx > 2200 ? 5 : 3)
              : 4];
      width *= 1.2;
      height = width * src.height / src.width;
    } else if (p.sprite == 2 || p.sprite == 4 || p.sprite == 6) {
      image = art.details;
      src =
          art.detailFrames[p.sprite == 2
              ? (p.artSize!.height >= 220 ? 3 : 0)
              : p.sprite == 4
              ? 1
              : 8];
      width *= p.sprite == 2 ? 1.12 : 1;
      height = width * src.height / src.width;
    }
    final foot = _floor(p.rect.center + Offset(0, p.rect.height * .25));
    final dest = Rect.fromLTWH(
      foot.dx - width / 2,
      foot.dy - height + 8,
      width,
      height,
    );
    final obscures =
        dest.inflate(12).contains(_floor(model.player) - const Offset(0, 26)) &&
        _floor(p.rect.center).dy > _floor(model.player).dy + 4;
    c.drawImageRect(
      image,
      src,
      dest,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(255, 255, 255, obscures ? .27 : 1),
    );
  }

  void _roomFloors(Canvas c, TownView view) {
    for (final d in model.world.doors) {
      if (!view.bounds.inflate(140).overlaps(d.room)) continue;
      c.save();
      c.transform(TownView.matrix);
      c.drawRect(d.room.deflate(16), Paint()..color = const Color(0x6b153b3e));
      c.drawRect(
        d.room.deflate(34),
        Paint()
          ..color = const Color(0x443e7472)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      c.restore();
      _label(
        c,
        d.name,
        _floor(d.room.center) + const Offset(0, 30),
        const Color(0xff8ab2a9),
        13,
      );
    }
    for (final s in model.world.stashes) {
      if (!view.bounds.inflate(80).contains(s.position)) continue;
      final p = _floor(s.position) - const Offset(0, 12);
      final color = s.id == 'refuge' ? cyan : amber;
      _shadow(c, s.position, 27);
      if (!s.empty) _glow(c, p, 38, color, .16);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 45, height: 29),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xff36484b),
      );
      c.drawRect(
        Rect.fromCenter(
          center: p - Offset(0, s.opened ? 18 : 10),
          width: 46,
          height: 7,
        ),
        Paint()..color = color.withValues(alpha: .65),
      );
      if (s.id == 'refuge') {
        c.drawLine(
          p - const Offset(6, 0),
          p + const Offset(6, 0),
          Paint()
            ..color = color
            ..strokeWidth = 3,
        );
        c.drawLine(
          p - const Offset(0, 6),
          p + const Offset(0, 6),
          Paint()
            ..color = color
            ..strokeWidth = 3,
        );
      } else {
        for (var j = -1; j <= 1; j++) {
          c.drawLine(
            p + Offset(j * 7, -5),
            p + Offset(j * 7, 5),
            Paint()
              ..color = color
              ..strokeWidth = 3,
          );
        }
      }
      if ((s.position - model.player).distance < 135) {
        _label(
          c,
          s.empty ? 'ĐÃ HẾT' : s.name.toUpperCase(),
          p + const Offset(0, 30),
          color,
          10,
        );
      }
    }
  }

  void _wall(Canvas c, Rect r) {
    final points = [
      _floor(r.topLeft),
      _floor(r.topRight),
      _floor(r.bottomRight),
      _floor(r.bottomLeft),
    ];
    const height = 70.0;
    final bounds = TownView.envelope([
      ...points,
      ...points.map((p) => p - const Offset(0, height)),
    ]);
    final obscures =
        bounds.contains(_floor(model.player) - const Offset(0, 25)) &&
        _floor(r.center).dy > _floor(model.player).dy;
    final alpha = obscures ? .32 : 1.0;
    for (final i in const [2, 3]) {
      final a = points[i], b = points[(i + 1) % 4];
      final face = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, b.dy - height)
        ..lineTo(a.dx, a.dy - height)
        ..close();
      c.drawPath(
        face,
        Paint()
          ..shader = art.groundShader
          ..color = Color.fromRGBO(255, 255, 255, alpha)
          ..colorFilter = ColorFilter.mode(
            i.isEven ? const Color(0xff9bb1b4) : const Color(0xff667c85),
            BlendMode.modulate,
          ),
      );
      for (var course = 1; course < 5; course++) {
        final v = Offset(0, -height * course / 5);
        c.drawLine(
          a + v,
          b + v,
          Paint()
            ..color = const Color(0xff71827c).withValues(alpha: alpha * .4)
            ..strokeWidth = 1,
        );
      }
      final segments = math.max(1, (b - a).distance ~/ 32);
      for (var k = 1; k < segments; k++) {
        final p = Offset.lerp(a, b, k / segments)!;
        c.drawLine(
          p,
          p - const Offset(0, height),
          Paint()
            ..color = const Color(0xff091923).withValues(alpha: alpha * .65)
            ..strokeWidth = 1,
        );
      }
    }
    final top = Path()
      ..addPolygon(
        points.map((p) => p - const Offset(0, height)).toList(),
        true,
      );
    c.drawPath(
      top,
      Paint()..color = const Color(0xff53625b).withValues(alpha: alpha),
    );
  }

  void _door(Canvas c, TownDoor door) {
    if (door.broken) {
      _label(c, 'CỬA VỠ', _floor(door.rect.center), const Color(0xffbd8873), 9);
      return;
    }
    final a = _floor(door.rect.bottomLeft);
    final b = _floor(
      door.open
          ? door.rect.bottomLeft - const Offset(0, 100)
          : door.rect.bottomRight,
    );
    const height = 72.0;
    final fade = (model.player - door.rect.center).distance < 70 ? .5 : 1.0;
    c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, b.dy - height)
        ..lineTo(a.dx, a.dy - height)
        ..close(),
      Paint()..color = const Color(0xff55432f).withValues(alpha: fade),
    );
    for (var i = 0; i <= 8; i++) {
      final p = Offset.lerp(a, b, i / 8)!;
      c.drawLine(
        p,
        p - const Offset(0, height),
        Paint()
          ..color = const Color(0xffb6a07b).withValues(alpha: fade * .6)
          ..strokeWidth = 1.2,
      );
    }
    for (final h in [18.0, 55.0]) {
      c.drawLine(
        a - Offset(0, h),
        b - Offset(0, h),
        Paint()
          ..color = const Color(0xff172a31).withValues(alpha: fade)
          ..strokeWidth = 5,
      );
    }
    final middle = (a + b) / 2;
    c.drawCircle(
      middle - const Offset(0, 38),
      3,
      Paint()..color = door.locked ? amber : cyan,
    );
    if ((model.player - door.rect.center).distance < 220) {
      _label(
        c,
        door.locked
            ? 'CẦN CHÌA KHO'
            : door.open
            ? 'CỬA MỞ'
            : 'CỬA ĐÓNG',
        middle - const Offset(0, 88),
        amber,
        9,
      );
      c.drawRect(
        Rect.fromCenter(
          center: middle - const Offset(0, 78),
          width: 65,
          height: 4,
        ),
        Paint()..color = const Color(0xff061017),
      );
      c.drawRect(
        Rect.fromLTWH(
          middle.dx - 32.5,
          middle.dy - 80,
          65 * door.health / 120,
          4,
        ),
        Paint()..color = door.health < 45 ? const Color(0xffeb7e6c) : cyan,
      );
    }
  }

  void _riftWarnings(Canvas c, TownView view) {
    for (final zone in model.bossRifts) {
      if (!view.bounds.inflate(140).contains(zone.position)) continue;
      const color = Color(0xffff7399);
      final progress = 1 - zone.warning / 1.4;
      final alpha = zone.detonated ? zone.fade / .5 : 1.0;
      c.save();
      c.transform(TownView.matrix);
      c.drawCircle(
        zone.position,
        BossRift.radius,
        Paint()..color = color.withValues(alpha: .10 * alpha),
      );
      c.restore();
      _groundRing(
        c,
        zone.position,
        BossRift.radius,
        color.withValues(alpha: .85 * alpha),
        2,
      );
      _groundRing(
        c,
        zone.position,
        BossRift.radius * progress,
        color.withValues(alpha: .5 * alpha),
        1.5,
      );
      if (!zone.detonated) {
        _label(
          c,
          'NỔ ${zone.warning.toStringAsFixed(1)}s',
          _floor(zone.position) - const Offset(0, 14),
          color,
          11,
        );
      }
    }
  }

  void _detail(Canvas c, TownDecoration d) {
    final src = art.detailFrames[d.frame], at = _floor(d.position);
    final height = d.width * src.height / src.width;
    final rect = Rect.fromLTWH(
      at.dx - d.width / 2,
      at.dy - height + 5,
      d.width,
      height,
    );
    final fades =
        rect.contains(_floor(model.player) - const Offset(0, 20)) &&
        at.dy > _floor(model.player).dy + 4;
    c.drawImageRect(
      art.details,
      src,
      rect,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(255, 255, 255, fades ? .3 : 1),
    );
  }

  void _wires(Canvas c, TownView view) {
    for (final y in const [490.0, 980.0, 1370.0, 1660.0]) {
      if (!view.bounds
          .inflate(170)
          .overlaps(Rect.fromLTWH(880, y - 100, 440, 200))) {
        continue;
      }
      final a = _floor(Offset(900, y)) - const Offset(0, 115);
      final b = _floor(Offset(1300, y)) - const Offset(0, 115);
      c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(
            (a.dx + b.dx) / 2,
            (a.dy + b.dy) / 2 + 33,
            b.dx,
            b.dy,
          ),
        Paint()
          ..color = const Color(0xb3081117)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }
  }

  void _item(Canvas c, FieldItem i) {
    final color = i.kind == 'core'
        ? cyan
        : i.kind == 'health'
        ? const Color(0xffa6d8af)
        : amber;
    final p =
        _floor(i.position) +
        Offset(0, math.sin(_time * 2 + i.position.dx) * 3 - 5);
    _glow(c, p, 32, color, .17);
    _groundRing(c, i.position, 20, color.withValues(alpha: .3), 1);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: 22, height: 18),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xff1c2e31),
    );
    if (i.kind == 'health') {
      c.drawLine(
        p - const Offset(6, 0),
        p + const Offset(6, 0),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
      c.drawLine(
        p - const Offset(0, 6),
        p + const Offset(0, 6),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
    } else if (i.kind.startsWith('gun_')) {
      final pistol = i.kind == 'gun_pistol';
      final length = pistol ? 18.0 : 34.0;
      c.drawLine(
        p - Offset(length / 2, 3),
        p + Offset(length / 2, 3),
        Paint()
          ..color = color
          ..strokeWidth = pistol ? 5 : 4,
      );
      c.drawLine(
        p + const Offset(0, 1),
        p + const Offset(-3, 8),
        Paint()
          ..color = color
          ..strokeWidth = 4,
      );
    } else if (i.kind == 'key_armory') {
      _ring(c, p - const Offset(6, 0), 4, amber, 2);
      c.drawLine(
        p - const Offset(2, 0),
        p + const Offset(9, 0),
        Paint()
          ..color = amber
          ..strokeWidth = 2,
      );
      c.drawLine(
        p + const Offset(7, 0),
        p + const Offset(7, 4),
        Paint()
          ..color = amber
          ..strokeWidth = 2,
      );
    } else if (i.kind == 'core') {
      c.drawCircle(p, 5, Paint()..color = color);
      _ring(c, p, 8, color, 1);
    } else {
      for (var j = -1; j <= 1; j++) {
        c.drawLine(
          p + Offset(j * 5, -5),
          p + Offset(j * 5, 5),
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
      }
    }
    _label(
      c,
      i.kind == 'core'
          ? 'LÕI TÍN HIỆU'
          : i.kind == 'health'
          ? 'TÚI MÁU · CẤT VÀO TÚI'
          : i.kind == 'key_armory'
          ? 'CHÌA KHO'
          : i.kind.startsWith('gun_')
          ? (i.kind == 'gun_pistol' ? 'SÚNG LỤC · 1' : 'SHOTGUN · 3')
          : 'ĐẠN VŨ KHÍ',
      p + const Offset(0, 28),
      color,
      9,
    );
  }

  void _actor(
    Canvas c,
    int row,
    int frame,
    Offset p,
    double side, {
    bool flip = false,
    double alpha = 1,
  }) {
    c.save();
    c.translate(p.dx, p.dy + 9);
    if (flip) c.scale(-1, 1);
    c.drawImageRect(
      art.actors,
      art.actorFrame(row, frame),
      Rect.fromLTWH(-side / 2, -side, side, side),
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(255, 255, 255, alpha),
    );
    c.restore();
  }

  double _facing(double angle) =>
      _floor(Offset(math.cos(angle), math.sin(angle))).direction;
  void _player(Canvas c) {
    final m = model, at = _floor(model.player);
    final dead = m.health <= 0, angle = _facing(m.facing);
    final row = math.sin(angle).abs() > .7 ? (math.sin(angle) > 0 ? 1 : 2) : 0;
    final frame = dead
        ? (m.dyingFor > .5
              ? 5
              : m.dyingFor > .2
              ? 6
              : 7)
        : m.rollFor > 0
        ? 6
        : m.hurtFor > .16
        ? 5
        : m.reloadFor > 0 || m.healing
        ? 4
        : m.shotCooldown > .10
        ? 3
        : m.movement.distance > .1
        ? 1 + (m.walkTime.floor() % 2)
        : 0;
    _shadow(c, m.player, 22);
    if (!dead) _groundRing(c, m.player, 18, cyan.withValues(alpha: .24), 1);
    final stance = m.stanceFor > 0 && m.stance == PlayerStance.standing
        ? m.previousStance
        : m.stance;
    if (!dead && m.rollFor <= 0 && stance != PlayerStance.standing) {
      final src =
          art.stanceFrames[((stance == PlayerStance.prone ? 3 : 0) + row) * 8 +
              (m.stanceFor > 0 ? 6 : frame)];
      final scale =
          90 /
          (art.stances.width / 8) *
          (stance == PlayerStance.prone ? .9 : .75);
      final s = Size(src.width * scale, src.height * scale);
      final dest = stance == PlayerStance.prone
          ? Rect.fromCenter(
              center: const Offset(0, -6),
              width: s.width,
              height: s.height,
            )
          : Rect.fromLTWH(-s.width / 2, -s.height + 9, s.width, s.height);
      c.save();
      c.translate(at.dx, at.dy);
      if (row == 0 && math.cos(angle) < 0) c.scale(-1, 1);
      c.drawImageRect(
        art.stances,
        src,
        dest,
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Color.fromRGBO(255, 255, 255, m.hidden ? .3 : 1),
      );
      c.restore();
    } else {
      _actor(
        c,
        row,
        frame,
        at,
        87,
        flip: row == 0 && math.cos(angle) < 0,
        alpha: m.hidden ? .3 : 1,
      );
    }
    if (!dead && m.reloadFor > 0) {
      _label(c, 'ĐANG NẠP', at - const Offset(0, 84), amber, 10);
    }
    if (!dead && m.healing) {
      _label(c, 'BĂNG BÓ', at - const Offset(0, 84), cyan, 10);
    }
  }

  void _enemy(Canvas c, Creature e) {
    final side = e.kind == CreatureKind.boss
        ? 152.0
        : e.kind == CreatureKind.heavy
        ? 108.0
        : 89.0;
    final frame = !e.alive
        ? 7
        : e.stun > 0
        ? 6
        : e.hit > .12
        ? 5
        : e.strikeFor > 0 || e.weak > 2.8
        ? 4
        : e.charge > 0 || e.windup > 0 || e.casting
        ? 3
        : 1 + (e.animation * 6).floor() % 2;
    final at = _floor(e.position);
    _shadow(c, e.position, e.radius * 1.15);
    if (e.alive) {
      _glow(
        c,
        at - Offset(0, side * .35),
        side * .48,
        cyan,
        e.kind == CreatureKind.jammer ? .16 : .07,
      );
      if (!reducedEffects) {
        for (var j = 0; j < 3; j++) {
          final shift = math.sin(_time * 2 + j + e.id) * 7;
          c.drawPath(
            Path()
              ..moveTo(at.dx - 16 + j * 12, at.dy - 22)
              ..quadraticBezierTo(
                at.dx - 30 + shift,
                at.dy - 48 - j * 6,
                at.dx - 24 + shift,
                at.dy - 60 - j * 7,
              ),
            Paint()
              ..color = cyan.withValues(alpha: .12)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
      }
    }
    _actor(
      c,
      e.kind.index + 3,
      frame,
      at,
      side,
      flip: math.cos(_facing(e.facing)) < 0,
      alpha: e.alive
          ? (1 - e.spawnFor / 1.2).clamp(0, 1)
          : (e.death / .85).clamp(0, 1),
    );
    if (!e.alive) return;
    if (!showcase && e.huntState == HuntState.search) {
      _label(c, '? ĐANG TÌM', at - Offset(0, side + 10), amber, 9);
    }
    final p = at - Offset(0, side - 9),
        color = e.weak > 0 ? amber : const Color(0xffc46c57);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p, width: 58, height: 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xcc0a1417),
    );
    c.drawRect(
      Rect.fromLTWH(p.dx - 28, p.dy - 1.5, 56 * e.health / e.maxHealth, 3),
      Paint()..color = color,
    );
    if (e.stun > 0) _label(c, 'CHOÁNG', p - const Offset(0, 12), cyan, 9);
    if (e.casting) {
      _label(c, 'TỤ MA LỰC', p - const Offset(0, 12), violet, 10);
    }
    if (e.enraged) {
      _label(
        c,
        e.phaseFor > 0 ? 'BOSS CHUYỂN DẠNG!' : 'BOSS · GIAI ĐOẠN 2',
        p - const Offset(0, 26),
        const Color(0xfff98c9f),
        10,
      );
    }
    if (e.weak > 0) {
      _label(c, 'LỘ ĐIỂM YẾU', p - const Offset(0, 12), amber, 10);
    }
  }

  void _combatEffects(Canvas c, TownView view) {
    for (final e in model.effects.where(
      (e) => e.kind != 'trap' && view.bounds.inflate(260).contains(e.position),
    )) {
      final a = (e.life / e.maxLife).clamp(0.0, 1.0), p = _floor(e.position);
      if (e.kind == 'damage') {
        _label(
          c,
          e.text,
          p - Offset(0, 48 + (1 - a) * 20),
          amber.withValues(alpha: a),
          13,
        );
      } else if (e.kind == 'rift_blast') {
        _glow(c, p, 100, const Color(0xfffa6d91), a * .4);
        _groundRing(
          c,
          e.position,
          BossRift.radius * (1 + (1 - a) * .3),
          const Color(0xffff719c).withValues(alpha: a),
          4,
        );
      } else if (e.kind == 'door_hit') {
        _glow(c, p - const Offset(0, 30), 34, amber, a * .4);
      } else if (e.kind == 'magic_release' || e.kind == 'magic_impact') {
        _glow(c, p - const Offset(0, 22), 48, violet, a * .6);
        _groundRing(
          c,
          e.position,
          12 + (1 - a) * 45,
          violet.withValues(alpha: a),
          2,
        );
        if (!reducedEffects) {
          for (var i = 0; i < 7; i++) {
            final direction = Offset(
              math.cos(i * math.pi * 2 / 7),
              math.sin(i * math.pi * 2 / 7),
            );
            c.drawLine(
              p - const Offset(0, 22) + direction * 6,
              p - const Offset(0, 22) + direction * (12 + (1 - a) * 30),
              Paint()
                ..color = violet.withValues(alpha: a)
                ..strokeWidth = 1.5,
            );
          }
        }
      } else if (e.kind == 'flash') {
        _groundRing(c, e.position, 250 * (1 - a), cyan.withValues(alpha: a), 3);
      } else if (e.kind == 'slam') {
        _groundRing(
          c,
          e.position,
          130 * (1 - a),
          const Color(0xfff49c78).withValues(alpha: a),
          8 * a,
        );
      } else if (e.kind == 'muzzle' || e.kind == 'spark') {
        _glow(
          c,
          p - Offset(0, _shotHeight),
          e.kind == 'muzzle' ? 40 : 15,
          amber,
          a * .65,
        );
        if (e.kind == 'spark') {
          for (var j = 0; j < 5; j++) {
            final v = Offset(math.cos(j * 1.7), math.sin(j * 1.7));
            c.drawLine(
              p + v * 4,
              p + v * (6 + (1 - a) * 15),
              Paint()
                ..color = amber.withValues(alpha: a)
                ..strokeWidth = 1,
            );
          }
        }
      }
    }
  }

  void _magicTelegraphs(Canvas c, TownView view) {
    for (final e in model.enemies.where(
      (e) =>
          e.alive && e.casting && view.bounds.inflate(180).contains(e.position),
    )) {
      final progress = 1 - e.castFor / e.castDuration;
      final color = e.kind == CreatureKind.boss ? violet : cyan;
      _groundRing(
        c,
        e.position,
        43 + progress * 15,
        color.withValues(alpha: .8),
        2,
      );
      _groundRing(c, e.castTarget!, 25, color.withValues(alpha: .6), 1.5);
      final at = _floor(e.position) - const Offset(0, 25);
      final target = _floor(e.castTarget!) - const Offset(0, 25),
          delta = target - at;
      // The target marker stays where the player was when charging began.
      if (delta.distance > 1) {
        for (double along = 25; along < delta.distance; along += 26) {
          c.drawLine(
            at + delta / delta.distance * along,
            at + delta / delta.distance * math.min(along + 11, delta.distance),
            Paint()
              ..color = color.withValues(alpha: .18 + progress * .14)
              ..strokeWidth = 1.2,
          );
        }
      }
      _glow(c, at, 35 + progress * 25, color, .25 + progress * .25);
      for (var j = 0; j < 6; j++) {
        final a = j * math.pi / 3 + (reducedEffects ? 0 : _time * .9);
        final p = e.position + Offset(math.cos(a), math.sin(a)) * 52;
        final q = e.position + Offset(math.cos(a + .1), math.sin(a + .1)) * 61;
        c.drawLine(
          _floor(p),
          _floor(q),
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _magicBolts(Canvas c, TownView view) {
    for (final bolt in model.enemyBolts) {
      if (!view.bounds.inflate(100).contains(bolt.position)) continue;
      final p = _floor(bolt.position) - const Offset(0, 22);
      final color = bolt.boss ? violet : cyan;
      final tail =
          _floor(bolt.position - bolt.direction * 48) - const Offset(0, 22);
      _glow(c, p, bolt.boss ? 36 : 28, color, .65);
      c.drawLine(
        tail,
        p,
        Paint()
          ..color = color.withValues(alpha: .45)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round,
      );
      c.drawLine(
        (tail + p) / 2,
        p,
        Paint()
          ..color = color
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      c.drawCircle(p, bolt.radius * .75, Paint()..color = color);
      c.drawCircle(p, 3.2, Paint()..color = const Color(0xfff4eaff));
      _ring(c, p, bolt.radius + 3, color.withValues(alpha: .75), 1);
      if (!reducedEffects) {
        final angle = _time * 8 + bolt.sourceId;
        for (var j = 0; j < 2; j++) {
          final at =
              p +
              Offset(
                    math.cos(angle + j * math.pi),
                    math.sin(angle + j * math.pi),
                  ) *
                  (bolt.radius + 6);
          c.drawCircle(at, 1.7, Paint()..color = color);
        }
      }
    }
  }

  void _atmosphere(Canvas c, Size size, TownView view) {
    c.save();
    c.clipRect(Offset.zero & size);
    _stamp(c, art.lighting.sky, Offset.zero & size, 1);
    if (!reducedEffects) _weather(c, size, _time, view);
    if (model.blackoutFor > 0) {
      final pool = Rect.fromCircle(
        center: view.project(model.player),
        radius: 300 * view.zoom,
      );
      // Draw the dark area outside the cached light pool without saveLayer.
      c.drawPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(Offset.zero & size)
          ..addRect(pool),
        Paint()..color = const Color(0xab07121c),
      );
      _stamp(c, art.lighting.blackout, pool, 1);
    }
    _stamp(
      c,
      art.lighting.vignette,
      Rect.fromCircle(
        center: Offset(size.width * .5, size.height * .48),
        radius: size.longestSide * .69,
      ),
      .6,
    );
    if (model.hurtFor > 0) {
      _stamp(
        c,
        art.lighting.hurtEdge,
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.longestSide * .6,
        ),
        model.hurtFor * .65,
      );
    }
    if (model.lowHealth) {
      final pulse = reducedEffects ? .5 : .5 + .5 * math.sin(_time * 5.4);
      _stamp(
        c,
        art.lighting.redEdge,
        Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: size.longestSide * .6,
        ),
        .28 + .22 * pulse,
      );
    }
    c.restore();
  }

  void _weather(Canvas c, Size size, double t, TownView view) {
    for (var i = 0; i < 64; i++) {
      final x =
          ((i * 163.1 - t * 32 - view.origin.dx * .4) % (size.width + 40)) - 20;
      final y = (i * 93.7 + t * 330 - view.origin.dy * .2) % (size.height + 30);
      c.drawLine(
        Offset(x, y),
        Offset(x - 5, y + 14),
        Paint()
          ..color = const Color(0x326e9caa)
          ..strokeWidth = .7,
      );
    }
    for (var i = 0; i < 3; i++) {
      final center = Offset(
        size.width * (.15 + i * .4) + math.sin(t * .08 + i) * 80,
        size.height * (.32 + i * .21),
      );
      c.save();
      c.translate(center.dx, center.dy);
      c.scale(1, .23);
      _stamp(
        c,
        art.lighting.fog,
        Rect.fromCircle(center: Offset.zero, radius: size.width * .42),
        .14,
      );
      c.restore();
    }
  }

  void _groundShadow(Canvas c, Offset p, double width, double height) {
    final r = Rect.fromCenter(
      center: p + const Offset(10, 12),
      width: width * 2,
      height: height * 2 + 10,
    );
    _stamp(c, art.lighting.shadow, r, .69);
  }

  void _shadow(Canvas c, Offset p, double r) {
    c.save();
    c.transform(TownView.matrix);
    _groundShadow(c, p, r, r * .4);
    c.restore();
  }

  void _groundRing(Canvas c, Offset p, double r, Color color, double stroke) {
    c.save();
    c.transform(TownView.matrix);
    _ring(c, p, r, color, stroke);
    c.restore();
  }

  void _ring(Canvas c, Offset p, double r, Color color, double stroke) =>
      c.drawCircle(
        p,
        r,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
  void _glow(Canvas c, Offset p, double r, Color color, double alpha) => _stamp(
    c,
    color == amber ? art.lighting.amber : art.lighting.cyan,
    Rect.fromCircle(center: p, radius: r),
    alpha,
    tint: color == amber || color == cyan ? null : color,
  );

  void _stamp(
    Canvas c,
    ui.Image image,
    Rect rect,
    double alpha, {
    Color? tint,
  }) {
    c.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()
        ..filterQuality = FilterQuality.low
        ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1))
        ..colorFilter = tint == null
            ? null
            : ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }

  void _label(Canvas c, String text, Offset p, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: color,
          shadows: const [Shadow(color: Colors.black, offset: Offset(0, 1))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, p - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(covariant TownPainter oldDelegate) => true;
}

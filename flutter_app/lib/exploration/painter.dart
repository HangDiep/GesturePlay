import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'model.dart';
import 'world.dart';

class FieldViewport {
  FieldViewport(Offset focus, Size size, {bool overview = false}) {
    zoom = overview
        ? math.min(
            size.width / FieldWorld.width,
            size.height / FieldWorld.height,
          )
        : (size.shortestSide / 610).clamp(.6, 1.15);
    origin = overview
        ? Offset(
            -(size.width / zoom - FieldWorld.width) / 2,
            -(size.height / zoom - FieldWorld.height) / 2,
          )
        : Offset(
            (focus.dx - size.width / zoom / 2).clamp(
              0,
              math.max(0, FieldWorld.width - size.width / zoom),
            ),
            (focus.dy - size.height / zoom / 2).clamp(
              0,
              math.max(0, FieldWorld.height - size.height / zoom),
            ),
          );
  }
  late final double zoom;
  late final Offset origin;
  Offset project(Offset world) => (world - origin) * zoom;
  Offset unproject(Offset screen) => screen / zoom + origin;
}

class ExplorationPainter extends CustomPainter {
  ExplorationPainter(this.model, {this.overview = false, this.reticle = true});
  final ExplorationModel model;
  final bool overview, reticle;
  @override
  void paint(Canvas c, Size size) {
    final view = FieldViewport(model.player, size, overview: overview),
        w = model.world;
    c.save();
    c.clipRect(Offset.zero & size);
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xff13252c));
    c.scale(view.zoom);
    c.translate(-view.origin.dx, -view.origin.dy);
    final bounds = const Rect.fromLTWH(
      0,
      0,
      FieldWorld.width,
      FieldWorld.height,
    );
    c.drawRect(bounds, Paint()..color = w.ground);
    final random = math.Random(917 + w.id.index);
    for (var i = 0; i < 900; i++) {
      final p = Offset(
        random.nextDouble() * FieldWorld.width,
        random.nextDouble() * FieldWorld.height,
      );
      c.drawCircle(
        p,
        1 + random.nextDouble() * 3,
        Paint()
          ..color = Colors.black.withValues(
            alpha: .045 + random.nextDouble() * .04,
          ),
      );
    }
    for (final road in w.roads) {
      final color = switch (w.id) {
        FieldMap.forest => const Color(0xff9b8f6c),
        FieldMap.town => const Color(0xff4a535a),
        FieldMap.harbor => const Color(0xff8b918b),
        FieldMap.factory => const Color(0xff506168),
      };
      c.drawRRect(
        RRect.fromRectAndRadius(road.inflate(8), const Radius.circular(8)),
        Paint()..color = color.withValues(alpha: .3),
      );
      c.drawRect(road, Paint()..color = color);
      if (w.id == FieldMap.town) {
        if (road.height > road.width) {
          for (var y = road.top + 15; y < road.bottom; y += 65) {
            c.drawRect(
              Rect.fromLTWH(road.center.dx - 2, y, 4, 25),
              Paint()..color = const Color(0xffd5c79f),
            );
          }
        } else {
          for (var x = road.left + 15; x < road.right; x += 65) {
            c.drawRect(
              Rect.fromLTWH(x, road.center.dy - 2, 25, 4),
              Paint()..color = const Color(0xffd5c79f),
            );
          }
        }
      }
    }
    for (final hazard in w.hazards) {
      c.drawOval(
        hazard,
        Paint()..color = const Color(0xff91bc4c).withValues(alpha: .35),
      );
      c.drawOval(
        hazard.deflate(7 + math.sin(model.elapsed * 3) * 4),
        Paint()
          ..color = const Color(0xffcbe578).withValues(alpha: .4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      _label(c, 'VÙNG NHIỄM', hazard.center, const Color(0xffe1ec9e), 10);
    }
    final exit = FieldWorld.extraction;
    c.drawCircle(
      exit,
      60,
      Paint()..color = const Color(0xff98d6b5).withValues(alpha: .12),
    );
    c.drawCircle(
      exit,
      50 + math.sin(model.elapsed * 3) * 3,
      Paint()
        ..color = const Color(0xffa9e7c6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.drawLine(
      exit - const Offset(18, 0),
      exit + const Offset(18, 0),
      Paint()
        ..color = const Color(0xffc7f0da)
        ..strokeWidth = 5,
    );
    c.drawLine(
      exit - const Offset(0, 18),
      exit + const Offset(0, 18),
      Paint()
        ..color = const Color(0xffc7f0da)
        ..strokeWidth = 5,
    );
    _label(
      c,
      'ĐIỂM CỨU HỘ',
      exit + const Offset(0, 78),
      const Color(0xffd2eddb),
      12,
    );
    for (final prop in w.props) {
      _prop(c, prop);
    }
    if (w.id == FieldMap.harbor) {
      final crane = Paint()
        ..color = const Color(0xffd9b763)
        ..strokeWidth = 8;
      c.drawLine(const Offset(235, 260), const Offset(1955, 260), crane);
      for (var x = 250.0; x < 1950; x += 90) {
        c.drawLine(Offset(x, 260), Offset(x + 45, 310), crane..strokeWidth = 3);
        c.drawLine(Offset(x + 45, 310), Offset(x + 90, 260), crane);
      }
      c.drawLine(
        const Offset(235, 310),
        const Offset(1955, 310),
        crane..strokeWidth = 5,
      );
    }
    for (final item in model.items.where((i) => !i.taken)) {
      _item(c, item);
    }
    for (final e in model.effects.where(
      (e) => e.kind != 'damage' && e.kind != 'spark' && e.kind != 'muzzle',
    )) {
      _effect(c, e);
    }
    final actors = <({double y, Creature? enemy})>[
      (y: model.player.dy, enemy: null),
      for (final e in model.enemies) (y: e.position.dy, enemy: e),
    ]..sort((a, b) => a.y.compareTo(b.y));
    for (final actor in actors) {
      if (actor.enemy case final e?) {
        _enemy(c, e);
      } else {
        _player(c);
      }
    }
    for (final b in model.bullets) {
      c.drawLine(
        b.position - b.direction * 18,
        b.position,
        Paint()
          ..color = const Color(0xffffe3a2)
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final e in model.effects.where(
      (e) => e.kind == 'damage' || e.kind == 'spark' || e.kind == 'muzzle',
    )) {
      _effect(c, e);
    }
    if (reticle && !overview && !model.finished) {
      final color = model.reloadFor > 0
          ? const Color(0xffd79b70)
          : const Color(0xfff7e8bd);
      c.drawCircle(
        model.aim,
        10,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      for (final d in const [
        Offset(1, 0),
        Offset(-1, 0),
        Offset(0, 1),
        Offset(0, -1),
      ]) {
        c.drawLine(
          model.aim + d * 14,
          model.aim + d * 20,
          Paint()
            ..color = color
            ..strokeWidth = 2,
        );
      }
    }
    c.drawRect(
      const Rect.fromLTWH(55, 55, 2090, 1690),
      Paint()
        ..color = const Color(0xff1b3137).withValues(alpha: .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
    c.restore();
    if (model.flashFor > 0) {
      c.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: model.flashFor * 1.5),
      );
    }
    if (model.hurtFor > 0) {
      c.drawRect(
        (Offset.zero & size).deflate(4),
        Paint()
          ..color = const Color(0xffe16c60).withValues(alpha: model.hurtFor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10,
      );
    }
    if (model.jammed && !overview) {
      for (var i = 0; i < 7; i++) {
        final y = (model.elapsed * 90 + i * 103) % size.height;
        c.drawRect(
          Rect.fromLTWH(0, y, size.width, 3),
          Paint()..color = const Color(0xff9be1e8).withValues(alpha: .14),
        );
      }
    }
  }

  void _prop(Canvas c, FieldProp prop) {
    final r = prop.rect;
    final shadow = r.shift(const Offset(7, 9));
    if (prop.kind != PropKind.water && prop.kind != PropKind.pipe) {
      c.drawRRect(
        RRect.fromRectAndRadius(shadow, const Radius.circular(7)),
        Paint()..color = Colors.black.withValues(alpha: .22),
      );
    }
    switch (prop.kind) {
      case PropKind.tree:
        final p = r.center;
        c.drawCircle(
          p + const Offset(0, 8),
          9,
          Paint()..color = const Color(0xff645341),
        );
        for (var i = 2; i >= 0; i--) {
          c.drawCircle(
            p + Offset((i - 1) * 5, -i * 5),
            r.width * (.5 - i * .07),
            Paint()
              ..color = Color.lerp(
                prop.color,
                const Color(0xff7f9d69),
                i * .16,
              )!,
          );
        }
        c.drawLine(
          p - const Offset(8, 13),
          p + const Offset(4, 6),
          Paint()
            ..color = Colors.white.withValues(alpha: .11)
            ..strokeWidth = 3,
        );
      case PropKind.rock:
        final path = Path()
          ..moveTo(r.left + 12, r.top + r.height * .15)
          ..lineTo(r.right - 18, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.right - 15, r.bottom)
          ..lineTo(r.left + 10, r.bottom - 8)
          ..lineTo(r.left, r.center.dy)
          ..close();
        c.drawPath(path, Paint()..color = prop.color);
        c.drawPath(
          path,
          Paint()
            ..color = Colors.white.withValues(alpha: .16)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
        c.drawLine(
          r.topLeft + const Offset(17, 20),
          r.bottomRight - const Offset(24, 18),
          Paint()
            ..color = Colors.black.withValues(alpha: .2)
            ..strokeWidth = 2,
        );
      case PropKind.house:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(5)),
          Paint()..color = prop.color,
        );
        c.drawRect(
          r.deflate(8),
          Paint()..color = Color.lerp(prop.color, const Color(0xff384c56), .5)!,
        );
        final roof = Path()
          ..moveTo(r.left + 8, r.top + 8)
          ..lineTo(r.right - 8, r.top + 8)
          ..lineTo(r.right - 8, r.bottom - 8)
          ..lineTo(r.center.dx, r.center.dy)
          ..close();
        c.drawPath(roof, Paint()..color = Colors.black.withValues(alpha: .16));
        c.drawLine(
          Offset(r.left + 8, r.center.dy),
          Offset(r.right - 8, r.center.dy),
          Paint()
            ..color = prop.color
            ..strokeWidth = 5,
        );
        c.drawRect(
          Rect.fromLTWH(r.left + 25, r.top + 20, 30, 18),
          Paint()..color = const Color(0xffa5bec1),
        );
        c.drawRect(
          Rect.fromLTWH(r.right - 45, r.bottom - 25, 25, 25),
          Paint()..color = const Color(0xffaa8f68),
        );
      case PropKind.container:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = prop.color,
        );
        for (var x = r.left + 12; x < r.right - 7; x += 16) {
          c.drawLine(
            Offset(x, r.top + 8),
            Offset(x, r.bottom - 8),
            Paint()
              ..color = Colors.black.withValues(alpha: .14)
              ..strokeWidth = 3,
          );
        }
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(6), const Radius.circular(2)),
          Paint()
            ..color = Colors.white.withValues(alpha: .2)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _label(
          c,
          'GP / CARGO',
          r.center,
          Colors.white.withValues(alpha: .6),
          12,
        );
      case PropKind.tank:
        c.drawOval(r, Paint()..color = prop.color);
        c.drawOval(r.deflate(12), Paint()..color = const Color(0xffb6c8c4));
        c.drawOval(
          r.deflate(25),
          Paint()
            ..color = prop.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        c.drawCircle(r.center, 20, Paint()..color = const Color(0xff5f7375));
        c.drawLine(
          r.center,
          r.centerRight - const Offset(12, 0),
          Paint()
            ..color = const Color(0xffd6c489)
            ..strokeWidth = 9,
        );
      case PropKind.machine:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(5)),
          Paint()..color = prop.color,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(7), const Radius.circular(3)),
          Paint()..color = Colors.black.withValues(alpha: .18),
        );
        for (var x = r.left + 14; x < r.right - 10; x += 13) {
          c.drawLine(
            Offset(x, r.top + 12),
            Offset(x, r.bottom - 13),
            Paint()
              ..color = Colors.white.withValues(alpha: .15)
              ..strokeWidth = 3,
          );
        }
        c.drawCircle(
          r.topRight + const Offset(-12, 12),
          3,
          Paint()..color = const Color(0xffbbd990),
        );
      case PropKind.pipe:
        c.drawRRect(
          RRect.fromRectAndRadius(
            r.shift(const Offset(0, 7)),
            const Radius.circular(14),
          ),
          Paint()..color = Colors.black.withValues(alpha: .2),
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(14)),
          Paint()..color = prop.color,
        );
        for (var x = r.left + 30; x < r.right; x += 120) {
          c.drawLine(
            Offset(x, r.top - 4),
            Offset(x, r.bottom + 4),
            Paint()
              ..color = const Color(0xff58676a)
              ..strokeWidth = 6,
          );
        }
      case PropKind.water:
        c.drawRect(r, Paint()..color = prop.color);
        c.save();
        c.clipRect(r);
        for (var x = r.left - 40; x < r.right; x += 50) {
          final y = r.center.dy + math.sin(x * .03 + model.elapsed) * 18;
          c.drawLine(
            Offset(x, y),
            Offset(x + 25, y),
            Paint()
              ..color = const Color(0xffa4d0d2).withValues(alpha: .3)
              ..strokeWidth = 3,
          );
        }
        c.restore();
        c.drawRect(
          Rect.fromLTWH(r.left, r.bottom - 6, r.width, 6),
          Paint()..color = const Color(0xffb6aa88),
        );
    }
  }

  void _player(Canvas c) {
    final p = model.player;
    final stride = model.movement.distance > .1
        ? math.sin(model.walkTime) * 5
        : 0.0;
    c.drawOval(
      Rect.fromCenter(center: p + const Offset(2, 8), width: 40, height: 26),
      Paint()..color = Colors.black.withValues(alpha: .3),
    );
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(model.facing);
    if (model.rollFor > 0) c.rotate(model.elapsed * 25);
    for (final side in [-1, 1]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-7 + stride * side, side * 10),
            width: 18,
            height: 10,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xff233541),
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-13, -16, 29, 32),
        const Radius.circular(9),
      ),
      Paint()
        ..color = model.hurtFor > 0
            ? const Color(0xffe3a390)
            : const Color(0xff51798b),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -11, 13, 22),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xff91a782),
    );
    c.drawCircle(
      const Offset(5, 0),
      11,
      Paint()..color = const Color(0xffd2b18a),
    );
    c.drawArc(
      Rect.fromCircle(center: const Offset(3, 0), radius: 12),
      math.pi / 2,
      math.pi,
      true,
      Paint()..color = const Color(0xff2e4a60),
    );
    c.drawLine(
      const Offset(12, 10),
      const Offset(34, 10),
      Paint()
        ..color = const Color(0xff24313c)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      const Offset(29, 10),
      const Offset(37, 10),
      Paint()
        ..color = const Color(0xffc6ae75)
        ..strokeWidth = 4,
    );
    c.restore();
    c.drawCircle(
      p,
      model.rollFor > 0 ? 25 : 23,
      Paint()
        ..color = const Color(0xff9fd9c5).withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _enemy(Canvas c, Creature e) {
    final p = e.position, r = e.radius;
    final dead = !e.alive;
    final alpha = dead ? (e.death / .85).clamp(0.0, 1.0) : 1.0;
    var color = [
      const Color(0xffaa6a60),
      const Color(0xff9a8163),
      const Color(0xff72a5b1),
      const Color(0xff6f7794),
    ][e.kind.index];
    if (e.hit > 0) color = Color.lerp(color, const Color(0xffffd3ad), .75)!;
    if (e.stun > 0) color = const Color(0xff8bd2df);
    c.saveLayer(
      Rect.fromCircle(center: p, radius: 130),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    c.drawOval(
      Rect.fromCenter(
        center: p + const Offset(3, 7),
        width: r * 2.3,
        height: r * 1.6,
      ),
      Paint()..color = Colors.black.withValues(alpha: .28),
    );
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(e.facing + (dead ? (1 - alpha) * 2 : 0));
    if (dead) c.scale(.6 + .4 * alpha);
    final gait = e.stun > 0 || e.charge > 0 || e.weak > 0
        ? 0
        : math.sin(e.animation * (e.kind == CreatureKind.runner ? 13 : 7)) * 4;
    for (final side in [-1, 1]) {
      c.drawLine(
        Offset(-r * .5, side * r * .6),
        Offset(-r + gait * side, side * r),
        Paint()
          ..color = color.withValues(alpha: .75)
          ..strokeWidth = r * .5
          ..strokeCap = StrokeCap.round,
      );
      c.drawLine(
        Offset(r * .3, side * r * .7),
        Offset(r * 1.1 + gait * side, side * r),
        Paint()
          ..color = color
          ..strokeWidth = r * .4
          ..strokeCap = StrokeCap.round,
      );
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.9, height: r * 1.7),
        Radius.circular(r * .45),
      ),
      Paint()..color = color,
    );
    c.drawCircle(
      Offset(r * .4, 0),
      r * .55,
      Paint()..color = Color.lerp(color, const Color(0xffd5bda4), .35)!,
    );
    if (e.kind == CreatureKind.heavy || e.kind == CreatureKind.boss) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-r * .2, 0),
            width: r * .8,
            height: r * 1.65,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xff46515f),
      );
    }
    if (e.kind == CreatureKind.boss) {
      c.drawCircle(
        Offset(r * .2, 0),
        r * .32,
        Paint()
          ..color = e.weak > 0
              ? const Color(0xffffdb7f)
              : const Color(0xff9ba7b9),
      );
    }
    if (e.kind == CreatureKind.jammer && e.stun <= 0 && e.alive) {
      final pulse = (e.animation * .7) % 1;
      c.drawCircle(
        Offset.zero,
        r + pulse * 25,
        Paint()
          ..color = const Color(0xff90d1df).withValues(alpha: (1 - pulse) * .5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    c.restore();
    if (e.charge > 0 || e.weak > 0) {
      c.drawCircle(
        p,
        e.charge > 0 ? 130 : r + 8,
        Paint()
          ..color =
              (e.charge > 0 ? const Color(0xffe48170) : const Color(0xffffdb7f))
                  .withValues(
                    alpha: .15 + .13 * math.sin(e.animation * 12).abs(),
                  ),
      );
      c.drawCircle(
        p,
        e.charge > 0 ? 130 : r + 8,
        Paint()
          ..color = e.charge > 0
              ? const Color(0xffe48170)
              : const Color(0xffffdb7f)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (e.stun > 0) {
      _label(c, 'ϟ CHOÁNG', p - Offset(0, r + 22), const Color(0xffb9ebf0), 10);
    }
    if (e.alive) {
      final bar = Rect.fromLTWH(p.dx - 27, p.dy - r - 12, 54, 4);
      c.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = const Color(0xff192b32),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            bar.left,
            bar.top,
            bar.width * e.health / e.maxHealth,
            4,
          ),
          const Radius.circular(2),
        ),
        Paint()
          ..color = e.weak > 0
              ? const Color(0xffffdb7f)
              : const Color(0xffe4917d),
      );
      if (e.kind == CreatureKind.boss) {
        _label(
          c,
          e.charge > 0
              ? 'NẠP ĐÒN'
              : e.weak > 0
              ? 'ĐIỂM YẾU'
              : 'VẬT CHỦ · GIÁP',
          p - Offset(0, r + 27),
          const Color(0xfff8dda3),
          10,
        );
      }
    }
    c.restore();
  }

  void _item(Canvas c, FieldItem item) {
    final p =
        item.position +
        Offset(0, math.sin(model.elapsed * 3 + item.position.dx) * 4);
    final color = item.kind == 'core'
        ? const Color(0xffffd688)
        : item.kind == 'health'
        ? const Color(0xffa8dfb6)
        : const Color(0xffa8cfe0);
    c.drawCircle(p, 23, Paint()..color = color.withValues(alpha: .12));
    if (item.kind == 'core') {
      final path = Path()
        ..moveTo(p.dx, p.dy - 13)
        ..lineTo(p.dx + 10, p.dy)
        ..lineTo(p.dx, p.dy + 13)
        ..lineTo(p.dx - 10, p.dy)
        ..close();
      c.drawPath(path, Paint()..color = color);
      c.drawLine(
        p - const Offset(0, 9),
        p + const Offset(0, 9),
        Paint()
          ..color = const Color(0xfff6efd7)
          ..strokeWidth = 2,
      );
    } else {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 24, height: 20),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xff243b43),
      );
      _label(
        c,
        item.kind == 'health' ? '+' : 'III',
        p - const Offset(0, 8),
        color,
        15,
      );
    }
  }

  void _effect(Canvas c, FieldEffect e) {
    final t = (1 - e.life / e.maxLife).clamp(0.0, 1.0);
    switch (e.kind) {
      case 'trap':
        c.drawCircle(
          e.position,
          65,
          Paint()..color = const Color(0xff7cced8).withValues(alpha: .1),
        );
        c.drawCircle(
          e.position,
          55 + math.sin(model.elapsed * 5) * 5,
          Paint()
            ..color = const Color(0xff9ae0e6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _label(
          c,
          'BẪY',
          e.position - const Offset(0, 6),
          const Color(0xffb8e5e7),
          10,
        );
      case 'flash':
      case 'slam':
        c.drawCircle(
          e.position,
          (e.kind == 'flash' ? 250 : 130) * t,
          Paint()
            ..color =
                (e.kind == 'flash'
                        ? const Color(0xffcce9e5)
                        : const Color(0xffe69776))
                    .withValues(alpha: (1 - t) * .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - t),
        );
      case 'damage':
        _label(
          c,
          e.text,
          e.position,
          const Color(0xffffe3ab).withValues(alpha: 1 - t),
          13,
        );
      case 'muzzle':
      case 'spark':
        for (var i = 0; i < 6; i++) {
          final d = Offset(
            math.cos(i * math.pi / 3),
            math.sin(i * math.pi / 3),
          );
          c.drawLine(
            e.position + d * (3 + t * 9),
            e.position + d * (8 + t * 14),
            Paint()
              ..color = const Color(0xffffd79d).withValues(alpha: 1 - t)
              ..strokeWidth = 2,
          );
        }
    }
  }

  void _label(Canvas c, String text, Offset p, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w600,
          shadows: const [Shadow(blurRadius: 3, color: Color(0xcc10252a))],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, p - Offset(painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant ExplorationPainter oldDelegate) => true;
}

class FieldMinimap extends CustomPainter {
  FieldMinimap(this.model);
  final ExplorationModel model;
  @override
  void paint(Canvas c, Size size) {
    final sx = size.width / FieldWorld.width,
        sy = size.height / FieldWorld.height;
    Offset p(Offset at) => Offset(at.dx * sx, at.dy * sy);
    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = const Color(0xe614282f),
    );
    c.save();
    c.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
    );
    for (final prop in model.world.props) {
      c.drawRect(
        Rect.fromLTRB(
          prop.rect.left * sx,
          prop.rect.top * sy,
          prop.rect.right * sx,
          prop.rect.bottom * sy,
        ),
        Paint()..color = prop.color.withValues(alpha: .45),
      );
    }
    for (final item in model.items.where((i) => i.kind == 'core' && !i.taken)) {
      c.drawCircle(
        p(item.position),
        3,
        Paint()..color = const Color(0xffffdc8d),
      );
    }
    if (!model.jammed) {
      for (final e in model.enemies.where(
        (e) => e.alive && (e.position - model.player).distance < 450,
      )) {
        c.drawCircle(
          p(e.position),
          e.kind == CreatureKind.boss ? 4 : 2.5,
          Paint()..color = const Color(0xffef9c86),
        );
      }
    }
    c.drawCircle(
      p(FieldWorld.extraction),
      4,
      Paint()
        ..color = const Color(0xff9de1bb)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final player = p(model.player),
        direction = Offset(math.cos(model.facing), math.sin(model.facing));
    c.drawLine(
      player,
      player + direction * 10,
      Paint()
        ..color = const Color(0xffe7f6ef)
        ..strokeWidth = 2,
    );
    c.drawCircle(player, 3.5, Paint()..color = const Color(0xffe7f6ef));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant FieldMinimap oldDelegate) => true;
}

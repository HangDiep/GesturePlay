part of 'scene.dart';

class EnemyIllustrator {
  static void paint(Canvas c, Size size, Intruder e) {
    final p = Offset(e.aimPoint.dx * size.width, e.aimPoint.dy * size.height);
    final scale = (size.height / 350).clamp(.55, 1.25);
    final s =
        (22 + e.progress * 33) *
        scale *
        (e.kind == EnemyKind.boss
            ? 1.5
            : e.kind == EnemyKind.breaker
            ? 1.18
            : 1);
    final dead = !e.alive;
    final death = (e.deathFor / SignalRules.deathDuration).clamp(0.0, 1.0);
    final moving =
        e.alive &&
        e.stunnedFor <= 0 &&
        !e.charging &&
        !e.exposed &&
        e.state != EnemyState.attacking;
    final gait = moving
        ? math.sin(e.animationTime * (e.kind == EnemyKind.runner ? 12 : 6))
        : 0.0;
    c.drawOval(
      Rect.fromCenter(
        center: p + Offset(0, s * .65),
        width: s * 1.8,
        height: s * .25,
      ),
      Paint()..color = Colors.black.withValues(alpha: dead ? death * .5 : .5),
    );
    if (dead) {
      c.saveLayer(
        Rect.fromCenter(center: p, width: s * 5, height: s * 5),
        Paint()..color = Colors.white.withValues(alpha: death),
      );
    }
    c.save();
    final recoil = e.hitFor > 0 ? math.sin(e.hitFor * 90) * e.hitFor * 7 : 0.0;
    c.translate(
      p.dx + recoil,
      p.dy + gait.abs() * s * .035 + (dead ? (1 - death) * s * .4 : 0),
    );
    if (dead) {
      c.rotate((1 - death) * .8);
      c.scale(.7 + .3 * death, .35 + .65 * death);
    }
    _body(c, e, s, gait);
    c.restore();
    if (dead) {
      c.restore();
      _sparks(
        c,
        p,
        1 - death,
        s * 1.7,
        e.id,
        e.kind == EnemyKind.boss ? signalAmber : signalGreen,
      );
      _label(
        c,
        'TIÊU DIỆT',
        p - Offset(0, s * (1.1 + (1 - death) * .4)),
        signalGreen.withValues(alpha: death),
        11,
      );
      return;
    }
    final statusColor = e.stunnedFor > 0
        ? const Color(0xff80deee)
        : e.charging
        ? signalRed
        : e.exposed
        ? signalAmber
        : signalMuted;
    final bar = Rect.fromLTWH(p.dx - s * .7, p.dy - s * 1.3, s * 1.4, 5);
    _label(
      c,
      e.kind.label.toUpperCase(),
      Offset(p.dx, bar.top - 18),
      e.kind == EnemyKind.boss ? signalAmber : signalText,
      9,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(bar, const Radius.circular(2)),
      Paint()..color = signalBg,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bar.left,
          bar.top,
          bar.width * (e.health / e.maxHealth).clamp(0, 1),
          bar.height,
        ),
        const Radius.circular(2),
      ),
      Paint()
        ..color = e.exposed
            ? signalAmber
            : e.stunnedFor > 0
            ? signalGreen
            : signalRed,
    );
    _label(
      c,
      '${e.health.ceil()}/${e.maxHealth.ceil()} · ${e.status}',
      Offset(p.dx, bar.bottom + 3),
      statusColor,
      8,
    );
    if (e.hitFor > 0) {
      final t = 1 - e.hitFor / .4;
      final color = e.lastHitArmored
          ? const Color(0xffa6d1ea)
          : e.lastHitWeak
          ? signalAmber
          : Colors.white;
      _sparks(c, p, t, s * .75, e.id, color);
      _label(
        c,
        '−${e.lastDamage.toInt()}${e.lastHitArmored
            ? ' GIÁP'
            : e.lastHitWeak
            ? ' ĐIỂM YẾU'
            : ''}',
        p + Offset(s * .8 + t * 12, -s * .55 - t * 12),
        color.withValues(alpha: 1 - t),
        e.lastHitWeak ? 14 : 12,
      );
    }
    if (e.charging) {
      final t = 1 - e.windupFor / SignalRules.bossWindup;
      c.drawArc(
        Rect.fromCircle(center: p, radius: s * .9),
        -math.pi / 2,
        math.pi * 2 * t,
        false,
        Paint()
          ..color = signalRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      c.drawLine(
        p + Offset(-s, s * .8),
        p + Offset(s, s * .8),
        Paint()
          ..color = signalRed.withValues(alpha: .4 + .5 * t)
          ..strokeWidth = 3,
      );
    }
  }

  static void _body(Canvas c, Intruder e, double s, double gait) {
    final stunned = e.stunnedFor > 0;
    final exposed = e.exposed || (!e.alive && e.lastHitWeak);
    final base = switch (e.kind) {
      EnemyKind.runner => const Color(0xff28323b),
      EnemyKind.breaker => const Color(0xff493c32),
      EnemyKind.jammer => const Color(0xff193a48),
      EnemyKind.boss => const Color(0xff252938),
    };
    final accent = stunned
        ? const Color(0xff80deee)
        : e.charging
        ? signalRed
        : exposed
        ? signalAmber
        : switch (e.kind) {
            EnemyKind.runner => signalRed,
            EnemyKind.breaker => const Color(0xffb89468),
            EnemyKind.jammer => const Color(0xff72bfcf),
            EnemyKind.boss => const Color(0xff9bacc8),
          };
    final flash = (e.hitFor / .4).clamp(0.0, 1.0) * .75;
    final body = Paint()
      ..color = Color.lerp(
        base,
        e.lastHitArmored ? const Color(0xffceeaff) : const Color(0xffffd0bd),
        flash,
      )!;
    final outline = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Jointed limbs move with simulation time, so pause freezes animation too.
    for (final side in [-1, 1]) {
      final stride = gait * side * s * .1;
      final leg = Path()
        ..moveTo(side * s * .15, s * .12)
        ..lineTo(side * s * .31 + stride, s * .4)
        ..lineTo(side * s * .4 - stride, s * .7);
      c.drawPath(
        leg,
        Paint()
          ..color = base
          ..strokeWidth = s * (e.kind == EnemyKind.breaker ? .28 : .18)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(leg, outline);
      final arm = Path()
        ..moveTo(side * s * .36, -s * .27)
        ..lineTo(side * s * .65, -s * .04 + stride)
        ..lineTo(side * s * .75, s * .36 + stride);
      c.drawPath(
        arm,
        Paint()
          ..color = body.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * (e.kind == EnemyKind.breaker ? .3 : .13)
          ..strokeCap = StrokeCap.round,
      );
      c.drawPath(arm, outline);
      for (var claw = 0; claw < 3; claw++) {
        c.drawLine(
          Offset(side * s * .75 + claw * 2, s * .31 + stride),
          Offset(side * s * .82 + claw * 3, s * .47 + stride),
          outline,
        );
      }
    }
    final torso = Path()
      ..moveTo(-s * .36, -s * .46)
      ..lineTo(s * .36, -s * .46)
      ..lineTo(s * .44, s * .02)
      ..lineTo(s * .2, s * .29)
      ..lineTo(-s * .2, s * .29)
      ..lineTo(-s * .44, s * .02)
      ..close();
    c.drawPath(torso, body);
    c.drawPath(torso, outline);
    final head = Rect.fromCenter(
      center: Offset(0, -s * .68),
      width: s * .52,
      height: s * .61,
    );
    c.drawOval(head, body);
    c.drawOval(head, outline);
    for (final side in [-1, 1]) {
      final eye = Offset(side * s * .12, -s * .7);
      c.drawCircle(
        eye,
        3.5,
        Paint()
          ..color = accent.withValues(alpha: .4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      c.drawCircle(eye, 2, Paint()..color = accent);
    }
    if (e.kind == EnemyKind.runner) {
      for (var i = 0; i < 3; i++) {
        c.drawLine(
          Offset(-s * .23, -s * .23 + i * s * .12),
          Offset(s * .23, -s * .16 + i * s * .12),
          outline..color = accent.withValues(alpha: .5),
        );
      }
    } else if (e.kind == EnemyKind.breaker) {
      for (final side in [-1, 1]) {
        final plate = Rect.fromCenter(
          center: Offset(side * s * .41, -s * .31),
          width: s * .4,
          height: s * .4,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(plate, Radius.circular(s * .06)),
          Paint()..color = Color.lerp(body.color, Colors.black, .2)!,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(plate, Radius.circular(s * .06)),
          outline,
        );
        for (var i = 0; i < 3; i++) {
          c.drawCircle(
            Offset(plate.center.dx, plate.top + s * .08 + i * s * .1),
            1.5,
            Paint()..color = accent,
          );
        }
      }
    } else if (e.kind == EnemyKind.jammer) {
      final tip = Offset(s * .15, -s * 1.23);
      c.drawLine(Offset(0, -s * .9), tip, outline);
      c.drawCircle(tip, 3, Paint()..color = accent);
      if (!stunned && e.alive) {
        for (var i = 0; i < 2; i++) {
          final t = (e.animationTime * .9 + i * .5) % 1;
          c.drawArc(
            Rect.fromCircle(center: tip, radius: 6 + t * s * .35),
            math.pi * 1.1,
            math.pi * .8,
            false,
            Paint()
              ..color = accent.withValues(alpha: (1 - t) * .6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
      }
      c.drawCircle(
        Offset(0, -s * .12),
        s * .13,
        Paint()..color = accent.withValues(alpha: .4),
      );
    } else {
      for (final side in [-1, 1]) {
        final horn = Path()
          ..moveTo(side * s * .18, -s * .85)
          ..lineTo(side * s * .37, -s * 1.15)
          ..lineTo(side * s * .34, -s * .7)
          ..close();
        c.drawPath(horn, body);
        c.drawPath(horn, outline);
        final armor = Path()
          ..moveTo(side * s * .2, -s * .47)
          ..lineTo(side * s * .62, -s * .53)
          ..lineTo(side * s * .56, -s * .15)
          ..lineTo(side * s * .3, -s * .1)
          ..close();
        c.drawPath(armor, body);
        c.drawPath(armor, outline);
      }
      final core = Offset(0, -s * .1);
      if (exposed) {
        final pulse = .8 + .2 * math.sin(e.animationTime * 12);
        c.drawCircle(
          core,
          s * .26,
          Paint()
            ..color = signalAmber.withValues(alpha: .4 * pulse)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
        c.drawCircle(core, s * .15, Paint()..color = signalAmber);
        c.drawCircle(
          core,
          s * .24,
          outline
            ..color = signalAmber
            ..strokeWidth = 2,
        );
      } else {
        final shield = Path()
          ..moveTo(0, -s * .38)
          ..lineTo(s * .25, -s * .24)
          ..lineTo(s * .18, s * .1)
          ..lineTo(0, s * .24)
          ..lineTo(-s * .18, s * .1)
          ..lineTo(-s * .25, -s * .24)
          ..close();
        c.drawPath(shield, Paint()..color = const Color(0xff4a5367));
        c.drawPath(shield, outline);
        c.drawLine(Offset(0, -s * .26), Offset(0, s * .08), outline);
      }
    }
    if (stunned) {
      for (var i = 0; i < 3; i++) {
        final a = e.animationTime * 3 + i * math.pi * 2 / 3;
        final p = Offset(
          math.cos(a) * s * .5,
          -s * 1.05 + math.sin(a) * s * .12,
        );
        final bolt = Path()
          ..moveTo(p.dx + 3, p.dy - 6)
          ..lineTo(p.dx - 3, p.dy)
          ..lineTo(p.dx + 2, p.dy)
          ..lineTo(p.dx - 2, p.dy + 6);
        c.drawPath(bolt, outline..color = const Color(0xff80deee));
      }
    }
  }

  static void _sparks(
    Canvas c,
    Offset p,
    double t,
    double spread,
    int seed,
    Color color,
  ) {
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi * 2 / 10 + seed * .53;
      final radius = (.15 + .85 * t) * spread * (.6 + (i % 3) * .2);
      final tip =
          p +
          Offset(
            math.cos(a) * radius,
            math.sin(a) * radius + t * t * spread * .4,
          );
      c.drawLine(
        tip,
        tip - Offset(math.cos(a), math.sin(a)) * (3 + 5 * (1 - t)),
        Paint()
          ..color = color.withValues(alpha: (1 - t).clamp(0, 1))
          ..strokeWidth = 1.5,
      );
    }
  }

  static void _label(
    Canvas c,
    String text,
    Offset at,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          at.dx - painter.width / 2 - 3,
          at.dy - 1,
          painter.width + 6,
          painter.height + 2,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = signalBg.withValues(alpha: .75),
    );
    painter.paint(c, Offset(at.dx - painter.width / 2, at.dy));
  }
}

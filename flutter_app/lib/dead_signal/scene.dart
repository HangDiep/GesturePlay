import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'model.dart';

part 'enemy_painter.dart';

const signalBg = Color(0xff0a1015), signalPanel = Color(0xff111c24);
const signalLine = Color(0xff293945), signalText = Color(0xffe5edf0);
const signalMuted = Color(0xff8b9ca6), signalGreen = Color(0xff9fe0b2);
const signalAmber = Color(0xffefbb6c), signalRed = Color(0xffed7a72);

class SecurityScene extends CustomPainter {
  SecurityScene({this.model, this.aim, this.preview = false});
  final SignalModel? model;
  final Offset? aim;
  final bool preview;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final w = size.width, h = size.height;
    final camera = model?.camera ?? 0;
    final online = preview || (model?.cameraOnline ?? true);
    final jam = !preview && (model?.jammed ?? false);
    final bg = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(bg, Paint()..color = const Color(0xff070c11));
    if (!online || jam) {
      final rand = math.Random(((model?.elapsed ?? 0) * 24).floor() + camera);
      for (var i = 0; i < (jam ? 180 : 18); i++) {
        final y = rand.nextDouble() * h;
        canvas.drawRect(
          Rect.fromLTWH(0, y, w, 1 + rand.nextDouble() * 3),
          Paint()..color = signalMuted.withValues(alpha: jam ? .08 : .02),
        );
      }
      if (jam) {
        final y = ((model?.elapsed ?? 0) * 95) % h;
        canvas.drawRect(
          Rect.fromLTWH(0, y, w, 12),
          Paint()..color = signalRed.withValues(alpha: .12),
        );
      }
      canvas.restore();
      return;
    }
    final vx =
            w *
            (camera == 1
                ? .57
                : camera == 2
                ? .43
                : .5),
        vy = h * .32;
    final farLeft = Offset(vx - w * .105, h * .21),
        farRight = Offset(vx + w * .105, h * .21);
    final floor = Path()
      ..moveTo(0, h)
      ..lineTo(w, h)
      ..lineTo(farRight.dx, h * .51)
      ..lineTo(farLeft.dx, h * .51)
      ..close();
    canvas.drawPath(
      floor,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xff24343a), Color(0xff080f14)],
        ).createShader(bg),
    );
    final left = Path()
      ..moveTo(0, 0)
      ..lineTo(farLeft.dx, farLeft.dy)
      ..lineTo(farLeft.dx, h * .51)
      ..lineTo(0, h)
      ..close();
    final right = Path()
      ..moveTo(w, 0)
      ..lineTo(farRight.dx, farRight.dy)
      ..lineTo(farRight.dx, h * .51)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(
      left,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff1b2c34), Color(0xff101b22)],
        ).createShader(bg),
    );
    canvas.drawPath(
      right,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff101b22), Color(0xff20343a)],
        ).createShader(bg),
    );
    final line = Paint()
      ..color = const Color(0xff3a4d53)
      ..strokeWidth = 1;
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(
        Offset(vx, vy),
        Offset(w * .5 + i * w * .33, h),
        line..color = const Color(0xff304047),
      );
    }
    for (var i = 0; i < 8; i++) {
      final depth = math.pow(i / 8, 1.9).toDouble();
      final y = h * .51 + h * .49 * depth;
      canvas.drawLine(
        Offset(0, y),
        Offset(w, y),
        line..color = const Color(0xff293c42),
      );
    }
    for (var i = 0; i < 5; i++) {
      final t = math.pow(i / 5, 1.3).toDouble();
      final lx = farLeft.dx * (1 - t), rx = farRight.dx + (w - farRight.dx) * t;
      final top = h * .21 * (1 - t), bottom = h * .51 + h * .49 * t;
      canvas.drawLine(
        Offset(lx, top),
        Offset(lx, bottom),
        line
          ..color = const Color(0xff3b5059)
          ..strokeWidth = 2 + 5 * t,
      );
      canvas.drawLine(Offset(rx, top), Offset(rx, bottom), line);
      canvas.drawLine(Offset(lx, top), Offset(rx, top), line);
      final lightRect = Rect.fromCenter(
        center: Offset(vx, top + 12),
        width: w * (.035 + t * .085),
        height: 3 + t * 3,
      );
      canvas.drawRect(
        lightRect.inflate(8),
        Paint()
          ..color = signalGreen.withValues(alpha: .07)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawRect(
        lightRect,
        Paint()..color = signalGreen.withValues(alpha: .7),
      );
      if (i > 1) {
        canvas.drawRect(
          Rect.fromLTWH(
            lx + 10,
            top + (bottom - top) * .4,
            5 + t * 12,
            10 + t * 24,
          ),
          Paint()..color = signalAmber.withValues(alpha: .5),
        );
      }
    }
    final endDoor = Rect.fromLTRB(
      farLeft.dx + 5,
      h * .26,
      farRight.dx - 5,
      h * .52,
    );
    canvas.drawRect(endDoor, Paint()..color = const Color(0xff03090c));
    canvas.drawRect(
      endDoor,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xff45616b)
        ..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(vx, endDoor.top),
      Offset(vx, endDoor.bottom),
      line
        ..color = const Color(0xff53625b)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(
      Offset(vx + 6, endDoor.center.dy),
      2,
      Paint()..color = signalRed,
    );
    // Physical cabling and utility cabinets give each camera a distinct space.
    final pipes = Paint()
      ..color = const Color(0xff344d50)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(w * .03, h * .16),
      Offset(farLeft.dx, h * .34),
      pipes,
    );
    canvas.drawLine(
      Offset(w * .97, h * .18),
      Offset(farRight.dx, h * .35),
      pipes,
    );
    final cabinet = Rect.fromLTWH(
      camera == 2 ? w * .1 : w * .82,
      h * .28,
      w * .07,
      h * .27,
    );
    canvas.drawRect(cabinet, Paint()..color = const Color(0xff203038));
    canvas.drawRect(
      cabinet,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = signalLine,
    );
    for (var i = 0; i < 5; i++) {
      canvas.drawLine(
        Offset(cabinet.left + 7, cabinet.top + 12 + i * 6),
        Offset(cabinet.right - 7, cabinet.top + 12 + i * 6),
        line..color = signalMuted.withValues(alpha: .3),
      );
    }
    if (model != null && !preview) {
      final sorted = model!.renderedEnemies.toList()
        ..sort((a, b) => a.progress.compareTo(b.progress));
      for (final e in sorted) {
        EnemyIllustrator.paint(canvas, size, e);
      }
      if (model!.barrierFor > 0 && model!.barrierZone == camera) {
        final r = Rect.fromLTWH(w * .24, h * .34, w * .52, h * .48);
        canvas.drawRect(r, Paint()..color = const Color(0xdd253039));
        for (var y = r.top; y < r.bottom; y += 13) {
          canvas.drawLine(
            Offset(r.left, y),
            Offset(r.right, y),
            line..color = signalAmber.withValues(alpha: .5),
          );
        }
      }
      if (model!.shotFor > 0) {
        final p = Offset(model!.lastShot.dx * w, model!.lastShot.dy * h);
        canvas.drawLine(
          Offset(w * .5, h),
          p,
          Paint()
            ..color = signalAmber
            ..strokeWidth = 2,
        );
        canvas.drawCircle(
          p,
          13 * model!.shotFor / .18,
          Paint()
            ..color =
                (model!.lastShotHit
                        ? model!.lastShotArmored
                              ? const Color(0xffa6d1ea)
                              : signalAmber
                        : signalMuted)
                    .withValues(alpha: .65),
        );
      }
      if (model!.flashFor > 0 && model!.selectedZone == camera) {
        canvas.drawRect(
          bg,
          Paint()..color = Colors.white.withValues(alpha: model!.flashFor),
        );
      }
      if (model!.impactFor > 0 && model!.impactZone == camera) {
        canvas.drawRect(
          bg.deflate(3),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = signalRed.withValues(
              alpha: model!.impactFor.clamp(0, .5),
            ),
        );
      }
    }
    canvas.drawRect(
      bg,
      Paint()
        ..shader = RadialGradient(
          radius: .85,
          colors: [Colors.transparent, Colors.black.withValues(alpha: .7)],
        ).createShader(bg),
    );
    final scan = Paint()..color = Colors.black.withValues(alpha: .11);
    for (double y = 0; y < h; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(w, y), scan);
    }
    // Frame corners are part of the simulated CCTV overlay.
    final frame = Paint()
      ..color = signalGreen.withValues(alpha: .45)
      ..strokeWidth = 1.5;
    for (final p in [
      const Offset(18, 18),
      Offset(w - 18, 18),
      Offset(18, h - 18),
      Offset(w - 18, h - 18),
    ]) {
      canvas.drawLine(p, p + Offset(p.dx > w / 2 ? -18 : 18, 0), frame);
      canvas.drawLine(p, p + Offset(0, p.dy > h / 2 ? -18 : 18), frame);
    }
    if (aim != null && model?.gunMode == true) {
      final p = Offset(aim!.dx * w, aim!.dy * h);
      final cross = Paint()
        ..color = signalAmber
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(p, 13, cross);
      canvas.drawLine(p - const Offset(22, 0), p + const Offset(22, 0), cross);
      canvas.drawLine(p - const Offset(0, 22), p + const Offset(0, 22), cross);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SecurityScene oldDelegate) => true;
}

class FacilityMap extends CustomPainter {
  FacilityMap(this.model);
  final SignalModel model;
  static const zones = [Offset(.5, .24), Offset(.2, .54), Offset(.8, .54)];
  @override
  void paint(Canvas c, Size size) {
    Offset point(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    final line = Paint()
      ..color = signalLine
      ..strokeWidth = 12;
    final room = point(const Offset(.5, .84));
    for (final p in zones.skip(1)) {
      c.drawLine(point(zones[0]), point(p), line);
      c.drawLine(point(p), room, line);
    }
    for (var i = 0; i < 3; i++) {
      final p = point(zones[i]);
      final color = model.sensor(i)
          ? signalRed
          : i == model.selectedZone
          ? signalGreen
          : signalMuted;
      c.drawCircle(p, 17, Paint()..color = signalPanel);
      c.drawCircle(
        p,
        17,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = color
          ..strokeWidth = i == model.selectedZone ? 2 : 1,
      );
      final text = TextPainter(
        text: TextSpan(
          text: '0${i + 1}',
          style: TextStyle(
            fontFamily: 'Segoe UI',
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(c, p - Offset(text.width / 2, text.height / 2));
      if (model.sensor(i)) {
        c.drawCircle(p + const Offset(13, -14), 3, Paint()..color = signalRed);
      }
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: room, width: 74, height: 28),
        const Radius.circular(3),
      ),
      Paint()..color = signalGreen.withValues(alpha: .12),
    );
    final label = TextPainter(
      text: const TextSpan(
        text: 'PHÒNG TRỰC',
        style: TextStyle(
          color: signalGreen,
          fontSize: 9,
          fontFamily: 'Segoe UI',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(c, room - Offset(label.width / 2, label.height / 2));
    for (var i = 0; i < 2; i++) {
      final p = point(Offset(i == 0 ? .34 : .66, .7));
      c.drawCircle(
        p,
        5,
        Paint()
          ..color = model.doors[i].broken
              ? signalRed
              : model.doors[i].locked
              ? signalGreen
              : signalAmber,
      );
    }
  }

  @override
  bool shouldRepaint(covariant FacilityMap oldDelegate) => true;
}

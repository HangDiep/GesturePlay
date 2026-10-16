import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'runner_controller.dart';
import 'runner_model.dart';

class GestureRunnerGame extends FlameGame {
  GestureRunnerGame(this.controller);
  final RunnerController controller;
  @override
  Color backgroundColor() => const Color(0xffdff4ee);
  @override
  Future<void> onLoad() async {
    await add(RunnerWorld(controller));
  }

  @override
  void update(double dt) {
    controller.tick(dt);
    super.update(dt);
  }
}

class RunnerWorld extends PositionComponent {
  RunnerWorld(this.controller) : super(size: Vector2(1120, 700));
  final RunnerController controller;
  static const navy = Color(0xff142633),
      teal = Color(0xff139182),
      mint = Color(0xff7fe6c0),
      gold = Color(0xffffc94c);
  Paint p(Color color) => Paint()..color = color;
  void polygon(Canvas canvas, List<Offset> points, Color color) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path..close(), p(color));
  }

  void rounded(Canvas c, Rect rect, Color color, double radius) => c.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(radius)),
    p(color),
  );
  @override
  void render(Canvas canvas) {
    final c = canvas;
    final model = controller.game;
    final distance = model?.distance ?? 0;
    c.drawRect(
      const Rect.fromLTWH(0, 0, 1120, 700),
      p(const Color(0xffdff4ee)),
    );
    c.drawCircle(const Offset(942, 164), 68, p(const Color(0xffffe3a1)));
    c.drawCircle(const Offset(942, 164), 47, p(const Color(0xffffebbc)));
    for (final cloud in [(90.0, 180.0), (530.0, 145.0), (1000.0, 282.0)]) {
      final x = (cloud.$1 - distance * .07) % 1300 - 90;
      for (final circle in [
        (0.0, 0.0, 22.0),
        (28.0, -12.0, 30.0),
        (58.0, 0.0, 24.0),
      ]) {
        c.drawCircle(
          Offset(x + circle.$1, cloud.$2 + circle.$2),
          circle.$3,
          p(const Color(0xfff6fcf1)),
        );
      }
    }
    final farOffset = distance * .13 % 650;
    for (var i = -1; i < 4; i++) {
      final x = i * 650 - farOffset;
      polygon(c, [
        Offset(x, 500),
        Offset(x + 170, 281),
        Offset(x + 320, 400),
        Offset(x + 470, 267),
        Offset(x + 650, 500),
      ], const Color(0xff9ecec2));
      polygon(c, [
        Offset(x + 170, 281),
        Offset(x + 119, 346),
        Offset(x + 178, 327),
        Offset(x + 222, 343),
      ], const Color(0xffc0e2d5));
    }
    final nearOffset = distance * .32 % 400;
    for (var i = -1; i < 5; i++) {
      c.drawOval(
        Rect.fromLTWH(i * 400 - nearOffset, 424, 480, 190),
        p(const Color(0xff64a691)),
      );
    }
    for (final strip in [
      (532.0, 24.0, 0xff347763),
      (548.0, 10.0, 0xff67a573),
      (558.0, 142.0, 0xffb6865c),
      (558.0, 20.0, 0xffc89a6b),
    ]) {
      c.drawRect(
        Rect.fromLTWH(0, strip.$1, 1120, strip.$2),
        p(Color(strip.$3)),
      );
    }
    for (var i = 0; i < 32; i++) {
      final x = (i * 43 - distance * .9) % 1180 - 30, y = 595.0 + (i % 3) * 21;
      c.drawLine(
        Offset(x, y),
        Offset(x + 13, y),
        p(const Color(0xff9f7554))..strokeWidth = 3,
      );
    }
    if (model != null) {
      for (final coin in model.coins) {
        if (coin.collected) continue;
        final x = coin.x - distance;
        if (x < -20 || x > 1140) continue;
        final w = 5 + 8 * math.sin(model.elapsed * 5 + coin.x * .01).abs();
        c.drawOval(
          Rect.fromCenter(center: Offset(x, coin.y), width: w * 2, height: 26),
          p(const Color(0xffbe8428)),
        );
        c.drawOval(
          Rect.fromCenter(
            center: Offset(x, coin.y),
            width: w * 2 - 3,
            height: 22,
          ),
          p(gold),
        );
      }
      for (final obstacle in model.obstacles) {
        final x = obstacle.x - distance;
        if (x > 1150 || x + obstacle.width < -20) continue;
        spikes(c, x, obstacle.spikes, obstacle.height);
      }
      character(
        c,
        RunnerModel.playerX,
        model.feet,
        model.elapsed,
        model.grounded,
      );
    } else {
      character(c, 794, 548, 0, true);
      spikes(c, 902, 2, 52);
      for (final coin in [
        const Offset(875, 416),
        const Offset(922, 396),
        const Offset(969, 416),
      ]) {
        c.drawCircle(coin, 12, p(gold));
      }
    }
  }

  void spikes(Canvas c, double x, int count, double height) {
    for (var i = 0; i < count; i++) {
      final sx = x + i * 28;
      polygon(c, [
        Offset(sx, 548),
        Offset(sx + 14, 548 - height),
        Offset(sx + 28, 548),
      ], const Color(0xff5e4672));
      polygon(c, [
        Offset(sx + 14, 548 - height),
        Offset(sx + 14, 548),
        Offset(sx + 28, 548),
      ], const Color(0xff936ca0));
    }
  }

  void character(
    Canvas c,
    double x,
    double feet,
    double elapsed,
    bool grounded,
  ) {
    final shadow = math.max(18.0, 50 - (548 - feet) * .15);
    c.drawOval(
      Rect.fromCenter(center: Offset(x + 23, 547), width: shadow, height: 8),
      p(const Color(0xff356f5c)),
    );
    final top = feet - 64 + (grounded ? math.sin(elapsed * 18) * 2 : 0);
    polygon(c, [
      Offset(x + 8, top + 31),
      Offset(x - 21, top + 30),
      Offset(x - 8, top + 42),
    ], const Color(0xfff4904d));
    rounded(c, Rect.fromLTWH(x + 5, top + 25, 36, 31), teal, 8);
    rounded(c, Rect.fromLTWH(x, top, 46, 35), const Color(0xff2cbaa1), 12);
    rounded(c, Rect.fromLTWH(x + 10, top + 9, 31, 17), navy, 6);
    for (final dx in [15.0, 27.0]) {
      rounded(c, Rect.fromLTWH(x + dx, top + 13, 5, 6), mint, 2);
    }
    c.drawCircle(Offset(x + 31, top + 43), 4, p(gold));
    final stride = grounded ? math.sin(elapsed * 20) * 6 : 4;
    rounded(
      c,
      Rect.fromLTWH(x + 10, feet - 12 + stride * .25, 11, 12),
      navy,
      4,
    );
    rounded(
      c,
      Rect.fromLTWH(x + 28, feet - 12 - stride * .25, 11, 12),
      navy,
      4,
    );
  }
}

import 'package:flutter/material.dart';
import '../services/hand_bridge.dart';

class TownHandsPreviewPainter extends CustomPainter {
  TownHandsPreviewPainter(this.hands, {this.swap = false});
  final HandPacket? hands;
  final bool swap;
  @override
  void paint(Canvas c, Size size) {
    for (final side in ['left', 'right']) {
      final h = hands?.hand(side);
      if (h == null || !h.flag('valid') || h.palm == null) continue;
      final moving = (side == 'left') != swap;
      final color = moving ? const Color(0xff72c7bc) : const Color(0xffdeb779);
      Offset map(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
      final p = map(h.palm!);
      c.drawCircle(
        p,
        9,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final points = h.points;
      if (points.length == 2) {
        c.drawLine(
          map(points[0]),
          map(points[1]),
          Paint()
            ..color = color
            ..strokeWidth = h.flag('pinched') ? 4 : 1.5,
        );
      }
      final text = TextPainter(
        text: TextSpan(
          text: moving ? 'ĐI' : 'NGẮM',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(c, p + const Offset(10, -18));
      text.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant TownHandsPreviewPainter oldDelegate) => true;
}

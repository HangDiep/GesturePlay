import 'package:flutter/material.dart';

/// The preview JPEG is 320x240. Match Image.memory's contain fit so the
/// fingertip markers stay on the fingers, including letterboxed previews.
class HandPreviewPainter extends CustomPainter {
  HandPreviewPainter(this.points, this.pinched);
  final List<Offset> points;
  final bool pinched;
  @override
  void paint(Canvas canvas, Size size) {
    if (points.length != 2) return;
    final fitted = applyBoxFit(BoxFit.contain, const Size(320, 240), size);
    final area = Alignment.center.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    Offset map(Offset p) =>
        area.topLeft + Offset(p.dx * area.width, p.dy * area.height);
    final thumb = map(points[0]), index = map(points[1]);
    final paint = Paint()
      ..color = pinched ? const Color(0xffffc94c) : const Color(0xff9fe0b2)
      ..strokeWidth = 2;
    canvas.drawLine(thumb, index, paint);
    canvas.drawCircle(thumb, 5, paint);
    canvas.drawCircle(index, 10, paint..style = PaintingStyle.stroke);
    canvas.drawLine(
      index - const Offset(15, 0),
      index + const Offset(15, 0),
      paint,
    );
    canvas.drawLine(
      index - const Offset(0, 15),
      index + const Offset(0, 15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant HandPreviewPainter oldDelegate) => true;
}

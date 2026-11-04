import 'package:flutter/material.dart';
import '../exploration/model.dart';
import 'scene.dart';
export 'scene.dart';
export 'view.dart';

class TownRadar extends CustomPainter {
  TownRadar(this.model, {this.detailed = false});
  final ExplorationModel model;
  final bool detailed;
  @override
  void paint(Canvas c, Size size) {
    Offset map(Offset p) => Offset(
      p.dx / model.world.mapWidth * size.width,
      p.dy / model.world.mapHeight * size.height,
    );
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xdc0e1b21));
    for (final road in model.world.roads) {
      c.drawRect(
        Rect.fromPoints(map(road.topLeft), map(road.bottomRight)),
        Paint()..color = const Color(0xff1e333b),
      );
    }
    for (final p in model.world.props.where((p) => p.solid)) {
      c.drawRect(
        Rect.fromPoints(map(p.rect.topLeft), map(p.rect.bottomRight)),
        Paint()..color = const Color(0xff3e5054),
      );
    }
    for (final door in model.world.doors) {
      final room = Rect.fromPoints(
        map(door.room.topLeft),
        map(door.room.bottomRight),
      );
      c.drawRect(
        room,
        Paint()
          ..color = door.id == 'refuge'
              ? const Color(0x67478e7d)
              : const Color(0x676d6846),
      );
      c.drawRect(
        Rect.fromPoints(map(door.rect.topLeft), map(door.rect.bottomRight)),
        Paint()..color = door.open ? TownPainter.cyan : TownPainter.amber,
      );
      if (detailed) {
        final text = TextPainter(
          text: TextSpan(
            text: door.name,
            style: const TextStyle(color: Color(0xffead8aa), fontSize: 10),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(c, room.center - Offset(text.width / 2, text.height / 2));
        text.dispose();
      }
    }
    if (!model.jammed) {
      for (final e in model.enemies.where((e) => e.alive)) {
        c.drawCircle(
          map(e.position),
          e.kind == CreatureKind.boss ? 3 : 2,
          Paint()..color = const Color(0xffd47b60),
        );
      }
    }
    for (final i in model.items.where((i) => !i.taken && i.kind == 'core')) {
      c.drawCircle(
        map(i.position),
        detailed ? 5 : 2,
        Paint()..color = TownPainter.cyan,
      );
    }
    for (final spot in model.world.hidingSpots) {
      c.drawCircle(
        map(spot.center),
        detailed ? 5 : 1.8,
        Paint()..color = const Color(0xff85b98b),
      );
    }
    if (detailed) {
      for (final i in model.items.where(
        (i) => !i.taken && i.kind != 'core' && i.unlockAt <= model.elapsed,
      )) {
        c.drawCircle(
          map(i.position),
          4,
          Paint()
            ..color = i.kind == 'health'
                ? const Color(0xffd8cdb0)
                : TownPainter.amber,
        );
      }
      for (final p in const [
        Offset(1100, 160),
        Offset(3300, 160),
        Offset(1100, 2000),
        Offset(3300, 2000),
      ]) {
        final tp = TextPainter(
          text: TextSpan(
            text: model.world.locationAt(p),
            style: const TextStyle(
              color: Color(0xff9aacab),
              fontSize: 12,
              letterSpacing: 2,
              fontFamily: 'Segoe UI',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(c, map(p) - Offset(tp.width / 2, 0));
        tp.dispose();
      }
    }
    c.drawCircle(
      map(model.player),
      detailed ? 6 : 3,
      Paint()..color = const Color(0xfff6e8cc),
    );
  }

  @override
  bool shouldRepaint(covariant TownRadar oldDelegate) => true;
}

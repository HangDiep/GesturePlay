import 'dart:ui';
import '../exploration/world.dart';

class TownDecoration {
  const TownDecoration(this.frame, this.position, this.width);
  final int frame;
  final Offset position;
  final double width;
}

/// Fixed, cosmetic dressing. Solid cover still comes only from FieldWorld.
/// A weak cache avoids rebuilding the arrangement on every animation frame.
class TownScenery {
  TownScenery._(FieldWorld world) {
    for (final p in world.props.where((p) => p.sprite == 0)) {
      final at = p.rect.center;
      final seed = (at.dx + at.dy).toInt();
      decorations.add(
        TownDecoration(
          seed % 3 == 0 ? 5 : 6,
          at + Offset(p.rect.width * .52, p.rect.height * .4 + 12),
          seed % 3 == 0 ? 87 : 66,
        ),
      );
      decorations.add(
        TownDecoration(
          2,
          at + Offset(-p.rect.width * .56, p.rect.height * .28),
          95,
        ),
      );
    }
    for (final spot in world.hidingSpots) {
      for (final offset in const [Offset(-55, 22), Offset(48, 32)]) {
        decorations.add(TownDecoration(0, spot.center + offset, 106));
      }
    }
    for (final p in world.props.where((p) => p.sprite == 10)) {
      decorations.add(TownDecoration(11, p.rect.bottomRight, 105));
    }
    // Trees frame the playable town boundary; they don't add unseen blockers.
    for (double x = 40; x < world.mapWidth; x += 290) {
      decorations.add(TownDecoration(3, Offset(x, 35), 300));
      decorations.add(
        TownDecoration(3, Offset(x + 90, world.mapHeight - 28), 330),
      );
    }
    for (double y = 300; y < world.mapHeight - 200; y += 320) {
      decorations.add(TownDecoration(3, Offset(25, y), 290));
      decorations.add(
        TownDecoration(3, Offset(world.mapWidth - 20, y + 90), 310),
      );
    }
  }
  final decorations = <TownDecoration>[];
  static final _cache = Expando<TownScenery>();
  static TownScenery of(FieldWorld world) =>
      _cache[world] ??= TownScenery._(world);
}

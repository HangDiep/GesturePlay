import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import '../exploration/world.dart';

/// Only the drawing plane is tilted. Combat, paths and cover stay in world
/// coordinates; every input uses the same inverse so screen directions agree.
class TownView {
  TownView(Offset focus, Size size, {FieldWorld? world}) {
    zoom = (size.shortestSide / 650).clamp(.62, 1.2);
    final map = Rect.fromLTWH(
      0,
      0,
      world?.mapWidth ?? FieldWorld.width,
      world?.mapHeight ?? FieldWorld.height,
    );
    final limits = envelope(corners(map).map(floor));
    final visible = Size(size.width / zoom, size.height / zoom);
    final center = floor(focus);
    origin = Offset(
      (center.dx - visible.width * .5).clamp(
        limits.left,
        math.max(limits.left, limits.right - visible.width),
      ),
      (center.dy - visible.height * .58).clamp(
        limits.top,
        math.max(limits.top, limits.bottom - visible.height),
      ),
    );
    bounds = envelope(corners(origin & visible).map(unfloor));
  }

  late final double zoom;

  /// Camera origin in the projected plane; bounds are in simulation space.
  late final Offset origin;
  late final Rect bounds;

  static Offset floor(Offset p) =>
      Offset(p.dx + p.dy * .45, p.dy * .62 - p.dx * .26);
  static Offset unfloor(Offset p) =>
      Offset((p.dx * .62 - p.dy * .45) / .737, (p.dx * .26 + p.dy) / .737);
  static Iterable<Offset> corners(Rect r) => [
    r.topLeft,
    r.topRight,
    r.bottomLeft,
    r.bottomRight,
  ];
  static Rect envelope(Iterable<Offset> points) {
    final p = points.toList();
    return Rect.fromLTRB(
      p.map((p) => p.dx).reduce(math.min),
      p.map((p) => p.dy).reduce(math.min),
      p.map((p) => p.dx).reduce(math.max),
      p.map((p) => p.dy).reduce(math.max),
    );
  }

  static final matrix = Float64List.fromList([
    1,
    -.26,
    0,
    0,
    .45,
    .62,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ]);

  /// Preserve analog strength and world speed while rotating the direction.
  static Offset movement(Offset screenDirection) {
    final world = unfloor(screenDirection);
    return world.distance < .0001
        ? Offset.zero
        : world / world.distance * screenDirection.distance.clamp(0, 1);
  }

  static double muzzleHeight(int stance) => const [30.0, 18.0, 8.0][stance];
  Offset project(Offset p) => (floor(p) - origin) * zoom;
  Offset unproject(Offset p) => unfloor(p / zoom + origin);
  Offset projectShot(Offset p, double height) =>
      project(p) - Offset(0, height * zoom);
  Offset unprojectShot(Offset p, double height) =>
      unproject(p + Offset(0, height * zoom));
}

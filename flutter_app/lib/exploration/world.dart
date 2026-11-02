import 'dart:math' as math;
import 'dart:ui';

enum FieldMap { forest, town, harbor, factory }

enum PropKind { tree, rock, house, container, tank, machine, pipe, water }

class FieldProp {
  const FieldProp(this.kind, this.rect, this.color, {this.solid = true});
  final PropKind kind;
  final Rect rect;
  final Color color;
  final bool solid;
}

class FieldWorld {
  FieldWorld(this.id) {
    final rng = math.Random(731 + id.index);
    cores = List.unmodifiable([
      const Offset(320, 330),
      const Offset(1850, 370),
      Offset(1100, id == FieldMap.harbor ? 255 : 210),
    ]);
    switch (id) {
      case FieldMap.forest:
        roads.add(const Rect.fromLTWH(1010, 80, 180, 1570));
        roads.add(const Rect.fromLTWH(260, 280, 1600, 130));
        for (var i = 0; i < 110; i++) {
          final at = Offset(
            120 + rng.nextDouble() * 1960,
            100 + rng.nextDouble() * 1400,
          );
          if (at.dx > 940 && at.dx < 1260 ||
              cores.any((p) => (p - at).distance < 130) ||
              supplies.any((p) => (p - at).distance < 90) ||
              at.dy > 245 && at.dy < 450 ||
              (at - spawn).distance < 200) {
            continue;
          }
          props.add(
            FieldProp(
              PropKind.tree,
              Rect.fromCenter(center: at, width: 58, height: 58),
              const Color(0xff335d49),
            ),
          );
        }
        for (final at in const [
          Offset(700, 960),
          Offset(1500, 1050),
          Offset(1570, 650),
          Offset(550, 620),
        ]) {
          props.add(
            FieldProp(
              PropKind.rock,
              Rect.fromCenter(center: at, width: 135, height: 100),
              const Color(0xff6c7b78),
            ),
          );
        }
        props.add(
          const FieldProp(
            PropKind.house,
            Rect.fromLTWH(220, 500, 220, 145),
            Color(0xff8e7051),
          ),
        );
      case FieldMap.town:
        roads.add(const Rect.fromLTWH(1000, 60, 200, 1630));
        roads.add(const Rect.fromLTWH(70, 270, 2060, 160));
        roads.add(const Rect.fromLTWH(70, 1130, 2060, 150));
        for (final x in [260.0, 610.0, 1370.0, 1740.0]) {
          for (final y in [510.0, 860.0, 1330.0]) {
            props.add(
              FieldProp(
                PropKind.house,
                Rect.fromLTWH(x, y, 230, 190),
                x < 1000 ? const Color(0xffc3a78c) : const Color(0xff88a7aa),
              ),
            );
          }
        }
        props.add(
          const FieldProp(
            PropKind.rock,
            Rect.fromLTWH(1040, 710, 120, 100),
            Color(0xffb5c1b7),
          ),
        );
      case FieldMap.harbor:
        roads.add(const Rect.fromLTWH(1040, 100, 120, 1500));
        props.add(
          const FieldProp(
            PropKind.water,
            Rect.fromLTWH(60, 60, 2080, 135),
            Color(0xff326c81),
          ),
        );
        for (final x in [250.0, 650.0, 1330.0, 1720.0]) {
          for (final y in [530.0, 850.0, 1170.0]) {
            props.add(
              FieldProp(
                PropKind.container,
                Rect.fromLTWH(x, y, 230, 130),
                [
                  const Color(0xffad6756),
                  const Color(0xff608c9c),
                  const Color(0xffbba66d),
                ][rng.nextInt(3)],
              ),
            );
          }
        }
        for (final x in [200.0, 1920.0]) {
          props.add(
            FieldProp(
              PropKind.machine,
              Rect.fromLTWH(x, 220, 75, 220),
              const Color(0xffd1a355),
            ),
          );
        }
      case FieldMap.factory:
        roads.add(const Rect.fromLTWH(1010, 90, 180, 1530));
        for (final x in [380.0, 1630.0]) {
          for (final y in [660.0, 1200.0]) {
            props.add(
              FieldProp(
                PropKind.tank,
                Rect.fromCenter(center: Offset(x, y), width: 210, height: 210),
                const Color(0xff899c9b),
              ),
            );
          }
        }
        for (final x in [760.0, 1330.0]) {
          for (final y in [550.0, 940.0, 1330.0]) {
            props.add(
              FieldProp(
                PropKind.machine,
                Rect.fromLTWH(x, y, 115, 80),
                const Color(0xff64787d),
              ),
            );
          }
        }
        props.add(
          const FieldProp(
            PropKind.pipe,
            Rect.fromLTWH(280, 450, 1640, 35),
            Color(0xffb4a368),
            solid: false,
          ),
        );
        hazards.addAll(const [
          Rect.fromLTWH(580, 600, 130, 130),
          Rect.fromLTWH(1450, 1000, 130, 130),
          Rect.fromLTWH(1760, 230, 130, 100),
        ]);
    }
    obstacles = List.unmodifiable(
      props.where((p) => p.solid).map((p) => p.rect),
    );
  }
  final FieldMap id;
  static const width = 2200.0, height = 1800.0, grid = 50.0;
  static const columns = 44, rows = 36;
  static const spawn = Offset(1100, 1500), extraction = Offset(1100, 1600);
  final props = <FieldProp>[];
  final roads = <Rect>[], hazards = <Rect>[];
  late final List<Rect> obstacles;
  late final List<Offset> cores;
  final _walkCache = <int, bool>{};
  String get title =>
      ['Rừng thông', 'Thị trấn bỏ hoang', 'Bến cảng', 'Nhà máy'][id.index];
  String get description => [
    'Đường mòn xuyên rừng, trạm gác và những khe đá.',
    'Phố giao nhau, các dãy nhà và quảng trường bỏ trống.',
    'Luồn qua bãi container và khu cần cẩu sát mặt nước.',
    'Bồn chứa, đường ống và vùng nhiễm gây mất máu.',
  ][id.index];
  Color get ground => [
    const Color(0xff435d48),
    const Color(0xff8b8172),
    const Color(0xff566d7c),
    const Color(0xff39484d),
  ][id.index];
  Color get accent => [
    const Color(0xffa4c995),
    const Color(0xffe3b885),
    const Color(0xff81cfdf),
    const Color(0xffbed884),
  ][id.index];
  late final List<Offset> supplies = [
    const Offset(925, 1230),
    const Offset(1250, 760),
    id == FieldMap.harbor ? const Offset(2020, 500) : const Offset(1970, 440),
  ];

  bool walkable(Offset p, [double radius = 16]) =>
      p.dx >= 60 + radius &&
      p.dx <= width - 60 - radius &&
      p.dy >= 60 + radius &&
      p.dy <= height - 60 - radius &&
      !obstacles.any((r) => r.inflate(radius).contains(p));

  Offset move(Offset p, Offset delta, [double radius = 16]) {
    final x = Offset(p.dx + delta.dx, p.dy);
    if (walkable(x, radius)) p = x;
    final y = Offset(p.dx, p.dy + delta.dy);
    if (walkable(y, radius)) p = y;
    return p;
  }

  bool clearLine(Offset a, Offset b, [double radius = 0]) =>
      !obstacles.any((rect) => segmentRect(a, b, rect.inflate(radius)) != null);

  /// A* follows each map's actual obstacles; diagonal corner cutting is blocked.
  List<Offset> route(Offset from, Offset to) {
    int cell(Offset p) =>
        ((p.dy / grid).floor().clamp(0, rows - 1) * columns +
        (p.dx / grid).floor().clamp(0, columns - 1));
    bool pass(int id) =>
        _walkCache.putIfAbsent(id, () => walkable(center(id), 24));
    int nearest(Offset p) {
      final original = cell(p), x = original % columns, y = original ~/ columns;
      for (var radius = 0; radius < 4; radius++) {
        for (var dy = -radius; dy <= radius; dy++) {
          for (var dx = -radius; dx <= radius; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx >= 0 &&
                nx < columns &&
                ny >= 0 &&
                ny < rows &&
                pass(ny * columns + nx)) {
              return ny * columns + nx;
            }
          }
        }
      }
      return original;
    }

    final start = nearest(from), goal = nearest(to);
    final open = <int>[start],
        seen = <int>{},
        came = <int, int>{},
        cost = <int, double>{start: 0};
    double heuristic(int id) => (center(id) - center(goal)).distance;
    while (open.isNotEmpty) {
      var best = 0;
      for (var i = 1; i < open.length; i++) {
        if (cost[open[i]]! + heuristic(open[i]) <
            cost[open[best]]! + heuristic(open[best])) {
          best = i;
        }
      }
      final current = open.removeAt(best);
      if (current == goal) {
        final path = <Offset>[center(goal)];
        var previous = current;
        while (came.containsKey(previous)) {
          previous = came[previous]!;
          path.add(center(previous));
        }
        return path.reversed.skip(1).toList();
      }
      seen.add(current);
      final x = current % columns, y = current ~/ columns;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx, ny = y + dy, next = ny * columns + nx;
          if (nx < 0 ||
              nx >= columns ||
              ny < 0 ||
              ny >= rows ||
              seen.contains(next) ||
              !pass(next)) {
            continue;
          }
          if (dx != 0 &&
              dy != 0 &&
              (!pass(y * columns + nx) || !pass(ny * columns + x))) {
            continue;
          }
          final distance =
              cost[current]! + (dx == 0 || dy == 0 ? grid : grid * math.sqrt2);
          if (distance < (cost[next] ?? double.infinity)) {
            cost[next] = distance;
            came[next] = current;
            if (!open.contains(next)) open.add(next);
          }
        }
      }
    }
    return [];
  }

  Offset center(int cell) =>
      Offset((cell % columns + .5) * grid, (cell ~/ columns + .5) * grid);
}

double? segmentRect(Offset a, Offset b, Rect rect) {
  final d = b - a;
  var low = 0.0, high = 1.0;
  final p = [-d.dx, d.dx, -d.dy, d.dy];
  final q = [
    a.dx - rect.left,
    rect.right - a.dx,
    a.dy - rect.top,
    rect.bottom - a.dy,
  ];
  for (var i = 0; i < 4; i++) {
    if (p[i].abs() < 1e-9) {
      if (q[i] < 0) return null;
    } else {
      final t = q[i] / p[i];
      if (p[i] < 0) {
        low = math.max(low, t);
      } else {
        high = math.min(high, t);
      }
      if (low > high) return null;
    }
  }
  return low;
}

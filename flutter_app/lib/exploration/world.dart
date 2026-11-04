import 'dart:math' as math;
import 'dart:ui';

enum FieldMap { forest, town, harbor, factory }

enum PropKind { tree, rock, house, container, tank, machine, pipe, water }

class FieldProp {
  const FieldProp(
    this.kind,
    this.rect,
    this.color, {
    this.solid = true,
    this.sprite,
    this.artSize,
    this.lowCover = false,
  });
  final PropKind kind;
  final Rect rect;
  final Color color;
  final bool solid;
  final int? sprite;
  final Size? artSize;
  final bool lowCover;
}

class HidingSpot {
  const HidingSpot(this.name, this.center);
  final String name;
  final Offset center;
  Rect get area => Rect.fromCenter(center: center, width: 110, height: 90);
}

class TownDoor {
  TownDoor(this.id, this.name, this.rect, this.room, {this.locked = false});
  final String id, name;
  final Rect rect, room;
  bool locked, _open = false;
  bool get open => _open;
  double health = 120;
  bool get broken => health <= 0;
  Offset get outside => rect.center + const Offset(0, 85);
}

class TownStash {
  TownStash(this.id, this.name, this.position, {this.locked = false});
  final String id, name;
  final Offset position;
  bool locked, opened = false;
  int medStock = 2, rifleRounds = 48, pistolRounds = 24, shells = 8;
  bool shotgunAvailable = false;
  bool get empty =>
      medStock + rifleRounds + pistolRounds + shells == 0 && !shotgunAvailable;
}

class FieldWorld {
  FieldWorld(this.id, {this.quarantine = false}) {
    final rng = math.Random(731 + id.index);
    cores = List.unmodifiable(
      quarantine
          ? const [Offset(450, 650), Offset(3400, 680), Offset(3470, 3000)]
          : [
              const Offset(320, 330),
              const Offset(1850, 370),
              Offset(1100, id == FieldMap.harbor ? 255 : 210),
            ],
    );
    if (quarantine) {
      _buildQuarantineTown();
      _buildInteractiveRooms();
    } else {
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
                  Rect.fromCenter(
                    center: Offset(x, y),
                    width: 210,
                    height: 210,
                  ),
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
    }
    _staticObstacles = List.unmodifiable(
      props.where((p) => p.solid).map((p) => p.rect),
    );
  }
  final FieldMap id;
  final bool quarantine;

  void _buildQuarantineTown() {
    void prop(
      int sprite,
      double x,
      double y,
      double width,
      double depth,
      double artWidth,
      double artHeight, {
      bool solid = true,
    }) {
      props.add(
        FieldProp(
          PropKind.values[sprite == 0
              ? 2
              : sprite == 2
              ? 0
              : 1],
          Rect.fromCenter(center: Offset(x, y), width: width, height: depth),
          const Color(0xff283a3d),
          // Town vegetation is passable; houses, walls and hard cover keep
          // their solid footprints. Legacy maps use their own collision rules.
          solid: solid && sprite != 2,
          sprite: sprite,
          artSize: Size(artWidth, artHeight),
          lowCover: const [4, 7, 8, 11].contains(sprite),
        ),
      );
    }

    roads.addAll(const [
      Rect.fromLTWH(940, 100, 320, 1600),
      Rect.fromLTWH(100, 530, 2000, 240),
      Rect.fromLTWH(100, 1050, 2000, 240),
    ]);
    // Facades face the main lane, leaving a sidewalk outside each footprint.
    for (final x in [280.0, 790.0, 1410.0, 1920.0]) {
      for (final y in [420.0, 900.0, 1470.0]) {
        prop(0, x, y, 210, 110, 310, 300);
      }
    }
    prop(1, 1100, 200, 300, 65, 360, 260, solid: false);
    prop(3, 745, 1140, 180, 90, 255, 205);
    prop(5, 1360, 1140, 85, 65, 150, 175);
    prop(10, 1590, 1140, 175, 125, 230, 205);
    prop(10, 490, 160, 175, 110, 215, 180);
    for (final x in [900.0, 1300.0]) {
      for (final y in [490.0, 980.0, 1370.0, 1660.0]) {
        prop(6, x, y, 22, 22, 64, 135);
      }
    }
    for (final p in const [
      Offset(100, 740),
      Offset(420, 1010),
      Offset(1810, 1010),
      Offset(2090, 750),
      Offset(490, 1590),
      Offset(1740, 1600),
      Offset(1460, 220),
      Offset(780, 190),
    ]) {
      prop(2, p.dx, p.dy, 65, 45, 200, 240);
    }
    for (final p in const [
      Offset(480, 440),
      Offset(1730, 440),
      Offset(480, 920),
      Offset(1720, 920),
      Offset(460, 1430),
    ]) {
      prop(4, p.dx, p.dy, 130, 28, 165, 85);
    }
    for (final p in const [
      Offset(820, 400),
      Offset(1460, 1340),
      Offset(2000, 1190),
    ]) {
      prop(7, p.dx, p.dy, 55, 40, 85, 90);
    }
    prop(8, 470, 1190, 60, 45, 100, 90);
    prop(8, 1770, 260, 60, 45, 100, 90);
    prop(9, 1640, 170, 150, 25, 195, 95);
    prop(11, 1880, 1610, 60, 45, 110, 100);
    prop(11, 350, 710, 60, 40, 100, 90);

    // These streets join the existing town: no level change or loading gate.
    roads.addAll(const [
      Rect.fromLTWH(2040, 100, 320, 3400),
      Rect.fromLTWH(100, 1720, 4200, 240),
      Rect.fromLTWH(940, 1550, 320, 1950),
      Rect.fromLTWH(1900, 530, 2400, 240),
      Rect.fromLTWH(1900, 1050, 2400, 240),
      Rect.fromLTWH(100, 2360, 4200, 220),
      Rect.fromLTWH(100, 2940, 4200, 200),
      Rect.fromLTWH(3300, 200, 260, 3200),
    ]);
    // Eastern temple courtyard: gateways, low walls and two ways around cover.
    for (final x in [2600.0, 3950.0]) {
      for (final y in [420.0, 1320.0]) {
        prop(0, x, y, 210, 110, 310, 300);
      }
    }
    prop(1, 3410, 260, 260, 60, 350, 260, solid: false);
    prop(5, 3390, 470, 95, 70, 180, 210);
    prop(5, 3740, 900, 95, 70, 180, 210);
    prop(10, 3980, 1050, 185, 135, 250, 220);
    for (final x in [2860.0, 3070.0, 3700.0, 3920.0]) {
      prop(4, x, 850, 150, 35, 180, 100);
    }
    // Southern night market has tighter alleys and supply cover.
    for (final x in [250.0, 650.0, 1550.0, 1950.0]) {
      for (final y in [2180.0, 2720.0, 3250.0]) {
        prop(0, x, y, 210, 110, 310, 300);
      }
    }
    for (final x in [880.0, 1320.0]) {
      for (final y in [2230.0, 2780.0, 3290.0]) {
        prop(5, x, y, 65, 55, 120, 145);
        prop(8, x - 90, y + 30, 60, 45, 90, 80);
      }
    }
    prop(3, 1800, 1920, 180, 85, 255, 205);
    prop(3, 2800, 1850, 180, 85, 255, 205);
    prop(9, 2940, 1310, 160, 28, 210, 105);
    hidingSpots.addAll(const [
      HidingSpot('Bụi cây đầu phố', Offset(1250, 1530)),
      HidingSpot('Sau xe tải', Offset(760, 1030)),
      HidingSpot('Góc sân đền', Offset(3220, 980)),
      HidingSpot('Bụi rậm chợ đêm', Offset(1260, 2610)),
      HidingSpot('Vườn tượng hoang', Offset(3310, 2940)),
      HidingSpot('Lối khuất tường đá', Offset(4050, 1990)),
    ]);
    prop(5, 3710, 2750, 130, 85, 240, 260);
    for (final x in [2550.0, 2900.0, 3300.0, 3700.0, 4100.0]) {
      for (final y in [2130.0, 2570.0, 2950.0, 3360.0]) {
        final p = Offset(x, y);
        if (hidingSpots.any((s) => (s.center - p).distance < 150)) continue;
        prop(2, x, y, 65, 45, 210, 245);
        prop(11, x + 100, y + 70, 50, 35, 90, 80);
      }
    }
    for (final x in [2500.0, 3200.0, 3800.0, 4200.0]) {
      for (final y in [650.0, 1700.0, 2450.0, 3150.0]) {
        prop(6, x, y, 22, 22, 64, 135);
      }
    }
    for (final spot in hidingSpots) {
      // Vegetation is soft cover, not an invisible solid box.
      prop(
        2,
        spot.center.dx,
        spot.center.dy + 45,
        55,
        30,
        175,
        185,
        solid: false,
      );
    }
  }

  static const width = 2200.0, height = 1800.0, grid = 50.0;
  static const columns = 44, rows = 36;
  static const spawn = Offset(1100, 1500), extraction = Offset(1100, 1600);
  double get mapWidth => quarantine ? 4400 : width;
  double get mapHeight => quarantine ? 3600 : height;
  int get mapColumns => (mapWidth / grid).round();
  int get mapRows => (mapHeight / grid).round();
  final hidingSpots = <HidingSpot>[];
  String locationAt(Offset p) => !quarantine
      ? title
      : p.dx < 2200
      ? (p.dy < 1800 ? 'PHỐ CỔ' : 'CHỢ ĐÊM')
      : (p.dy < 1800 ? 'SÂN ĐỀN' : 'VƯỜN HOANG');
  final props = <FieldProp>[];
  final roads = <Rect>[], hazards = <Rect>[];
  late final List<Rect> _staticObstacles;
  List<Rect>? _collisionCache;
  List<Rect> get obstacles => _collisionCache ??= List.unmodifiable([
    ..._staticObstacles,
    ...doors.where((d) => !d.open).map((d) => d.rect),
  ]);
  final doors = <TownDoor>[];
  final stashes = <TownStash>[];
  int navigationVersion = 0;
  void setDoorOpen(TownDoor door, bool open) {
    if (door.open == open) return;
    door._open = open;
    _collisionCache = null;
    _walkCache.clear();
    navigationVersion++;
  }

  void _buildInteractiveRooms() {
    void room(String id, String name, Rect area, {bool locked = false}) {
      // Keep an apron clear so neighbouring billboard roofs do not cover the
      // walk-in room or its doorway even when their footprints sit outside it.
      final apron = Rect.fromLTRB(
        area.left - 120,
        area.top - 80,
        area.right + 160,
        area.bottom + 260,
      );
      props.removeWhere((p) => p.rect.overlaps(apron));
      void wall(Rect r) => props.add(
        FieldProp(
          PropKind.rock,
          r,
          const Color(0xff27383e),
          sprite: 12,
          artSize: Size(r.width, 90),
        ),
      );
      wall(Rect.fromLTWH(area.left, area.top, area.width, 22));
      wall(Rect.fromLTWH(area.left, area.top, 22, area.height));
      wall(Rect.fromLTWH(area.right - 22, area.top, 22, area.height));
      wall(Rect.fromLTWH(area.left, area.bottom - 22, area.width / 2 - 50, 22));
      wall(
        Rect.fromLTWH(
          area.center.dx + 50,
          area.bottom - 22,
          area.width / 2 - 50,
          22,
        ),
      );
      final door = TownDoor(
        id,
        name,
        Rect.fromLTWH(area.center.dx - 50, area.bottom - 22, 100, 22),
        area,
        locked: locked,
      );
      door._open = !locked;
      doors.add(door);
    }

    room('refuge', 'PHÒNG TRÚ', const Rect.fromLTWH(420, 1700, 360, 300));
    room(
      'armory',
      'KHO TIẾP TẾ',
      const Rect.fromLTWH(2800, 2080, 400, 360),
      locked: true,
    );
    hidingSpots.add(const HidingSpot('Góc phòng trú', Offset(510, 1840)));
    stashes.add(TownStash('refuge', 'Tủ thuốc', const Offset(690, 1810)));
    stashes.add(TownStash('armory', 'Hòm vũ khí', const Offset(3090, 2160)));
  }

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
  late final List<Offset> supplies = quarantine
      ? const [Offset(890, 1220), Offset(1260, 750), Offset(1820, 600)]
      : [
          const Offset(925, 1230),
          const Offset(1250, 760),
          id == FieldMap.harbor
              ? const Offset(2020, 500)
              : const Offset(1970, 440),
        ];

  bool walkable(Offset p, [double radius = 16]) =>
      p.dx >= 60 + radius &&
      p.dx <= mapWidth - 60 - radius &&
      p.dy >= 60 + radius &&
      p.dy <= mapHeight - 60 - radius &&
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

  /// Low walls block low silhouettes and low shots, but can be seen/fired over
  /// when standing or briefly peeking. Movement always uses solid footprints.
  Iterable<Rect> shotObstacles({required bool lowShot}) sync* {
    yield* props
        .where((p) => p.solid && (lowShot || !p.lowCover))
        .map((p) => p.rect);
    yield* doors.where((d) => !d.open).map((d) => d.rect);
  }

  bool clearSight(Offset a, Offset b, {required bool lowProfile}) =>
      !shotObstacles(
        lowShot: lowProfile,
      ).any((r) => segmentRect(a, b, r.inflate(2)) != null);
  bool inVegetation(Offset p) =>
      hidingSpots.any((s) => s.area.inflate(15).contains(p)) ||
      props.any(
        (s) => s.kind == PropKind.tree && s.rect.inflate(55).contains(p),
      );
  bool nearLowCover(Offset p) =>
      props.any((s) => s.solid && s.lowCover && s.rect.inflate(65).contains(p));

  /// A* follows each map's actual obstacles; diagonal corner cutting is blocked.
  List<Offset> route(Offset from, Offset to) {
    final columns = mapColumns, rows = mapRows;
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
      Offset((cell % mapColumns + .5) * grid, (cell ~/ mapColumns + .5) * grid);
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

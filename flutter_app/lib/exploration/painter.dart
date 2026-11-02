import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'model.dart';
import 'world.dart';

class FieldViewport {
  FieldViewport(Offset focus, Size size, {bool overview = false}) {
    zoom = overview
        ? math.min(
            size.width / FieldWorld.width,
            size.height / FieldWorld.height,
          )
        : (size.shortestSide / 610).clamp(.6, 1.15);
    origin = overview
        ? Offset(
            -(size.width / zoom - FieldWorld.width) / 2,
            -(size.height / zoom - FieldWorld.height) / 2,
          )
        : Offset(
            (focus.dx - size.width / zoom / 2).clamp(
              0,
              math.max(0, FieldWorld.width - size.width / zoom),
            ),
            (focus.dy - size.height / zoom / 2).clamp(
              0,
              math.max(0, FieldWorld.height - size.height / zoom),
            ),
          );
  }
  late final double zoom;
  late final Offset origin;
  Offset project(Offset world) => (world - origin) * zoom;
  Offset unproject(Offset screen) => screen / zoom + origin;
}

class ExplorationPainter extends CustomPainter {
  ExplorationPainter(this.model, {this.overview = false, this.reticle = true});
  final ExplorationModel model;
  final bool overview, reticle;

  @override
  void paint(Canvas c, Size size) {
    final view = FieldViewport(model.player, size, overview: overview);
    final w = model.world;

    c.save();
    c.clipRect(Offset.zero & size);

    // Deep midnight fog background
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xff080f14));
    c.scale(view.zoom);
    c.translate(-view.origin.dx, -view.origin.dy);

    final bounds = const Rect.fromLTWH(0, 0, FieldWorld.width, FieldWorld.height);

    // Ground: Dark moody cobblestone & wet asphalt
    final groundBaseColor = switch (w.id) {
      FieldMap.town => const Color(0xff161e24),
      FieldMap.forest => const Color(0xff111c19),
      FieldMap.harbor => const Color(0xff131d22),
      FieldMap.factory => const Color(0xff181b1d),
    };
    c.drawRect(bounds, Paint()..color = groundBaseColor);

    // Texture grain on ground
    final random = math.Random(917 + w.id.index);
    for (var i = 0; i < 650; i++) {
      final p = Offset(
        random.nextDouble() * FieldWorld.width,
        random.nextDouble() * FieldWorld.height,
      );
      c.drawCircle(
        p,
        1 + random.nextDouble() * 2.5,
        Paint()..color = Colors.black.withValues(alpha: .06 + random.nextDouble() * .05),
      );
    }

    // Roads with cobblestone edges and wet puddle reflections
    for (final road in w.roads) {
      _drawAtmosphericRoad(c, road, w.id);
    }

    // Puddle reflections
    _drawPuddles(c, w.id);

    // Hazard radioactive / bio zones
    for (final hazard in w.hazards) {
      _drawHazard(c, hazard);
    }

    // Extraction Circle (Green emergency beacon)
    _drawExtractionZone(c);

    // Street Lamps / Light emitters on map
    _drawStreetLamps(c, w);

    // Props: Houses, Trees, Rocks, Military Truck, Crates
    for (final prop in w.props) {
      _prop(c, prop, w.id);
    }

    // Extra decoration for Town: Military truck as seen in concept art
    if (w.id == FieldMap.town) {
      _drawMilitaryTruck(c, const Offset(960, 480));
    }

    // Harbor crane decoration
    if (w.id == FieldMap.harbor) {
      _drawHarborCrane(c);
    }

    // Items (Cores, Health kits, Ammo boxes)
    for (final item in model.items.where((i) => !i.taken)) {
      _item(c, item);
    }

    // Lower particle effects (traps, flash grounds)
    for (final e in model.effects.where(
      (e) => e.kind != 'damage' && e.kind != 'spark' && e.kind != 'muzzle',
    )) {
      _effect(c, e);
    }

    // Entities sorted by Y coordinate for depth sorting
    final actors = <({double y, Creature? enemy})>[
      (y: model.player.dy, enemy: null),
      for (final e in model.enemies) (y: e.position.dy, enemy: e),
    ]..sort((a, b) => a.y.compareTo(b.y));

    for (final actor in actors) {
      if (actor.enemy case final e?) {
        _enemy(c, e);
      } else {
        _player(c);
      }
    }

    // Bullets with golden light streaks
    for (final b in model.bullets) {
      c.drawLine(
        b.position - b.direction * 22,
        b.position,
        Paint()
          ..color = const Color(0xffffe699)
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round,
      );
      c.drawLine(
        b.position - b.direction * 10,
        b.position,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    // Upper effects: hit sparks, muzzle flash, damage numbers
    for (final e in model.effects.where(
      (e) => e.kind == 'damage' || e.kind == 'spark' || e.kind == 'muzzle',
    )) {
      _effect(c, e);
    }

    // Atmospheric Darkness & Flashlight Cone (Dynamic Lighting)
    if (!overview) {
      _drawDynamicAtmosphere(c, bounds);
    }

    // Spectral Cyan Mist floating across streets
    _drawSpectralMist(c, bounds);

    // Subtle Night Rain Streaks
    _drawNightRain(c, bounds);

    // Aim Reticle & Laser guide
    if (reticle && !overview && !model.finished) {
      _drawAimLaserAndReticle(c);
    }

    // Map borders
    c.drawRect(
      const Rect.fromLTWH(55, 55, 2090, 1690),
      Paint()
        ..color = const Color(0xff122329).withValues(alpha: .75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );

    c.restore();

    // Screen-space FX: Flash bang
    if (model.flashFor > 0) {
      c.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: (model.flashFor * 1.5).clamp(0.0, 1.0)),
      );
    }

    // Screen-space FX: Hurt vignette
    if (model.hurtFor > 0) {
      _drawBloodVignette(c, size, model.hurtFor);
    }

    // Screen-space FX: Death Fade Out & Vignette
    if (model.dyingFor > 0 || model.phase == FieldPhase.lost) {
      _drawDeathScreenOverlay(c, size);
    }
  }

  // --- Dynamic Lighting & Atmosphere ---

  void _drawDynamicAtmosphere(Canvas c, Rect bounds) {
    // Ambient darkness layer with radial cutouts for player flashlight and warm street lights
    final player = model.player;
    final facing = model.facing;

    // Flashlight cone extending from player
    final coneLength = 380.0;
    final coneAngle = 0.65; // ~37 degrees spread
    final conePath = Path()
      ..moveTo(player.dx, player.dy)
      ..arcTo(
        Rect.fromCircle(center: player, radius: coneLength),
        facing - coneAngle / 2,
        coneAngle,
        false,
      )
      ..close();

    // Flashlight beam glow
    final beamGradient = RadialGradient(
      center: Alignment.center,
      radius: 1.0,
      colors: [
        const Color(0xfffff0cc).withValues(alpha: .22),
        const Color(0xffd4e7ed).withValues(alpha: .08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.65, 1.0],
    );
    c.drawPath(
      conePath,
      Paint()
        ..shader = beamGradient.createShader(Rect.fromCircle(center: player, radius: coneLength)),
    );

    // Player personal aura (small circle around feet)
    c.drawCircle(
      player,
      85,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xffffe8b3).withValues(alpha: .18),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: player, radius: 85)),
    );
  }

  void _drawSpectralMist(Canvas c, Rect bounds) {
    // Floating eerie cyan wisps
    final time = model.elapsed * 0.4;
    final mistPaint = Paint()
      ..color = const Color(0xff4fe3c1).withValues(alpha: .045);

    for (var i = 0; i < 8; i++) {
      final x = ((i * 270.0 + time * 45) % (FieldWorld.width + 200)) - 100;
      final y = 200.0 + (i * 180.0 + math.sin(time + i) * 60) % (FieldWorld.height - 300);
      c.drawOval(
        Rect.fromCenter(
          center: Offset(x, y),
          width: 240 + math.sin(time + i) * 40,
          height: 90 + math.cos(time + i) * 20,
        ),
        mistPaint,
      );
    }
  }

  void _drawNightRain(Canvas c, Rect bounds) {
    if (model.world.id != FieldMap.town) return;
    final time = model.elapsed;
    final rainPaint = Paint()
      ..color = const Color(0xff88a8ba).withValues(alpha: .14)
      ..strokeWidth = 1.2;

    final player = model.player;
    // Draw rain only around player viewport to keep performance fast
    final rng = math.Random(42);
    for (var i = 0; i < 90; i++) {
      final rx = (rng.nextDouble() * 900 - 450) + player.dx;
      final ry = ((rng.nextDouble() * 700 + time * 1200) % 700 - 350) + player.dy;
      c.drawLine(
        Offset(rx, ry),
        Offset(rx - 4, ry + 16),
        rainPaint,
      );
    }
  }

  void _drawStreetLamps(Canvas c, FieldWorld w) {
    if (w.id != FieldMap.town) return;
    // Lantern positions along the street
    final lampPositions = [
      const Offset(970, 240),
      const Offset(1230, 240),
      const Offset(970, 680),
      const Offset(1230, 680),
      const Offset(970, 1100),
      const Offset(1230, 1100),
      const Offset(970, 1420),
      const Offset(1230, 1420),
    ];

    for (final pos in lampPositions) {
      // Warm amber lantern glow
      c.drawCircle(
        pos,
        140,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xffffba42).withValues(alpha: .24),
              const Color(0xffff9900).withValues(alpha: .08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(Rect.fromCircle(center: pos, radius: 140)),
      );

      // Lamp pole (iron post with lantern)
      c.drawCircle(pos, 4, Paint()..color = const Color(0xff182025));
      c.drawCircle(pos - const Offset(0, 2), 6, Paint()..color = const Color(0xffffd066));
    }
  }

  void _drawAtmosphericRoad(Canvas c, Rect road, FieldMap mapId) {
    // Wet pavement with curbs
    final curbColor = const Color(0xff222e37);
    final asphaltColor = const Color(0xff182229);

    // Curb border
    c.drawRRect(
      RRect.fromRectAndRadius(road.inflate(8), const Radius.circular(6)),
      Paint()..color = curbColor,
    );
    // Main road surface
    c.drawRect(road, Paint()..color = asphaltColor);

    if (mapId == FieldMap.town) {
      // Road markings
      final markPaint = Paint()..color = const Color(0xffe8d39e).withValues(alpha: .35);
      if (road.height > road.width) {
        for (var y = road.top + 20; y < road.bottom; y += 75) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(road.center.dx - 2.5, y, 5, 28),
              const Radius.circular(2),
            ),
            markPaint,
          );
        }
      } else {
        for (var x = road.left + 20; x < road.right; x += 75) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x, road.center.dy - 2.5, 28, 5),
              const Radius.circular(2),
            ),
            markPaint,
          );
        }
      }
    }
  }

  void _drawPuddles(Canvas c, FieldMap mapId) {
    if (mapId != FieldMap.town) return;
    final puddles = [
      const Rect.fromLTWH(1030, 420, 65, 35),
      const Rect.fromLTWH(1120, 890, 80, 45),
      const Rect.fromLTWH(1040, 1280, 70, 40),
    ];
    for (final p in puddles) {
      c.drawOval(
        p,
        Paint()..color = const Color(0xff0e181e).withValues(alpha: .85),
      );
      c.drawOval(
        p.deflate(2),
        Paint()
          ..color = const Color(0xff4ca6a4).withValues(alpha: .18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawHazard(Canvas c, Rect hazard) {
    c.drawOval(
      hazard,
      Paint()..color = const Color(0xff559922).withValues(alpha: .28),
    );
    c.drawOval(
      hazard.deflate(6 + math.sin(model.elapsed * 3.5) * 5),
      Paint()
        ..color = const Color(0xffa1e643).withValues(alpha: .45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _label(c, '☣ KHU NHIỄM ĐỘC', hazard.center, const Color(0xffbcee68), 10);
  }

  void _drawExtractionZone(Canvas c) {
    final exit = FieldWorld.extraction;
    c.drawCircle(
      exit,
      65,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xff5cdbb5).withValues(alpha: .25),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: exit, radius: 65)),
    );
    c.drawCircle(
      exit,
      50 + math.sin(model.elapsed * 3.2) * 4,
      Paint()
        ..color = const Color(0xff6ef0c8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    c.drawLine(
      exit - const Offset(18, 0),
      exit + const Offset(18, 0),
      Paint()
        ..color = const Color(0xffd5fff2)
        ..strokeWidth = 5,
    );
    c.drawLine(
      exit - const Offset(0, 18),
      exit + const Offset(0, 18),
      Paint()
        ..color = const Color(0xffd5fff2)
        ..strokeWidth = 5,
    );
    _label(c, 'ĐIỂM CỨU HỘ', exit + const Offset(0, 72), const Color(0xffd5fff2), 11);
  }

  void _drawMilitaryTruck(Canvas c, Offset center) {
    // Abandoned military supply truck from concept art
    c.save();
    c.translate(center.dx, center.dy);

    // Shadow
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-38, -68, 76, 136),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.black.withValues(alpha: .45),
    );

    // Truck Body (Army Green / Weathered)
    const bodyColor = Color(0xff2d3b2f);
    const canvasCoverColor = Color(0xff434f45);
    const windowColor = Color(0xff577073);

    // Cargo Bed / Canvas top
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, -60, 64, 75),
        const Radius.circular(5),
      ),
      Paint()..color = canvasCoverColor,
    );
    // Canvas ribs
    for (var y = -50.0; y <= 5.0; y += 14) {
      c.drawLine(
        Offset(-30, y),
        Offset(30, y),
        Paint()
          ..color = const Color(0xff252f27)
          ..strokeWidth = 2,
      );
    }

    // Cab
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-32, 18, 64, 44),
        const Radius.circular(6),
      ),
      Paint()..color = bodyColor,
    );
    // Windshield
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-26, 26, 52, 14),
        const Radius.circular(2),
      ),
      Paint()..color = windowColor,
    );
    // Hood & Grill
    c.drawRect(
      const Rect.fromLTWH(-20, 52, 40, 10),
      Paint()..color = const Color(0xff1e261f),
    );
    // Yellow headlamps
    c.drawCircle(const Offset(-22, 58), 4, Paint()..color = const Color(0xffffdf80));
    c.drawCircle(const Offset(22, 58), 4, Paint()..color = const Color(0xffffdf80));

    c.restore();
  }

  void _drawHarborCrane(Canvas c) {
    final crane = Paint()
      ..color = const Color(0xffd9b763)
      ..strokeWidth = 8;
    c.drawLine(const Offset(235, 260), const Offset(1955, 260), crane);
    for (var x = 250.0; x < 1950; x += 90) {
      c.drawLine(Offset(x, 260), Offset(x + 45, 310), crane..strokeWidth = 3);
      c.drawLine(Offset(x + 45, 310), Offset(x + 90, 260), crane);
    }
    c.drawLine(
      const Offset(235, 310),
      const Offset(1955, 310),
      crane..strokeWidth = 5,
    );
  }

  // --- Props & Obstacles ---

  void _prop(Canvas c, FieldProp prop, FieldMap mapId) {
    final r = prop.rect;
    switch (prop.kind) {
      case PropKind.tree:
        // Twisted pine / gnarly dark tree with layered canopy
        c.drawOval(
          Rect.fromCenter(center: r.center + const Offset(4, 8), width: r.width * 1.1, height: r.height * .9),
          Paint()..color = Colors.black.withValues(alpha: .35),
        );
        // Base trunk
        c.drawCircle(r.center, r.width * .35, Paint()..color = const Color(0xff221b16));
        // Foliage layers
        c.drawCircle(r.center - const Offset(2, 2), r.width * .48, Paint()..color = const Color(0xff1a3327));
        c.drawCircle(r.center - const Offset(5, 5), r.width * .38, Paint()..color = const Color(0xff284f3e));
        c.drawCircle(r.center - const Offset(7, 7), r.width * .22, Paint()..color = const Color(0xff3b6b55));

      case PropKind.rock:
        // Weathered mossy stone
        final path = Path()
          ..moveTo(r.left + 14, r.top + r.height * .18)
          ..lineTo(r.right - 20, r.top)
          ..lineTo(r.right, r.center.dy)
          ..lineTo(r.right - 18, r.bottom)
          ..lineTo(r.left + 12, r.bottom - 10)
          ..lineTo(r.left, r.center.dy)
          ..close();
        c.drawPath(path, Paint()..color = prop.color);
        c.drawPath(
          path,
          Paint()
            ..color = const Color(0xff4a6258).withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );

      case PropKind.house:
        // Abandoned Victorian / Asian tiled building with warm amber window glow
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = prop.color,
        );
        // Dark roof slope
        c.drawRect(
          r.deflate(6),
          Paint()..color = const Color(0xff222a30),
        );
        // Roof ridge lines
        final ridge = Paint()
          ..color = const Color(0xff36444e)
          ..strokeWidth = 3;
        c.drawLine(r.topLeft + const Offset(12, 12), r.bottomRight - const Offset(12, 12), ridge);
        c.drawLine(r.topRight + const Offset(-12, 12), r.bottomLeft + const Offset(12, -12), ridge);

        // Windows with warm amber lantern glow
        final windowGlow = Paint()..color = const Color(0xffffb84d);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + 22, r.top + 20, 24, 16),
            const Radius.circular(2),
          ),
          windowGlow,
        );
        // Door
        c.drawRect(
          Rect.fromLTWH(r.right - 40, r.bottom - 28, 26, 26),
          Paint()..color = const Color(0xff573e2a),
        );

      case PropKind.container:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = prop.color,
        );
        for (var x = r.left + 12; x < r.right - 7; x += 16) {
          c.drawLine(
            Offset(x, r.top + 8),
            Offset(x, r.bottom - 8),
            Paint()
              ..color = Colors.black.withValues(alpha: .22)
              ..strokeWidth = 3,
          );
        }
        c.drawRRect(
          RRect.fromRectAndRadius(r.deflate(5), const Radius.circular(2)),
          Paint()
            ..color = Colors.white.withValues(alpha: .18)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        _label(c, 'GP / CARGO', r.center, Colors.white.withValues(alpha: .6), 11);

      case PropKind.tank:
        c.drawOval(r, Paint()..color = prop.color);
        c.drawOval(r.deflate(12), Paint()..color = const Color(0xff324346));
        c.drawOval(
          r.deflate(25),
          Paint()
            ..color = prop.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        c.drawCircle(r.center, 20, Paint()..color = const Color(0xff1b2628));

      case PropKind.machine:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..color = prop.color,
        );
        c.drawRect(r.deflate(8), Paint()..color = const Color(0xff29393e));
        c.drawCircle(r.center, 16, Paint()..color = const Color(0xffd5b161));

      case PropKind.pipe:
        c.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()..color = prop.color,
        );

      case PropKind.water:
        c.drawRect(r, Paint()..color = prop.color.withValues(alpha: .6));
        for (var y = r.top + 16; y < r.bottom; y += 28) {
          final wave = math.sin(model.elapsed * 2 + y) * 8;
          c.drawLine(
            Offset(r.left + 12 + wave, y),
            Offset(r.right - 12 + wave, y),
            Paint()
              ..color = const Color(0xff74afc4).withValues(alpha: .35)
              ..strokeWidth = 2,
          );
        }
    }
  }

  // --- Player: Dark Hunter with Red Scarf ---

  void _player(Canvas c) {
    final p = model.player;
    final dead = model.phase == FieldPhase.lost || model.dyingFor > 0;
    final hurt = model.hurtFor > 0;

    // Drop shadow
    c.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 6), width: 34, height: 22),
      Paint()..color = Colors.black.withValues(alpha: .45),
    );

    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(model.facing);

    if (dead) {
      // Fallen hunter on the ground
      c.rotate(0.9);
      c.scale(0.85);
    }

    // Hunter Boots
    final stride = math.sin(model.walkTime) * 6;
    for (final side in [-1, 1]) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-9 + stride * side, side * 11),
            width: 17,
            height: 9,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xff181e22),
      );
    }

    // Dark Trench Coat / Hunter Jacket
    final coatColor = hurt ? const Color(0xffc86454) : const Color(0xff26363d);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-15, -16, 32, 32),
        const Radius.circular(8),
      ),
      Paint()..color = coatColor,
    );
    // Coat collar & inner vest
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-18, -12, 14, 24),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xff4a5d52),
    );

    // SIGNATURE RED SCARF (from concept art!)
    final scarfFlutter = math.sin(model.walkTime * 1.5 + model.elapsed * 6) * 5;
    final scarfPath = Path()
      ..moveTo(-12, -4)
      ..quadraticBezierTo(-24, -8 + scarfFlutter, -38, -6 + scarfFlutter * 1.4)
      ..lineTo(-36, 2 + scarfFlutter * 1.2)
      ..quadraticBezierTo(-22, 0 + scarfFlutter, -10, 4)
      ..close();
    c.drawPath(scarfPath, Paint()..color = const Color(0xffd63031)); // Vivid crimson red
    c.drawCircle(const Offset(-9, 0), 6, Paint()..color = const Color(0xffc0392b));

    // Hunter Head & Dark Fedora / Cap
    c.drawCircle(const Offset(6, 0), 10, Paint()..color = const Color(0xffe0c3a2));
    c.drawArc(
      Rect.fromCircle(center: const Offset(4, 0), radius: 11),
      math.pi / 2,
      math.pi,
      true,
      Paint()..color = const Color(0xff1a2228),
    );

    // Hunting Rifle (Long barrel with wooden stock)
    // Wooden stock
    c.drawLine(
      const Offset(2, 9),
      const Offset(16, 9),
      Paint()
        ..color = const Color(0xff6e4a2c)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // Metal barrel
    c.drawLine(
      const Offset(16, 9),
      const Offset(40, 9),
      Paint()
        ..color = const Color(0xff1d2328)
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round,
    );
    // Muzzle tip
    c.drawCircle(const Offset(40, 9), 2.5, Paint()..color = const Color(0xff95a5a6));

    c.restore();

    // Dodging ring indicator
    if (model.rollFor > 0) {
      c.drawCircle(
        p,
        28,
        Paint()
          ..color = const Color(0xff68e8c5).withValues(alpha: .7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  // --- Spectral Shadow Beasts (Quái Vật Ma Mị) ---

  void _enemy(Canvas c, Creature e) {
    final p = e.position;
    final r = e.radius;
    final dead = !e.alive;
    final alpha = dead ? (e.death / .85).clamp(0.0, 1.0) : 1.0;

    c.saveLayer(
      Rect.fromCircle(center: p, radius: 150),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );

    // Ground shadow
    c.drawOval(
      Rect.fromCenter(center: p + const Offset(2, 8), width: r * 2.5, height: r * 1.7),
      Paint()..color = Colors.black.withValues(alpha: .45),
    );

    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(e.facing + (dead ? (1 - alpha) * 2.5 : 0));
    if (dead) c.scale(.5 + .5 * alpha);

    final gait = e.stun > 0 || e.charge > 0 || e.weak > 0
        ? 0.0
        : math.sin(e.animation * (e.kind == CreatureKind.runner ? 14 : 8)) * 5;

    switch (e.kind) {
      case CreatureKind.runner:
        // Spectral Stalker: Lean shadow fiend with long claws, trailing dark smoke, glowing cyan eyes
        // Dark spectral mist tail
        final tail = Path()
          ..moveTo(-r * 1.2, 0)
          ..quadraticBezierTo(-r * 2.2, gait, -r * 3.0, gait * 1.5)
          ..lineTo(-r * 2.2, -gait)
          ..close();
        c.drawPath(tail, Paint()..color = const Color(0xff122329).withValues(alpha: .6));

        // Claws
        for (final side in [-1, 1]) {
          c.drawLine(
            Offset(r * .4, side * r * .6),
            Offset(r * 1.5 + gait * side, side * r * .9),
            Paint()
              ..color = const Color(0xff1d2e33)
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round,
          );
        }
        // Shadow body
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 1.8, height: r * 1.4),
            Radius.circular(r * .5),
          ),
          Paint()..color = e.hit > 0 ? const Color(0xffff8080) : const Color(0xff162024),
        );
        // Piercing Cyan Eyes
        c.drawCircle(Offset(r * .6, -4), 3, Paint()..color = const Color(0xff00ffcc));
        c.drawCircle(Offset(r * .6, 4), 3, Paint()..color = const Color(0xff00ffcc));

      case CreatureKind.heavy:
        // Armored Golem: Bulky hulking beast with bone spikes
        for (final side in [-1, 1]) {
          c.drawLine(
            Offset(-r * .6, side * r * .8),
            Offset(-r * 1.2 + gait * side, side * r * 1.1),
            Paint()
              ..color = const Color(0xff2d3a3f)
              ..strokeWidth = r * .6
              ..strokeCap = StrokeCap.round,
          );
        }
        // Rocky jagged torso
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 2.1, height: r * 1.9),
            Radius.circular(r * .35),
          ),
          Paint()..color = e.hit > 0 ? const Color(0xffff8a65) : const Color(0xff3a484e),
        );
        // Bone carapace plates
        c.drawRect(
          Rect.fromCenter(center: Offset(-r * .2, 0), width: r * 1.0, height: r * 1.6),
          Paint()..color = const Color(0xff242e32),
        );
        // Fiery red/amber eyes
        c.drawCircle(Offset(r * .7, -5), 3.5, Paint()..color = const Color(0xffff5722));
        c.drawCircle(Offset(r * .7, 5), 3.5, Paint()..color = const Color(0xffff5722));

      case CreatureKind.jammer:
        // Void Wraith: Ethereal distortion specter with static glitch aura
        final pulse = (e.animation * 0.9) % 1;
        c.drawCircle(
          Offset.zero,
          r + pulse * 32,
          Paint()
            ..color = const Color(0xffb388ff).withValues(alpha: (1 - pulse) * .55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        // Shifting void body
        c.drawCircle(
          Offset.zero,
          r * 1.1,
          Paint()..color = e.hit > 0 ? Colors.white : const Color(0xff2c1b4d),
        );
        // Electric core
        c.drawCircle(
          Offset(r * .2, 0),
          r * .5,
          Paint()..color = const Color(0xff7c4dff),
        );
        // Cyan static eyes
        c.drawCircle(Offset(r * .5, -3), 2.5, Paint()..color = const Color(0xff80d8ff));
        c.drawCircle(Offset(r * .5, 3), 2.5, Paint()..color = const Color(0xff80d8ff));

      case CreatureKind.boss:
        // Colossal Ancient Overlord (Vật Chủ): Armored titan with horned helmet & glowing soul core
        // Great horned silhouette
        for (final side in [-1, 1]) {
          c.drawLine(
            Offset(r * .2, side * r * .8),
            Offset(r * .9, side * r * 1.6),
            Paint()
              ..color = const Color(0xffd4af37) // Golden horn tips
              ..strokeWidth = 6
              ..strokeCap = StrokeCap.round,
          );
        }
        // Heavy shoulders & chest plate
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: r * 2.3, height: r * 2.1),
            Radius.circular(r * .4),
          ),
          Paint()..color = e.hit > 0 ? const Color(0xffffd54f) : const Color(0xff222a30),
        );
        // Horned crown / cowl
        c.drawCircle(Offset(r * .5, 0), r * .6, Paint()..color = const Color(0xff181f24));
        // SOUL CORE (Lõi Linh Hồn) on chest
        final coreColor = e.weak > 0 ? const Color(0xffffd700) : const Color(0xff00e5ff);
        final coreGlow = e.weak > 0 ? 12.0 : 7.0;
        c.drawCircle(
          Offset(-r * .1, 0),
          coreGlow + math.sin(e.animation * 8) * 2,
          Paint()..color = coreColor.withValues(alpha: .4),
        );
        c.drawCircle(
          Offset(-r * .1, 0),
          coreGlow * .7,
          Paint()..color = coreColor,
        );
        // Eyes
        c.drawCircle(Offset(r * .7, -6), 4, Paint()..color = const Color(0xffff3d00));
        c.drawCircle(Offset(r * .7, 6), 4, Paint()..color = const Color(0xffff3d00));
    }

    c.restore();

    // Boss Charge & Weak Point Telegraph Rings
    if (e.charge > 0 || e.weak > 0) {
      final ringColor = e.charge > 0 ? const Color(0xffff1744) : const Color(0xffffd700);
      final radius = e.charge > 0 ? 130.0 : r + 12.0;
      c.drawCircle(
        p,
        radius,
        Paint()
          ..color = ringColor.withValues(alpha: .18 + .15 * math.sin(e.animation * 14).abs()),
      );
      c.drawCircle(
        p,
        radius,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Status label: STUN
    if (e.stun > 0) {
      _label(c, '⚡ CHOÁNG', p - Offset(0, r + 24), const Color(0xff80d8ff), 11);
    }

    // Health bar above enemy
    if (e.alive) {
      final bar = Rect.fromLTWH(p.dx - 28, p.dy - r - 14, 56, 4.5);
      c.drawRRect(
        RRect.fromRectAndRadius(bar, const Radius.circular(2)),
        Paint()..color = const Color(0xff0e171b),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bar.left, bar.top, bar.width * (e.health / e.maxHealth).clamp(0.0, 1.0), 4.5),
          const Radius.circular(2),
        ),
        Paint()..color = e.weak > 0 ? const Color(0xffffd700) : const Color(0xffff5252),
      );
      if (e.kind == CreatureKind.boss) {
        _label(
          c,
          e.charge > 0
              ? 'NẠP ĐÒN ĐẬP ĐẤT!'
              : e.weak > 0
              ? 'LỘ LÕI YẾU (BẮN NGAY!)'
              : 'VẬT CHỦ (GIÁP BẢO VỆ)',
          p - Offset(0, r + 30),
          const Color(0xffffd700),
          11,
        );
      }
    }

    c.restore();
  }

  // --- Items & Pickups ---

  void _item(Canvas c, FieldItem item) {
    final bob = math.sin(model.elapsed * 3.5 + item.position.dx) * 4;
    final p = item.position + Offset(0, bob);
    final color = item.kind == 'core'
        ? const Color(0xffffd700)
        : item.kind == 'health'
        ? const Color(0xff00e676)
        : const Color(0xff00b0ff);

    // Glow aura
    c.drawCircle(p, 25, Paint()..color = color.withValues(alpha: .2));

    if (item.kind == 'core') {
      // Golden Data Core
      final path = Path()
        ..moveTo(p.dx, p.dy - 14)
        ..lineTo(p.dx + 11, p.dy)
        ..lineTo(p.dx, p.dy + 14)
        ..lineTo(p.dx - 11, p.dy)
        ..close();
      c.drawPath(path, Paint()..color = color);
      c.drawCircle(p, 4, Paint()..color = Colors.white);
    } else {
      // First aid kit or ammo crate
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 26, height: 22),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xff1c2b30),
      );
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 26, height: 22),
          const Radius.circular(5),
        ),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _label(
        c,
        item.kind == 'health' ? '+' : 'AMMO',
        p - const Offset(0, 8),
        color,
        item.kind == 'health' ? 16 : 9,
      );
    }
  }

  // --- Particle Effects ---

  void _effect(Canvas c, FieldEffect e) {
    final t = (1 - e.life / e.maxLife).clamp(0.0, 1.0);
    switch (e.kind) {
      case 'trap':
        c.drawCircle(e.position, 65, Paint()..color = const Color(0xff00e5ff).withValues(alpha: .12));
        c.drawCircle(
          e.position,
          55 + math.sin(model.elapsed * 6) * 5,
          Paint()
            ..color = const Color(0xff80d8ff)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
        _label(c, 'BẪY ĐIỆN', e.position - const Offset(0, 6), const Color(0xffb388ff), 10);

      case 'flash':
      case 'slam':
        c.drawCircle(
          e.position,
          (e.kind == 'flash' ? 250 : 130) * t,
          Paint()
            ..color = (e.kind == 'flash' ? const Color(0xffe0f7fa) : const Color(0xffff3d00))
                .withValues(alpha: (1 - t) * .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - t),
        );

      case 'damage':
        _label(
          c,
          e.text,
          e.position,
          const Color(0xffffeb3b).withValues(alpha: 1 - t),
          14,
        );

      case 'muzzle':
      case 'spark':
        for (var i = 0; i < 7; i++) {
          final d = Offset(
            math.cos(i * math.pi / 3.5),
            math.sin(i * math.pi / 3.5),
          );
          c.drawLine(
            e.position + d * (3 + t * 10),
            e.position + d * (9 + t * 16),
            Paint()
              ..color = const Color(0xffffd54f).withValues(alpha: 1 - t)
              ..strokeWidth = 2.2,
          );
        }
    }
  }

  // --- Aiming Laser & Reticle ---

  void _drawAimLaserAndReticle(Canvas c) {
    final aim = model.aim;
    final player = model.player;
    final color = model.reloadFor > 0 ? const Color(0xffff9800) : const Color(0xffffe082);

    // Laser sight line
    c.drawLine(
      player,
      aim,
      Paint()
        ..color = color.withValues(alpha: .28)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    // Reticle circle
    c.drawCircle(
      aim,
      12,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    for (final d in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1),
    ]) {
      c.drawLine(aim + d * 15, aim + d * 22, Paint()..color = color..strokeWidth = 2.2);
    }
  }

  // --- Screen-Space Overlays: Hurt Vignette & Death Screen ---

  void _drawBloodVignette(Canvas c, Size size, double hurtIntensity) {
    c.drawRect(
      (Offset.zero & size).deflate(4),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            const Color(0xffd50000).withValues(alpha: (hurtIntensity * 0.7).clamp(0.0, 0.8)),
          ],
          stops: const [0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  void _drawDeathScreenOverlay(Canvas c, Size size) {
    // Pitch-black dark vignette creeping in
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xaa000000),
    );
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            const Color(0xff2b0000).withValues(alpha: .85),
          ],
          stops: const [0.4, 1.0],
        ).createShader(Offset.zero & size),
    );
  }

  void _label(Canvas c, String text, Offset p, Color color, double fontSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Segoe UI',
          fontSize: fontSize,
          color: color,
          fontWeight: FontWeight.w700,
          shadows: const [
            Shadow(blurRadius: 4, color: Colors.black),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(c, p - Offset(painter.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant ExplorationPainter oldDelegate) => true;
}

class FieldMinimap extends CustomPainter {
  FieldMinimap(this.model);
  final ExplorationModel model;

  @override
  void paint(Canvas c, Size size) {
    final sx = size.width / FieldWorld.width;
    final sy = size.height / FieldWorld.height;
    Offset p(Offset at) => Offset(at.dx * sx, at.dy * sy);

    c.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)),
      Paint()..color = const Color(0xf00b1419),
    );
    c.save();
    c.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(10)));

    for (final prop in model.world.props) {
      c.drawRect(
        Rect.fromLTRB(
          prop.rect.left * sx,
          prop.rect.top * sy,
          prop.rect.right * sx,
          prop.rect.bottom * sy,
        ),
        Paint()..color = prop.color.withValues(alpha: .35),
      );
    }
    for (final item in model.items.where((i) => i.kind == 'core' && !i.taken)) {
      c.drawCircle(p(item.position), 3.5, Paint()..color = const Color(0xffffd700));
    }
    if (!model.jammed) {
      for (final e in model.enemies.where((e) => e.alive && (e.position - model.player).distance < 450)) {
        c.drawCircle(
          p(e.position),
          e.kind == CreatureKind.boss ? 4.5 : 3.0,
          Paint()..color = const Color(0xffff5252),
        );
      }
    }
    c.drawCircle(
      p(FieldWorld.extraction),
      4.5,
      Paint()
        ..color = const Color(0xff6ef0c8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final player = p(model.player);
    final direction = Offset(math.cos(model.facing), math.sin(model.facing));
    c.drawLine(
      player,
      player + direction * 11,
      Paint()
        ..color = const Color(0xffe7f6ef)
        ..strokeWidth = 2,
    );
    c.drawCircle(player, 4.0, Paint()..color = const Color(0xffe7f6ef));
    c.restore();
  }

  @override
  bool shouldRepaint(covariant FieldMinimap oldDelegate) => true;
}

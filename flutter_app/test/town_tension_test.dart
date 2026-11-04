import 'dart:ui' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/survival/painter.dart';

ExplorationModel quietTown() =>
    ExplorationModel(FieldMap.town, survival: true, seed: 13)
      ..start()
      ..wave = 5;
void advance(ExplorationModel m, double seconds) {
  for (var t = 0.0; t < seconds; t += .025) {
    m.update(.025);
  }
}

void main() {
  test('town trees are passable while house footprints block movement', () {
    final w = quietTown().world;
    final trees = w.props.where((p) => p.kind == PropKind.tree).toList();
    expect(trees, isNotEmpty);
    expect(trees.every((p) => !p.solid), true);
    final tree = trees.first;
    var at = tree.rect.topCenter - const Offset(0, 35);
    final start = at;
    for (var i = 0; i < 30; i++) {
      at = w.move(at, const Offset(0, 5));
    }
    expect(at.dy, closeTo(start.dy + 150, .001));
    expect(w.inVegetation(tree.rect.center), true);

    final houses = w.props.where((p) => p.sprite == 0).toList();
    expect(houses, isNotEmpty);
    for (final house in houses) {
      expect(house.solid, true);
      expect(w.walkable(house.rect.center), false);
    }
    final house = houses.first;
    for (final radius in [16.0, 25.0]) {
      at = house.rect.bottomCenter + const Offset(0, 55);
      for (var i = 0; i < 40; i++) {
        at = w.move(at, const Offset(0, -5), radius);
      }
      expect(at.dy, greaterThanOrEqualTo(house.rect.bottom + radius));
      expect(at.dy, lessThan(house.rect.bottom + 55));
    }
  });

  test(
    'new arrivals cannot know the exact position of an already hidden player',
    () {
      final m = quietTown();
      m.player = m.world.hidingSpots.first.center;
      m.toggleHide();
      final e = m.spawn(CreatureKind.runner);
      expect((e.position - m.player).distance, greaterThan(450));
      expect(e.investigate, isNull);
      expect(e.lastKnown, isNull);
      expect(e.noiseFor, 0);
      advance(m, 1.3);
      expect(m.hidden, true);
      expect(e.huntState, HuntState.patrol);
    },
  );
  test(
    'one continuous town is four times larger and the camera reaches the new boundaries',
    () {
      final m = quietTown(), w = m.world;
      expect(
        w.mapWidth * w.mapHeight,
        FieldWorld.width * FieldWorld.height * 4,
      );
      expect(w.walkable(const Offset(4300, 3500), 24), true);
      final path = w.route(FieldWorld.spawn, const Offset(4300, 3500));
      expect(path, isNotEmpty);
      expect(path.last.dx, greaterThan(FieldWorld.width));
      expect(path.last.dy, greaterThan(FieldWorld.height));
      final view = TownView(
        const Offset(4300, 3500),
        const Size(1280, 800),
        world: w,
      );
      expect(view.bounds.left, greaterThan(FieldWorld.width));
      expect(view.bounds.top, greaterThan(FieldWorld.height));
      expect(view.bounds.contains(const Offset(4300, 3500)), true);
      final projected = view.project(const Offset(4300, 3500));
      expect((Offset.zero & const Size(1280, 800)).contains(projected), true);
      expect(view.unproject(projected).dx, closeTo(4300, .01));
      expect(view.unproject(projected).dy, closeTo(3500, .01));
    },
  );

  test(
    'every hiding spot is walkable and reachable without crossing cover',
    () {
      final m = quietTown();
      expect(m.world.hidingSpots.length, greaterThanOrEqualTo(6));
      for (final spot in m.world.hidingSpots) {
        expect(m.world.walkable(spot.center, 24), true, reason: spot.name);
        final path = m.world.route(m.player, spot.center);
        expect(path, isNotEmpty, reason: spot.name);
        var previous = m.player;
        for (final p in path) {
          expect(
            m.world.clearLine(previous, p, 16),
            true,
            reason: '${spot.name}: $previous -> $p',
          );
          previous = p;
        }
      }
    },
  );

  test(
    'hiding has a breath limit and exit cooldown, and combat can still hurt the player',
    () {
      final m = quietTown();
      m.player = m.world.hidingSpots.first.center;
      expect(m.toggleHide(), true);
      expect(m.hidden, true);
      m.pause();
      final breath = m.hideFor;
      m.update(.25);
      expect(m.hideFor, breath);
      m.resume();
      advance(m, 10.05);
      expect(m.hidden, false);
      expect(m.hideCooldown, greaterThan(0));
      expect(m.toggleHide(), false);
      advance(m, 3.1);
      expect(m.toggleHide(), true);
      m.hurt(8);
      expect(m.health, 92);
      expect(m.hidden, false);
    },
  );

  test(
    'shooting and moving leave hiding instead of giving invisibility during combat',
    () {
      final m = quietTown();
      m.player = m.world.hidingSpots.first.center;
      m.toggleHide();
      expect(m.shoot(m.player - const Offset(0, 100)), true);
      expect(m.hidden, false);
      advance(m, 3.1);
      m.toggleHide();
      m.movement = const Offset(0, -1);
      m.update(.025);
      expect(m.hidden, false);
    },
  );

  test(
    'creatures remember the last sighting but cannot track a concealed player forever',
    () {
      final m = quietTown();
      final oldPosition = m.player;
      final e = m.spawn(CreatureKind.runner, at: const Offset(1100, 1100));
      m.update(.025);
      expect(e.huntState, HuntState.chase);
      expect(e.lastKnown, oldPosition);
      m.player = m.world.hidingSpots.first.center;
      expect(m.toggleHide(), true);
      m.update(.025);
      expect(e.huntState, HuntState.investigate);
      expect(e.lastKnown, oldPosition);
      advance(m, 7.2);
      expect(m.hidden, true);
      expect(e.huntState, HuntState.patrol);
      expect(e.lastKnown, isNull);
    },
  );

  test(
    'a creature that checks the hiding place at close range exposes the player',
    () {
      final m = quietTown();
      m.player = m.world.hidingSpots.first.center;
      m.toggleHide();
      m.spawn(CreatureKind.runner, at: m.player - const Offset(0, 65));
      m.update(.025);
      expect(m.hidden, false);
      expect(m.message, contains('phát hiện'));
    },
  );

  test(
    'a gunshot attracts distant creatures while quiet cover blocks their sight',
    () {
      final m = quietTown();
      final e = m.spawn(CreatureKind.runner, at: const Offset(1100, 2400));
      m.update(.025);
      expect(e.huntState, HuntState.patrol);
      m.shoot(m.player - const Offset(0, 100));
      m.update(.025);
      expect(e.huntState, HuntState.investigate);
      expect(e.lastKnown, m.player);
    },
  );

  test('running can be heard behind a truck, quiet walking cannot', () {
    final m = quietTown()..player = const Offset(745, 1030);
    final e = m.spawn(CreatureKind.runner, at: const Offset(745, 1250));
    expect(m.world.clearLine(e.position, m.player), false);
    m.update(.025);
    expect(e.lastKnown, isNull);
    m.sprinting = true;
    m.movement = const Offset(1, 0);
    m.update(.025);
    expect(e.huntState, HuntState.investigate);
    expect(e.lastKnown, isNotNull);
  });

  test('approach howls use a bounded cooldown and freeze when paused', () {
    final m = quietTown();
    m.spawn(CreatureKind.runner, at: m.player - const Offset(0, 330));
    m.update(.025);
    expect(m.howlSerial, 1);
    expect(m.howlFor, greaterThan(0));
    advance(m, .5);
    expect(m.howlSerial, 1);
    m.pause();
    final cooldown = m.howlCooldown;
    m.update(.25);
    expect(m.howlCooldown, cooldown);
    expect(m.howlSerial, 1);
  });

  test('stunned and dead creatures cannot produce approach warnings', () {
    final m = quietTown();
    final e = m.spawn(CreatureKind.runner, at: m.player - const Offset(0, 200))
      ..stun = 4;
    m.update(.025);
    expect(m.howlSerial, 0);
    m.hit(e, 1000);
    m.update(.025);
    expect(m.nearestThreat, isNull);
    expect(m.howlSerial, 0);
  });

  test('critical health clears on healing and blackouts freeze on pause', () {
    final m = quietTown();
    m.hurt(75);
    expect(m.lowHealth, true);
    m.player = m.world.supplies.first;
    m.update(.025);
    expect(m.health, 25);
    expect(m.medkits, 2);
    expect(m.useMedkit(), true);
    advance(m, 2.9);
    expect(m.health, 65);
    expect(m.lowHealth, false);
    m.elapsed = 51.99;
    m.update(.025);
    expect(m.blackoutFor, greaterThan(13));
    m.pause();
    final blackout = m.blackoutFor;
    m.update(.25);
    expect(m.blackoutFor, blackout);
  });
}

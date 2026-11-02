import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/exploration/model.dart';
import 'package:gestureplay/exploration/world.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/survival/hand_input.dart';
import 'package:gestureplay/survival/view.dart';

void main() {
  test('oblique camera round trips aim and includes all viewport corners', () {
    final world = FieldWorld(FieldMap.town, quarantine: true);
    for (final size in const [
      Size(1280, 800),
      Size(844, 390),
      Size(390, 844),
    ]) {
      for (final focus in const [
        FieldWorld.spawn,
        Offset(80, 80),
        Offset(4300, 3500),
      ]) {
        final view = TownView(focus, size, world: world);
        expect((Offset.zero & size).contains(view.project(focus)), true);
        for (final screen in [
          Offset.zero,
          Offset(size.width, size.height),
          size.center(Offset.zero),
        ]) {
          final point = view.unproject(screen);
          final back = view.project(point);
          expect(back.dx, closeTo(screen.dx, .00001));
          expect(back.dy, closeTo(screen.dy, .00001));
          expect(view.bounds.inflate(.01).contains(point), true);
          for (var stance = 0; stance < 3; stance++) {
            final shot = view.projectShot(
              view.unprojectShot(screen, TownView.muzzleHeight(stance)),
              TownView.muzzleHeight(stance),
            );
            expect((shot - screen).distance, lessThan(.00001));
          }
        }
      }
    }
  });

  test(
    'screen input points the same way after projection at every analog strength',
    () {
      for (final direction in const [
        Offset(0, -1),
        Offset(1, 0),
        Offset(0, 1),
        Offset(-1, 0),
        Offset(.3, .6),
      ]) {
        final movement = TownView.movement(direction);
        final projected = TownView.floor(movement);
        expect(movement.distance, closeTo(direction.distance, .00001));
        expect(projected.direction, closeTo(direction.direction, .00001));
      }
      expect(TownView.movement(Offset.zero), Offset.zero);
      expect(
        TownView.movement(const Offset(10, 10)).distance,
        closeTo(1, .00001),
      );
    },
  );

  test('open palm and pinch still move and aim right on the tilted street', () {
    final m = ExplorationModel(FieldMap.town, survival: true)
      ..start()
      ..wave = 5;
    final bridge = HandBridge(autoLaunch: false, clock: () => 0);
    addTearDown(bridge.dispose);
    final input = TownHandInput();
    var seq = 0;
    void sample(double x, {bool pinch = false}) {
      bridge.acceptPacket({
        'type': 'hand',
        'protocol': 1,
        'epoch': 'oblique',
        'seq': ++seq,
        'jump_id': 0,
        'age_ms': 0,
        'valid': true,
        'ready': true,
        'released': !pinch,
        'pinched': pinch,
        'fist': false,
        'palm_x': x,
        'palm_y': .5,
      });
      input.apply(m, bridge, .05);
    }

    sample(.5);
    sample(.7);
    final move = TownView.floor(m.movement);
    expect(move.dx, greaterThan(0));
    expect(move.dy, closeTo(0, .00001));
    sample(.7, pinch: true);
    expect(m.firing, true);
    expect(m.movement, Offset.zero);
    final aim = TownView.floor(m.aim - m.player);
    expect(aim.dx, greaterThan(0));
    expect(aim.dy, closeTo(0, .00001));
    expect(aim.direction.abs(), lessThan(math.pi / 180));
    sample(.7);
    expect(m.firing, false);
  });
}

import 'dart:ui';
import '../services/hand_bridge.dart';
import 'model.dart';

class FieldHandInput {
  Offset? center;
  bool _fist = false;
  void reset() {
    center = null;
    _fist = false;
  }

  void apply(ExplorationModel model, HandBridge hand) {
    if (!hand.valid || !hand.ready) {
      model.movement = Offset.zero;
      model.firing = false;
      model.pause();
      _fist = false;
      return;
    }
    final packet = hand.latest!;
    final x = packet.number('palm_x'), y = packet.number('palm_y');
    if (x == null || y == null) {
      model.movement = Offset.zero;
      model.firing = false;
      model.pause();
      return;
    }
    final palm = Offset(x, y);
    center ??= palm;
    final delta = palm - center!;
    double dead(double value) =>
        value.abs() <= .04 ? 0 : value.sign * (value.abs() - .04);
    final direction = Offset(dead(delta.dx), dead(delta.dy));
    final fist = packet.flag('fist') || packet.flag('fist_pending');
    model.sprinting = false;
    model.movement = hand.pinched || fist ? Offset.zero : direction / .16;
    model.firing = hand.pinched && !fist;
    if (hand.pinched && direction.distance > .018) {
      model.aim = model.player + direction / direction.distance * 400;
    }
    if (packet.flag('fist') && !_fist) model.reload();
    _fist = packet.flag('fist');
  }
}

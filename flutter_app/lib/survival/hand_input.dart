import 'dart:ui';
import '../exploration/model.dart';
import '../services/hand_bridge.dart';
import 'view.dart';

/// Short fist reloads on release. A long fist exclusively opens the skill
/// wheel. Pinching always fires and can never accidentally trigger a roll.
class TownHandInput {
  Offset? center;
  double heldFor = 0;
  bool wheelOpen = false, waitingRelease = false, _pinched = false;
  int selection = 0;
  int? _queued;
  Offset? _previousPalm;
  double _time = 0, _sampleAt = 0;
  int _sequence = -1;
  bool _rollArmed = true;

  void reset() {
    center = null;
    heldFor = 0;
    wheelOpen = waitingRelease = _pinched = false;
    _queued = null;
    _previousPalm = null;
    _time = _sampleAt = 0;
    _sequence = -1;
    _rollArmed = true;
  }

  void select(int? skill) {
    wheelOpen = false;
    waitingRelease = true;
    _queued = skill;
  }

  void apply(ExplorationModel model, HandBridge hand, double dt) {
    _time += dt;
    if (!hand.valid || !hand.ready) {
      model.pause();
      model.movement = Offset.zero;
      model.firing = false;
      heldFor = 0;
      wheelOpen = waitingRelease = false;
      _queued = null;
      _previousPalm = null;
      return;
    }
    final packet = hand.latest!;
    final x = packet.number('palm_x'), y = packet.number('palm_y');
    if (x == null || y == null) {
      model.pause();
      return;
    }
    final palm = Offset(x, y);
    center ??= palm;
    final fist = packet.flag('fist') || packet.flag('fist_pending');
    if (waitingRelease) {
      if (hand.released && !hand.pinched && !fist) {
        waitingRelease = false;
        center = palm;
        _previousPalm = palm;
        _sequence = packet.sequence;
        _sampleAt = _time;
        _rollArmed = true;
        model.resume();
        if (_queued == 0) model.flash();
        if (_queued == 1) model.trap();
        if (_queued == 2) model.toggleHide();
        if (_queued != null && _queued! >= 3 && _queued! <= 5) {
          model.setStance(PlayerStance.values[_queued! - 3]);
        }
        _queued = null;
        heldFor = 0;
      }
      return;
    }
    if (wheelOpen) {
      final xOffset = palm.dx - center!.dx;
      selection = palm.dy - center!.dy > .1
          ? (xOffset < -.06
                ? 3
                : xOffset > .06
                ? 5
                : 4)
          : xOffset < -.06
          ? 0
          : xOffset > .06
          ? 1
          : 2;
      if (_pinched && !hand.pinched) select(selection);
      _pinched = hand.pinched;
      return;
    }
    if (!model.active) return;
    if (fist) {
      heldFor += dt;
      model.movement = Offset.zero;
      model.firing = false;
      if (heldFor >= .8) {
        model.pause();
        wheelOpen = true;
        _pinched = false;
      }
      return;
    }
    if (heldFor > 0) {
      model.reload();
      heldFor = 0;
    }
    final delta = palm - center!;
    // The legacy Python jump_id is a pinch event. It must not cause a roll.
    // A fresh upward palm flick rolls once; returning to neutral rearms it.
    if (packet.sequence != _sequence) {
      final previous = _previousPalm;
      final age = _time - _sampleAt;
      if (!hand.pinched &&
          _rollArmed &&
          previous != null &&
          age > 0 &&
          age <= .15 &&
          delta.dy < -.12 &&
          (previous.dy - palm.dy) / age > 1.2) {
        model.roll();
        _rollArmed = false;
      }
      if (delta.dy > -.04) _rollArmed = true;
      _previousPalm = palm;
      _sampleAt = _time;
      _sequence = packet.sequence;
    }
    double dead(double v) => v.abs() <= .04 ? 0 : v.sign * (v.abs() - .04);
    final direction = Offset(dead(delta.dx), dead(delta.dy));
    model.sprinting = false;
    model.movement = hand.pinched
        ? Offset.zero
        : TownView.movement(direction / .16);
    model.firing = hand.pinched;
    if (hand.pinched && direction.distance > .018) {
      model.aim =
          model.player +
          TownView.movement(direction / direction.distance) * 400;
    }
  }
}

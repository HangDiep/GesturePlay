import 'dart:ui';
import '../exploration/model.dart';
import '../services/hand_bridge.dart';
import 'view.dart';

/// Single-hand controls retain their original mapping. Two-hand controls keep
/// movement, aim and exclusive release gestures independent.
class TownHandInput {
  bool twoHands = false, swapHands = false;
  double movementSensitivity = 1, pointerSensitivity = 1;
  Offset? aimCenter, _aimDirection;
  double _leftFistFor = 0,
      _rightFistFor = 0,
      _leftPinchFor = 0,
      _bothFistFor = 0;
  bool _dualArmed = false, _menuArmed = false;
  String _dualEpoch = '';
  double _menuPinchFor = 0;
  static const startFistSeconds = .45;
  double _startFistFor = 0;
  bool _startFistLatched = false;
  bool _startFistBlocked = false;
  double get startFistProgress =>
      (_startFistFor / startFistSeconds).clamp(0, 1);
  int? _uiAction;
  int? takeUiAction() {
    final action = _uiAction;
    _uiAction = null;
    return action;
  }

  Offset? center;
  Offset? wheelAnchor;
  double heldFor = 0;
  bool wheelOpen = false, waitingRelease = false, _pinched = false;
  int selection = 0;
  int? _queued;
  Offset? _previousPalm;
  double _time = 0, _sampleAt = 0;
  int _sequence = -1;
  bool _rollArmed = true;

  void reset() {
    aimCenter = _aimDirection = null;
    _leftFistFor = _rightFistFor = _leftPinchFor = _bothFistFor = 0;
    _dualArmed = false;
    _dualEpoch = '';
    _startFistFor = 0;
    _startFistLatched = false;
    _startFistBlocked = false;
    _uiAction = null;
    clearMenuConfirm();
    center = null;
    wheelAnchor = null;
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
    if (twoHands) {
      _applyTwoHands(model, hand, dt);
      return;
    }
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
        if (_queued == 0) model.reload();
        if (_queued == 1) model.roll();
        if (_queued == 2) model.toggleHide();
        if (_queued == 6) model.useMedkit();
        if (_queued == 7) model.cycleWeapon();
        if (_queued == 8) model.interact();
        if (_queued != null && _queued! >= 3 && _queued! <= 5) {
          model.setStance(PlayerStance.values[_queued! - 3]);
        }
        _queued = null;
        heldFor = 0;
      }
      return;
    }
    if (wheelOpen) {
      final anchor = wheelAnchor ?? center!;
      final xOffset = palm.dx - anchor.dx;
      selection = palm.dy - anchor.dy > .24
          ? (xOffset < -.06
                ? 6
                : xOffset > .06
                ? 8
                : 7)
          : palm.dy - anchor.dy > .1
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
        wheelAnchor = Offset(
          center!.dx.clamp(.35, .65),
          center!.dy.clamp(.28, .5),
        );
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
        : TownView.movement(direction * movementSensitivity / .16);
    model.firing = hand.pinched;
    if (hand.pinched && direction.distance > .018) {
      model.aim =
          model.player +
          TownView.movement(direction / direction.distance) *
              400 *
              pointerSensitivity;
    }
  }

  HandPacket? moveHand(HandBridge hand) => swapHands ? hand.right : hand.left;
  HandPacket? aimHand(HandBridge hand) => swapHands ? hand.left : hand.right;

  /// Start and pause-screen Continue use the physical right fist even when
  /// roles are swapped. Gameplay waits for both open hands after confirmation.
  bool startConfirm(HandBridge hand, double dt) {
    if (!twoHands || !hand.handReady('right')) {
      _startFistFor = 0;
      _startFistLatched = false;
      return false;
    }
    final right = hand.right!;
    if (_startFistBlocked) {
      if (right.open) _startFistBlocked = false;
      return false;
    }
    if (!right.flag('fist')) {
      _startFistFor = 0;
      _startFistLatched = false;
      return false;
    }
    if (_startFistLatched) return false;
    _startFistFor += dt.clamp(0, .1);
    if (_startFistFor < startFistSeconds) return false;
    _startFistLatched = true;
    return true;
  }

  /// Do not turn a fist already held when pausing into a new Continue press.
  void blockHeldFist(HandBridge hand) {
    _startFistFor = 0;
    _startFistLatched = false;
    _startFistBlocked =
        hand.right?.flag('fist') == true ||
        hand.right?.flag('fist_pending') == true;
  }

  void clearMenuConfirm() {
    _menuArmed = false;
    _menuPinchFor = 0;
  }

  /// An explicit open -> pinch -> open sequence; reacquiring hands alone never resumes.
  bool menuConfirm(HandBridge hand, double dt) {
    if (!twoHands || !hand.twoHandsReady || !moveHand(hand)!.open) {
      clearMenuConfirm();
      return false;
    }
    final aim = aimHand(hand)!;
    if (aim.open) {
      final confirmed = _menuArmed && _menuPinchFor >= .12;
      _menuArmed = true;
      _menuPinchFor = 0;
      return confirmed;
    }
    if (aim.flag('fist') || aim.flag('fist_pending')) {
      clearMenuConfirm();
      return false;
    }
    if (_menuArmed && aim.flag('pinched')) _menuPinchFor += dt;
    return false;
  }

  void _perform(ExplorationModel m, int? action) {
    switch (action) {
      case 0:
        m.reload();
      case 1:
        m.roll();
      case 2:
        m.toggleHide();
      case 3:
        m.setStance(PlayerStance.standing);
      case 4:
        m.setStance(PlayerStance.crouching);
      case 5:
        m.setStance(PlayerStance.prone);
      case 6:
        m.useMedkit();
      case 7:
        m.cycleWeapon();
      case 8:
        m.interact();
      case 9 || 10 || 11:
        _uiAction = action;
    }
  }

  void _applyTwoHands(ExplorationModel m, HandBridge hand, double dt) {
    _time += dt;
    if (!hand.twoHandsReady) {
      m.pause();
      m.movement = Offset.zero;
      m.firing = m.sprinting = false;
      reset();
      return;
    }
    if (_dualEpoch.isNotEmpty && _dualEpoch != hand.latest!.epoch) {
      m.pause();
      m.movement = Offset.zero;
      m.firing = false;
      reset();
      return;
    }
    _dualEpoch = hand.latest!.epoch;
    final left = moveHand(hand)!, right = aimHand(hand)!;
    final lp = left.palm!, rp = right.palm!;
    final lf = left.flag('fist') || left.flag('fist_pending');
    final rf = right.flag('fist') || right.flag('fist_pending');
    final clean = left.open && right.open;
    if (waitingRelease) {
      if (clean) {
        waitingRelease = false;
        center = lp;
        aimCenter = rp;
        _previousPalm = lp;
        _sequence = hand.latest!.sequence;
        _sampleAt = _time;
        _rollArmed = _dualArmed = true;
        _leftFistFor = _rightFistFor = _leftPinchFor = _bothFistFor = 0;
        m.resume();
        _perform(m, _queued);
        _queued = null;
      }
      return;
    }
    if (wheelOpen) {
      if (left.flag('pinched') && !lf) {
        select(null);
        return;
      }
      final delta = rp - wheelAnchor!;
      final column = delta.dx < -.06
          ? 0
          : delta.dx > .06
          ? 2
          : 1;
      final row = delta.dy > .37
          ? 3
          : delta.dy > .24
          ? 2
          : delta.dy > .1
          ? 1
          : 0;
      selection = const [
        [0, 2, 1],
        [3, 4, 5],
        [6, 7, 8],
        [9, 10, 11],
      ][row][column];
      if (_pinched && !right.flag('pinched') && !rf) select(selection);
      _pinched = right.flag('pinched') && !rf;
      return;
    }
    if (!m.active) return;
    clearMenuConfirm();
    if (!_dualArmed) {
      m.firing = false;
      m.movement = Offset.zero;
      if (clean) {
        _dualArmed = true;
        center = lp;
        aimCenter = rp;
        _previousPalm = lp;
        _sequence = hand.latest!.sequence;
        _sampleAt = _time;
        final delta = m.aim - m.player;
        _aimDirection = delta.distance > 1
            ? delta / delta.distance
            : const Offset(0, -1);
      }
      return;
    }
    m.sprinting = false;
    if (lf && rf) {
      _bothFistFor += dt;
      m.movement = Offset.zero;
      m.firing = false;
      _leftFistFor = _rightFistFor = _leftPinchFor = 0;
      if (_bothFistFor >= .8) {
        m.pause();
        reset();
      }
      return;
    }
    if (_bothFistFor > 0) {
      _bothFistFor = 0;
      center = lp;
      aimCenter = rp;
      m.movement = Offset.zero;
      m.firing = false;
      return;
    }
    if (lf) {
      _leftFistFor += dt;
      _leftPinchFor = 0;
      m.movement = Offset.zero;
      m.firing = false;
      if (_leftFistFor >= .8) {
        m.pause();
        wheelOpen = true;
        _pinched = false;
        wheelAnchor = Offset(rp.dx.clamp(.2, .8), rp.dy.clamp(.2, .4));
      }
      return;
    }
    if (_leftFistFor > 0) {
      if (_leftFistFor >= .12) {
        m.setStance(PlayerStance.values[(m.stance.index + 1) % 3]);
      }
      _leftFistFor = 0;
      center = lp;
      _previousPalm = lp;
    }
    if (left.flag('pinched')) {
      _leftPinchFor += dt;
      m.movement = Offset.zero;
    } else {
      if (_leftPinchFor >= .8) {
        m.useMedkit();
      } else if (_leftPinchFor >= .12) {
        if (m.nearbyDoor != null || m.nearbyStash != null) {
          m.interact();
        } else {
          m.toggleHide();
        }
      }
      if (_leftPinchFor > 0) {
        center = lp;
        _previousPalm = lp;
      }
      _leftPinchFor = 0;
      double dead(double v) => v.abs() <= .04 ? 0 : v.sign * (v.abs() - .04);
      final delta = lp - center!;
      m.movement = TownView.movement(
        Offset(dead(delta.dx), dead(delta.dy)) * movementSensitivity / .16,
      );
      if (hand.latest!.sequence != _sequence) {
        final age = _time - _sampleAt;
        if (_rollArmed &&
            _previousPalm != null &&
            age > 0 &&
            age <= .15 &&
            delta.dy < -.12 &&
            (_previousPalm!.dy - lp.dy) / age > 1.2) {
          m.roll();
          _rollArmed = false;
        }
        if (delta.dy > -.04) _rollArmed = true;
        _previousPalm = lp;
        _sequence = hand.latest!.sequence;
        _sampleAt = _time;
      }
    }
    if (rf) {
      _rightFistFor += dt;
      m.firing = false;
    } else {
      if (_rightFistFor >= .8) {
        m.cycleWeapon();
      } else if (_rightFistFor >= .12) {
        m.reload();
      }
      if (_rightFistFor > 0) aimCenter = rp;
      _rightFistFor = 0;
      final delta = rp - aimCenter!;
      if (delta.distance > .04) {
        _aimDirection = TownView.movement(delta / delta.distance);
      }
      m.aim =
          m.player +
          (_aimDirection ?? const Offset(0, -1)) * 500 * pointerSensitivity;
      m.firing = right.flag('pinched');
    }
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../services/hand_bridge.dart';
import 'gesture_pointer.dart';
import 'model.dart';
import 'settings.dart';

enum SignalPage { home, setup, calibration, tutorial, settings, game, result }

class SignalController extends ChangeNotifier {
  SignalController(this.hand, this.settings);
  final HandBridge hand;
  final SignalSettings settings;
  final pointer = GesturePointer();
  SignalPage page = SignalPage.home;
  SignalDifficulty difficulty = SignalDifficulty.easy;
  bool handControl = false, advanced = true, focused = true, preview = true;
  bool training = false,
      trainingSelected = false,
      trainingDragged = false,
      trainingLocked = false;
  double countdown = 0, _ui = 0;
  SignalModel? model;
  String pauseReason = '';
  int practiceShots = 0;
  void Function(HandPointerEvent)? onPointer;
  bool _disposed = false;
  bool get inputReady =>
      !handControl ||
      (hand.ready && hand.released && hand.latest?.flag('fist') != true);
  bool get inRound => page == SignalPage.game && model != null;
  bool get needsHand =>
      handControl &&
      (inRound ||
          page == SignalPage.calibration ||
          page == SignalPage.tutorial);
  void refresh() {
    if (!_disposed) notifyListeners();
  }

  void navigate(SignalPage target) {
    if (model?.active == true) pause('Bạn đã rời màn chơi.');
    page = target;
    _cancelPointer();
    if (needsHand) {
      unawaited(hand.start());
      hand.setPreview(true);
    } else {
      hand.stop();
    }
    refresh();
  }

  void setHand(bool value) {
    if (model?.active == true) return;
    handControl = value;
    _cancelPointer();
    if (needsHand) {
      unawaited(hand.start());
      hand.setPreview(true);
    } else {
      hand.stop();
    }
    refresh();
  }

  void prepare() {
    training = false;
    model = SignalModel(
      difficulty: difficulty,
      advanced: advanced,
      seed: DateTime.now().millisecondsSinceEpoch,
    );
    countdown = 3;
    pauseReason = '';
    page = SignalPage.game;
    _cancelPointer();
    if (handControl) {
      unawaited(hand.start());
      hand.setPreview(preview);
    } else {
      hand.stop();
    }
    refresh();
  }

  void pause(String reason) {
    if (!inRound || model!.finished || model!.phase == RoundPhase.paused) {
      return;
    }
    model!.pause();
    if (model!.phase == RoundPhase.ready) model!.phase = RoundPhase.paused;
    countdown = 0;
    pauseReason = reason;
    _cancelPointer();
    refresh();
  }

  void resume() {
    if (!inRound ||
        model!.phase != RoundPhase.paused ||
        !focused ||
        !inputReady) {
      return;
    }
    countdown = 2;
    pauseReason = '';
    _cancelPointer();
    refresh();
  }

  void _cancelPointer() {
    onPointer?.call(HandPointerEvent(PointerAction.cancel, pointer.position));
    pointer.reset();
  }

  void setFocus(bool value) {
    focused = value;
    if (!value) pause('Cửa sổ đang ở nền.');
    refresh();
  }

  void abandon() {
    model?.abandon();
    countdown = 0;
    hand.stop();
    _cancelPointer();
    page = SignalPage.home;
    refresh();
  }

  void action(void Function(SignalModel) action) {
    final game = model;
    if (game == null || !game.active) return;
    action(game);
    refresh();
  }

  void tick(double dt) {
    if (_disposed || !dt.isFinite || dt < 0) return;
    dt = dt.clamp(0, .1);
    if (needsHand) {
      final packet = hand.latest;
      final points = packet?.points ?? const <Offset>[];
      final palmX = packet?.number('palm_x'), palmY = packet?.number('palm_y');
      final events = pointer.update(
        valid:
            hand.valid &&
            points.length == 2 &&
            packet?.flag('fist_pending') != true,
        epoch: packet?.epoch ?? '',
        sequence: packet?.sequence ?? -1,
        target: points.length == 2 ? points[1] : pointer.position,
        palm: palmX != null && palmY != null ? Offset(palmX, palmY) : null,
        pinched: hand.pinched,
        fist: packet?.flag('fist') == true,
        sensitivity: settings.sensitivity,
      );
      for (final event in events) {
        if (event.action == PointerAction.fist) {
          if (page == SignalPage.tutorial) {
            trainingLocked = true;
          } else if (model?.active == true) {
            if (model!.hasSelectedDoor) {
              model!.toggleDoor(model!.selectedDoor, emergency: true);
            } else {
              model!.notify(
                'Hãy chọn cửa trái hoặc phải trước khi nắm tay.',
                'denied',
              );
            }
          }
        } else {
          onPointer?.call(event);
        }
      }
    }
    if (inRound && !model!.finished) {
      if ((!focused || (handControl && !hand.valid)) &&
          model!.phase != RoundPhase.paused) {
        pause(
          !focused
              ? 'Cửa sổ đang ở nền.'
              : 'Mất bàn tay hoặc kết nối nhận diện.',
        );
      } else if (countdown > 0) {
        if (!handControl || hand.ready) {
          countdown = (countdown - dt).clamp(0, 3);
          if (countdown == 0) {
            if (model!.phase == RoundPhase.ready) {
              model!.start();
            } else {
              model!.resume();
            }
            _cancelPointer();
          }
        }
      } else if (model!.active) {
        model!.update(dt);
        if (model!.finished) {
          page = SignalPage.result;
          hand.stop();
          _cancelPointer();
        }
      }
    }
    _ui += dt;
    if (_ui >= 1 / 30) {
      _ui = 0;
      refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelPointer();
    hand.stop();
    super.dispose();
  }
}

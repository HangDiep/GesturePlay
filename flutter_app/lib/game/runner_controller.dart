import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../services/hand_bridge.dart';
import '../services/local_scores.dart';
import 'runner_model.dart';

enum GameScene { menu, preparing, countdown, playing, paused, result }

class RunnerController extends ChangeNotifier {
  RunnerController(this.hand, this.scores);
  final HandBridge hand;
  final LocalScores scores;
  GameScene scene = GameScene.menu;
  Difficulty difficulty = Difficulty.normal;
  ControlMode control = ControlMode.hand;
  RunnerModel? game;
  RunnerResult? result;
  bool saving = false,
      saved = false,
      previewEnabled = false,
      showMetrics = false,
      focused = true;
  double countdown = 3, _uiTime = 0, _fpsTime = 0;
  int _frames = 0;
  double fps = 0;
  String pauseReason = '';
  bool _resumeCountdown = false, _jump = false, _disposed = false;
  bool get canBegin =>
      control == ControlMode.keyboard || (hand.ready && hand.released);
  bool get canResume =>
      focused &&
      (control == ControlMode.keyboard || (hand.ready && hand.released));
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void selectDifficulty(Difficulty value) {
    difficulty = value;
    _notify();
  }

  void prepare([ControlMode? mode]) {
    control = mode ?? control;
    game = RunnerModel(difficulty: difficulty, control: control);
    result = null;
    saved = saving = false;
    scene = GameScene.preparing;
    _jump = false;
    hand.discardJumps();
    if (control == ControlMode.hand) {
      hand.setPreview(true);
      unawaited(hand.start());
    } else {
      hand.stop();
    }
    _notify();
  }

  void begin() {
    if (scene != GameScene.preparing || !canBegin) return;
    countdown = 3;
    _resumeCountdown = false;
    scene = GameScene.countdown;
    hand.setPreview(previewEnabled);
    hand.discardJumps();
    _notify();
  }

  void pause([String reason = 'Bạn đã tạm dừng']) {
    if (scene != GameScene.playing) return;
    game!.pause();
    scene = GameScene.paused;
    pauseReason = reason;
    _jump = false;
    _notify();
  }

  void resume() {
    if (scene != GameScene.paused || !canResume) return;
    countdown = 2;
    _resumeCountdown = true;
    scene = GameScene.countdown;
    hand.discardJumps();
    _notify();
  }

  void menu() {
    game?.pause();
    game = null;
    scene = GameScene.menu;
    hand.stop();
    _jump = false;
    _notify();
  }

  void jump() {
    if (scene == GameScene.playing && control == ControlMode.keyboard) {
      _jump = true;
    }
  }

  void togglePreview() {
    previewEnabled = !previewEnabled;
    hand.setPreview(previewEnabled || scene == GameScene.preparing);
    _notify();
  }

  void toggleMetrics() {
    showMetrics = !showMetrics;
    _notify();
  }

  void lostFocus() {
    focused = false;
    if (scene == GameScene.countdown) {
      scene = _resumeCountdown ? GameScene.paused : GameScene.preparing;
      pauseReason = 'Cửa sổ vừa mất tiêu điểm';
      _notify();
    } else {
      pause('Cửa sổ vừa mất tiêu điểm');
    }
  }

  void tick(double rawDt) {
    final dt = math.min(.1, math.max(0.0, rawDt));
    _frames++;
    _fpsTime += rawDt.isFinite && rawDt >= 0 ? rawDt : 0;
    _uiTime += dt;
    if (_fpsTime >= 1) {
      fps = _frames / _fpsTime;
      _frames = 0;
      _fpsTime = 0;
    }
    final handJump = hand.consumeJump();
    if (scene == GameScene.countdown) {
      if (!focused || (control == ControlMode.hand && !hand.valid)) {
        scene = _resumeCountdown ? GameScene.paused : GameScene.preparing;
        pauseReason = 'Chờ tín hiệu bàn tay ổn định';
        if (scene == GameScene.preparing) hand.setPreview(true);
        _notify();
        return;
      }
      countdown = math.max(0, countdown - dt);
      if (countdown <= 1e-8) {
        game!.start();
        scene = GameScene.playing;
        hand.discardJumps();
        _notify();
      }
    } else if (scene == GameScene.playing) {
      if (!focused) {
        pause('Cửa sổ vừa mất tiêu điểm');
        return;
      }
      if (control == ControlMode.hand && !hand.valid) {
        pause('Mất tín hiệu bàn tay · ván chơi đã dừng');
        return;
      }
      game!.update(
        dt,
        jumpPressed: control == ControlMode.hand ? handJump : _jump,
      );
      _jump = false;
      if (game!.finished) {
        result = game!.result();
        scene = GameScene.result;
        hand.stop();
        unawaited(save());
        _notify();
      }
    }
    if (_uiTime >= .1) {
      _uiTime = 0;
      _notify();
    }
  }

  Future<void> save() async {
    final report = result;
    if (report == null || saving) return;
    saving = true;
    _notify();
    final success = await scores.save(report);
    if (!_disposed && result?.id == report.id) {
      saved = success;
      saving = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    hand.stop();
    super.dispose();
  }
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/game/runner_controller.dart';
import 'package:gestureplay/game/runner_model.dart';
import 'package:gestureplay/services/hand_bridge.dart';
import 'package:gestureplay/services/local_scores.dart';

Map<String, dynamic> packet(
  int seq, {
  int jump = 0,
  String epoch = 'one',
  bool valid = true,
}) => {
  'type': 'hand',
  'protocol': 1,
  'epoch': epoch,
  'seq': seq,
  'jump_id': jump,
  'valid': valid,
  'ready': true,
  'released': true,
  'pinched': false,
  'age_ms': 20,
};

class FakeHand extends HandBridge {
  FakeHand(int Function() clock) : super(autoLaunch: false, clock: clock);
  int starts = 0, stops = 0;
  @override
  Future<void> start() async {
    starts++;
  }

  @override
  void stop() {
    stops++;
    discardJumps();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'latched jump survives packet gaps but each event is consumed only once',
    () {
      final hand = HandBridge(autoLaunch: false, clock: () => 0);
      addTearDown(hand.dispose);
      hand.acceptPacket(packet(1));
      hand.discardJumps();
      hand.acceptPacket(packet(4, jump: 1));
      expect(hand.consumeJump(), true);
      expect(hand.consumeJump(), false);
      hand.acceptPacket(packet(3, jump: 2));
      expect(hand.consumeJump(), false);
      hand.acceptPacket(packet(1, epoch: 'reconnect', jump: 4));
      expect(hand.consumeJump(), false);
      hand.acceptPacket(packet(2, epoch: 'reconnect', jump: 5));
      expect(hand.consumeJump(), true);
    },
  );
  test('monotonic receive age disables stale results without a new packet', () {
    var now = 0;
    final hand = HandBridge(autoLaunch: false, clock: () => now);
    addTearDown(hand.dispose);
    hand.acceptPacket(packet(1));
    expect(hand.valid, true);
    now = 231;
    expect(hand.valid, false);
    expect(hand.ready, false);
  });

  test(
    'old buffered jump is discarded even when the newest hand packet is fresh',
    () {
      final hand = HandBridge(autoLaunch: false, clock: () => 0);
      addTearDown(hand.dispose);
      hand.acceptPacket(packet(1));
      hand.discardJumps();
      hand.acceptPacket({...packet(2, jump: 1), 'jump_age_ms': 500});
      expect(hand.valid, true);
      expect(hand.consumeJump(), false);
    },
  );
  test(
    'hand loss pauses immediately; reacquisition needs explicit resume',
    () async {
      final dir = await Directory.systemTemp.createTemp('gestureplay_dart_');
      addTearDown(() => dir.delete(recursive: true));
      var now = 0;
      final hand = FakeHand(() => now);
      addTearDown(hand.dispose);
      final controller = RunnerController(
        hand,
        LocalScores(File('${dir.path}/scores.json')),
      );
      addTearDown(controller.dispose);
      controller.prepare(ControlMode.hand);
      hand.acceptPacket(packet(1));
      controller.begin();
      for (var i = 0; i < 30; i++) {
        hand.acceptPacket(packet(i + 2));
        controller.tick(.1);
      }
      expect(controller.scene, GameScene.playing);
      now = 300;
      controller.tick(.1);
      expect(controller.scene, GameScene.paused);
      final time = controller.game!.elapsed;
      hand.acceptPacket(packet(40));
      controller.tick(.1);
      expect(controller.scene, GameScene.paused);
      expect(controller.game!.elapsed, time);
      controller.resume();
      for (var i = 0; i < 20; i++) {
        controller.tick(.1);
      }
      expect(controller.scene, GameScene.playing);
      expect(controller.game!.elapsed, time);
    },
  );
  test(
    'keyboard mode opens no Python service, pause and focus freeze time',
    () async {
      final dir = await Directory.systemTemp.createTemp('gestureplay_dart_');
      addTearDown(() => dir.delete(recursive: true));
      final hand = FakeHand(() => 0);
      addTearDown(hand.dispose);
      final controller = RunnerController(
        hand,
        LocalScores(File('${dir.path}/scores.json')),
      );
      addTearDown(controller.dispose);
      controller.prepare(ControlMode.keyboard);
      controller.begin();
      for (var i = 0; i < 30; i++) {
        controller.tick(.1);
      }
      controller.jump();
      controller.tick(.1);
      expect(controller.game!.feet, lessThan(RunnerModel.ground));
      final elapsed = controller.game!.elapsed;
      controller.lostFocus();
      controller.tick(.1);
      expect(controller.scene, GameScene.paused);
      expect(controller.game!.elapsed, elapsed);
      expect(hand.starts, 0);
      controller.menu();
      expect(controller.game, isNull);
    },
  );
  test(
    'Dart saves one result per round and keeps hand/keyboard records separate',
    () async {
      final dir = await Directory.systemTemp.createTemp('gestureplay_scores_');
      addTearDown(() => dir.delete(recursive: true));
      final scores = LocalScores(File('${dir.path}/scores.json'));
      const result = RunnerResult(
        id: 'one',
        difficulty: Difficulty.normal,
        control: ControlMode.hand,
        outcome: 'lost',
        score: 40,
        durationMs: 1000,
        obstacles: 0,
        coins: 2,
        distance: 30,
      );
      expect(await scores.save(result), true);
      expect(await scores.save(result), true);
      expect(scores.records.length, 1);
      expect(scores.best(Difficulty.normal, ControlMode.hand), 40);
      expect(scores.best(Difficulty.normal, ControlMode.keyboard), 0);
      final loaded = LocalScores(scores.file);
      await loaded.load();
      expect(loaded.records.length, 1);
    },
  );
}

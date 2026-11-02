import 'package:flutter_test/flutter_test.dart';
import 'package:gestureplay/dead_signal/gesture_pointer.dart';
import 'package:gestureplay/dead_signal/controller.dart';
import 'package:gestureplay/dead_signal/model.dart';
import 'package:gestureplay/dead_signal/settings.dart';
import 'package:gestureplay/services/hand_bridge.dart';

void main() {
  test(
    'pinching and reopening fingers keeps a click on the pointed target',
    () {
      final p = GesturePointer();
      var sequence = 0;
      List<HandPointerEvent> sample(
        Offset index, {
        bool pinched = false,
        Offset palm = const Offset(.5, .6),
      }) => p.update(
        valid: true,
        epoch: 'real-motion',
        sequence: ++sequence,
        target: index,
        palm: palm,
        pinched: pinched,
        fist: false,
      );
      for (var i = 0; i < 15; i++) {
        sample(const Offset(.7, .3));
      }
      final anchor = p.position;
      final down = sample(const Offset(.62, .4), pinched: true);
      expect(down.first.position, anchor);
      for (var i = 0; i < 5; i++) {
        sample(const Offset(.61, .42), pinched: true);
      }
      final up = sample(const Offset(.72, .27));
      expect(up.first.action, PointerAction.up);
      expect((up.first.position - anchor).distance, lessThan(.001));
    },
  );
  test('holding pinch follows palm movement to drag despite finger curl', () {
    final p = GesturePointer();
    var seq = 0;
    List<HandPointerEvent> sample(Offset index, Offset palm, bool pinched) =>
        p.update(
          valid: true,
          epoch: 'drag-motion',
          sequence: ++seq,
          target: index,
          palm: palm,
          pinched: pinched,
          fist: false,
        );
    for (var i = 0; i < 15; i++) {
      sample(const Offset(.3, .4), const Offset(.3, .6), false);
    }
    final anchor = p.position;
    sample(const Offset(.24, .45), const Offset(.3, .6), true);
    for (var i = 0; i < 15; i++) {
      sample(const Offset(.44, .45), const Offset(.5, .6), true);
    }
    expect(p.position.dx, closeTo(anchor.dx + .25, .003));
    expect(p.position.dy, closeTo(anchor.dy, .003));
    final up = sample(const Offset(.55, .3), const Offset(.5, .6), false);
    expect(up.first.action, PointerAction.up);
    expect(up.first.position.dx, closeTo(anchor.dx + .25, .003));
  });
  test('closing a fist cancels a pinch before the stable lock gesture', () {
    final hand = HandBridge(autoLaunch: false, clock: () => 0);
    final c = SignalController(hand, SignalSettings())..prepare();
    for (var i = 0; i < 35; i++) {
      c.tick(.1);
    }
    c.handControl = true;
    c.model!.selectDoor(0);
    final events = <PointerAction>[];
    c.onPointer = (e) => events.add(e.action);
    var seq = 0;
    void feed({bool pinch = false, bool pending = false, bool fist = false}) {
      hand.acceptPacket({
        'type': 'hand',
        'protocol': 1,
        'epoch': 'fist-test',
        'seq': ++seq,
        'jump_id': 0,
        'valid': true,
        'ready': true,
        'age_ms': 0,
        'pinched': pinch,
        'released': !pinch,
        'fist_pending': pending,
        'fist': fist,
        'pinch_points': [
          [.5, .5],
          [.5, .5],
        ],
      });
      c.tick(.05);
    }

    feed();
    feed(pinch: true);
    feed(pinch: true, pending: true);
    expect(events, contains(PointerAction.cancel));
    expect(events, isNot(contains(PointerAction.up)));
    expect(c.model!.active, true);
    expect(c.model!.doors[0].locked, false);
    feed(pinch: true, fist: true);
    expect(c.model!.doors[0].locked, true);
    c.dispose();
    hand.dispose();
  });
  List<HandPointerEvent> feed(
    GesturePointer p,
    int seq, {
    bool pinch = false,
    bool fist = false,
    bool valid = true,
    String epoch = 'a',
  }) => p.update(
    valid: valid,
    epoch: epoch,
    sequence: seq,
    target: const Offset(.5, .5),
    pinched: pinch,
    fist: fist,
  );
  test(
    'pinch creates exactly one down and one release, duplicate packets ignored',
    () {
      final p = GesturePointer();
      expect(feed(p, 1, pinch: true).map((e) => e.action), [
        PointerAction.move,
      ]);
      feed(p, 2);
      expect(feed(p, 3, pinch: true).first.action, PointerAction.down);
      expect(feed(p, 3, pinch: true), isEmpty);
      expect(feed(p, 4, pinch: true).map((e) => e.action), [
        PointerAction.move,
      ]);
      expect(feed(p, 5).first.action, PointerAction.up);
      expect(feed(p, 6).map((e) => e.action), [PointerAction.move]);
    },
  );
  test('tracking loss cancels drag; reconnecting closed hand never clicks', () {
    final p = GesturePointer();
    feed(p, 1);
    feed(p, 2, pinch: true);
    expect(feed(p, 3, valid: false).single.action, PointerAction.cancel);
    expect(feed(p, 4, pinch: true).map((e) => e.action), [PointerAction.move]);
    feed(p, 5);
    expect(feed(p, 6, pinch: true).first.action, PointerAction.down);
  });
  test('fist cancels pinch and only fires once until opened', () {
    final p = GesturePointer();
    feed(p, 1);
    feed(p, 2, pinch: true);
    expect(feed(p, 3, pinch: true, fist: true).map((e) => e.action), [
      PointerAction.cancel,
      PointerAction.fist,
    ]);
    expect(feed(p, 4, pinch: true, fist: true), isEmpty);
    expect(feed(p, 5, pinch: true).map((e) => e.action), [PointerAction.move]);
    feed(p, 6);
    expect(feed(p, 7, fist: true).single.action, PointerAction.fist);
  });
  test('fresh epoch cannot complete a stale gesture', () {
    final p = GesturePointer();
    feed(p, 1);
    feed(p, 2, pinch: true);
    expect(feed(p, 1, epoch: 'b').map((e) => e.action), [
      PointerAction.cancel,
      PointerAction.move,
    ]);
  });
  test('focus loss pauses countdown and explicit resume is required', () {
    final hand = HandBridge(autoLaunch: false);
    final c = SignalController(hand, SignalSettings());
    c.prepare();
    c.tick(.1);
    c.setFocus(false);
    expect(c.model!.phase, RoundPhase.paused);
    c.setFocus(true);
    c.tick(.1);
    expect(c.model!.phase, RoundPhase.paused);
    c.resume();
    for (var i = 0; i < 25; i++) {
      c.tick(.1);
    }
    expect(c.model!.active, true);
    c.dispose();
    hand.dispose();
  });
  test('loss of hand pauses round and switching to mouse can resume it', () {
    final hand = HandBridge(autoLaunch: false);
    final c = SignalController(hand, SignalSettings());
    c.prepare();
    for (var i = 0; i < 35; i++) {
      c.tick(.1);
    }
    expect(c.model!.active, true);
    c.handControl = true;
    c.tick(.1);
    expect(c.model!.phase, RoundPhase.paused);
    final elapsed = c.model!.elapsed;
    c.setHand(false);
    c.resume();
    for (var i = 0; i < 25; i++) {
      c.tick(.1);
    }
    expect(c.model!.elapsed, greaterThan(elapsed));
    c.dispose();
    hand.dispose();
  });
}

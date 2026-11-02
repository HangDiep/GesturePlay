import 'dart:ui';

enum PointerAction { down, move, up, cancel, fist }

class HandPointerEvent {
  const HandPointerEvent(this.action, this.position);
  final PointerAction action;
  final Offset position;
}

/// Converts fresh packets into one pointer stream. Reacquisition always needs
/// an open hand; invalid input cancels a drag and never becomes a click.
class GesturePointer {
  Offset position = const Offset(.5, .5);
  bool _armed = false, _down = false, _fist = false;
  bool _dragging = false;
  Offset _pressPosition = const Offset(.5, .5);
  Offset? _pressIndex, _pressPalm;
  bool get pressed => _down;
  bool get dragging => _dragging;
  String _epoch = '';
  int _sequence = -1;
  void reset() {
    _armed = _down = _fist = false;
    _dragging = false;
    _pressIndex = _pressPalm = null;
    _sequence = -1;
  }

  List<HandPointerEvent> update({
    required bool valid,
    required String epoch,
    required int sequence,
    required Offset target,
    Offset? palm,
    required bool pinched,
    required bool fist,
    double sensitivity = 1,
  }) {
    if (!valid) {
      final wasDown = _down;
      reset();
      return wasDown ? [HandPointerEvent(PointerAction.cancel, position)] : [];
    }
    final events = <HandPointerEvent>[];
    if (epoch != _epoch) {
      if (_down) events.add(HandPointerEvent(PointerAction.cancel, position));
      reset();
      _epoch = epoch;
    }
    if (sequence <= _sequence || !target.dx.isFinite || !target.dy.isFinite) {
      return [];
    }
    _sequence = sequence;
    final mapped = Offset(
      ((target.dx - .5) * sensitivity / .8 + .5).clamp(0, 1),
      ((target.dy - .5) * sensitivity / .8 + .5).clamp(0, 1),
    );
    if (fist) {
      if (_down) events.add(HandPointerEvent(PointerAction.cancel, position));
      _down = false;
      _armed = false;
      _dragging = false;
      if (!_fist) events.add(HandPointerEvent(PointerAction.fist, position));
      _fist = true;
      return events;
    }
    _fist = false;
    if (_down && !pinched) {
      // Reopening the index finger must not move the release off the button
      // or drag target. Follow the open index again on the next sample.
      events.add(HandPointerEvent(PointerAction.up, position));
      _down = false;
      _armed = true;
      _dragging = false;
      _pressIndex = _pressPalm = null;
    } else if (_down) {
      final hasPalm = palm != null && palm.dx.isFinite && palm.dy.isFinite;
      final delta = hasPalm && _pressPalm != null
          ? (palm - _pressPalm!) * (sensitivity / .8)
          : mapped - (_pressIndex ?? mapped);
      // Finger curl is not a drag. Only translate the held cursor after
      // deliberate hand movement; the palm stays stable during a pinch.
      if (delta.distance >= .025) _dragging = true;
      if (_dragging) {
        final next = _pressPosition + delta;
        position = Offset.lerp(
          position,
          Offset(next.dx.clamp(0, 1), next.dy.clamp(0, 1)),
          .48,
        )!;
      }
    } else if (_armed && !_down) {
      if (pinched) {
        // Select where the player was pointing before the fingers curled.
        _down = true;
        _armed = false;
        _dragging = false;
        _pressPosition = position;
        _pressIndex = mapped;
        _pressPalm = palm != null && palm.dx.isFinite && palm.dy.isFinite
            ? palm
            : null;
        events.add(HandPointerEvent(PointerAction.down, position));
      } else {
        position = Offset.lerp(position, mapped, .48)!;
      }
    } else {
      position = Offset.lerp(position, mapped, .48)!;
      if (!pinched) _armed = true;
    }
    events.add(HandPointerEvent(PointerAction.move, position));
    return events;
  }
}

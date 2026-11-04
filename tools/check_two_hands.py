"""Smoke-test the actual LIVE_STREAM detector on a local two-hand photo.

Usage: .venv/Scripts/python.exe tools/check_two_hands.py path/to/photo.jpg
Does not open a webcam, save landmarks, or transmit the supplied image.
"""
import json
from pathlib import Path
import sys
import threading
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import cv2
import mediapipe as mp
from mediapipe.tasks.python import vision
from config import AppConfig
from core.hand_tracker import HandTracker, landmarker_options
from core.shared_state import CameraFrame, SharedState


def main():
    image = cv2.imread(sys.argv[1])
    if image is None:
        raise ValueError('Cannot read test photo')
    image = cv2.flip(image, 1)  # Same reflection as CameraWorker.
    state = SharedState()
    tracker = HandTracker(AppConfig(), state)
    finished = threading.Event()
    native_sides = []
    def receive(result, output, stamp):
        native_sides.extend(c[0].category_name for c in result.handedness)
        tracker._on_result(result, output, stamp)
        finished.set()
    captured = time.monotonic_ns()
    stamp = tracker._remember(CameraFrame(1, captured, image))
    with vision.HandLandmarker.create_from_options(landmarker_options(AppConfig(), receive)) as detector:
        rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        detector.detect_async(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), stamp)
        if not finished.wait(15):
            raise TimeoutError('No LIVE_STREAM callback')
    tracker.stop()
    hand = state.snapshot().hand
    report = {'detected_hands': len(hand.hands) if hand else 0,
              'physical_roles': sorted(h.side for h in hand.hands) if hand else [],
              'native_mirrored_labels': native_sides,
              'webcam_opened': False}
    print(json.dumps(report))
    if report['physical_roles'] != ['left', 'right']:
        raise RuntimeError('Expected both hand roles from the actual model')


if __name__ == '__main__':
    main()

"""Một HandLandmarker LIVE_STREAM, một luồng gửi và callback ngắn."""

from collections import OrderedDict
import logging
import math
import threading
import time

import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision

from config import AppConfig
from core.shared_state import CameraFrame, HandResult, SharedState


LOGGER = logging.getLogger(__name__)
PALM_INDICES = (0, 5, 9, 13, 17)


def palm_center(landmarks) -> tuple[float, float]:
    return (
        sum(landmarks[index].x for index in PALM_INDICES) / len(PALM_INDICES),
        sum(landmarks[index].y for index in PALM_INDICES) / len(PALM_INDICES),
    )


def pinch_ratio(landmarks, aspect_ratio: float = 4 / 3) -> float | None:
    """Khoảng cách cái–trỏ chia chiều rộng lòng bàn tay, có bù tỷ lệ ảnh."""
    def distance(a, b):
        return math.hypot((a.x - b.x) * aspect_ratio, a.y - b.y)

    palm_width = distance(landmarks[5], landmarks[17])
    if palm_width < 1e-6:
        return None
    ratio = distance(landmarks[4], landmarks[8]) / palm_width
    return ratio if math.isfinite(ratio) else None


def landmarker_options(config: AppConfig, callback):
    return vision.HandLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(config.model_path)),
        running_mode=vision.RunningMode.LIVE_STREAM,
        num_hands=1,
        min_hand_detection_confidence=config.confidence,
        min_hand_presence_confidence=config.confidence,
        min_tracking_confidence=config.confidence,
        result_callback=callback,
    )


class HandTracker:
    def __init__(self, config: AppConfig, state: SharedState) -> None:
        self.config = config
        self.state = state
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="hand-tracker", daemon=True)
        self._pending_lock = threading.Lock()
        # MediaPipe có thể bỏ input khi bận. Metadata cũng phải có giới hạn.
        self._pending: OrderedDict[int, tuple[int, int, float]] = OrderedDict()
        self._last_timestamp_ms = -1

    def start(self) -> None:
        self._thread.start()

    def stop(self, timeout: float = 10.0) -> bool:
        # Lần nạp model đầu có thể mất vài giây. Cửa sổ đã được đóng trước
        # khi chờ, nhưng phải cho native init cơ hội kết thúc và được close.
        self._stop.set()
        if self._thread.ident is not None:
            self._thread.join(timeout)
        stopped = not self._thread.is_alive()
        if not stopped:
            LOGGER.warning("Bộ nhận diện chưa đóng sau %.1f giây.", timeout)
        return stopped

    def _remember(self, frame: CameraFrame) -> int:
        timestamp_ms = max(self._last_timestamp_ms + 1, frame.captured_at_ns // 1_000_000)
        self._last_timestamp_ms = timestamp_ms
        with self._pending_lock:
            aspect = (frame.bgr.shape[1] / frame.bgr.shape[0] if frame.bgr is not None
                      else self.config.camera_width / self.config.camera_height)
            self._pending[timestamp_ms] = (frame.frame_id, frame.captured_at_ns, aspect)
            while len(self._pending) > 64:
                self._pending.popitem(last=False)
        return timestamp_ms

    def _on_result(self, result, _output_image, timestamp_ms: int) -> None:
        if self._stop.is_set():
            return
        try:
            completed_at_ns = time.monotonic_ns()
            with self._pending_lock:
                metadata = self._pending.pop(timestamp_ms, None)
                # Callback có thứ tự timestamp; các input cũ hơn đã bị bỏ.
                while self._pending and next(iter(self._pending)) < timestamp_ms:
                    self._pending.popitem(last=False)
            if metadata is None:
                return
            frame_id, captured_at_ns, aspect = metadata
            landmarks = result.hand_landmarks[0] if result.hand_landmarks else None
            center = palm_center(landmarks) if landmarks else (None, None)
            pinch = pinch_ratio(landmarks, aspect) if landmarks else None
            points = ((landmarks[4].x, landmarks[4].y),
                      (landmarks[8].x, landmarks[8].y)) if landmarks else None
            self.state.publish_hand(HandResult(
                timestamp_ms, frame_id, captured_at_ns, completed_at_ns, *center, pinch, points,
            ))
        except Exception as exc:
            # Không để ngoại lệ Python thoát qua biên callback native.
            LOGGER.exception("Lỗi callback nhận diện")
            self.state.set_tracker_status("error", str(exc))
            self._stop.set()

    def _run(self) -> None:
        try:
            self.state.set_tracker_status("starting", "Đang nạp mô hình bàn tay")
            with vision.HandLandmarker.create_from_options(
                landmarker_options(self.config, self._on_result)
            ) as landmarker:
                self.state.set_tracker_status("running", "Một bàn tay · LIVE_STREAM")
                last_frame_id = -1
                next_send = 0.0
                interval = 1.0 / self.config.detection_fps
                while not self._stop.is_set():
                    delay = next_send - time.monotonic()
                    if delay > 0 and self._stop.wait(delay):
                        break
                    frame = self.state.latest_frame()
                    if frame is None or frame.frame_id == last_frame_id:
                        self._stop.wait(0.005)
                        continue
                    last_frame_id = frame.frame_id
                    if time.monotonic_ns() - frame.captured_at_ns > self.config.result_timeout_ms * 1_000_000:
                        continue
                    rgb = cv2.cvtColor(frame.bgr, cv2.COLOR_BGR2RGB)
                    # mp.Image sở hữu một bản sao bất biến. Không tái sử dụng buffer RGB.
                    mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)
                    timestamp_ms = self._remember(frame)
                    landmarker.detect_async(mp_image, timestamp_ms)
                    self.state.record_submission()
                    next_send = time.monotonic() + interval
        except Exception as exc:
            LOGGER.exception("Lỗi bộ nhận diện")
            self.state.set_tracker_status("error", str(exc))
        finally:
            with self._pending_lock:
                self._pending.clear()
            if self.state.snapshot().tracker.phase != "error":
                self.state.set_tracker_status("stopped", "Đã đóng bộ nhận diện")

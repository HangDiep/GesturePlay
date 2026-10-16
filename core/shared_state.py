"""Chỉ giữ ảnh và kết quả mới nhất; không tích lũy hàng đợi khung hình."""

from dataclasses import dataclass
from threading import Lock
from typing import Any


@dataclass(frozen=True)
class CameraFrame:
    frame_id: int
    captured_at_ns: int
    bgr: Any  # ndarray do camera sở hữu; các bên đọc không được sửa nội dung.


@dataclass(frozen=True)
class HandResult:
    timestamp_ms: int
    frame_id: int
    captured_at_ns: int
    completed_at_ns: int
    palm_x: float | None = None
    palm_y: float | None = None
    pinch_ratio: float | None = None
    pinch_points: tuple[tuple[float, float], tuple[float, float]] | None = None

    @property
    def has_hand(self) -> bool:
        return self.palm_x is not None and self.palm_y is not None


@dataclass(frozen=True)
class WorkerStatus:
    phase: str = "starting"
    message: str = "Đang khởi tạo"


@dataclass(frozen=True)
class StateSnapshot:
    frame: CameraFrame | None
    hand: HandResult | None
    camera: WorkerStatus
    tracker: WorkerStatus
    camera_frames: int
    submitted_frames: int
    completed_results: int


class SharedState:
    def __init__(self) -> None:
        self._lock = Lock()
        self._frame: CameraFrame | None = None
        self._hand: HandResult | None = None
        self._camera = WorkerStatus()
        self._tracker = WorkerStatus()
        self._camera_frames = 0
        self._submitted_frames = 0
        self._completed_results = 0

    def publish_frame(self, frame: CameraFrame) -> None:
        with self._lock:
            self._frame = frame
            self._camera_frames += 1

    def latest_frame(self) -> CameraFrame | None:
        with self._lock:
            return self._frame

    def publish_hand(self, result: HandResult) -> None:
        with self._lock:
            # Một callback đến muộn không được ghi đè kết quả mới hơn.
            if self._hand is None or result.timestamp_ms > self._hand.timestamp_ms:
                self._hand = result
            self._completed_results += 1

    def record_submission(self) -> None:
        with self._lock:
            self._submitted_frames += 1

    def set_camera_status(self, phase: str, message: str) -> None:
        with self._lock:
            self._camera = WorkerStatus(phase, message)

    def set_tracker_status(self, phase: str, message: str) -> None:
        with self._lock:
            self._tracker = WorkerStatus(phase, message)

    def snapshot(self) -> StateSnapshot:
        # Chỉ sao chép tham chiếu và số đếm; không sao chép ảnh trong khóa.
        with self._lock:
            return StateSnapshot(
                self._frame, self._hand, self._camera, self._tracker,
                self._camera_frames, self._submitted_frames, self._completed_results,
            )

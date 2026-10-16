"""Luồng duy nhất sở hữu VideoCapture, kể cả thao tác release."""

import logging
import os
import threading
import time

import cv2

from config import AppConfig
from core.shared_state import CameraFrame, SharedState


LOGGER = logging.getLogger(__name__)


class CameraWorker:
    def __init__(self, config: AppConfig, state: SharedState) -> None:
        self.config = config
        self.state = state
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="camera", daemon=True)

    def start(self) -> None:
        self._thread.start()

    def stop(self, timeout: float = 3.0) -> bool:
        self._stop.set()
        if self._thread.ident is not None:
            self._thread.join(timeout)
        stopped = not self._thread.is_alive()
        if not stopped:
            LOGGER.warning("Driver camera chưa trả về sau %.1f giây đóng.", timeout)
        return stopped

    def _run(self) -> None:
        capture = None
        try:
            backends = {"dshow": cv2.CAP_DSHOW, "msmf": cv2.CAP_MSMF,
                        "auto": cv2.CAP_ANY}
            backend = backends[self.config.camera_backend] if os.name == "nt" else cv2.CAP_ANY
            capture = cv2.VideoCapture(self.config.camera_index, backend)
            if not capture.isOpened():
                raise RuntimeError(
                    f"Không mở được camera {self.config.camera_index}. "
                    "Đóng ứng dụng đang dùng webcam; thử --backend msmf hoặc --camera 1."
                )
            capture.set(cv2.CAP_PROP_FRAME_WIDTH, self.config.camera_width)
            capture.set(cv2.CAP_PROP_FRAME_HEIGHT, self.config.camera_height)
            capture.set(cv2.CAP_PROP_FPS, self.config.camera_fps)
            capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)  # Driver có thể bỏ qua.
            reported_fps = capture.get(cv2.CAP_PROP_FPS)
            frame_id = 0
            failures = 0
            while not self._stop.is_set():
                ok, bgr = capture.read()
                captured_at_ns = time.monotonic_ns()
                if self._stop.is_set():
                    break
                if not ok or bgr is None or bgr.size == 0:
                    failures += 1
                    if failures >= 10:
                        raise RuntimeError("Camera không trả ảnh. Kiểm tra kết nối rồi chạy lại.")
                    self._stop.wait(0.02)
                    continue
                failures = 0
                # Lật đúng một lần; preview và bộ nhận diện cùng dùng ảnh này.
                mirrored = cv2.flip(bgr, 1)
                mirrored.setflags(write=False)
                frame_id += 1
                self.state.publish_frame(CameraFrame(frame_id, captured_at_ns, mirrored))
                if frame_id == 1:
                    height, width = mirrored.shape[:2]
                    message = f"Camera {self.config.camera_index} · {width} × {height}"
                    self.state.set_camera_status("running", message)
                    LOGGER.info("%s; driver báo %.1f FPS, đo FPS thực trên giao diện.",
                                message, reported_fps)
        except Exception as exc:
            LOGGER.exception("Lỗi camera")
            self.state.set_camera_status("error", str(exc))
        finally:
            if capture is not None:
                capture.release()
            if self.state.snapshot().camera.phase != "error":
                self.state.set_camera_status("stopped", "Đã đóng camera")

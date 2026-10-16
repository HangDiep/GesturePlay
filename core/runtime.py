"""Vòng đời camera và MediaPipe, không phụ thuộc giao diện hay luật game."""

import logging
import threading

from config import AppConfig
from core.shared_state import SharedState


LOGGER = logging.getLogger(__name__)


class HandRuntime:
    def __init__(self, config: AppConfig):
        self.config = config
        self.state = SharedState()
        self._thread = None
        self._stop = threading.Event()
        self.clean_shutdown = True

    @property
    def running(self):
        return self._thread is not None and self._thread.is_alive()

    @property
    def closing(self):
        return self._thread is not None and self._thread.is_alive() and self._stop.is_set()

    def ensure_started(self):
        if not self.clean_shutdown or (self._thread is not None and self._thread.is_alive()):
            return
        self.state = SharedState()
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, name="hand-runtime", daemon=True)
        self._thread.start()

    def request_stop(self):
        self._stop.set()

    def _run(self):
        workers = []
        try:
            from core.camera import CameraWorker
            camera = CameraWorker(self.config, self.state)
            workers.append(camera)
            camera.start()
            if not self._stop.is_set():
                # Import/nạp native có thể chậm ở lần đầu; luôn nằm ngoài luồng vẽ.
                from core.hand_tracker import HandTracker
                if not self._stop.is_set():
                    tracker = HandTracker(self.config, self.state)
                    workers.append(tracker)
                    tracker.start()
            self._stop.wait()
        except Exception as exc:
            LOGGER.exception("Không khởi động được nhận diện")
            self.state.set_tracker_status("error", str(exc))
            self._stop.wait()
        finally:
            for worker in reversed(workers):
                self.clean_shutdown = worker.stop() and self.clean_shutdown

    def shutdown(self):
        self.request_stop()
        if self._thread is not None:
            self._thread.join(14)
            self.clean_shutdown = not self._thread.is_alive() and self.clean_shutdown
        return self.clean_shutdown

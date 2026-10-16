"""Bản Pygame thử nghiệm cũ; ứng dụng chính hiện là Flutter + Flame."""

import argparse
from dataclasses import replace
from datetime import datetime
import importlib.metadata
import logging
import os
from pathlib import Path
import struct
import sys
import threading
import time

from config import AppConfig, PROJECT_DIR, configure_console


os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
os.environ.setdefault("MPLCONFIGDIR", str(PROJECT_DIR / ".cache" / "matplotlib"))
LOGGER = logging.getLogger("gestureplay")


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description="GesturePlay: Sky Runner điều khiển bằng bàn tay.")
    parser.add_argument("--check", action="store_true", help="Kiểm tra thư viện, model và callback; không mở webcam")
    parser.add_argument("--camera-only", action="store_true", help="Chỉ camera và giao diện, chưa chạy AI")
    parser.add_argument("--demo", action="store_true", help="Mở bản kiểm tra thanh ngang cũ")
    parser.add_argument("--keyboard", action="store_true", help="Chọn chế độ luyện bàn phím, không cần webcam")
    parser.add_argument("--difficulty", choices=("easy", "normal", "hard"), default="normal")
    parser.add_argument("--camera", type=int, default=0, help="Chỉ số webcam (mặc định: 0)")
    parser.add_argument("--backend", choices=("dshow", "msmf", "auto"), default="dshow")
    parser.add_argument("--resolution", choices=("640x480", "480x360", "320x240"), default="640x480")
    parser.add_argument("--preview", action="store_true", help="Bật preview; V trong Runner, P trong demo")
    parser.add_argument("--render-fps", type=int, choices=(30, 60), default=60)
    parser.add_argument("--detect-fps", type=float, default=20.0)
    parser.add_argument("--alpha", type=float, default=0.6, help="Hệ số EMA của demo thanh ngang, trong khoảng (0, 1]")
    parser.add_argument("--model", type=Path, default=AppConfig().model_path)
    parser.add_argument("--duration", type=float, help="Tự thoát sau số giây này, ví dụ 300 để đo 5 phút")
    parser.add_argument("--log", nargs="?", const="", metavar="PATH", help="Ghi CSV mỗi giây; mặc định lưu trong logs/")
    args = parser.parse_args(argv)
    if args.demo and args.camera_only:
        parser.error("Chỉ chọn --demo hoặc --camera-only")
    if args.duration is not None and (not 0 < args.duration < float("inf")):
        parser.error("--duration phải là số giây hữu hạn lớn hơn 0")
    return args


def verify_model_file(path: Path) -> None:
    if not path.is_file() or path.stat().st_size == 0:
        raise RuntimeError(
            f"Chưa có mô hình tại {path}. "
            "Chạy .\\.venv\\Scripts\\python.exe download_model.py rồi thử lại."
        )


def check_opencv_packages() -> None:
    unwanted = []
    for name in ("opencv-python", "opencv-python-headless", "opencv-contrib-python-headless"):
        try:
            importlib.metadata.version(name)
            unwanted.append(name)
        except importlib.metadata.PackageNotFoundError:
            pass
    if unwanted:
        raise RuntimeError("Có nhiều bản OpenCV trong môi trường: " + ", ".join(unwanted) +
                           ". Tạo lại .venv bằng requirements-lock.txt; chỉ dùng opencv-contrib-python.")


def run_checks(config: AppConfig) -> int:
    check_opencv_packages()
    import cv2
    import numpy as np
    import pygame
    import mediapipe as mp
    from mediapipe.tasks.python import vision
    from core.hand_tracker import landmarker_options

    print(f"Python {sys.version.split()[0]} · {struct.calcsize('P') * 8}-bit")
    for name in ("mediapipe", "opencv-contrib-python", "pygame", "numpy"):
        print(f"  {name}=={importlib.metadata.version(name)}")
    verify_model_file(config.model_path)
    print(f"Model: {config.model_path} ({config.model_path.stat().st_size:,} bytes)")
    done = threading.Event()
    received = []

    def callback(result, _image, timestamp_ms):
        received.append((timestamp_ms, len(result.hand_landmarks)))
        done.set()

    with vision.HandLandmarker.create_from_options(landmarker_options(config, callback)) as landmarker:
        blank = mp.Image(image_format=mp.ImageFormat.SRGB, data=np.zeros((480, 640, 3), dtype=np.uint8))
        landmarker.detect_async(blank, time.monotonic_ns() // 1_000_000)
        if not done.wait(10):
            raise RuntimeError("Mô hình không trả callback trong 10 giây.")
    if not received or received[0][1] != 0:
        raise RuntimeError("Kết quả không mong đợi với ảnh trống.")
    print("OK: import, nạp model, LIVE_STREAM callback ảnh trống và đóng bộ nhận diện.")
    print("Chưa kiểm tra webcam, khả năng nhận tay thật hoặc hiệu năng 5 phút.")
    return 0


def run_app(config: AppConfig, camera_only: bool = False,
            duration: float | None = None, log_path: Path | None = None) -> int:
    check_opencv_packages()
    from core.camera import CameraWorker
    from core.controller import PaddleController
    from core.metrics import Metrics
    from core.shared_state import SharedState
    from ui.control_demo import ControlDemo

    tracker_class = None
    if not camera_only:
        verify_model_file(config.model_path)
        from core.hand_tracker import HandTracker
        tracker_class = HandTracker

    state = SharedState()
    workers = []
    ui = None
    metrics = None
    try:
        ui = ControlDemo(config, camera_only)
        controller = PaddleController(config, ui.play_rect.width)
        metrics = Metrics(log_path)
        if camera_only:
            state.set_tracker_status("disabled", "Chế độ chỉ camera")
        workers.append(CameraWorker(config, state))
        if tracker_class is not None:
            workers.append(tracker_class(config, state))
        for worker in workers:
            worker.start()
        started = time.monotonic()
        while ui.events():
            now_ns = time.monotonic_ns()
            if duration is not None and time.monotonic() - started >= duration:
                break
            snapshot = state.snapshot()
            available = snapshot.camera.phase == "running" and snapshot.tracker.phase == "running"
            control = controller.update(snapshot.hand, now_ns, available)
            current_metrics = metrics.tick(snapshot, now_ns)
            ui.draw(snapshot, control, current_metrics, now_ns)
            ui.limit_fps()
    finally:
        # Đóng cửa sổ trước; các worker được dừng/kết thúc bên ngoài vòng vẽ.
        if ui is not None:
            ui.close()
        clean_shutdown = True
        for worker in reversed(workers):
            clean_shutdown = worker.stop() and clean_shutdown
        if metrics is not None:
            metrics.close()
        snapshot = state.snapshot()
        LOGGER.info("Đã thoát: %d ảnh camera, %d lần gửi, %d kết quả AI.",
                    snapshot.camera_frames, snapshot.submitted_frames, snapshot.completed_results)
        if not clean_shutdown:
            LOGGER.warning("Một thao tác native vẫn đang chờ driver; tiến trình sẽ kết thúc.")
    failed = snapshot.camera.phase == "error" or snapshot.tracker.phase == "error"
    return 1 if failed or not clean_shutdown else 0


def main(argv=None) -> int:
    configure_console()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    args = parse_args(argv)
    try:
        width, height = map(int, args.resolution.split("x"))
        config = replace(AppConfig(), camera_index=args.camera, camera_backend=args.backend,
                         camera_width=width, camera_height=height,
                         detection_fps=args.detect_fps, render_fps=args.render_fps,
                         smoothing_alpha=args.alpha, preview_enabled=args.preview,
                         model_path=args.model.resolve())
        if args.check:
            return run_checks(config)
        log_path = None
        if args.log is not None:
            log_path = Path(args.log).resolve() if args.log else PROJECT_DIR / "logs" / (
                "metrics_" + datetime.now().strftime("%Y%m%d_%H%M%S_%f") + ".csv")
            LOGGER.info("Ghi số đo mỗi giây vào %s", log_path)
        if args.demo or args.camera_only:
            return run_app(config, args.camera_only, args.duration, log_path)
        from client.app import run_game
        return run_game(config, args.duration, log_path, args.difficulty, args.keyboard)
    except (ImportError, OSError, RuntimeError, ValueError) as exc:
        LOGGER.error("%s", exc)
        LOGGER.error("Xem README.md. Kiểm tra bằng .\\.venv\\Scripts\\python.exe main.py --check")
        return 1
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())

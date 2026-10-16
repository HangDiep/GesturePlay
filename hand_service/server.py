"""WebSocket loopback: một client điều khiển, một camera/model, không có luật game."""

import argparse
import asyncio
import json
import logging
import math
import os
import time
import uuid
from dataclasses import replace
from websockets.exceptions import ConnectionClosed

from config import AppConfig, PROJECT_DIR, configure_console
from core.gestures import GestureController
from core.runtime import HandRuntime

os.environ.setdefault("MPLCONFIGDIR", str(PROJECT_DIR / ".cache" / "matplotlib"))
LOGGER = logging.getLogger(__name__)


def finite(value):
    return value if isinstance(value, (int, float)) and math.isfinite(value) else None


class HandServer:
    def __init__(self, config=None, runtime=None, idle_timeout=30):
        self.config = config or AppConfig()
        self.runtime = runtime or HandRuntime(self.config)
        self.controller = GestureController(self.config)
        self.idle_timeout = idle_timeout
        self.shutdown_event = asyncio.Event()
        self.owner = None
        self.active = False
        self.preview = False
        self.last_client_at = time.monotonic()
        self.epoch = ""
        self.jump_id = 0
        self.sequence = 0

    async def command(self, payload):
        if not isinstance(payload, dict) or payload.get("type") != "command":
            raise ValueError("Sai dạng lệnh điều khiển.")
        action = payload.get("action")
        if action == "start":
            index = payload.get("camera_index", self.config.camera_index)
            backend = payload.get("backend", self.config.camera_backend)
            if type(index) is not int or not 0 <= index <= 20 or backend not in {"dshow", "msmf", "auto"}:
                raise ValueError("Cấu hình webcam không hợp lệ.")
            if index != self.config.camera_index or backend != self.config.camera_backend:
                if self.runtime.running or not self.runtime.clean_shutdown:
                    raise ValueError("Dừng camera trước khi đổi cấu hình.")
                self.config = replace(self.config, camera_index=index, camera_backend=backend)
                self.runtime = HandRuntime(self.config)
                self.controller.reset_calibration()
            self.active = True
        elif action == "stop":
            self.active = False
            self.runtime.request_stop()
            self.controller.reset()
        elif action == "restart":
            self.runtime.request_stop()
            self.controller.reset()
            self.active = True
        elif action == "preview":
            if type(payload.get("enabled")) is not bool:
                raise ValueError("Trạng thái preview không hợp lệ.")
            self.preview = payload["enabled"]
        elif action == "calibrate_open":
            self.controller.calibrate_open(time.monotonic_ns())
        elif action == "calibrate_closed":
            self.controller.calibrate_closed(time.monotonic_ns())
        elif action == "calibrate_reset":
            self.controller.reset_calibration()
        elif action == "shutdown":
            self.shutdown_event.set()
        else:
            raise ValueError("Lệnh không được hỗ trợ.")

    async def receive(self, websocket):
        async for message in websocket:
            try:
                if not isinstance(message, str):
                    raise ValueError("Lệnh phải là JSON văn bản.")
                await self.command(json.loads(message))
            except (ValueError, TypeError) as exc:
                await websocket.send(json.dumps({"type": "error", "message": str(exc)}, ensure_ascii=False))

    async def handler(self, websocket):
        if self.owner is not None:
            await websocket.close(1008, "Phần nhận diện đang được một cửa sổ khác sử dụng.")
            return
        self.owner = websocket
        self.last_client_at = time.monotonic()
        self.epoch = str(uuid.uuid4())
        self.jump_id = self.sequence = 0
        self.controller.reset()
        receiver = asyncio.create_task(self.receive(websocket))
        last_state = None
        last_send = last_preview = 0.0
        last_preview_id = -1
        previous_counts = (0, 0)
        rate_at = time.monotonic()
        camera_fps = result_fps = 0.0
        try:
            while not self.shutdown_event.is_set() and not receiver.done():
                now = time.monotonic()
                now_ns = time.monotonic_ns()
                if self.active:
                    self.runtime.ensure_started()
                if self.runtime.state is not last_state:
                    self.controller.reset()
                    last_state = self.runtime.state
                    previous_counts = (0, 0)
                    rate_at = now
                state = self.runtime.state.snapshot()
                available = (self.active and not self.runtime.closing and
                             state.camera.phase == "running" and state.tracker.phase == "running")
                gesture = self.controller.update(state.hand, now_ns, available)
                if gesture.jump_pressed:
                    self.jump_id += 1
                if now - rate_at >= 1:
                    camera_fps = max(0, state.camera_frames - previous_counts[0]) / (now - rate_at)
                    result_fps = max(0, state.completed_results - previous_counts[1]) / (now - rate_at)
                    previous_counts = state.camera_frames, state.completed_results
                    rate_at = now
                if now - last_send >= 1 / 20:
                    self.sequence += 1
                    hand = state.hand
                    packet = {
                        "type": "hand", "protocol": 1, "epoch": self.epoch, "seq": self.sequence,
                        "sent_at_ms": int(time.time() * 1000),
                        "active": self.active, "closing": self.runtime.closing,
                        "idle": not self.runtime.running and self.runtime.clean_shutdown,
                        "valid": gesture.valid, "ready": gesture.ready,
                        "released": gesture.released, "pinched": gesture.pinched,
                        "jump_id": self.jump_id, "reason": gesture.reason,
                        "jump_age_ms": ((now_ns - gesture.last_jump_ns) / 1_000_000
                                        if gesture.last_jump_ns is not None else None),
                        "ratio": gesture.ratio, "press_threshold": gesture.press_threshold,
                        "release_threshold": gesture.release_threshold,
                        "calibration_stage": gesture.calibration_stage,
                        "calibration_message": gesture.calibration_message,
                        "palm_x": finite(hand.palm_x) if hand else None,
                        "palm_y": finite(hand.palm_y) if hand else None,
                        "pinch_points": hand.pinch_points if hand and gesture.valid else None,
                        "age_ms": max(0, (now_ns - hand.captured_at_ns) / 1_000_000) if hand else None,
                        "camera_phase": state.camera.phase, "tracker_phase": state.tracker.phase,
                        "camera_message": state.camera.message, "tracker_message": state.tracker.message,
                        "camera_fps": camera_fps, "result_fps": result_fps,
                    }
                    await asyncio.wait_for(websocket.send(json.dumps(packet, ensure_ascii=False, allow_nan=False)), 1)
                    last_send = now
                if self.preview and self.active and state.frame is not None:
                    if state.frame.frame_id != last_preview_id and now - last_preview >= 1 / 8:
                        encoded = await asyncio.to_thread(self.encode_preview, state.frame.bgr)
                        if encoded is not None:
                            await asyncio.wait_for(websocket.send(encoded), 1)
                        last_preview_id = state.frame.frame_id
                        last_preview = now
                await asyncio.sleep(1 / 60)
        except (TimeoutError, OSError, ConnectionClosed):
            LOGGER.info("Kết nối nhận diện đã ngắt hoặc chậm quá hạn.")
        finally:
            receiver.cancel()
            await asyncio.gather(receiver, return_exceptions=True)
            self.active = self.preview = False
            self.runtime.request_stop()
            self.controller.reset()
            self.owner = None
            self.last_client_at = time.monotonic()

    @staticmethod
    def encode_preview(bgr):
        import cv2
        small = cv2.resize(bgr, (320, 240), interpolation=cv2.INTER_AREA)
        ok, encoded = cv2.imencode(".jpg", small, [cv2.IMWRITE_JPEG_QUALITY, 65])
        return encoded.tobytes() if ok else None

    async def run(self, port=8765):
        from websockets.asyncio.server import serve
        async with serve(self.handler, "127.0.0.1", port, origins=[None],
                         max_size=4096, max_queue=4, write_limit=16384):
            LOGGER.info("HAND_SERVICE_READY ws://127.0.0.1:%s", port)
            while not self.shutdown_event.is_set():
                if self.idle_timeout and self.owner is None and time.monotonic() - self.last_client_at > self.idle_timeout:
                    break
                try:
                    await asyncio.wait_for(self.shutdown_event.wait(), .5)
                except asyncio.TimeoutError:
                    pass
        return await asyncio.to_thread(self.runtime.shutdown)


def main(argv=None):
    configure_console()
    parser = argparse.ArgumentParser(description="Python nhận diện tay cho ứng dụng Flutter Windows.")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--camera", type=int, default=0)
    parser.add_argument("--backend", choices=("dshow", "msmf", "auto"), default="dshow")
    parser.add_argument("--idle-timeout", type=float, default=30)
    args = parser.parse_args(argv)
    if not 0 < args.port < 65536 or not math.isfinite(args.idle_timeout) or args.idle_timeout < 0:
        parser.error("Port hoặc thời gian chờ không hợp lệ.")
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    service = HandServer(replace(AppConfig(), camera_index=args.camera, camera_backend=args.backend),
                         idle_timeout=args.idle_timeout)
    try:
        return 0 if asyncio.run(service.run(args.port)) else 1
    except KeyboardInterrupt:
        service.runtime.shutdown()
        return 0
    except OSError as exc:
        LOGGER.error("Không mở được dịch vụ nhận diện: %s", exc)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

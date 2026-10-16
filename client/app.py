"""Vòng lặp duy nhất điều phối menu, chuẩn bị, chơi, pause và kết quả local."""

import logging
from pathlib import Path
import time

from config import AppConfig
from core.metrics import Metrics
from client.core.gesture_controller import GestureController
from client.core.scene_manager import Scene, SceneManager
from client.screens.runner_screen import RunnerScreen
from client.services.hand_runtime import HandRuntime
from client.services.local_scores import LocalScores


LOGGER = logging.getLogger(__name__)


def run_game(config: AppConfig, duration: float | None = None, log_path: Path | None = None,
             difficulty="normal", keyboard=False, scores_path: Path | None = None) -> int:
    manager = SceneManager(LocalScores(scores_path), difficulty, keyboard)
    runtime = HandRuntime(config)
    controller = GestureController(config)
    ui = None
    metrics = None
    try:
        ui = RunnerScreen(config)
        metrics = Metrics(log_path)
        started = previous = time.monotonic()
        last_state = None
        while True:
            now = time.monotonic()
            if duration is not None and now - started >= duration:
                break
            dt = min(0.1, max(0, now - previous))
            previous = now
            actions, jump_key = ui.events()
            now_ns = time.monotonic_ns()
            if runtime.state is not last_state:
                controller.reset()
                last_state = runtime.state
            snapshot = runtime.state.snapshot()
            gesture = controller.update(snapshot.hand, now_ns,
                                        snapshot.camera.phase == "running" and snapshot.tracker.phase == "running"
                                        and not runtime.closing)
            should_quit = False
            for action in actions:
                if action == "quit" or (action == "escape" and manager.scene == Scene.MENU):
                    should_quit = True
                elif action == "play_hand":
                    manager.prepare("hand")
                elif action == "play_keyboard":
                    manager.prepare("keyboard")
                elif action == "enter" and manager.scene == Scene.MENU:
                    manager.prepare()
                elif action.startswith("difficulty_") and manager.scene == Scene.MENU:
                    manager.difficulty = action.removeprefix("difficulty_")
                elif action == "begin" or (action == "enter" and manager.scene == Scene.PREPARING):
                    manager.begin(gesture)
                elif action == "resume" or (action in {"pause_toggle", "enter"} and manager.scene == Scene.PAUSED):
                    manager.resume(gesture)
                elif action in {"pause_toggle", "escape"} and manager.scene == Scene.PLAYING:
                    manager.pause()
                elif action == "menu" or (action == "escape" and manager.scene in {
                    Scene.PREPARING, Scene.PAUSED, Scene.RESULT, Scene.COUNTDOWN,
                }):
                    manager.to_menu()
                elif action == "restart" and manager.scene in {Scene.PLAYING, Scene.PAUSED, Scene.RESULT}:
                    manager.prepare()
                elif action == "save_retry":
                    manager.retry_save()
                elif action == "camera_retry":
                    runtime.request_stop()
                    controller.reset()
                elif action in {"calibrate_open", "calibrate_closed", "calibrate_reset"} and manager.scene == Scene.PREPARING:
                    if action == "calibrate_reset":
                        controller.reset_calibration()
                    elif action == "calibrate_open":
                        controller.calibrate_open(now_ns)
                    else:
                        controller.calibrate_closed(now_ns)
                    gesture = controller.update(snapshot.hand, now_ns,
                                                snapshot.camera.phase == "running"
                                                and snapshot.tracker.phase == "running"
                                                and not runtime.closing)
            if should_quit:
                break
            if manager.needs_camera:
                runtime.ensure_started()
            else:
                runtime.request_stop()
            manager.update(dt, gesture, jump_key, ui.focused)
            current_metrics = metrics.tick(snapshot, now_ns)
            ui.draw(manager, gesture, snapshot, current_metrics, now_ns, runtime.closing)
            ui.limit_fps()
    finally:
        if ui is not None:
            ui.close()
        clean = runtime.shutdown()
        if metrics is not None:
            metrics.close()
    if not clean:
        LOGGER.error("Một tài nguyên camera/nhận diện chưa đóng đúng thời hạn.")
    return 0 if clean else 1

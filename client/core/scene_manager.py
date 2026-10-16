"""Chỉ cập nhật game trong PLAYING; pause/countdown không cộng thời gian."""

from enum import Enum

from client.core.gesture_controller import GestureInput
from client.games import GAME_TYPES
from client.services.local_scores import LocalScores


class Scene(str, Enum):
    MENU = "menu"
    PREPARING = "preparing"
    COUNTDOWN = "countdown"
    PLAYING = "playing"
    PAUSED = "paused"
    RESULT = "result"


class SceneManager:
    def __init__(self, scores: LocalScores, difficulty="normal", keyboard=False):
        self.scores = scores
        self.difficulty = difficulty
        self.control_mode = "keyboard" if keyboard else "hand"
        self.scene = Scene.MENU
        self.game = None
        self.countdown = 3.0
        self.pause_reason = ""
        self.result = None
        self.saved = False
        self._resuming = False

    @property
    def needs_camera(self):
        return self.control_mode == "hand" and self.scene in {
            Scene.PREPARING, Scene.COUNTDOWN, Scene.PLAYING, Scene.PAUSED,
        }

    def prepare(self, mode=None, game_code="runner"):
        if game_code not in GAME_TYPES:
            raise ValueError("Trò chơi chưa được hỗ trợ.")
        if mode is not None:
            if mode not in {"hand", "keyboard"}:
                raise ValueError("Kiểu điều khiển không hợp lệ.")
            self.control_mode = mode
        self.game = GAME_TYPES[game_code](self.difficulty, self.control_mode)
        self.result = None
        self.saved = False
        self._resuming = False
        self.scene = Scene.PREPARING

    def begin(self, gesture: GestureInput):
        if self.scene != Scene.PREPARING:
            return False
        if self.control_mode == "hand" and not (gesture.ready and gesture.released):
            return False
        self.countdown = 3.0
        self._resuming = False
        self.scene = Scene.COUNTDOWN
        return True

    def pause(self, reason="Bạn đã tạm dừng"):
        if self.scene == Scene.PLAYING:
            self.pause_reason = reason
            self.game.pause()
            self.scene = Scene.PAUSED

    def resume(self, gesture: GestureInput):
        if self.scene != Scene.PAUSED:
            return False
        if self.control_mode == "hand" and not gesture.ready:
            return False
        self.countdown = 2.0
        self._resuming = True
        self.scene = Scene.COUNTDOWN
        return True

    def to_menu(self):
        if self.game is not None:
            self.game.pause()
        self.game = None
        self.scene = Scene.MENU

    def retry_save(self):
        if self.result is not None:
            self.saved = self.scores.save(self.result)

    def update(self, dt: float, gesture: GestureInput, jump_key=False, focused=True):
        if self.scene == Scene.COUNTDOWN:
            if not focused or (self.control_mode == "hand" and not gesture.valid):
                if self._resuming:
                    self.scene = Scene.PAUSED
                    self.pause_reason = "Chưa đủ tín hiệu để tiếp tục"
                else:
                    self.scene = Scene.PREPARING
                return
            self.countdown = max(0, self.countdown - dt)
            if self.countdown <= 1e-8:
                self.game.start()
                self.scene = Scene.PLAYING
            return
        if self.scene != Scene.PLAYING:
            return
        if not focused:
            self.pause("Cửa sổ vừa mất tiêu điểm")
            return
        if self.control_mode == "hand" and not gesture.valid:
            self.pause("Mất tín hiệu bàn tay · ván chơi đã dừng")
            return
        jump = gesture.jump_pressed if self.control_mode == "hand" else jump_key
        self.game.update(dt, jump)
        if self.game.finished:
            self.result = self.game.get_result()
            self.scene = Scene.RESULT
            self.retry_save()

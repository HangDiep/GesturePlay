"""Ánh xạ tâm bàn tay, EMA theo kết quả mới và hết hạn dữ liệu."""

from dataclasses import dataclass
import math

from config import AppConfig
from core.shared_state import HandResult


@dataclass(frozen=True)
class ControlState:
    paddle_x: float
    active: bool
    reason: str
    normalized_x: float | None = None
    palm_y: float | None = None


class PaddleController:
    def __init__(self, config: AppConfig, play_width: int) -> None:
        if play_width < config.paddle_width:
            raise ValueError("Vùng chơi phải rộng hơn thanh điều khiển.")
        self.config = config
        self._travel = play_width - config.paddle_width
        self._x = self._travel / 2
        self._last_timestamp = -1
        self._active = False

    def update(self, result: HandResult | None, now_ns: int,
               available: bool = True) -> ControlState:
        reason = "waiting"
        if not available:
            reason = "unavailable"
        elif result is not None:
            if now_ns - result.captured_at_ns > self.config.result_timeout_ms * 1_000_000:
                reason = "stale"
            elif not result.has_hand:
                reason = "no_hand"
            elif not all(math.isfinite(value) for value in (result.palm_x, result.palm_y)):
                reason = "no_hand"
            else:
                reason = "tracking"

        if reason != "tracking":
            self._active = False
            if result is not None:
                self._last_timestamp = max(self._last_timestamp, result.timestamp_ms)
            return ControlState(self._x, False, reason)

        u = min(1.0, max(0.0, (result.palm_x - self.config.control_min_x) /
                             (self.config.control_max_x - self.config.control_min_x)))
        if result.timestamp_ms > self._last_timestamp:
            target_x = u * self._travel
            alpha = self.config.smoothing_alpha
            self._x = alpha * target_x + (1 - alpha) * self._x if self._active else target_x
            self._last_timestamp = result.timestamp_ms
            self._active = True
        # Một kết quả cũ không được kích hoạt lại sau khi bị vô hiệu hóa.
        return ControlState(self._x, self._active,
                            "tracking" if self._active else "waiting", u, result.palm_y)

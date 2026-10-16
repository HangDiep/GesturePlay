"""Nhận cử chỉ tay cho dịch vụ Python, độc lập Flutter và Pygame."""

from dataclasses import dataclass
from collections import deque
import math
from statistics import median

from config import AppConfig
from core.shared_state import HandResult


@dataclass(frozen=True)
class GestureInput:
    valid: bool = False
    ready: bool = False
    jump_pressed: bool = False
    pinched: bool = False
    released: bool = False
    reason: str = "Đang chờ bàn tay"
    ratio: float | None = None
    press_threshold: float = 0.28
    release_threshold: float = 0.45
    calibration_stage: str = "none"
    calibration_message: str = "Chụm chưa nhận? Ghi lại hai tư thế bên phải."
    last_jump_ns: int | None = None


class GestureController:
    press_threshold = 0.28
    release_threshold = 0.45
    stable_ns = 600_000_000

    def __init__(self, config: AppConfig):
        self.config = config
        self.press_threshold = type(self).press_threshold
        self.release_threshold = type(self).release_threshold
        self._open_ratio = None
        self.calibration_stage = "none"
        self.calibration_message = "Chụm chưa nhận? Ghi lại hai tư thế bên phải."
        self.reset()

    def reset(self):
        self._last_timestamp = -1
        self._stable_since = None
        self._pinched = False
        self._armed = False
        self._recent = deque(maxlen=12)
        self._last_jump_ns = None

    def reset_calibration(self):
        self.press_threshold = type(self).press_threshold
        self.release_threshold = type(self).release_threshold
        self._open_ratio = None
        self.calibration_stage = "none"
        self.calibration_message = "Đã về mặc định. Bạn có thể ghi lại hai tư thế."
        self.reset()

    def _calibration_sample(self, now_ns):
        values = [ratio for captured_ns, ratio in self._recent
                  if 0 <= now_ns - captured_ns <= 450_000_000]
        if (len(values) < 3 or not self._recent
                or now_ns - self._recent[-1][0] > self.config.result_timeout_ms * 1_000_000):
            self.calibration_message = "Giữ một tư thế khoảng nửa giây rồi bấm lại."
            return None
        value = median(values)
        if max(values) - min(values) > max(.12, value * .30):
            self.calibration_message = "Cử chỉ còn dao động. Giữ yên rồi bấm lại."
            return None
        return value

    def calibrate_open(self, now_ns) -> bool:
        value = self._calibration_sample(now_ns)
        if value is None:
            return False
        if value < .20:
            self.calibration_message = "Tách ngón cái và trỏ rộng hơn rồi ghi tay mở."
            return False
        self._open_ratio = value
        self.calibration_stage = "opened"
        self.calibration_message = "Đã ghi tay mở. Chụm lại, giữ yên rồi ghi tay chụm."
        self._armed = True
        self._pinched = False
        return True

    def calibrate_closed(self, now_ns) -> bool:
        if self._open_ratio is None:
            self.calibration_message = "Ghi tay mở trước, sau đó mới ghi tay chụm."
            return False
        value = self._calibration_sample(now_ns)
        if value is None:
            return False
        difference = self._open_ratio - value
        if difference < max(.12, self._open_ratio * .18):
            self.calibration_message = "Hai tư thế quá giống nhau. Mở rộng và ghi lại."
            return False
        self.press_threshold = value + difference * .35
        self.release_threshold = value + difference * .65
        self.calibration_stage = "ready"
        self.calibration_message = "Đã hiệu chỉnh. Thả hai ngón rồi chụm để thử."
        self._armed = False
        self._pinched = True
        return True

    def _input(self, *, ratio=None, **kwargs):
        return GestureInput(**kwargs, ratio=ratio, press_threshold=self.press_threshold,
                            release_threshold=self.release_threshold,
                            calibration_stage=self.calibration_stage,
                            calibration_message=self.calibration_message,
                            last_jump_ns=self._last_jump_ns)

    def update(self, result: HandResult | None, now_ns: int, available=True) -> GestureInput:
        reason = None
        if not available:
            reason = "Camera hoặc bộ nhận diện chưa sẵn sàng"
        elif result is None or not result.has_hand:
            reason = "Chưa thấy bàn tay"
        elif now_ns - result.captured_at_ns > self.config.result_timeout_ms * 1_000_000:
            reason = "Tín hiệu tay đã cũ"
        elif (result.pinch_ratio is None or not math.isfinite(result.pinch_ratio)
              or result.pinch_ratio < 0 or not math.isfinite(result.palm_x)
              or not math.isfinite(result.palm_y)):
            reason = "Hướng lòng bàn tay rõ hơn về camera"
        if reason is not None:
            self._stable_since = None
            self._pinched = False
            self._armed = False
            self._recent.clear()
            if result is not None:
                self._last_timestamp = max(self._last_timestamp, result.timestamp_ms)
            return self._input(reason=reason)

        jump = False
        if result.timestamp_ms > self._last_timestamp:
            self._last_timestamp = result.timestamp_ms
            self._recent.append((result.captured_at_ns, result.pinch_ratio))
            if self._stable_since is None:
                self._stable_since = now_ns
            if result.pinch_ratio >= self.release_threshold:
                self._pinched = False
                self._armed = True
            elif result.pinch_ratio <= self.press_threshold:
                jump = self._armed and not self._pinched
                self._pinched = True
                self._armed = False
                if jump:
                    self._last_jump_ns = now_ns
        stable = self._stable_since is not None and now_ns - self._stable_since >= self.stable_ns
        return self._input(valid=True, ready=stable, jump_pressed=jump,
                           pinched=self._pinched, released=self._armed,
                           reason="Tay ổn định" if stable else "Giữ tay ổn định một chút",
                           ratio=result.pinch_ratio)

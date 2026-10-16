"""Các thông số ban đầu của bản thử điều khiển bằng tay."""

from dataclasses import dataclass
from pathlib import Path
import sys


PROJECT_DIR = Path(__file__).resolve().parent


def configure_console() -> None:
    """Giữ tiếng Việt đọc được cả khi PowerShell chuyển hướng đầu ra."""
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


@dataclass(frozen=True)
class AppConfig:
    camera_index: int = 0
    camera_backend: str = "dshow"
    camera_width: int = 640
    camera_height: int = 480
    camera_fps: int = 30
    detection_fps: float = 20.0
    render_fps: int = 60
    window_width: int = 1120
    window_height: int = 700
    paddle_width: int = 160
    paddle_height: int = 18
    smoothing_alpha: float = 0.6
    control_min_x: float = 0.15
    control_max_x: float = 0.85
    result_timeout_ms: int = 250
    confidence: float = 0.5
    preview_enabled: bool = False
    preview_fps: float = 12.0
    model_path: Path = PROJECT_DIR / "models" / "hand_landmarker.task"

    def __post_init__(self) -> None:
        if self.camera_index < 0:
            raise ValueError("Chỉ số camera phải từ 0 trở lên.")
        if self.camera_backend not in {"dshow", "msmf", "auto"}:
            raise ValueError("Backend camera phải là dshow, msmf hoặc auto.")
        if min(self.camera_width, self.camera_height, self.camera_fps,
               self.render_fps, self.result_timeout_ms) <= 0:
            raise ValueError("Kích thước, FPS và thời gian hết hạn phải lớn hơn 0.")
        if not 0 < self.detection_fps <= 120 or not 0 < self.preview_fps <= 60:
            raise ValueError("FPS nhận diện/preview nằm ngoài khoảng cho phép.")
        if not 0 < self.smoothing_alpha <= 1:
            raise ValueError("Alpha phải lớn hơn 0 và không vượt quá 1.")
        if not 0 <= self.control_min_x < self.control_max_x <= 1:
            raise ValueError("Vùng điều khiển phải nằm trong khoảng 0 đến 1.")
        if not 0 <= self.confidence <= 1:
            raise ValueError("Ngưỡng confidence phải nằm trong khoảng 0 đến 1.")

"""FPS tính từ số đếm thực, độ cũ ảnh và thời gian tới callback."""

import csv
from dataclasses import asdict, dataclass
from pathlib import Path
import time

from core.shared_state import StateSnapshot


@dataclass(frozen=True)
class MetricSnapshot:
    elapsed_s: float
    ui_fps: float = 0.0
    camera_fps: float = 0.0
    submitted_fps: float = 0.0
    result_fps: float = 0.0
    result_age_ms: float | None = None
    callback_latency_ms: float | None = None


class Metrics:
    def __init__(self, log_path: Path | None = None) -> None:
        self._started = time.monotonic_ns()
        self._last_sample = self._started
        self._ui_frames = 0
        self._last_counts = (0, 0, 0, 0)
        self._rates = (0.0, 0.0, 0.0, 0.0)
        self._log_file = None
        self._writer = None
        if log_path is not None:
            log_path.parent.mkdir(parents=True, exist_ok=True)
            self._log_file = log_path.open("w", newline="", encoding="utf-8")
            self._writer = csv.DictWriter(self._log_file, fieldnames=list(MetricSnapshot.__dataclass_fields__))
            self._writer.writeheader()

    def tick(self, snapshot: StateSnapshot, now_ns: int) -> MetricSnapshot:
        self._ui_frames += 1
        counts = (self._ui_frames, snapshot.camera_frames,
                  snapshot.submitted_frames, snapshot.completed_results)
        interval = (now_ns - self._last_sample) / 1_000_000_000
        sample_due = interval >= 1.0
        if sample_due:
            self._rates = tuple(max(0, value - previous) / interval
                                for value, previous in zip(counts, self._last_counts))
            self._last_counts = counts
            self._last_sample = now_ns
        hand = snapshot.hand
        age = max(0.0, (now_ns - hand.captured_at_ns) / 1_000_000) if hand else None
        latency = max(0.0, (hand.completed_at_ns - hand.captured_at_ns) / 1_000_000) if hand else None
        metrics = MetricSnapshot((now_ns - self._started) / 1_000_000_000,
                                 *self._rates, age, latency)
        if sample_due and self._writer is not None:
            self._writer.writerow({key: round(value, 3) if isinstance(value, float) else value
                                   for key, value in asdict(metrics).items()})
            self._log_file.flush()
        return metrics

    def close(self) -> None:
        if self._log_file is not None:
            self._log_file.close()

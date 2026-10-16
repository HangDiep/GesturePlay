"""Báo cáo local theo các trường được đề xuất cho API sau này."""

from dataclasses import dataclass


@dataclass(frozen=True)
class GameResult:
    session_id: str
    game_code: str
    difficulty: str
    rules_version: int
    outcome: str
    score: int
    active_duration_ms: int
    metrics: dict[str, int]
    control_mode: str

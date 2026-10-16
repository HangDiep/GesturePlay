"""Lưu tối đa 100 kết quả local; không phải bảng xếp hạng máy chủ."""

from dataclasses import asdict
from datetime import datetime, timezone
import json
from pathlib import Path

from client.games.base_game import GameResult
from client.games.runner import RULES
from config import PROJECT_DIR


class LocalScores:
    def __init__(self, path: Path | None = None):
        self.path = path or PROJECT_DIR / "client" / "data" / "runner_scores.json"
        self.records = []
        self.error: str | None = None
        try:
            if self.path.exists():
                payload = json.loads(self.path.read_text(encoding="utf-8"))
                if not isinstance(payload, dict) or payload.get("version") != 1 or not isinstance(payload.get("rounds"), list):
                    raise ValueError("Sai cấu trúc dữ liệu local")
                self.records = [record for record in payload["rounds"] if self._valid(record)][-100:]
        except (OSError, ValueError):
            self.error = "Không đọc được thành tích cũ trên máy."

    @staticmethod
    def _valid(record):
        return (isinstance(record, dict) and record.get("game_code") == "runner"
                and isinstance(record.get("difficulty"), str) and record["difficulty"] in RULES
                and record.get("rules_version") == 1
                and isinstance(record.get("session_id"), str)
                and type(record.get("score")) is int and record["score"] >= 0
                and isinstance(record.get("control_mode"), str)
                and record["control_mode"] in {"hand", "keyboard"})

    def best(self, difficulty, control_mode="hand"):
        return max((record["score"] for record in self.records
                    if record["difficulty"] == difficulty and record["control_mode"] == control_mode), default=0)

    def save(self, result: GameResult) -> bool:
        if any(record["session_id"] == result.session_id for record in self.records):
            return True
        record = asdict(result)
        record["created_at"] = datetime.now(timezone.utc).isoformat()
        records = self.records + [record]
        # Giữ 94 lượt gần nhất và kỷ lục của 6 nhóm độ khó/điều khiển.
        if len(records) > 100:
            keep = {entry["session_id"] for entry in records[-94:]}
            for difficulty in RULES:
                for mode in ("hand", "keyboard"):
                    group = [entry for entry in records if entry["difficulty"] == difficulty
                             and entry["control_mode"] == mode]
                    if group:
                        keep.add(max(group, key=lambda entry: entry["score"])["session_id"])
            records = [entry for entry in records if entry["session_id"] in keep]
        temporary = self.path.with_suffix(".tmp")
        try:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            temporary.write_text(json.dumps({"version": 1, "rounds": records}, ensure_ascii=False, indent=2), encoding="utf-8")
            temporary.replace(self.path)
        except OSError:
            self.error = "Chưa lưu được kết quả trên máy. Bạn có thể thử lại."
            return False
        self.records = records
        self.error = None
        return True

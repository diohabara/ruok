from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

from ruok.models import AdviceRecord


class RunStore:
    def __init__(self, data_dir: Path) -> None:
        self.data_dir = data_dir
        self.records_path = data_dir / "records.jsonl"
        self.screenshots_dir = data_dir / "screenshots"

    def append(self, record: AdviceRecord) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.screenshots_dir.mkdir(parents=True, exist_ok=True)
        with self.records_path.open("a", encoding="utf-8") as file:
            file.write(json.dumps(asdict(record), ensure_ascii=False) + "\n")

    def latest(self) -> AdviceRecord | None:
        records = self.list_records(limit=1)
        return records[0] if records else None

    def list_records(self, limit: int = 50) -> list[AdviceRecord]:
        if not self.records_path.exists():
            return []

        records = []
        for line in self.records_path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                records.append(AdviceRecord(**json.loads(line)))
        return list(reversed(records))[:limit]

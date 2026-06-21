from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class AdviceRecord:
    id: str
    created_at: str
    screenshot_path: str
    previous_screenshot_path: str | None
    changed_percent: float
    rms: float
    summary: str
    advice: str
    model: str


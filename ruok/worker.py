from __future__ import annotations

import asyncio
from contextlib import suppress
from datetime import datetime
from pathlib import Path
from typing import Protocol
from uuid import uuid4

from ruok.image_diff import ImageDelta, compare_images
from ruok.models import AdviceRecord
from ruok.notifier import NotificationSink
from ruok.store import RunStore


class ScreenshotCapturer(Protocol):
    def capture(self, destination: Path) -> Path: ...


class VisionAdvisor(Protocol):
    model: str

    async def advise(
        self, previous_path: Path | None, current_path: Path, delta: ImageDelta
    ) -> str: ...


class MonitorService:
    def __init__(
        self,
        store: RunStore,
        capturer: ScreenshotCapturer,
        advisor: VisionAdvisor,
        notifier: NotificationSink | None = None,
    ) -> None:
        self.store = store
        self.capturer = capturer
        self.advisor = advisor
        self.notifier = notifier
        self._lock = asyncio.Lock()

    async def run_once(self) -> AdviceRecord:
        async with self._lock:
            created_at = datetime.now().astimezone()
            record_id = f"{created_at.strftime('%Y%m%d-%H%M%S')}-{uuid4().hex[:8]}"
            current_path = self.store.screenshots_dir / f"{record_id}.png"

            latest = self.store.latest()
            latest_screenshot_path = (
                self.store.data_dir / latest.screenshot_path
                if latest is not None and latest.screenshot_path
                else None
            )
            previous_path = (
                latest_screenshot_path
                if latest_screenshot_path is not None and latest_screenshot_path.exists()
                else None
            )

            self.capturer.capture(current_path)
            delta = compare_images(previous_path, current_path)
            advice, model = await self._advise(previous_path, current_path, delta)

            record = AdviceRecord(
                id=record_id,
                created_at=created_at.isoformat(timespec="seconds"),
                screenshot_path=current_path.relative_to(self.store.data_dir).as_posix(),
                previous_screenshot_path=(
                    previous_path.relative_to(self.store.data_dir).as_posix()
                    if previous_path is not None
                    else None
                ),
                changed_percent=delta.changed_percent,
                rms=delta.rms,
                summary=delta.summary,
                advice=advice,
                model=model,
            )
            self.store.append(record)
            await self._notify(record)
            return record

    async def _advise(
        self, previous_path: Path | None, current_path: Path, delta: ImageDelta
    ) -> tuple[str, str]:
        try:
            advice = await self.advisor.advise(previous_path, current_path, delta)
        except Exception as exc:
            return (_fallback_advice(delta, exc), f"fallback:{self.advisor.model}")
        return advice, self.advisor.model

    async def _notify(self, record: AdviceRecord) -> None:
        if self.notifier is None:
            return
        try:
            await self.notifier.notify(record)
        except Exception:
            return


def _fallback_advice(delta: ImageDelta, exc: Exception) -> str:
    return (
        f"{delta.summary}\n\n"
        "ローカルLLMから助言を取得できませんでした。"
        f" Ollamaの起動、モデル名、画面収録権限を確認してください。詳細: {exc}\n\n"
        "次の一手: 直近5分で進めたい作業を1つだけ決めて、次のチェックまで続けてください。"
    )


class MonitorRunner:
    def __init__(self, service: MonitorService, interval_seconds: int) -> None:
        self.service = service
        self.interval_seconds = interval_seconds
        self.last_error: str | None = None
        self._task: asyncio.Task[None] | None = None

    @property
    def running(self) -> bool:
        return self._task is not None and not self._task.done()

    async def start(self, run_immediately: bool = False) -> None:
        if self.running:
            return
        self._task = asyncio.create_task(self._loop(run_immediately=run_immediately))

    async def stop(self) -> None:
        if self._task is None:
            return
        self._task.cancel()
        with suppress(asyncio.CancelledError):
            await self._task
        self._task = None

    async def _loop(self, run_immediately: bool) -> None:
        if run_immediately:
            await self._run_once_safely()
        while True:
            await asyncio.sleep(self.interval_seconds)
            await self._run_once_safely()

    async def _run_once_safely(self) -> None:
        try:
            await self.service.run_once()
            self.last_error = None
        except Exception as exc:
            self.last_error = str(exc)

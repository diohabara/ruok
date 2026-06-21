from pathlib import Path

import pytest
from PIL import Image

from ruok.image_diff import ImageDelta
from ruok.models import AdviceRecord
from ruok.store import RunStore
from ruok.worker import MonitorService


class FakeCapturer:
    def __init__(self) -> None:
        self.colors = ["white", "black"]

    def capture(self, destination: Path) -> Path:
        color = self.colors.pop(0)
        destination.parent.mkdir(parents=True, exist_ok=True)
        Image.new("RGB", (80, 60), color).save(destination)
        return destination


class FakeAdvisor:
    model = "fake-vision"

    def __init__(self) -> None:
        self.calls: list[tuple[Path | None, Path, ImageDelta]] = []

    async def advise(
        self, previous_path: Path | None, current_path: Path, delta: ImageDelta
    ) -> str:
        self.calls.append((previous_path, current_path, delta))
        return "5分以内に次の小さな区切りを決めましょう。"


class FakeNotifier:
    def __init__(self) -> None:
        self.records = []

    async def notify(self, record) -> None:
        self.records.append(record)


@pytest.mark.asyncio
async def test_monitor_service_creates_records_with_previous_screenshot(tmp_path: Path) -> None:
    store = RunStore(tmp_path)
    advisor = FakeAdvisor()
    notifier = FakeNotifier()
    service = MonitorService(
        store=store,
        capturer=FakeCapturer(),
        advisor=advisor,
        notifier=notifier,
    )

    first = await service.run_once()
    second = await service.run_once()

    assert first.previous_screenshot_path is None
    assert second.previous_screenshot_path == first.screenshot_path
    assert second.changed_percent > 90
    assert store.latest() == second
    assert advisor.calls[0][0] is None
    assert advisor.calls[1][0] is not None
    assert [record.id for record in notifier.records] == [first.id, second.id]


@pytest.mark.asyncio
async def test_monitor_service_ignores_missing_previous_screenshot_for_advice(
    tmp_path: Path,
) -> None:
    store = RunStore(tmp_path)
    store.append(
        AdviceRecord(
            id="stale",
            created_at="2026-06-22T01:00:00+09:00",
            screenshot_path="screenshots/deleted.png",
            previous_screenshot_path=None,
            changed_percent=100.0,
            rms=0.0,
            summary="古い記録です。",
            advice="古い助言です。",
            model="fake",
        )
    )
    advisor = FakeAdvisor()
    service = MonitorService(store=store, capturer=FakeCapturer(), advisor=advisor)

    record = await service.run_once()

    assert record.previous_screenshot_path is None
    assert advisor.calls[0][0] is None

from pathlib import Path

from ruok.models import AdviceRecord
from ruok.store import RunStore


def test_store_appends_and_lists_latest_records(tmp_path: Path) -> None:
    store = RunStore(tmp_path)
    first = AdviceRecord(
        id="first",
        created_at="2026-06-22T01:00:00+09:00",
        screenshot_path="screenshots/first.png",
        previous_screenshot_path=None,
        changed_percent=100.0,
        rms=0.0,
        summary="初回です。",
        advice="まず作業の意図を確認しましょう。",
        model="fallback",
    )
    second = AdviceRecord(
        id="second",
        created_at="2026-06-22T01:05:00+09:00",
        screenshot_path="screenshots/second.png",
        previous_screenshot_path="screenshots/first.png",
        changed_percent=12.0,
        rms=20.0,
        summary="少し変化しました。",
        advice="次の小さな区切りを決めましょう。",
        model="fallback",
    )

    store.append(first)
    store.append(second)

    assert store.latest().id == "second"
    assert [record.id for record in store.list_records(limit=1)] == ["second"]
    assert [record.id for record in store.list_records(limit=10)] == ["second", "first"]


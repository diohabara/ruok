import pytest

from ruok.models import AdviceRecord
import ruok.notifier as notifier
from ruok.notifier import FallbackNotificationSink, notification_from_record


def _record() -> AdviceRecord:
    return AdviceRecord(
        id="check-1",
        created_at="2026-06-22T01:00:00+09:00",
        screenshot_path="screenshots/check-1.png",
        previous_screenshot_path=None,
        changed_percent=12.5,
        rms=30.0,
        summary="小さな変化があります。",
        advice=(
            "1. 状況: エディタからブラウザへ移動しました。\n"
            "2. 注意: 調査に寄りすぎています。\n"
            "3. 次の一手: いま書く1行を決めて戻りましょう。"
        ),
        model="qwen2.5vl:7b",
    )


def test_notification_message_uses_advice_summary_and_next_action() -> None:
    record = _record()

    message = notification_from_record(record)

    assert message.title == "RUOK: 小さな変化があります。"
    assert "12.5% changed" in message.subtitle
    assert "次の一手" in message.body
    assert len(message.body) <= 220


def test_notifier_module_defers_pync_import_until_desktop_notification() -> None:
    assert "Notifier" not in notifier.__dict__


class FailingSink:
    async def notify(self, record: AdviceRecord) -> None:
        raise RuntimeError("notifications blocked")


class RecordingSink:
    def __init__(self) -> None:
        self.records: list[AdviceRecord] = []

    async def notify(self, record: AdviceRecord) -> None:
        self.records.append(record)


@pytest.mark.asyncio
async def test_fallback_notification_sink_uses_backup_when_primary_fails() -> None:
    backup = RecordingSink()
    sink = FallbackNotificationSink(primary=FailingSink(), fallback=backup)
    record = _record()

    await sink.notify(record)

    assert backup.records == [record]

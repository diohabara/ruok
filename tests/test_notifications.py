from dataclasses import replace

import pytest

from ruok.image_diff import ImageDelta
from ruok.models import AdviceRecord
import ruok.notifier as notifier
from ruok.notifier import FallbackNotificationSink, notification_from_record
from ruok.worker import _fallback_advice


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

    assert message.title == "助言"
    assert message.subtitle == "小さな変化があります。 · 12.5% · qwen2.5vl:7b"
    assert message.body.startswith("次の一手: いま書く1行を決めて戻りましょう。")
    assert "状況: エディタからブラウザへ移動しました。" in message.body
    assert "注意: 調査に寄りすぎています。" in message.body
    assert len(message.body) <= 260


def test_notification_message_marks_fallback_model_as_disconnected() -> None:
    fallback_record = replace(
        _record(),
        model="fallback:qwen2.5vl:7b",
        advice=_fallback_advice(
            ImageDelta(
                has_previous=True,
                changed_percent=12.5,
                rms=30.0,
                summary="小さな変化があります。",
            ),
            RuntimeError("Ollama refused connection"),
        ),
    )

    message = notification_from_record(fallback_record)

    assert message.title == "助言"
    assert message.subtitle == "小さな変化があります。 · 12.5% · LLM未接続"
    assert "ローカルLLMから助言を取得できませんでした。" in message.body
    assert "Ollama refused connection" in message.body
    assert "次の一手: 直近5分で進めたい作業を1つだけ決めて" in message.body
    assert len(message.body) <= 260


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

from __future__ import annotations

import asyncio
import re
from dataclasses import dataclass
from typing import Protocol

from ruok.models import AdviceRecord


@dataclass(frozen=True)
class NotificationMessage:
    title: str
    subtitle: str
    body: str


class NotificationSink(Protocol):
    async def notify(self, record: AdviceRecord) -> None: ...


def notification_from_record(record: AdviceRecord) -> NotificationMessage:
    is_fallback = record.model.startswith("fallback:")
    title = _action_title(record.advice, is_fallback=is_fallback)
    subtitle = f"{record.summary} · {record.changed_percent:.1f}% · {_model_label(record.model)}"
    body = _compact(
        _format_advice_body(record.advice, preserve_diagnostics=is_fallback),
        limit=260,
    )
    return NotificationMessage(title=title, subtitle=subtitle, body=body)


class DesktopNotificationSink:
    async def notify(self, record: AdviceRecord) -> None:
        message = notification_from_record(record)
        await asyncio.to_thread(
            _pync_notifier().notify,
            message.body,
            title=message.title,
            subtitle=message.subtitle,
        )


class ConsoleNotificationSink:
    async def notify(self, record: AdviceRecord) -> None:
        message = notification_from_record(record)
        print(f"\n[{message.title}] {message.subtitle}\n{message.body}\n", flush=True)


class FallbackNotificationSink:
    def __init__(self, primary: NotificationSink, fallback: NotificationSink) -> None:
        self.primary = primary
        self.fallback = fallback

    async def notify(self, record: AdviceRecord) -> None:
        try:
            await self.primary.notify(record)
        except Exception:
            await self.fallback.notify(record)


def _compact(text: str, limit: int) -> str:
    normalized = "\n".join(line.strip() for line in text.splitlines() if line.strip())
    if len(normalized) <= limit:
        return normalized
    return normalized[: limit - 3].rstrip() + "..."


def _format_advice_body(advice: str, preserve_diagnostics: bool = False) -> str:
    if preserve_diagnostics:
        return _format_diagnostic_body(advice)

    sections = _extract_advice_sections(advice)
    next_action = sections.get("次の一手")
    if not next_action:
        return advice

    lines = [f"次の一手: {next_action}"]
    if situation := sections.get("状況"):
        lines.append(f"状況: {situation}")
    if caution := sections.get("注意"):
        lines.append(f"注意: {caution}")
    return "\n".join(lines)


def _format_diagnostic_body(advice: str) -> str:
    lines = _nonempty_lines(advice)
    diagnostic = next(
        (line for line in lines if "ローカルLLM" in line or "詳細:" in line),
        None,
    )
    if not diagnostic:
        return advice

    sections = _extract_advice_sections(advice)
    body = [diagnostic]
    if next_action := sections.get("次の一手"):
        body.append(f"次の一手: {next_action}")
    return "\n".join(body)


def _action_title(advice: str, is_fallback: bool = False) -> str:
    if is_fallback:
        return "Ollama接続を確認しましょう"

    sections = _extract_advice_sections(advice)
    if next_action := sections.get("次の一手"):
        return _compact_title(next_action)
    return "次の小さな行動を決めましょう"


def _compact_title(text: str, limit: int = 34) -> str:
    title = re.sub(r"[。.!！]+$", "", text.strip())
    if len(title) <= limit:
        return title
    return title[: limit - 1].rstrip() + "…"


def _extract_advice_sections(advice: str) -> dict[str, str]:
    sections: dict[str, str] = {}
    for raw_line in advice.splitlines():
        line = re.sub(r"^\s*\d+[.)]\s*", "", raw_line.strip())
        for label in ("状況", "注意", "次の一手"):
            match = re.match(rf"^{label}\s*[:：]\s*(.+)$", line)
            if match:
                sections[label] = match.group(1).strip()
                break
    return sections


def _nonempty_lines(text: str) -> list[str]:
    return [line.strip() for line in text.splitlines() if line.strip()]


def _model_label(model: str) -> str:
    if model.startswith("fallback:"):
        return "LLM未接続"
    return model


def _pync_notifier():
    from pync import Notifier

    return Notifier

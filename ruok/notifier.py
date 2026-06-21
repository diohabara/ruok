from __future__ import annotations

import asyncio
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
    title = f"RUOK: {record.summary}"
    subtitle = f"{record.changed_percent:.1f}% changed · {record.model}"
    body = _compact(record.advice, limit=220)
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


def _pync_notifier():
    from pync import Notifier

    return Notifier

from __future__ import annotations

import argparse
import asyncio
import os
from collections.abc import Sequence
from pathlib import Path

from ruok.capture import MssScreenshotCapturer
from ruok.image_storage import DEFAULT_MAX_SCREENSHOT_EDGE, ScreenshotStorageOptimizer
from ruok.notifier import (
    ConsoleNotificationSink,
    DesktopNotificationSink,
    FallbackNotificationSink,
    NotificationSink,
)
from ruok.ollama_client import OllamaVisionAdvisor
from ruok.store import RunStore
from ruok.worker import MonitorService


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run the RUOK local notification monitor.")
    parser.add_argument("--data-dir", default=os.getenv("RUOK_DATA_DIR", "data"))
    parser.add_argument("--interval", type=int, default=int(os.getenv("RUOK_INTERVAL_SECONDS", "300")))
    parser.add_argument("--model", default=os.getenv("RUOK_OLLAMA_MODEL", "qwen2.5vl:7b"))
    parser.add_argument(
        "--max-screenshot-edge",
        type=int,
        default=int(os.getenv("RUOK_MAX_SCREENSHOT_EDGE", str(DEFAULT_MAX_SCREENSHOT_EDGE))),
        help="Downscale stored screenshots when their longest edge exceeds this size.",
    )
    parser.add_argument(
        "--ollama-endpoint",
        default=os.getenv("RUOK_OLLAMA_ENDPOINT", "http://localhost:11434"),
    )
    parser.add_argument("--once", action="store_true", help="Run one check and exit.")
    parser.add_argument(
        "--console",
        action="store_true",
        help="Print notifications to stdout instead of sending desktop notifications.",
    )
    parser.add_argument(
        "--no-immediate",
        action="store_true",
        help="Wait one interval before the first check when running continuously.",
    )
    args = parser.parse_args(argv)
    if args.interval <= 0:
        parser.error("--interval must be a positive integer")
    if args.max_screenshot_edge <= 0:
        parser.error("--max-screenshot-edge must be a positive integer")
    return args


def main() -> None:
    args = parse_args()
    try:
        asyncio.run(run(args))
    except KeyboardInterrupt:
        print("\nRUOK stopped.", flush=True)


async def run(args: argparse.Namespace) -> None:
    service = build_service(args)
    if args.once:
        await service.run_once()
        return

    if not args.no_immediate:
        await service.run_once()

    while True:
        await asyncio.sleep(args.interval)
        await service.run_once()


def build_service(args: argparse.Namespace) -> MonitorService:
    notifier = _notifier(console=args.console)
    return MonitorService(
        store=RunStore(Path(args.data_dir)),
        capturer=MssScreenshotCapturer(max_edge=args.max_screenshot_edge),
        advisor=OllamaVisionAdvisor(model=args.model, endpoint=args.ollama_endpoint),
        notifier=notifier,
        screenshot_compressor=ScreenshotStorageOptimizer(max_edge=args.max_screenshot_edge),
    )


def _notifier(console: bool) -> NotificationSink:
    console_sink = ConsoleNotificationSink()
    if console:
        return console_sink
    return FallbackNotificationSink(primary=DesktopNotificationSink(), fallback=console_sink)

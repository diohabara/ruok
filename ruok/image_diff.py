from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from math import sqrt

from PIL import Image, ImageChops, ImageStat

@dataclass(frozen=True)
class ImageDelta:
    has_previous: bool
    changed_percent: float
    rms: float
    summary: str


def compare_images(previous_path: Path | None, current_path: Path) -> ImageDelta:
    if previous_path is None or not previous_path.exists():
        return ImageDelta(
            has_previous=False,
            changed_percent=100.0,
            rms=0.0,
            summary="初回のスクリーンショットです。次回から前回との差分を比較します。",
        )

    with Image.open(previous_path) as previous_image, Image.open(current_path) as current_image:
        previous = previous_image.convert("RGB").resize((256, 144))
        current = current_image.convert("RGB").resize((256, 144))
        diff = ImageChops.difference(previous, current)

    grayscale = diff.convert("L")
    histogram = grayscale.histogram()
    changed_pixels = sum(count for value, count in enumerate(histogram) if value > 12)
    total_pixels = sum(histogram)
    changed_percent = round((changed_pixels / total_pixels) * 100, 1) if total_pixels else 0.0

    stat = ImageStat.Stat(diff)
    rms = round(sqrt(sum(value * value for value in stat.rms) / len(stat.rms)), 1)

    if changed_percent < 1:
        summary = "画面変化はほとんどありません。"
    elif changed_percent < 10:
        summary = "小さな変化があります。"
    elif changed_percent < 35:
        summary = "変化があります。"
    else:
        summary = "大きな変化があります。"

    return ImageDelta(
        has_previous=True,
        changed_percent=changed_percent,
        rms=rms,
        summary=summary,
    )

from __future__ import annotations

from pathlib import Path

from PIL import Image

DEFAULT_MAX_SCREENSHOT_EDGE = 1600
IMAGE_SUFFIXES = {".png", ".jpg", ".jpeg"}


class ScreenshotStorageOptimizer:
    def __init__(self, max_edge: int = DEFAULT_MAX_SCREENSHOT_EDGE) -> None:
        self.max_edge = max_edge

    def compress_directory(self, directory: Path) -> int:
        return compress_screenshot_directory(directory, max_edge=self.max_edge)


def save_screenshot_image(
    image: Image.Image,
    destination: Path,
    max_edge: int = DEFAULT_MAX_SCREENSHOT_EDGE,
) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    _resize_to_max_edge(image.convert("RGB"), max_edge).save(destination, **_save_options(destination))
    return destination


def compress_image_file(path: Path, max_edge: int = DEFAULT_MAX_SCREENSHOT_EDGE) -> bool:
    if not path.exists() or path.suffix.lower() not in IMAGE_SUFFIXES:
        return False

    try:
        with Image.open(path) as image:
            original_size = image.size
            compressed = _resize_to_max_edge(image.convert("RGB"), max_edge)
            if compressed.size == original_size:
                return False
            save_screenshot_image(compressed, path, max_edge=max_edge)
            return True
    except OSError:
        return False


def compress_screenshot_directory(
    directory: Path,
    max_edge: int = DEFAULT_MAX_SCREENSHOT_EDGE,
) -> int:
    if not directory.exists():
        return 0

    changed = 0
    for path in directory.iterdir():
        if compress_image_file(path, max_edge=max_edge):
            changed += 1
    return changed


def _resize_to_max_edge(image: Image.Image, max_edge: int) -> Image.Image:
    if max_edge <= 0:
        raise ValueError("max_edge must be positive")

    width, height = image.size
    longest = max(width, height)
    if longest <= max_edge:
        return image

    scale = max_edge / longest
    size = (max(1, round(width * scale)), max(1, round(height * scale)))
    return image.resize(size, Image.Resampling.LANCZOS)


def _save_options(destination: Path) -> dict[str, object]:
    if destination.suffix.lower() in {".jpg", ".jpeg"}:
        return {"quality": 85, "optimize": True}
    return {"optimize": True, "compress_level": 9}

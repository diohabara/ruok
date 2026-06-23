from __future__ import annotations

from pathlib import Path

import mss
from PIL import Image

from ruok.image_storage import DEFAULT_MAX_SCREENSHOT_EDGE, save_screenshot_image


class MssScreenshotCapturer:
    def __init__(self, max_edge: int = DEFAULT_MAX_SCREENSHOT_EDGE) -> None:
        self.max_edge = max_edge

    def capture(self, destination: Path) -> Path:
        with mss.mss() as screen:
            monitor = screen.monitors[0]
            shot = screen.grab(monitor)
        image = Image.frombytes("RGB", shot.size, shot.rgb)
        return save_screenshot_image(image, destination, max_edge=self.max_edge)

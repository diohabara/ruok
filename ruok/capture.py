from __future__ import annotations

from pathlib import Path

import mss
from PIL import Image


class MssScreenshotCapturer:
    def capture(self, destination: Path) -> Path:
        destination.parent.mkdir(parents=True, exist_ok=True)
        with mss.mss() as screen:
            monitor = screen.monitors[0]
            shot = screen.grab(monitor)
        image = Image.frombytes("RGB", shot.size, shot.rgb)
        image.save(destination)
        return destination


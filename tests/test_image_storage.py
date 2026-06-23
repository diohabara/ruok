from pathlib import Path

from PIL import Image

from ruok.image_storage import compress_image_file, compress_screenshot_directory


def _image(path: Path, size: tuple[int, int]) -> Path:
    Image.new("RGB", size, "white").save(path)
    return path


def test_compress_image_file_downscales_oversized_screenshot(tmp_path: Path) -> None:
    screenshot = _image(tmp_path / "large.png", (400, 200))

    changed = compress_image_file(screenshot, max_edge=100)

    assert changed is True
    with Image.open(screenshot) as image:
        assert image.size == (100, 50)


def test_compress_image_file_downscales_oversized_jpeg(tmp_path: Path) -> None:
    screenshot = _image(tmp_path / "large.jpg", (400, 200))

    changed = compress_image_file(screenshot, max_edge=100)

    assert changed is True
    with Image.open(screenshot) as image:
        assert image.size == (100, 50)


def test_compress_image_file_keeps_small_screenshot_unchanged(tmp_path: Path) -> None:
    screenshot = _image(tmp_path / "small.png", (80, 40))

    changed = compress_image_file(screenshot, max_edge=100)

    assert changed is False
    with Image.open(screenshot) as image:
        assert image.size == (80, 40)


def test_compress_screenshot_directory_counts_oversized_images(tmp_path: Path) -> None:
    _image(tmp_path / "large.png", (400, 200))
    _image(tmp_path / "small.png", (80, 40))
    (tmp_path / "notes.txt").write_text("not an image", encoding="utf-8")

    changed = compress_screenshot_directory(tmp_path, max_edge=100)

    assert changed == 1

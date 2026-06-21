from pathlib import Path

from PIL import Image, ImageDraw

from ruok.image_diff import compare_images


def _image(path: Path, color: str, marker: str | None = None) -> Path:
    image = Image.new("RGB", (120, 80), color)
    if marker:
        draw = ImageDraw.Draw(image)
        draw.rectangle((60, 20, 100, 60), fill=marker)
    image.save(path)
    return path


def test_compare_images_reports_no_previous_screenshot(tmp_path: Path) -> None:
    current = _image(tmp_path / "current.png", "white")

    delta = compare_images(None, current)

    assert delta.has_previous is False
    assert delta.changed_percent == 100.0
    assert "初回" in delta.summary


def test_compare_images_scores_visual_change(tmp_path: Path) -> None:
    previous = _image(tmp_path / "previous.png", "white")
    current = _image(tmp_path / "current.png", "white", marker="black")

    delta = compare_images(previous, current)

    assert delta.has_previous is True
    assert delta.changed_percent > 5
    assert delta.rms > 20
    assert "変化" in delta.summary


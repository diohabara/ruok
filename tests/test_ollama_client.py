import base64
from pathlib import Path

from PIL import Image

from ruok.image_diff import ImageDelta
from ruok.ollama_client import OllamaVisionAdvisor


def _png(path: Path, color: str) -> Path:
    Image.new("RGB", (16, 16), color).save(path)
    return path


def test_ollama_payload_sends_two_screenshots_and_no_streaming(tmp_path: Path) -> None:
    previous = _png(tmp_path / "previous.png", "white")
    current = _png(tmp_path / "current.png", "black")
    advisor = OllamaVisionAdvisor(model="qwen2.5vl:7b", endpoint="http://localhost:11434")
    delta = ImageDelta(
        has_previous=True,
        changed_percent=42.5,
        rms=91.2,
        summary="大きな変化があります。",
    )

    payload = advisor.build_payload(previous, current, delta)

    assert payload["model"] == "qwen2.5vl:7b"
    assert payload["stream"] is False
    assert len(payload["messages"]) == 1
    message = payload["messages"][0]
    assert message["role"] == "user"
    assert len(message["images"]) == 2
    assert base64.b64decode(message["images"][0])
    assert "42.5%" in message["content"]
    assert "日本語" in message["content"]


def test_ollama_client_uses_short_connect_timeout() -> None:
    advisor = OllamaVisionAdvisor(model="qwen2.5vl:7b", endpoint="http://localhost:11434")

    assert advisor.timeout.connect == 2.0
    assert advisor.timeout.read == 120.0

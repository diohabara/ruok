from __future__ import annotations

import base64
from pathlib import Path

import httpx

from ruok.image_diff import ImageDelta


class OllamaVisionAdvisor:
    def __init__(self, model: str, endpoint: str) -> None:
        self.model = model
        self.endpoint = endpoint.rstrip("/")
        self.timeout = httpx.Timeout(connect=2.0, read=120.0, write=30.0, pool=5.0)

    def build_payload(
        self, previous_path: Path | None, current_path: Path, delta: ImageDelta
    ) -> dict[str, object]:
        images = []
        if previous_path is not None:
            images.append(_read_image_base64(previous_path))
        images.append(_read_image_base64(current_path))

        prompt = (
            "あなたは作業中の画面を5分ごとに見守るローカルアシスタントです。\n"
            "添付画像は、前回のスクリーンショット、今回のスクリーンショットの順です。"
            "画像が1枚だけの場合は初回チェックです。\n\n"
            f"画像差分: 変化率 {delta.changed_percent:.1f}%, RMS {delta.rms:.1f}。"
            f"機械的な要約: {delta.summary}\n\n"
            "日本語で、次の形式で短く返してください。\n"
            "1. 状況: 画面上で何が変わったか、または停滞しているか\n"
            "2. 注意: 集中・休憩・迷走・セキュリティ・個人情報露出の観点で気づいたこと\n"
            "3. 次の一手: 5分以内に取れる具体的な行動を1つ\n"
            "次の一手は通知タイトルに使うため、20〜30字程度の短い行動文にしてください。"
            "できれば動詞から始め、今すぐ着手できる内容にしてください。\n"
            "推測しすぎず、画面から分かる範囲に限定してください。"
        )

        return {
            "model": self.model,
            "stream": False,
            "messages": [
                {
                    "role": "user",
                    "content": prompt,
                    "images": images,
                }
            ],
        }

    async def advise(
        self, previous_path: Path | None, current_path: Path, delta: ImageDelta
    ) -> str:
        payload = self.build_payload(previous_path, current_path, delta)
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(f"{self.endpoint}/api/chat", json=payload)
            response.raise_for_status()
            body = response.json()

        message = body.get("message")
        if isinstance(message, dict) and isinstance(message.get("content"), str):
            return message["content"].strip()
        if isinstance(body.get("response"), str):
            return body["response"].strip()
        raise ValueError("Ollama response did not include message.content")


def _read_image_base64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")

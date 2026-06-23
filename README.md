# RUOK

RUOK is a local screen check-in app. It captures your screen every 5 minutes,
compares it with the previous screenshot, and asks a local vision LLM for a short
Japanese suggestion. Suggestions are delivered as desktop notifications.

The default local LLM backend is an Ollama-compatible API.

## Requirements

- macOS 13+ for the native menu bar app
- Xcode Command Line Tools or another Swift toolchain for building the app
- Ollama running locally
- A vision-capable Ollama model, for example `qwen2.5vl:7b` or `llava`

On macOS, the app that starts RUOK needs Screen Recording permission and
notification permission.

The Python CLI is still available for non-menu-bar use and requires Python 3.11+
and `uv`.

## macOS Menu Bar App

Build and open the native Swift/AppKit menu bar app:

```bash
scripts/build-menu-bar-app.sh
open dist/RUOK.app
```

The app appears in the macOS menu bar and does not start monitoring until you
choose `開始`. The monitoring loop, screenshot capture, screenshot compression,
Ollama API call, image comparison, and notifications are implemented in Swift.

Menu actions:

- `開始`: run RUOK every `RUOK_INTERVAL_SECONDS` seconds, defaulting to 300.
- `停止`: stop the background monitor.
- `今すぐ1回実行`: take one screenshot and send one notification.
- `データフォルダを開く`: open the native app data directory.
- `ログを開く`: open `~/Library/Logs/RUOK/ruok.menubar.log`.

By default, the app stores data under `~/Library/Application Support/RUOK/data`.
Set `RUOK_DATA_DIR` to override it.

## Python CLI

```bash
ollama serve
ollama pull qwen2.5vl:7b
uv run ruok --ollama-endpoint http://127.0.0.1:11434
```

By default RUOK runs one check immediately, sends a desktop notification, then
repeats every 300 seconds.

For setup and permission checks, run one check and print the notification text to
the terminal:

```bash
uv run ruok --once --console
```

## Options

```bash
uv run ruok --interval 300 --model qwen2.5vl:7b --data-dir data
uv run ruok --max-screenshot-edge 1600
uv run ruok --once
uv run ruok --console
uv run ruok --no-immediate
```

Environment variables are also supported:

```bash
RUOK_INTERVAL_SECONDS=300 \
RUOK_OLLAMA_MODEL=qwen2.5vl:7b \
RUOK_OLLAMA_ENDPOINT=http://localhost:11434 \
RUOK_MAX_SCREENSHOT_EDGE=1600 \
uv run ruok
```

Python CLI notifications use the `pync` package on macOS. `--console` is
available as a fallback when desktop notifications are blocked by OS settings.

## macOS LaunchAgent

Use the installer script to generate a LaunchAgent plist for the current
checkout and start RUOK in the background:

```bash
scripts/install-launch-agent.sh
launchctl print "gui/$(id -u)/io.github.diohabara.ruok.monitor"
```

Stop it with:

```bash
launchctl bootout "gui/$(id -u)/io.github.diohabara.ruok.monitor"
```

The installer respects `RUOK_INTERVAL_SECONDS`, `RUOK_OLLAMA_MODEL`,
`RUOK_OLLAMA_ENDPOINT`, `RUOK_MAX_SCREENSHOT_EDGE`, `RUOK_LAUNCHD_LABEL`, and
`UV_BIN` when generating the plist.

## Data

The native menu bar app stores screenshots and advice logs under
`~/Library/Application Support/RUOK/data` by default. The Python CLI stores them
under `data/` by default:

- `data/screenshots/*.png`
- `data/records.jsonl`

These files may contain sensitive screen content. Keep them local or add your own
retention policy before sharing the directory.

Stored screenshots are downscaled when their longest edge exceeds 1600 pixels by
default. RUOK also checks the existing screenshot directory before each run, so
oversized accumulated screenshots are compacted over time.

## Local Development

```bash
uv run --extra dev pytest -q
uv run --extra dev ruff check .
```

# RUOK

RUOK is a local screen check-in app. It captures your screen every 5 minutes,
compares it with the previous screenshot, and asks a local vision LLM for a short
Japanese suggestion. Suggestions are delivered as desktop notifications.

The default local LLM backend is an Ollama-compatible API.

## Requirements

- macOS, Linux, or another desktop environment supported by `mss`
- Python 3.11+
- `uv`
- Ollama running locally
- A vision-capable Ollama model, for example `qwen2.5vl:7b` or `llava`

On macOS, the terminal app that runs RUOK needs Screen Recording permission and
notification permission.

## Run

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
uv run ruok --once
uv run ruok --console
uv run ruok --no-immediate
```

Environment variables are also supported:

```bash
RUOK_INTERVAL_SECONDS=300 \
RUOK_OLLAMA_MODEL=qwen2.5vl:7b \
RUOK_OLLAMA_ENDPOINT=http://localhost:11434 \
uv run ruok
```

Notifications use the `pync` Python package on macOS. `--console` is available as
a fallback when desktop notifications are blocked by OS settings.

## macOS LaunchAgent

Use the installer script to generate a LaunchAgent plist for the current
checkout and start RUOK in the background:

```bash
scripts/install-launch-agent.sh
launchctl print "gui/$(id -u)/local.ruok.monitor"
```

Stop it with:

```bash
launchctl bootout "gui/$(id -u)/local.ruok.monitor"
```

The installer respects `RUOK_INTERVAL_SECONDS`, `RUOK_OLLAMA_MODEL`,
`RUOK_OLLAMA_ENDPOINT`, `RUOK_LAUNCHD_LABEL`, and `UV_BIN` when generating the
plist.

## Data

Screenshots and advice logs are stored under `data/` by default:

- `data/screenshots/*.png`
- `data/records.jsonl`

These files may contain sensitive screen content. Keep them local or add your own
retention policy before sharing the directory.

## Local Development

```bash
uv run --extra dev pytest -q
uv run --extra dev ruff check .
```

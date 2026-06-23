#!/bin/sh
set -eu

LABEL="${RUOK_LAUNCHD_LABEL:-io.github.diohabara.ruok.monitor}"
LEGACY_LABEL="local.ruok.monitor"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
UV_BIN="${UV_BIN:-$(command -v uv)}"
UV_BIN="$(cd "$(dirname "${UV_BIN}")" && pwd -P)/$(basename "${UV_BIN}")"
MODEL="${RUOK_OLLAMA_MODEL:-qwen2.5vl:7b}"
ENDPOINT="${RUOK_OLLAMA_ENDPOINT:-http://127.0.0.1:11434}"
INTERVAL="${RUOK_INTERVAL_SECONDS:-300}"
MAX_SCREENSHOT_EDGE="${RUOK_MAX_SCREENSHOT_EDGE:-1600}"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LABEL}.plist"
LEGACY_PLIST_PATH="${LAUNCH_AGENTS_DIR}/${LEGACY_LABEL}.plist"

mkdir -p "${ROOT_DIR}/logs" "${LAUNCH_AGENTS_DIR}"

LABEL="${LABEL}" \
ROOT_DIR="${ROOT_DIR}" \
UV_BIN="${UV_BIN}" \
MODEL="${MODEL}" \
ENDPOINT="${ENDPOINT}" \
INTERVAL="${INTERVAL}" \
MAX_SCREENSHOT_EDGE="${MAX_SCREENSHOT_EDGE}" \
PLIST_PATH="${PLIST_PATH}" \
"${UV_BIN}" run python - <<'PY'
from __future__ import annotations

import os
import plistlib
from pathlib import Path

root_dir = Path(os.environ["ROOT_DIR"])
plist = {
    "Label": os.environ["LABEL"],
    "ProgramArguments": [
        os.environ["UV_BIN"],
        "run",
        "ruok",
        "--model",
        os.environ["MODEL"],
        "--ollama-endpoint",
        os.environ["ENDPOINT"],
        "--interval",
        os.environ["INTERVAL"],
        "--max-screenshot-edge",
        os.environ["MAX_SCREENSHOT_EDGE"],
    ],
    "WorkingDirectory": str(root_dir),
    "EnvironmentVariables": {
        "PATH": (
            f"{Path.home()}/bin:/opt/homebrew/bin:/usr/local/bin:"
            "/usr/bin:/bin:/usr/sbin:/sbin"
        )
    },
    "RunAtLoad": True,
    "KeepAlive": True,
    "ThrottleInterval": 30,
    "StandardOutPath": str(root_dir / "logs" / "ruok.launchd.log"),
    "StandardErrorPath": str(root_dir / "logs" / "ruok.launchd.err.log"),
}

with Path(os.environ["PLIST_PATH"]).open("wb") as file:
    plistlib.dump(plist, file, sort_keys=False)
PY

plutil -lint "${PLIST_PATH}"
if [ "${LABEL}" != "${LEGACY_LABEL}" ]; then
  launchctl bootout "gui/$(id -u)/${LEGACY_LABEL}" 2>/dev/null || true
  rm -f "${LEGACY_PLIST_PATH}"
fi
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
launchctl print "gui/$(id -u)/${LABEL}" | sed -n '1,80p'

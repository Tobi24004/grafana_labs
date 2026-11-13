#!/usr/bin/env bash
# Chạy dashboard ở http://localhost:8787  (Ctrl+C để dừng)
set -euo pipefail
PORT="${1:-8787}"
cd "$(dirname "$0")"
echo "→ http://localhost:${PORT}/"
exec python3 -m http.server "$PORT" --bind 127.0.0.1

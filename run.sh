#!/usr/bin/env bash
# Mở dashboard như một app desktop.
#  1. Cửa sổ native GTK + WebKit2  (không thanh địa chỉ, không tab)
#  2. Nếu máy thiếu WebKit2 → chế độ --app của Chrome/Chromium
#  3. Nếu không có cả hai → mở bằng trình duyệt mặc định
set -euo pipefail
cd "$(dirname "$0")"
PAGE="$PWD/index.html"

if python3 -c "import gi; gi.require_version('WebKit2','4.1')" 2>/dev/null; then
  exec python3 desktop/app.py "$@"
fi

for B in google-chrome chromium chromium-browser brave-browser microsoft-edge; do
  if command -v "$B" >/dev/null; then
    echo "WebKit2 không có — dùng $B ở chế độ app."
    exec "$B" --app="file://$PAGE" --window-size=1480,920 --class=GrafanaLabsNOC
  fi
done

echo "Không có WebKit2 lẫn Chrome — mở bằng trình duyệt mặc định."
exec xdg-open "file://$PAGE"

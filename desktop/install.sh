#!/usr/bin/env bash
# Thêm app vào menu ứng dụng (GNOME/KDE/XFCE…) để bấm mở như mọi app khác.
#   ./desktop/install.sh            cài
#   ./desktop/install.sh --remove   gỡ
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/scalable/apps"
ID="com.example.grafanalabs.noc"

if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$APPS/$ID.desktop" "$ICONS/$ID.svg"
  command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" || true
  echo "Đã gỡ khỏi menu ứng dụng."
  exit 0
fi

mkdir -p "$APPS" "$ICONS"
install -m 644 "$ROOT/desktop/icon.svg" "$ICONS/$ID.svg"
cat > "$APPS/$ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Version=1.0
Name=Network Operations Center
GenericName=Grafana NOC dashboard
Comment=Mô phỏng Grafana cho hạ tầng mạng — dữ liệu sinh trong máy, không kết nối hệ thống thật
Exec=$ROOT/run.sh
Path=$ROOT
Icon=$ID
Terminal=false
StartupNotify=true
StartupWMClass=$ID
Categories=Network;Monitor;
Keywords=grafana;network;noc;monitoring;dashboard;
DESKTOP
chmod 644 "$APPS/$ID.desktop"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" || true
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
echo "Đã cài: $APPS/$ID.desktop"
echo "Tìm \"Network Operations Center\" trong menu ứng dụng (có thể cần đăng xuất/đăng nhập lại nếu chưa thấy)."

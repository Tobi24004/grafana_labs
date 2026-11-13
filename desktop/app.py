#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Network Operations Center — app desktop.

Mở dashboard trong một cửa sổ native (GTK + WebKit2), không thanh địa chỉ,
không tab, không cần web server. Chỉ dùng thư viện có sẵn của hệ thống.

Chạy:   ./desktop/app.py            (hoặc ./run.sh ở thư mục gốc)
Tự kiểm tra: ./desktop/app.py --selftest
"""
import os
import sys
import pathlib

APP_ID = "com.example.grafanalabs.noc"
TITLE = "Network Operations Center"
ROOT = pathlib.Path(__file__).resolve().parent.parent
PAGE = ROOT / "index.html"
ICON = ROOT / "desktop" / "icon.svg"
BG = "#111217"  # nền tối của dashboard, tránh nháy trắng lúc nạp

try:
    import gi

    gi.require_version("Gtk", "3.0")
    gi.require_version("WebKit2", "4.1")
    from gi.repository import Gtk, Gdk, GLib, WebKit2
except (ImportError, ValueError) as exc:  # thiếu python3-gi hoặc WebKit2
    sys.stderr.write(
        "Không nạp được GTK/WebKit2 (%s).\n"
        "Cài bằng:  sudo apt install python3-gi gir1.2-webkit2-4.1\n"
        "Hoặc dùng bản dự phòng chạy bằng trình duyệt:  ./run.sh\n" % exc
    )
    sys.exit(1)


class NocWindow(Gtk.Window):
    def __init__(self, selftest=False):
        super().__init__(title=TITLE)
        self.set_default_size(1480, 920)
        self.set_position(Gtk.WindowPosition.CENTER)
        if ICON.exists():
            try:
                self.set_icon_from_file(str(ICON))
            except GLib.Error:
                pass

        self.view = WebKit2.WebView()
        rgba = Gdk.RGBA()
        rgba.parse(BG)
        self.view.set_background_color(rgba)

        st = self.view.get_settings()
        st.set_property("enable-developer-extras", True)
        st.set_property("enable-write-console-messages-to-stdout", True)
        st.set_property("javascript-can-access-clipboard", True)  # nút copy CSV

        self.add(self.view)
        self.connect("destroy", Gtk.main_quit)
        self.connect("key-press-event", self.on_key)

        self.fullscreened = False
        self.view.load_uri(PAGE.as_uri())

        if selftest:
            self.view.connect("load-changed", self.on_selftest_load)
            GLib.timeout_add_seconds(15, self.selftest_timeout)

    # ---- phím tắt của cửa sổ (phím tắt trong dashboard do trang tự xử lý) ----
    def on_key(self, _w, ev):
        key = Gdk.keyval_name(ev.keyval)
        ctrl = ev.state & Gdk.ModifierType.CONTROL_MASK
        if key == "F11":
            self.unfullscreen() if self.fullscreened else self.fullscreen()
            self.fullscreened = not self.fullscreened
            return True
        if ctrl and key in ("q", "w"):
            Gtk.main_quit()
            return True
        if (ctrl and key == "r") or key == "F5":
            self.view.reload()
            return True
        if ctrl and key in ("plus", "equal"):
            self.view.set_zoom_level(min(3.0, self.view.get_zoom_level() + 0.1))
            return True
        if ctrl and key == "minus":
            self.view.set_zoom_level(max(0.4, self.view.get_zoom_level() - 0.1))
            return True
        if ctrl and key == "0":
            self.view.set_zoom_level(1.0)
            return True
        return False

    # ---- tự kiểm tra: nạp xong trang thì báo kết quả rồi thoát ----
    def on_selftest_load(self, view, event):
        if event != WebKit2.LoadEvent.FINISHED:
            return
        js = (
            "JSON.stringify({tab:document.querySelectorAll('.tab').length,"
            "panel:document.querySelectorAll('.panel').length,"
            "title:document.title})"
        )
        if hasattr(view, "evaluate_javascript"):  # WebKit 2.40+
            view.evaluate_javascript(js, -1, None, None, None, self.on_selftest_result, None)
        else:
            view.run_javascript(js, None, self.on_selftest_result, None)

    def on_selftest_result(self, view, result, _data):
        try:
            if hasattr(view, "evaluate_javascript_finish"):
                value = view.evaluate_javascript_finish(result).to_string()
            else:
                value = view.run_javascript_finish(result).get_js_value().to_string()
            print("SELFTEST OK:", value)
            code = 0
        except GLib.Error as exc:
            print("SELFTEST LỖI:", exc)
            code = 1
        Gtk.main_quit()
        sys.exit(code)

    def selftest_timeout(self):
        print("SELFTEST LỖI: quá 15 giây chưa nạp xong trang")
        Gtk.main_quit()
        sys.exit(1)


def main():
    if not PAGE.exists():
        sys.stderr.write("Không tìm thấy %s\n" % PAGE)
        return 1
    GLib.set_prgname(APP_ID)  # để GNOME ghép cửa sổ với đúng icon trong dock
    GLib.set_application_name(TITLE)
    win = NocWindow(selftest="--selftest" in sys.argv)
    win.show_all()
    Gtk.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())

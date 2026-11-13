# grafana_labs — Mô phỏng Grafana cho hạ tầng mạng (NOC)

Một trang HTML **duy nhất, không phụ thuộc build tool**, dựng lại giao diện và cách vận hành của Grafana
cho một trung tâm điều hành mạng: 5 dashboard, 44 panel, 50 thiết bị, 9 alert rule, 4 SLO.

> ⚠️ **Toàn bộ số liệu là mô phỏng sinh trong trình duyệt** (seeded random walk + mô hình Ornstein–Uhlenbeck).
> Trang **không** kết nối tới InfluxDB, Kafka, Prometheus hay bất kỳ thiết bị mạng thật nào.
> Các câu query hiển thị trong Inspect là query mẫu đúng cú pháp Flux/PromQL/LogQL, dùng để đọc và học,
> không phải query đang chạy. Dùng cho demo, đào tạo, thiết kế dashboard và thử nghiệm giao diện NOC.

---

## Chạy thử

```bash
git clone git@github.com:Tobi24004/grafana_labs.git
cd grafana_labs
./serve.sh            # → http://localhost:8787/
```

Hoặc mở thẳng `index.html` bằng trình duyệt (`file://` cũng chạy), hoặc bật **GitHub Pages**
(Settings → Pages → Deploy from branch → `main` / `root`) là có link công khai ngay,
vì toàn bộ ứng dụng nằm trong một file tĩnh.

Yêu cầu: một trình duyệt hiện đại. Không cần Node, không cần cài gói.
**Không cần mạng** — chỉ có dòng `<link>` nạp font Google; mất mạng thì trang tự dùng font hệ thống,
mọi thứ khác chạy nguyên vẹn vì không có một lời gọi `fetch`/`WebSocket` nào.

---

## Hệ thống được mô phỏng

Bốn tầng mạng, mỗi tầng là một nhóm thiết bị:

| Tầng | Vai trò | Đặc điểm số liệu |
|------|---------|------------------|
| **CORE** | Lõi trung tâm | băng thông lớn nhất (~78 Gbps), nhiệt độ chassis cao |
| **DIST** | Phân phối | trung chuyển giữa core và access, có firewall nội bộ |
| **ACC** | Truy nhập (PoE) | nhiều lỗi CRC nhất, chiếm phần lớn điện năng do PoE |
| **WAN** | Biên & Internet | uplink bão hoà nhất (~74%), nơi phát sinh BGP và packet loss |

Mỗi tầng theo dõi 5 chỉ số: **mức dùng uplink (%)**, **băng thông (Gbps)**, **lỗi CRC (/s)**,
**nhiệt độ thiết bị (°C)**, **công suất (kW)**.

50 thiết bị thuộc 6 loại — `Core switch`, `Distribution switch`, `Access switch`, `Router biên`,
`Firewall`, `Wi-Fi AP` — mỗi thiết bị có IP quản trị, vị trí (site + IDF), tốc độ uplink
(100G QSFP28 / 40G QSFP+ / 10G SFP+ / 1G RJ45), firmware, RTT quản trị, TCAM còn trống và trạng thái.

Luồng giám sát: `thiết bị mạng → collector gNMI/SNMP → Kafka telemetry bus → InfluxDB → Grafana`.

---

## 5 dashboard

| Tab | Nội dung |
|-----|----------|
| **Tổng quan** | 6 stat + sparkline, mức dùng uplink theo tầng (ngưỡng 85% + annotation alert), 4 gauge chất lượng, RTT p50/p95/p99, heatmap băng thông theo giờ × tầng, state timeline, sơ đồ topology 50 thiết bị, panel cảnh báo, syslog tail |
| **Thiết bị mạng** | Bảng 50 thiết bị (12 cột, sắp xếp / lọc / tìm / sparkline từng dòng), TCAM còn trống thấp nhất, phân bố RTT quản trị, cơ cấu theo loại, tiến độ nâng firmware, state timeline 20 thiết bị |
| **Điện & PoE** | Công suất stacked theo tầng, kWh và chi phí 24h, cột kWh theo giờ, tỉ trọng theo tầng, gauge PF / **PUE** / tải‑định mức, bảng phụ tải, đồ thị hệ số công suất |
| **Hạ tầng telemetry** | Bản tin theo nguồn (gNMI / SNMP / NetFlow / syslog), độ trễ ghi InfluxDB p50/p95/p99, heatmap phân bố độ trễ, phiên BGP, output queue drops, sơ đồ kiến trúc thu thập có số liệu sống, log pipeline, bảng retention |
| **Vận hành & SLO** | 4 SLO kèm ngân sách lỗi và burn rate, MTTR, bảng 9 alert rule, lịch sử incident, kíp trực, cửa sổ bảo trì, tài nguyên node collector |

---

## Những thứ làm đúng như Grafana thật

- **Query inspector** trên mọi panel (⋮ → Inspect): tab *Data* (bảng + copy CSV), tab *Query* hiện data source,
  query nguyên bản còn biến `${layer:json}` và query **đã nội suy** biến dashboard, tab *Panel JSON*.
- **JSON model** của cả dashboard (nút `{ }`): `uid`, `schemaVersion: 39`, `templating`, `annotations`,
  danh sách panel với `gridPos` và `targets`.
- **Unified alerting**: 9 rule có `expr`, `for`, label định tuyến và runbook; phân biệt `pending`
  (đã chạm ngưỡng, chưa đủ `for`) với `firing`. Alert mở quá 60 giây rồi tự đóng sẽ được ghi thành
  **incident mới** kèm MTTR.

  | Rule | Mức | Điều kiện |
  |------|-----|-----------|
  | `InterfaceDown` | major | `ifOperStatus == 2 unless ifAdminStatus == 2` |
  | `BGPSessionLost` | critical | số phiên established < 45 |
  | `LinkSaturation` | major | uplink WAN > 85% trong 5 phút |
  | `HighErrorRate` | warning | CRC/FCS > 5 lỗi/s |
  | `PacketLoss` | warning | loss thăm dò > 2.5% |
  | `BackboneLatencyHigh` | warning | RTT p95 > 100 ms |
  | `OutputQueueDrops` | major | `ifOutDiscards` > 600 pkt/s |
  | `TCAMExhaustion` | warning | TCAM còn trống < 15% |
  | `DeviceTempHigh` | critical | nhiệt thiết bị WAN > 68 °C |

- **SLO tính từ dữ liệu**, không phải số cứng: SLI lấy từ chính chuỗi mẫu (tỉ lệ mẫu RTT p95 < 100 ms,
  tỉ lệ thời gian có ≥ 45 phiên BGP…), ngân sách lỗi = `(100 − SLI) / (100 − target)`, kèm burn rate.
- **Template variable** `$layer`, `$device`, `$interval` lọc xuyên mọi panel và được nội suy vào query.
- Shared crosshair giữa các time series, legend bấm được để ẩn/hiện series, row gập được,
  panel mở toàn màn hình, time range + refresh picker, kiosk mode.

### Phím tắt

| Phím | Tác dụng |
|------|----------|
| `1` … `5` | Chuyển tab dashboard |
| `k` | Bật/tắt kiosk mode |
| `z` | Zoom out khoảng thời gian |
| `r` | Làm mới ngay một nhịp |
| `t` | Đổi sáng/tối |
| `?` | Bảng trợ giúp |
| `Esc` | Đóng panel / modal / kiosk |

---

## Ghi chú kỹ thuật

- **Một file, không dependency.** Chỉ nạp font từ Google Fonts; mọi thứ còn lại nội tuyến.
  Biểu đồ vẽ bằng Canvas 2D theo `devicePixelRatio`, sơ đồ topology và kiến trúc bằng SVG nội tuyến.
- **Mô hình dữ liệu**: PRNG có seed (LCG) ⇒ mỗi lần tải cho cùng một chuỗi; mỗi chỉ số là một
  `Sensor` kiểu Ornstein–Uhlenbeck có mùa vụ hình sin và xác suất spike. Chu kỳ mẫu 5 giây,
  giữ 1.441 mẫu (2 giờ) và được **mồi sẵn ngay khi tải** nên biểu đồ đầy dữ liệu từ giây đầu.
- **Syslog mô phỏng** đúng định dạng thiết bị thật: `%LINK-3-UPDOWN`, `%BGP-5-ADJCHANGE`,
  `%SW_MATM-4-MACFLAP_NOTIF`, xen với log poll SNMP và subscribe gNMI.
- **Màu**: bảng màu classic của Grafana cho cả hai theme, kiểm tra tương phản theo ΔE trong OKLab
  cho người mù màu. Những cặp màu sát nhau được bù bằng **mã hoá thứ cấp**: mỗi series có kiểu nét
  đứt riêng, lặp lại trong ô màu của legend — đọc được cả khi mù màu hoặc in đen trắng.
- **Theme**: dark/light theo chuẩn màu Grafana, tự theo hệ điều hành và nhớ lựa chọn trong `localStorage`.
  Màu canvas đọc lại từ CSS custom property ngay lúc vẽ nên đổi theme là vẽ lại đúng màu.
- **Hiệu năng**: hover chỉ vẽ lại các time series đang hiện (`renderCross`), không dựng lại DOM của
  bảng/log; panel bị gập hoặc ở tab khác thì không vẽ.

## Cấu trúc

```
grafana_labs/
├── index.html    # toàn bộ dashboard (HTML + CSS + JS nội tuyến)
├── serve.sh      # chạy web server cục bộ: ./serve.sh [port]
└── README.md
```

## Giấy phép

Chưa gán giấy phép. Mặc định bản quyền thuộc về chủ repo; thêm file `LICENSE` nếu muốn mở nguồn.

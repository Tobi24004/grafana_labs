# grafana_labs — Mô phỏng Grafana cho hệ thống server IoT

Một trang HTML **duy nhất, không phụ thuộc build tool**, dựng lại giao diện và cách vận hành của Grafana
cho một nền tảng IoT chạy trên cụm máy chủ: 5 dashboard, 43 panel, 50 host, 9 alert rule, 4 SLO.

> ⚠️ **Toàn bộ số liệu là mô phỏng sinh trong trình duyệt** (seeded random walk + mô hình Ornstein–Uhlenbeck).
> Trang **không** kết nối tới InfluxDB, EMQX, Prometheus hay bất kỳ máy chủ thật nào.
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

---

## Hệ thống được mô phỏng

Bốn cụm máy chủ, mỗi cụm là một rack:

| Cụm | Vai trò | Chỉ số theo dõi |
|-----|---------|-----------------|
| **C1** | Ingest workers | nhiệt CPU, RAM, req/s, I/O wait, công suất PDU |
| **C2** | Broker EMQX | như trên + số kết nối MQTT, độ sâu hàng đợi |
| **C3** | TSDB storage (InfluxDB) | như trên + độ trễ ghi p50/p95/p99, dung lượng đĩa |
| **C4** | Edge & API | như trên + băng thông edge gateway |

50 host với vai trò: `API gateway`, `MQTT broker`, `Ingest worker`, `TSDB node`, `Edge gateway`, `Rack PDU` —
mỗi host có rack‑U, IP, uplink (25/10/1 GbE hoặc WireGuard), phiên bản agent, RTT nội bộ, đĩa trống và trạng thái.

Luồng dữ liệu: `client IoT → LB/TLS (HAProxy) → EMQX cluster → ingest worker → InfluxDB → Grafana`.

---

## 5 dashboard

| Tab | Nội dung |
|-----|----------|
| **Tổng quan** | 6 stat + sparkline, nhiệt CPU theo cụm (có ngưỡng + annotation alert), 4 gauge tài nguyên, heatmap tải theo giờ × cụm, state timeline, sơ đồ rack 50 host, panel cảnh báo, log tail |
| **Máy chủ** | Bảng 50 host (12 cột, sắp xếp / lọc / tìm / sparkline từng dòng), đĩa trống thấp nhất, phân bố RTT, cơ cấu theo vai trò, tiến độ rollout agent, state timeline 20 host |
| **Điện năng DC** | Công suất stacked theo cụm, kWh và chi phí 24h, cột kWh theo giờ, tỉ trọng theo cụm, gauge PF / **PUE** / tải‑định mức, bảng phụ tải, đồ thị hệ số công suất |
| **Hạ tầng dữ liệu** | MQTT theo topic, độ trễ ghi p50/p95/p99 với SLO 100 ms, heatmap phân bố độ trễ, kết nối broker, hàng đợi, sơ đồ kiến trúc có số liệu sống, log pipeline, bảng retention |
| **Vận hành & SLO** | 4 SLO kèm ngân sách lỗi và burn rate, MTTR, bảng 9 alert rule, lịch sử incident, kíp trực, cửa sổ bảo trì, tài nguyên node ingest |

---

## Những thứ làm đúng như Grafana thật

- **Query inspector** trên mọi panel (⋮ → Inspect): tab *Data* (bảng + copy CSV), tab *Query* hiện data source,
  query nguyên bản còn biến `${cluster:json}` và query **đã nội suy** biến dashboard, tab *Panel JSON*.
- **JSON model** của cả dashboard (nút `{ }`): `uid`, `schemaVersion: 39`, `templating`, `annotations`,
  danh sách panel với `gridPos` và `targets`.
- **Unified alerting**: 9 rule có `expr`, `for`, label định tuyến và runbook; phân biệt `pending`
  (đã chạm ngưỡng, chưa đủ `for`) với `firing`. Alert mở quá 60 giây rồi tự đóng sẽ được ghi thành
  **incident mới** kèm MTTR.

  `NodeTempHigh` · `MemoryPressure` · `RequestRateHigh` · `DiskIOWaitHigh` · `IngestLatencyHigh`
  · `IngestDropRatio` · `BrokerQueueDepth` · `DiskSpaceLow` · `NodeDown`

- **SLO tính từ dữ liệu**, không phải số cứng: SLI lấy từ chính chuỗi mẫu (tỉ lệ mẫu p95 < 100 ms,
  tỉ lệ thời gian broker ≥ 45 kết nối…), ngân sách lỗi = `(100 − SLI) / (100 − target)`, kèm burn rate.
- **Template variable** `$cluster`, `$role`, `$interval` lọc xuyên mọi panel và được nội suy vào query.
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
  Biểu đồ vẽ bằng Canvas 2D theo `devicePixelRatio`, sơ đồ rack và kiến trúc bằng SVG nội tuyến.
- **Mô hình dữ liệu**: PRNG có seed (LCG) ⇒ mỗi lần tải cho cùng một chuỗi; mỗi chỉ số là một
  `Sensor` kiểu Ornstein–Uhlenbeck có mùa vụ hình sin và xác suất spike. Chu kỳ mẫu 5 giây,
  giữ 1.441 mẫu (2 giờ) và được **mồi sẵn ngay khi tải** nên biểu đồ đầy dữ liệu từ giây đầu.
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

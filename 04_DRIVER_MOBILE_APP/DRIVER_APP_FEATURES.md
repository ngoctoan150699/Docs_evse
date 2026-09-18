# TÍNH NĂNG CHI TIẾT ỨNG DỤNG TÀI XẾ THACO_CHARGE
## (DRIVER MOBILE APP FEATURES & USER EXPERIENCE SPECIFICATION)

Tài liệu này đặc tả chi tiết các phân hệ tính năng và luồng trải nghiệm người dùng của ứng dụng di động THACO_Charge.

---

## 1. BẢN ĐỒ TRẠM SẠC & DẪN ĐƯỜNG THÔNG MINH (`Map & Navigation`)
- Hiển thị danh sách và định vị toàn bộ các trạm sạc THACO trên bản đồ tương tác.
- Lọc trạm sạc theo: Khoảng cách gần nhất, Loại súng sạc (`CCS2` / `AC Type 2`), Công suất sạc (`60kW`, `120kW`, `180kW`).
- Trạng thái súng sạc trực quan bằng màu sắc: Xanh (Trống), Vàng (Đang sạc), Đỏ (Đang bảo trì/Lỗi).
- Nút bấm điều hướng: Tự động mở ứng dụng Google Maps / Apple Maps chỉ đường trực tiếp tới vị trí trạm.

---

## 2. QUÉT MÃ QR KÍCH HOẠT SẠC NHANH (`QR Scan & Remote Start`)
- Mở camera tích hợp bộ quét mã QR tốc độ cao.
- Tài xế chỉ cần cắm súng sạc vào xe, quét mã QR in trên đầu súng $\longrightarrow$ Ứng dụng tự động nhận diện trạm sạc và cổng sạc tương ứng.
- Màn hình xác nhận sạc: Hiển thị giá điện hiện tại, số dư ví khả dụng, nút gạt xác nhận **[BẮT ĐẦU SẠC]**.

---

## 3. THEO DÕI TIẾN TRÌNH SẠC TRỰC TIẾP (`Active Charging Session`)
- Nhận dữ liệu đo đếm liên tục từ máy chủ qua WebSocket / SSE:
  * Biểu đồ tròn dung lượng pin: Hiển thị % SoC tăng dần từ lúc bắt đầu sạc.
  * Tốc độ sạc hiện tại: Công suất (kW) và Dòng điện (A).
  * Thời gian sạc đã qua và dự kiến thời gian đầy pin.
  * Chi phí tiền điện tích lũy tính đến thời điểm hiện tại.
- Nút bấm **[DỪNG SẠC]** từ xa: Tài xế có thể ngồi trong quán cafe bấm dừng sạc bất kỳ lúc nào.

---

## 4. VÍ ĐIỆN TỬ & NẠP TIỀN TỰ ĐỘNG VIETQR SEPAY (`Wallet & Payment`)
- Hiển thị số dư tài khoản ví sạc (VND).
- Các gói nạp tiền nhanh: `100.000đ`, `200.000đ`, `500.000đ`, `1.000.000đ` hoặc số tiền tùy chọn.
- Bấm [Nạp tiền] $\longrightarrow$ Sinh mã VietQR có logo ngân hàng và mã giao dịch định danh.
- Hỗ trợ nút **[Mở App Ngân hàng]** tự động điền đầy đủ số tiền và nội dung chuyển khoản.
- Tài khoản được cộng tiền tức thì trong vòng 2 giây sau khi chuyển khoản thành công.

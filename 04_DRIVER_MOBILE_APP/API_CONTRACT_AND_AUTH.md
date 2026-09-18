# HỢP ĐỒNG API REST & LUỒNG XÁC THỰC BẢO MẬT (API CONTRACT)
## (CSMS GO BACKEND RESTFUL APIS & JWT AUTHENTICATION FLOW)

Tài liệu này định nghĩa chi tiết các API REST giữa Ứng dụng di động THACO_Charge và Máy chủ CSMS Go Backend.

---
> **Tham chiếu đầy đủ:** Xem chi tiết toàn bộ cấu trúc request/response của máy chủ CSMS tại [CSMS_REST_API_SPECIFICATION.md](../02_CSMS_CLOUD_PLATFORM/CSMS_REST_API_SPECIFICATION.md).


## 1. LUỒNG XÁC THỰC BẢO MẬT JWT (AUTHENTICATION FLOW)

- Sử dụng cơ chế cặp mã thông báo **Access Token (Thời hạn 15 phút)** và **Refresh Token (Thời hạn 30 ngày)**.
- Mọi API nghiệp vụ đều yêu cầu Header: `Authorization: Bearer <ACCESS_TOKEN>`.
- Danh tính người dùng (`userId`, `role`) được trích xuất trực tiếp từ chữ ký Token trên server, không tin tưởng dữ liệu gửi từ client body.

---

## 2. DANH SÁCH API ENDPOINTS CHÍNH

### 2.1. Nhóm Xác thực (Authentication):
- `POST /api/auth/send-otp`: Gửi mã OTP xác thực qua SMS/Email.
- `POST /api/auth/verify-otp`: Kiểm tra mã OTP và trả về Access Token + Refresh Token.
- `POST /api/auth/refresh`: Cấp mới Access Token khi token cũ hết hạn.

### 2.2. Nhóm Trạm sạc (Stations):
- `GET /api/stations`: Lấy danh sách trạm sạc theo tọa độ GPS bán kính $R$.
- `GET /api/stations/:id`: Lấy chi tiết thông tin trạm sạc và trạng thái các súng sạc.

### 2.3. Nhóm Điều khiển Phiên sạc (Charging Sessions):
- `POST /api/station/remote-start`: Yêu cầu kích hoạt phiên sạc (truyền `stationId`, `connectorId`).
- `POST /api/station/remote-stop`: Yêu cầu dừng phiên sạc (truyền `transactionId`).
- `GET /api/session/live/:transactionId`: Lấy dữ liệu mẫu đo thời gian thực (V, I, SoC %, Tiền).

### 2.4. Nhóm Thanh toán & Nạp tiền (SePay VietQR):
- `POST /api/payment/create-order`: Tạo đơn nạp tiền, nhận mã VietQR chuyển khoản.
- `GET /api/wallet/balance`: Đọc số dư ví và lịch sử nạp tiền.

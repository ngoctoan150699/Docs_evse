# ĐẶC TẢ CHI TIẾT TOÀN BỘ RESTFUL API MÁY CHỦ CSMS CLOUD
## (CSMS CLOUD REST API MASTER SPECIFICATION & ENDPOINT DIRECTORY)

> **Máy chủ:** THACO CSMS Go Backend Microservices (`backend-go/cmd/api`)  
> **Cổng dịch vụ:** HTTP Port `8080` (Internal) | HTTPS `443` qua Nginx Reverse Proxy  
> **WebSocket OCPP Gateway:** Port `9000` (`backend-go/cmd/ocpp-gateway`)  
> **Phiên bản API:** `v1.0.1` (Production Ready)  
> **Cập nhật:** `18/09/2026`

---

## 1. TỔNG QUAN KIẾN TRÚC API & CƠ CHẾ BẢO MẬT

Toàn bộ hệ thống API được viết bằng **Go (Chi Router v5)** với hiệu năng xử lý hàng chục nghìn request/giây, chia thành 4 nhóm quyền truy cập độc lập:

```text
+-------------------------------------------------------------------------------+
|                       THACO CSMS CLOUD REST API ROUTER                        |
+-------------------------------------------------------------------------------+
| 1. Public APIs (Không cần Auth)                                               |
|    - /health, /ready, /api/auth/login, /api/auth/refresh, /api/mobile/tariffs |
+-------------------------------------------------------------------------------+
| 2. SePay Webhook API (Xác thực API Key Header)                                |
|    - POST /api/payment/sepay/webhook                                          |
+-------------------------------------------------------------------------------+
| 3. Mobile Driver App APIs (/api/mobile/*) (Xác thực Firebase JWT)             |
|    - Quản lý tài khoản, xe điện, Autocharge PnC, ví tiền, quét QR & sạc xe     |
+-------------------------------------------------------------------------------+
| 4. CSMS Admin Portal APIs (/api/csms/*) (Xác thực Staff JWT & 7 vai trò RBAC) |
|    - Giám sát trụ, ra lệnh OCPP, quản lý thẻ RFID, bảng giá, người dùng       |
+-------------------------------------------------------------------------------+
```

### 1.1. Chuẩn Headers Bảo mật Bắt buộc
Mọi response từ API Server đều được đính kèm các Header bảo mật:
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY`
- `Referrer-Policy: no-referrer`
- `Access-Control-Allow-Origin`: Chỉ cho phép các domain được cấu hình trong `ALLOWED_ORIGINS`.

### 1.2. Chuẩn Phản hồi Dữ liệu (Response Format)
- **Thành công (HTTP 200/201):**
```json
{
  "success": true,
  "data": { ... },
  "timestamp": "2026-09-18T09:30:00Z"
}
```
- **Thất bại (HTTP 400/401/403/404/429/500):**
```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Tên đăng nhập hoặc mật khẩu không chính xác"
  },
  "timestamp": "2026-09-18T09:30:00Z"
}
```

---

## 2. NHÓM API HỆ THỐNG & XÁC THỰC ADMIN (`/api/auth/*`)

| Method | Endpoint | Quyền | Chức năng | Payload Request | Response |
| :--- | :--- | :---: | :--- | :--- | :--- |
| `GET` | `/health` | Public | Kiểm tra sức khỏe dịch vụ | Không | `{"status": "healthy"}` |
| `GET` | `/ready` | Public | Kiểm tra kết nối DB/Redis | Không | `{"status": "ready"}` |
| `POST`| `/api/auth/login` | Public | Đăng nhập Admin / Kỹ thuật viên | `{"username": "admin", "password": "..."}` | Trả về User info + Access Token (15m) + Refresh Token (30d) |
| `POST`| `/api/auth/refresh` | Public | Cấp mới Access Token | `{"refresh_token": "..."}` | Trả về cặp Access Token mới |
| `POST`| `/api/auth/logout` | Public | Đăng xuất người dùng | Không | `{"status": "logged_out"}` |
| `GET` | `/api/me` | Staff | Lấy thông tin tài khoản hiện tại | Bearer Token | Chi tiết User, Role, Quyền hạn |

---

## 3. NHÓM API ỨNG DỤNG DI ĐỘNG TÀI XẾ (`/api/mobile/*`)
*Yêu cầu Header: `Authorization: Bearer <FIREBASE_JWT_TOKEN>`*

### 3.1. Tài khoản & Cấu hình Người dùng:
- **`POST /api/mobile/auth/register`**: Đăng ký khách hàng mới lần đầu vào hệ thống CSMS.
- **`POST /api/mobile/auth/session`**: Khởi tạo session đăng nhập từ ứng dụng di động.
- **`GET /api/mobile/me`**: Lấy thông tin hồ sơ tài xế (Họ tên, SĐT, Email, Avatar).
- **`PATCH /api/mobile/me`**: Cập nhật thông tin cá nhân (Họ tên, địa chỉ, ảnh đại diện).
- **`GET /api/mobile/me/settings`**: Lấy cấu hình thông báo (Push notification, SMS, Email).
- **`PATCH /api/mobile/me/settings`**: Cập nhật bật/tắt nhận thông báo pin đầy, cảnh báo tiền ví.

### 3.2. Quản lý Xe điện & Tính năng Cắm là Sạc (Autocharge / Plug & Charge):
- **`GET /api/mobile/me/vehicles`**: Danh sách xe ô tô điện của tài xế (Biển số, Hãng xe, Model, Dung lượng pin kWh, Cổng sạc).
- **`POST /api/mobile/me/vehicles`**: Thêm mới xe điện vào tài khoản.
- **`DELETE /api/mobile/me/vehicles/{id}`**: Xóa xe điện khỏi tài khoản.
- **`POST /api/mobile/me/vehicles/{id}/autocharge`**: Kích hoạt tính năng **Autocharge** (gán mã định danh `EVCCID` của xe vào xe điện để cắm súng là tự sạc).
- **`DELETE /api/mobile/me/vehicles/{id}/autocharge`**: Hủy kích hoạt tính năng Autocharge.
- **`GET /api/mobile/me/detected-evcc`**: Lấy mã `EVCCID` vừa được trạm sạc phát hiện khi cắm cáp CCS2 gần nhất.

### 3.3. Ví tiền, Thẻ sạc & Lịch sử Giao dịch:
- **`GET /api/mobile/me/wallet`**: Lấy số dư ví khả dụng (VND), tổng nạp, điểm tích lũy.
- **`GET /api/mobile/me/wallet/transactions`**: Lịch sử biến động số dư ví (Nạp tiền, trừ tiền sạc).
- **`GET /api/mobile/me/charging-card`**: Xem thông tin thẻ sạc vật lý RFID liên kết với tài xế.
- **`PUT /api/mobile/me/charging-card`**: Liên kết thẻ RFID mới vào tài khoản di động.
- **`DELETE /api/mobile/me/charging-card`**: Hủy liên kết hoặc khóa thẻ RFID khi bị mất.
- **`GET /api/mobile/me/charging-card/transactions`**: Lịch sử các lần sạc bằng thẻ RFID.

### 3.4. Trạm sạc, Quét mã QR & Bảng giá:
- **`GET /api/mobile/stations`** (hoặc `/charge-points`): Lấy danh sách trạm sạc, lọc theo bán kính GPS gần nhất, hiển thị số súng trống/bận.
- **`POST /api/mobile/qr/resolve`**: Giải mã mã QR dán trên đầu súng sạc.
  - *Payload:* `{"qr_token": "TC_ST01_CN02"}`
  - *Response:* Trả về `station_id`, `connector_id`, công suất tối đa, giá điện hiện tại.
- **`GET /api/mobile/tariffs/current`**: Bảng giá điện hiện tại theo khung giờ (Peak, Normal, Off-peak).

### 3.5. Điều khiển Phiên sạc Thời gian thực:
- **`GET /api/mobile/charging-sessions`**: Danh sách lịch sử các phiên sạc của tài xế.
- **`GET /api/mobile/charging-sessions/active`**: Lấy thông tin phiên sạc **đang diễn ra** (% SoC, kW, V, A, Thời gian, Chi phí tạm tính).
- **`POST /api/mobile/charging-sessions`**: Khởi tạo yêu cầu sạc mới.
- **`POST /api/mobile/charging-sessions/{id}/start`**: Kích hoạt phát lệnh sạc xuống trụ sạc (gửi `RemoteStartTransaction`).
- **`POST /api/mobile/charging-sessions/{id}/stop`**: Lệnh dừng sạc từ xa (gửi `RemoteStopTransaction`).
- **`POST /api/mobile/charging-sessions/{id}/cancel`**: Hủy yêu cầu sạc khi chưa cấp điện.

### 3.6. Nạp tiền Ví qua Cổng Thanh toán VietQR SePay:
- **`POST /api/mobile/payment/orders`**: Tạo đơn nạp tiền vào ví.
  - *Payload:* `{"amount": 200000}`
  - *Response:* Trả về `order_code`, mã `vietqr_url`, số tài khoản nhận, ngân hàng, số tiền, nội dung chuyển khoản định danh.
- **`GET /api/mobile/payment/orders/{orderCode}`**: Kiểm tra trạng thái đơn nạp (`PENDING`, `SUCCESS`, `EXPIRED`).
- **`DELETE /api/mobile/payment/orders/{orderCode}`**: Hủy đơn nạp tiền chưa thanh toán.
- **`GET /api/mobile/payment/orders`**: Danh sách lịch sử các đơn nạp tiền của tài xế.

---

## 4. NHÓM API QUẢN TRỊ CSMS CLOUD (`/api/csms/*`)
*Yêu cầu Header: `Authorization: Bearer <STAFF_JWT_TOKEN>` (Kiểm tra 7 vai trò RBAC)*

### 4.1. Dashboard, Trạm sạc & Giám sát Kết nối:
- **`GET /api/csms/dashboard`**: Dữ liệu KPI tổng hợp toàn mạng lưới (Tổng điện kWh, doanh thu, đơn hàng, biểu đồ sạc theo giờ).
- **`GET /api/csms/stations`**: Danh sách tất cả các trạm sạc, lọc theo vùng miền, tỉnh thành.
- **`POST /api/csms/stations`**: Thêm mới trạm sạc.
- **`GET /api/csms/stations/{id}`**: Chi tiết trạm sạc, tọa độ GPS, danh sách trụ sạc.
- **`PATCH / PUT /api/csms/stations/{id}`**: Chỉnh sửa thông tin trạm sạc, giới hạn công suất trạm.
- **`DELETE /api/csms/stations/{id}`**: Xóa trạm sạc khỏi hệ thống.
- **`GET /api/csms/stations/{id}/ws`** (hoặc `/ws-check`): Kiểm tra trạng thái sống của kết nối WebSocket giữa trụ sạc và Gateway (`Online` / `Offline`, Ping/Pong latency).
- **`GET /api/csms/connectors`**: Danh sách tất cả các cổng súng sạc toàn quốc, trạng thái súng (`Available`, `Preparing`, `Charging`, `Faulted`).

### 4.2. Phiên sạc & Đo đếm MeterValues:
- **`GET /api/csms/transactions`**: Danh sách toàn bộ phiên sạc lịch sử và đang diễn ra, lọc theo mã thẻ, trạm sạc, thời gian.
- **`GET /api/csms/transactions/{id}`**: Chi tiết phiên sạc: Biểu đồ mẫu đo V/I/kW, chỉ số công tơ MeterStart/MeterStop, lý do dừng.
- **`GET /api/csms/meter-values`**: Truy vấn mẫu đo chuỗi thời gian từ bảng TimescaleDB Hypertable.

### 4.3. Quản lý Thẻ sạc RFID:
- **`GET /api/csms/cards`**: Danh sách thẻ sạc RFID trên hệ thống.
- **`POST /api/csms/cards`**: Đăng ký thẻ RFID mới (Mã UID thẻ, Tên chủ thẻ, Số dư khởi tạo).
- **`PATCH / PUT /api/csms/cards/{id}`**: Cập nhật thông tin thẻ, nạp tiền thủ công, khóa thẻ (`Active` / `Blocked`).
- **`DELETE /api/csms/cards/{id}`**: Xóa thẻ sạc khỏi hệ thống.
- **`GET /api/csms/cards/{id}/transactions`**: Lịch sử quẹt thẻ sạc của thẻ này.

### 4.4. Quản lý Khách hàng & Hạn mức Miễn phí (Free Quota):
- **`GET /api/csms/customers`**: Danh sách khách hàng, số điện thoại, tổng tiền chi tiêu.
- **`GET /api/csms/customers/{id}/wallet/transactions`**: Biến động số dư ví khách hàng.
- **`POST /api/csms/customers/{id}/wallet/adjust`**: Điều chỉnh cộng/trừ số dư ví khách hàng (có ghi log kiểm toán).
- **`POST /api/csms/customers/{id}/card`**: Gán thẻ RFID vật lý cho khách hàng.
- **`DELETE /api/csms/customers/{id}/card`**: Hủy gán thẻ RFID khỏi khách hàng.
- **`GET /api/csms/customers/{id}/vehicles`**: Xem danh sách xe của khách hàng.
- **`POST /api/csms/customers/{id}/vehicles`**: Admin thêm xe cho khách hàng.
- **`DELETE /api/csms/customers/{id}/vehicles/{vehicleId}`**: Admin xóa xe của khách hàng.
- **`POST /api/csms/customers/{id}/vehicles/{vehicleId}/autocharge`**: Admin bật/tắt Autocharge cho xe.
- **`GET /api/csms/customers/{id}/free-quota`**: Xem gói sạc miễn phí của khách hàng (ví dụ: tặng 500 kWh khi mua xe điện THACO).
- **`POST /api/csms/customers/{id}/free-quota`**: Gán gói sạc miễn phí cho khách hàng.
- **`DELETE /api/csms/customers/{id}/free-quota`**: Thu hồi gói sạc miễn phí.
- **`GET /api/csms/customers/{id}/free-quota/history`**: Lịch sử tiêu thụ hạn mức sạc miễn phí.
- **`GET /api/csms/vehicles`**: Danh sách toàn bộ xe điện đã đăng ký trên hệ thống.

### 4.5. Quản lý Bảng giá Điện (Tariffs):
- **`GET /api/csms/tariffs`**: Danh sách các gói biểu giá điện (Time-of-Use, phí sạc theo kWh, phí phạt chiếm chỗ).
- **`POST /api/csms/tariffs`**: Tạo biểu giá điện mới.
- **`PATCH / PUT /api/csms/tariffs/{id}`**: Cập nhật khung giờ và đơn giá.
- **`DELETE /api/csms/tariffs/{id}`**: Xóa biểu giá.

### 4.6. Điều khiển Lệnh OCPP Xuống Trụ Sạc (`/api/csms/commands`):
- **`POST /api/csms/commands`**: Phát lệnh điều khiển từ xa xuống trụ sạc:
  - **`RemoteStartTransaction`**: `{"action": "RemoteStartTransaction", "station_id": "...", "connector_id": 1, "id_tag": "..."}`
  - **`RemoteStopTransaction`**: `{"action": "RemoteStopTransaction", "station_id": "...", "transaction_id": 1001}`
  - **`Reset`**: `{"action": "Reset", "station_id": "...", "type": "Soft" | "Hard"}`
  - **`UnlockConnector`**: `{"action": "UnlockConnector", "station_id": "...", "connector_id": 1}`
  - **`ChangeAvailability`**: `{"action": "ChangeAvailability", "station_id": "...", "connector_id": 1, "type": "Operative" | "Inoperative"}`
  - **`GetConfiguration`**: `{"action": "GetConfiguration", "station_id": "...", "keys": ["HeartbeatInterval", "MeterValueSampleInterval"]}`
  - **`ChangeConfiguration`**: `{"action": "ChangeConfiguration", "station_id": "...", "key": "MeterValueSampleInterval", "value": "10"}`
  - **`TriggerMessage`**: `{"action": "TriggerMessage", "station_id": "...", "requested_message": "MeterValues"}`
  - **`UpdateFirmware`**: `{"action": "UpdateFirmware", "station_id": "...", "location": "http://.../firmware.bin", "retries": 3}`
- **`GET /api/csms/commands`**: Lịch sử các lệnh điều khiển đã phát và trạng thái phản hồi (`Pending`, `Accepted`, `Rejected`, `Timeout`).
- **`GET /api/csms/commands/{id}`**: Chi tiết kết quả thực thi một lệnh điều khiển.

### 4.7. Quản lý Đơn Nạp tiền & Webhook SePay:
- **`GET /api/csms/payment/orders`** (hoặc `/recharge-orders`): Danh sách toàn bộ các đơn nạp tiền VietQR SePay.
- **`DELETE /api/csms/payment/orders/{id}`**: Xóa hoặc hủy đơn nạp tiền.
- **`GET /api/csms/payment/webhooks`**: Nhật ký toàn bộ các request Webhook nhận được từ SePay, mã phản hồi HTTP, payload raw để đối soát tài chính.

### 4.8. Quản lý Nhân sự & Phân quyền RBAC (`/api/csms/users`):
- **`GET /api/csms/users`**: Danh sách nhân viên quản trị nội bộ.
- **`POST /api/csms/users`**: Tạo tài khoản nhân viên mới (chọn 1 trong 7 vai trò: `SUPER_ADMIN`, `C_LEVEL`, `OPERATOR`, `FINANCE`, `SITE_MANAGER`, `TECHNICIAN`, `CUSTOMER_SUPPORT`).
- **`PATCH / PUT /api/csms/users/{id}`**: Cập nhật thông tin, thay đổi vai trò nhân viên.
- **`POST /api/csms/users/{id}/reset-password`**: Đặt lại mật khẩu nhân viên.
- **`POST /api/csms/users/{id}/toggle-disabled`**: Khóa / Mở khóa tài khoản nhân viên.

### 4.9. Cài đặt Hệ thống & Nhật ký Kiểm toán (Settings & Audit):
- **`GET /api/csms/settings`**: Xem các cấu hình hệ thống (Thời gian timeout OCPP, cấu hình SePay API Key, giới hạn tốc độ).
- **`PUT /api/csms/settings`**: Lưu cấu hình hệ thống mới.
- **`GET /api/csms/logs`**: Nhật ký log hệ thống thời gian thực.
- **`GET /api/csms/audit-logs`**: Nhật ký kiểm toán an ninh (ai đã đổi mật khẩu, ai đã nạp tiền, ai phát lệnh ngắt sạc).

---

## 5. CỔNG THANH TOÁN SEPAY WEBHOOK ENDPOINT (`/api/payment/sepay/webhook`)

- **Method:** `POST`
- **Header:** `Authorization: Apikey <SEPAY_API_KEY>`
- **Payload:** JSON payload từ SePay khi có biến động số dư VietQR.
- **Xử lý:**
  1. Xác thực API Key.
  2. Bóc tách nội dung chuyển khoản tìm mã đơn `order_code`.
  3. Mở SQL Transaction: Khóa dòng (`FOR UPDATE`), cộng tiền số dư thẻ/ví, cập nhật trạng thái đơn thành `SUCCESS`.
  4. Phản hồi tức thì `HTTP 200 OK: {"success": true}` trong vòng $< 100\text{ ms}$.

# ĐẶC TẢ CHI TIẾT TOÀN BỘ RESTFUL API MÁY CHỦ CSMS CLOUD
## (CSMS CLOUD MASTER REST API SPECIFICATION & DEVELOPER REFERENCE MANUAL)

> **Máy chủ:** THACO CSMS Go Backend Microservices (`backend-go/cmd/api`)  
> **Cổng dịch vụ nội bộ:** HTTP Port `8080` | Cổng Public HTTPS: `443` qua Nginx Reverse Proxy & Cloudflare SSL  
> **WebSocket OCPP Gateway:** Port `9000` (`backend-go/cmd/ocpp-gateway`)  
> **Base URL Production:** `https://csms.thaco.vn/api`  
> **Base URL Nội bộ Trạm / Testbed:** `http://10.14.80.193:8080/api`  
> **Chuẩn dữ liệu:** JSON over HTTPS, UTF-8 Encoding  
> **Phiên bản hệ thống:** `v1.0.1` (Tháng 9/2026)

---

## 1. TỔNG QUAN KIẾN TRÚC API & CHUẨN KẾT NỐI (API CONVENTIONS & SECURITY)

Toàn bộ hệ thống API được viết bằng **Go (Chi Router v5)** đạt hiệu năng xử lý hàng chục nghìn request/giây với độ trễ $< 10\text{ ms}$. Hệ thống chia thành 4 phân vùng bảo mật nghiêm ngặt:

```text
+-------------------------------------------------------------------------------+
|                       THACO CSMS CLOUD REST API ROUTER                        |
+-------------------------------------------------------------------------------+
| 1. Public & Health Check Routes (Không cần Auth)                              |
|    - GET /health, GET /ready                                                  |
|    - POST /api/auth/login, POST /api/auth/refresh, POST /api/auth/logout      |
|    - GET /api/mobile/tariffs/current                                          |
+-------------------------------------------------------------------------------+
| 2. SePay Payment Webhook Receiver (Xác thực chữ ký HMAC-SHA256 & API Key)     |
|    - POST /api/payment/sepay/webhook                                          |
+-------------------------------------------------------------------------------+
| 3. Mobile Driver App APIs (/api/mobile/*) (Xác thực Firebase Token / JWT)     |
|    - Quản lý tài khoản, xe điện, Autocharge, nạp tiền ví VietQR, sạc xe       |
|    - (Xem chi tiết tại 04_DRIVER_MOBILE_APP/API_CONTRACT_AND_AUTH.md)         |
+-------------------------------------------------------------------------------+
| 4. CSMS Admin Portal APIs (/api/csms/*) (Xác thực Staff JWT & 7 vai trò RBAC) |
|    - Giám sát realtime, điều khiển OCPP, thẻ RFID, trạm sạc, biểu giá         |
+-------------------------------------------------------------------------------+
```

---

### 1.1. Chuẩn HTTP Headers Bắt buộc cho Admin APIs
Mọi yêu cầu gửi tới các endpoint `/api/csms/*` bắt buộc phải kèm các Header sau:

| Header Key | Bắt buộc? | Kiểu giá trị | Ví dụ | Mô tả |
| :--- | :---: | :---: | :--- | :--- |
| `Authorization` | **Bắt buộc** | String | `Bearer eyJhbGciOiJIUzI1NiIsIn...` | JWT Access Token của nhân viên quản trị |
| `Content-Type` | **Bắt buộc** | String | `application/json` | Áp dụng cho các phương thức POST, PUT, PATCH |
| `X-Tenant-Id` | Tùy chọn | String | `tenant_thaco_sala` | Định danh phân vùng dữ liệu theo từng đơn vị vận hành |
| `X-Request-Id` | Khuyến nghị | String | `req_01HX99REQ01` | UUID theo vết luồng log qua các microservices |

---

### 1.2. Chuẩn Khung Phản hồi (Standard Response Format)

#### A. Phản hồi Thành công (200 OK / 201 Created):
```json
{
  "success": true,
  "data": { ... },
  "message": "Thao tác thành công",
  "timestamp": "2026-09-18T10:15:00Z"
}
```

#### B. Phản hồi Phân trang Danh sách (Paginated List):
```json
{
  "success": true,
  "data": {
    "items": [ ... ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total_items": 156,
      "total_pages": 8
    }
  },
  "timestamp": "2026-09-18T10:15:00Z"
}
```

#### C. Phản hồi Lỗi (Error Envelope):
```json
{
  "success": false,
  "error": {
    "code": "INVALID_STATION_ID",
    "message": "Không tìm thấy trụ sạc hoặc trụ sạc đang Offline",
    "details": {
      "station_id": "EVSE_SALA_99",
      "hint": "Kiểm tra kết nối WebSocket trên cổng 9000"
    }
  },
  "timestamp": "2026-09-18T10:15:00Z"
}
```

---

## 2. NHÓM API 1: XÁC THỰC QUẢN TRỊ VIÊN (STAFF AUTHENTICATION)

### 2.1. Đăng nhập Quản trị viên (Staff Login)
- **Method & Endpoint:** `POST /api/auth/login`
- **Mô tả:** Xác thực tài khoản nhân viên vận hành, kỹ thuật viên hoặc lãnh đạo. Cấp cặp Access Token (hạn 15 phút) và Refresh Token (hạn 7 ngày).

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "username": "admin@thaco.vn",
    "password": "SuperSecretPassword123!"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfMDEiLCJuYW1lIjoiQWRtaW4gVEhBQ08iLCJyb2xlIjoiU1VQRVJfQURNSU4iLCJleHAiOjE3ODk3MjU2MDB9...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ1c3JfMDEiLCJ0b2tlbl90eXBlIjoicmVmcmVzaCIsImV4cCI6MTc5MjMxNzYwMH0...",
    "expires_in": 900,
    "user": {
      "id": "usr_01HX98ADMIN",
      "username": "admin@thaco.vn",
      "full_name": "Quản Trị Viên Hệ Thống",
      "role": "SUPER_ADMIN",
      "tenant_id": "thaco_corporate",
      "permissions": ["ALL"]
    }
  },
  "message": "Đăng nhập thành công"
}
```

#### Response Example (401 Unauthorized):
```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Tên đăng nhập hoặc mật khẩu không chính xác"
  }
}
```

---

### 2.2. Làm mới Access Token (Refresh Token)
- **Method & Endpoint:** `POST /api/auth/refresh`

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/auth/refresh" \
  -H "Content-Type: application/json" \
  -d '{
    "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expires_in": 900
  }
}
```

---

### 2.3. Lấy thông tin tài khoản hiện tại (Get My Profile)
- **Method & Endpoint:** `GET /api/me`

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

---

## 3. NHÓM API 2: DASHBOARD & GIÁM SÁT TOÀN QUỐC (EXECUTIVE DASHBOARD)

### 3.1. Lấy chỉ số KPIs & Giám sát trạm sạc Real-time (Get Dashboard Telemetry)
- **Method & Endpoint:** `GET /api/csms/dashboard`
- **Mô tả:** Cung cấp số liệu tổng hợp cho trang chủ Next.js Admin: Tổng năng lượng (kWh), Doanh thu (VND), Số đơn hàng, Trạng thái súng sạc (Available/Charging/Faulted) và Lưu lượng sạc theo giờ.

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/csms/dashboard" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "kpis": {
      "total_energy_kwh": 128450.75,
      "total_revenue_vnd": 494535387,
      "total_transactions": 3420,
      "co2_saved_kg": 98250.4,
      "active_stations": 42,
      "total_stations": 45
    },
    "connectors_status": {
      "available": 68,
      "charging": 18,
      "preparing": 4,
      "faulted": 2,
      "offline": 4
    },
    "hourly_load_curve": [
      {"hour": "00:00", "total_kw": 45.2},
      {"hour": "06:00", "total_kw": 120.5},
      {"hour": "12:00", "total_kw": 380.0},
      {"hour": "18:00", "total_kw": 450.8}
    ]
  }
}
```

---

## 4. NHÓM API 3: QUẢN LÝ TRẠM SẠC & SÚNG SẠC (STATIONS & CONNECTORS)

### 4.1. Danh sách trạm sạc & Bộ lọc nâng cao (List Stations)
- **Method & Endpoint:** `GET /api/csms/stations`
- **Query Parameters:**
  - `page` (int, mặc định `1`)
  - `limit` (int, mặc định `20`)
  - `search` (string, tìm theo tên hoặc mã trạm)
  - `status` (string, `ONLINE` / `OFFLINE`)

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/csms/stations?page=1&limit=10&search=Sala" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "sta_sala_01",
        "code": "EVSE_SALA_01",
        "name": "Trạm Sạc Nhanh THACO Sala Q2",
        "address": "Số 10 Mai Chí Thọ, P. An Lợi Đông, TP. Thủ Đức",
        "latitude": 10.7712,
        "longitude": 106.7215,
        "is_online": true,
        "ws_connected": true,
        "model": "THACO DC Fast 180kW Dual-Gun",
        "firmware_version": "v1.0.1",
        "max_power_kw": 180,
        "connectors_count": 2,
        "created_at": "2026-06-01T00:00:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total_items": 1,
      "total_pages": 1
    }
  }
}
```

---

### 4.2. Kiểm tra kết nối WebSocket OCPP trực tiếp của Trụ sạc (Check Station WebSocket Presence)
- **Method & Endpoint:** `GET /api/csms/stations/{id}/ws`
- **Mô tả:** Kiểm tra kết nối WebSocket WSS giữa trụ sạc và microservice `ocpp-gateway` qua Redis Presence.

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/csms/stations/EVSE_SALA_01/ws" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "station_id": "EVSE_SALA_01",
    "is_connected": true,
    "gateway_node": "ocpp-gateway-worker-1",
    "remote_ip": "10.14.80.19",
    "connected_at": "2026-09-18T08:00:15Z",
    "last_heartbeat_at": "2026-09-18T10:14:50Z",
    "ocpp_protocol": "ocpp1.6"
  }
}
```

---

### 4.3. Thêm mới trạm sạc vào hệ thống (Create Station)
- **Method & Endpoint:** `POST /api/csms/stations`

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/csms/stations" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "code": "EVSE_BINHCHANH_01",
    "name": "Trạm Sạc THACO Bình Chánh",
    "address": "Quốc Lộ 1A, Huyện Bình Chánh, TP.HCM",
    "latitude": 10.6850,
    "longitude": 106.5820,
    "max_power_kw": 360,
    "vendor": "THACO Auto",
    "model": "EVSE-360-DUAL",
    "connectors": [
      {"connector_id": 1, "type": "CCS2", "max_power_kw": 180},
      {"connector_id": 2, "type": "CCS2", "max_power_kw": 180}
    ]
  }'
```

#### Response Example (201 Created):
```json
{
  "success": true,
  "data": {
    "id": "sta_binhchanh_01",
    "code": "EVSE_BINHCHANH_01",
    "name": "Trạm Sạc THACO Bình Chánh",
    "created_at": "2026-09-18T10:16:00Z"
  },
  "message": "Khởi tạo trạm sạc mới thành công"
}
```

---

## 5. NHÓM API 4: ĐIỀU KHIỂN TỪ XA QUA GIAO THỨC OCPP 1.6J (REMOTE COMMANDS)

API này cho phép Quản trị viên điều khiển trực tiếp trụ sạc từ xa thông qua các bản tin chuẩn OCPP 1.6J JSON-RPC.

- **Method & Endpoint:** `POST /api/csms/commands`

### 5.1. Lệnh Bắt đầu Sạc từ xa (RemoteStartTransaction)
#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/csms/commands" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "station_id": "EVSE_SALA_01",
    "command": "RemoteStartTransaction",
    "payload": {
      "connectorId": 1,
      "idTag": "E2801191A003",
      "chargingProfile": {
        "chargingProfileId": 1,
        "stackLevel": 0,
        "chargingProfilePurpose": "TxDefaultProfile",
        "chargingProfileKind": "Absolute",
        "chargingSchedule": {
          "duration": 3600,
          "chargingRateUnit": "A",
          "chargingSchedulePeriod": [
            {"startPeriod": 0, "limit": 200.0}
          ]
        }
      }
    }
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "command_id": "cmd_01HX99CMD01",
    "station_id": "EVSE_SALA_01",
    "command": "RemoteStartTransaction",
    "status": "Accepted",
    "ocpp_response": {
      "status": "Accepted"
    },
    "executed_at": "2026-09-18T10:16:30Z"
  },
  "message": "Trụ sạc đã chấp nhận lệnh bắt đầu sạc từ xa"
}
```

---

### 5.2. Lệnh Dừng Sạc từ xa (RemoteStopTransaction)
#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/csms/commands" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "station_id": "EVSE_SALA_01",
    "command": "RemoteStopTransaction",
    "payload": {
      "transactionId": 100452
    }
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "command": "RemoteStopTransaction",
    "status": "Accepted",
    "ocpp_response": {
      "status": "Accepted"
    }
  }
}
```

---

### 5.3. Lệnh Mở khóa súng sạc (UnlockConnector)
- **Mô tả:** Dùng khi tài xế gặp sự cố kẹt súng sạc không rút ra được khỏi xe.
#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/csms/commands" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "station_id": "EVSE_SALA_01",
    "command": "UnlockConnector",
    "payload": {
      "connectorId": 1
    }
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "command": "UnlockConnector",
    "status": "Unlocked",
    "message": "Ngàm khóa súng sạc đã được mở thành công"
  }
}
```

---

### 5.4. Lệnh Khởi động lại Trụ sạc (Reset)
- **Mô tả:** Khởi động lại vi điều khiển STM32F429 / STM32H743 từ xa qua lệnh OCPP `Reset` (Soft Reset hoặc Hard Reset).

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/csms/commands" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "station_id": "EVSE_SALA_01",
    "command": "Reset",
    "payload": {
      "type": "Soft"
    }
  }'
```

---

## 6. NHÓM API 5: GIAO DỊCH, ĐO ĐẾM & MẪU TELEMETRY (TRANSACTIONS & METER VALUES)

### 6.1. Danh sách lịch sử phiên sạc (List Transactions)
- **Method & Endpoint:** `GET /api/csms/transactions`
- **Query Parameters:** `page=1`, `limit=20`, `station_id=EVSE_SALA_01`, `start_date=2026-09-01`, `end_date=2026-09-18`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "tx_01HX99TRANS01",
        "transaction_id": 100452,
        "station_id": "EVSE_SALA_01",
        "connector_id": 1,
        "id_tag": "E2801191A003",
        "customer_name": "Nguyễn Văn A",
        "meter_start": 1245000,
        "meter_stop": 1283650,
        "energy_consumed_kwh": 38.65,
        "duration_minutes": 35,
        "start_time": "2026-09-18T10:20:00Z",
        "stop_time": "2026-09-18T10:55:00Z",
        "total_cost_vnd": 148802,
        "stop_reason": "Remote",
        "payment_status": "SETTLED"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 20,
      "total_items": 1542,
      "total_pages": 78
    }
  }
}
```

---

### 6.2. Truy vấn mẫu đo đếm chi tiết Telemetry (Query MeterValues Time-Series)
- **Method & Endpoint:** `GET /api/csms/meter-values`
- **Query Parameters:** `transaction_id=100452`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "timestamp": "2026-09-18T10:25:00Z",
      "voltage_v": 382.5,
      "current_a": 150.2,
      "power_kw": 57.45,
      "soc_percent": 30,
      "energy_kwh": 4.75,
      "temperature_c": 34.0
    },
    {
      "timestamp": "2026-09-18T10:30:00Z",
      "voltage_v": 385.0,
      "current_a": 155.0,
      "power_kw": 59.67,
      "soc_percent": 42,
      "energy_kwh": 9.50,
      "temperature_c": 36.5
    }
  ]
}
```

---

## 7. NHÓM API 6: THANH TOÁN TỰ ĐỘNG & WEBHOOK SEPAY (SEPAY PAYMENT GATEWAY)

### 7.1. Tiếp nhận Webhook Biến động Số dư từ SePay (SePay IPN Webhook Receiver)
- **Method & Endpoint:** `POST /api/payment/sepay/webhook`
- **Mô tả:** Điểm tiếp nhận dữ liệu thanh toán ngân hàng tự động từ máy chủ SePay. Yêu cầu xác thực chữ ký HMAC-SHA256 (`x-sepay-signature`).
- **Xác thực:** Header `Authorization: Apikey <SEPAY_WEBHOOK_API_KEY>` hoặc HMAC Header.

#### Request Example (cURL do SePay gửi tới):
```bash
curl -X POST "https://csms.thaco.vn/api/payment/sepay/webhook" \
  -H "Content-Type: application/json" \
  -H "Authorization: Apikey test_api_key_sepay_thaco_evse" \
  -H "x-sepay-signature: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" \
  -d '{
    "id": 98765432,
    "gateway": "MBBank",
    "transactionDate": "2026-09-18 10:26:15",
    "accountNumber": "0988776655",
    "code": null,
    "content": "PAY100567 thanh toan nap tien vi",
    "transferType": "in",
    "transferAmount": 200000,
    "accumulated": 54200000,
    "subAccount": null,
    "referenceCode": "FT26091898765432",
    "description": "Nạp tiền ví sạc xe điện"
  }'
```

#### Response Example (200 OK - Bắt buộc trả về status 200 trong vòng 3 giây):
```json
{
  "success": true,
  "message": "Webhook processed successfully",
  "order_code": "PAY100567",
  "amount_credited": 200000
}
```

---

### 7.2. Điều chỉnh số dư ví thủ công (Manual Wallet Adjustment by Finance Staff)
- **Method & Endpoint:** `POST /api/csms/customers/{id}/wallet/adjust`
- **Phân quyền RBAC:** Chỉ vai trò `SUPER_ADMIN` và `FINANCE` được phép thực thi.

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/csms/customers/cust_01HX98Z12A/wallet/adjust" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50000,
    "direction": "CREDIT",
    "reason": "Hoàn tiền phiên sạc lỗi trụ EVSE_SALA_01",
    "ticket_reference": "CS-TICKET-2026-99"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "customer_id": "cust_01HX98Z12A",
    "adjustment_amount": 50000,
    "new_balance": 300000,
    "ledger_entry_id": "led_01HX99ADJUST01"
  },
  "message": "Điều chỉnh số dư thành công"
}
```

---

## 8. NHÓM API 7: QUẢN LÝ BIỂU GIÁ ĐIỆN THEO KHUNG GIỜ (TARIFFS)

### 8.1. Lấy danh sách biểu giá sạc (List Tariffs)
- **Method & Endpoint:** `GET /api/csms/tariffs`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "tar_standard_01",
      "name": "Biểu giá sạc tiêu chuẩn toàn quốc",
      "currency": "VND",
      "default_price_per_kwh": 3850,
      "time_of_use_periods": [
        {
          "name": "Giờ thấp điểm",
          "start_time": "22:00",
          "end_time": "04:00",
          "price_per_kwh": 3200
        },
        {
          "name": "Giờ bình thường",
          "start_time": "04:00",
          "end_time": "17:00",
          "price_per_kwh": 3850
        },
        {
          "name": "Giờ cao điểm",
          "start_time": "17:00",
          "end_time": "22:00",
          "price_per_kwh": 4500
        }
      ],
      "idle_fee": {
        "grace_period_minutes": 15,
        "fee_per_minute_vnd": 1000
      }
    }
  ]
}
```

---

## 9. NHÓM API 8: QUẢN TRỊ NGƯỜI DÙNG PHÂN QUYỀN 7 VAI TRÒ RBAC (STAFF USERS)

- **Method & Endpoint:** `GET /api/csms/users`, `POST /api/csms/users`, `PATCH /api/csms/users/{id}`

#### Bảng Ma trận Phân quyền 7 Vai trò RBAC:
| Nhóm Endpoint | Super Admin | C-Level | Operator | Finance | Site Manager | Technician | Support |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **GET /dashboard** | Full | Full | Read | Read | Branch | Read | No |
| **GET /stations** | Full | Read | Read | Read | Branch | Read | Read |
| **POST /stations** | Full | No | No | No | No | No | No |
| **POST /commands** | Full | No | Full | No | No | Test Mode | Unlock Only |
| **POST /wallet/adjust** | Full | No | No | Full | No | No | No |
| **POST /users** | Full | No | No | No | No | No | No |

# ĐẶC TẢ CHI TIẾT RESTFUL API ỨNG DỤNG TÀI XẾ THACO CHARGE
## (THACO CHARGE MOBILE DRIVER APP API SPECIFICATION & REFERENCE GUIDE)

> **Phân hệ:** Ứng dụng Di động Dành cho Tài xế Xe điện (THACO_Charge Flutter iOS & Android)  
> **Backend Service:** THACO CSMS Go Backend (`backend-go/internal/http/router.go` - Route Group `/api/mobile`)  
> **Base URL Production:** `https://csms.thaco.vn/api/mobile`  
> **Base URL Staging / Dev:** `http://10.14.80.193:8080/api/mobile`  
> **Chuẩn dữ liệu:** JSON over HTTPS (RESTful API), UTF-8  
> **Chuẩn xác thực:** Firebase Auth Token / Bearer JWT Token  
> **Phiên bản:** `v1.0.1` (Tháng 9/2026)

---

## 1. QUY CHUẨN CHUNG & CƠ CHẾ XÁC THỰC (AUTHENTICATION & CONVENTIONS)

### 1.1. HTTP Headers bắt buộc cho mọi Request
Mọi yêu cầu gửi từ ứng dụng di động THACO_Charge lên máy chủ CSMS đều phải đính kèm các Header sau:

| Header Key | Bắt buộc? | Kiểu giá trị | Ví dụ | Mô tả |
| :--- | :---: | :---: | :--- | :--- |
| `Authorization` | **Bắt buộc** (trừ route công khai) | String | `Bearer eyJhbGciOiJIUzI1NiIsIn...` | Token xác thực JWT / Firebase ID Token của tài xế |
| `Content-Type` | **Bắt buộc** (với POST/PATCH/PUT) | String | `application/json` | Định dạng dữ liệu gửi lên |
| `Accept` | **Bắt buộc** | String | `application/json` | Định dạng dữ liệu mong muốn nhận về |
| `X-App-Version` | Khuyến nghị | String | `1.0.1` | Phiên bản ứng dụng di động để phục vụ Force Update |
| `X-Platform` | Khuyến nghị | String | `iOS` hoặc `Android` | Hệ điều hành thiết bị người dùng |

---

### 1.2. Định dạng Phản hồi Chuẩn (Standard Response Envelopes)

#### A. Phản hồi Thành công (200 OK / 201 Created):
```json
{
  "success": true,
  "data": { ... },
  "message": "Thao tác thành công",
  "timestamp": 1789725600
}
```

#### B. Phản hồi Thất bại (4xx / 5xx Error):
```json
{
  "success": false,
  "error": {
    "code": "INSUFFICIENT_BALANCE",
    "message": "Số dư ví không đủ để kích hoạt phiên sạc. Vui lòng nạp tối thiểu 50.000 VNĐ.",
    "details": {
      "current_balance": 15000,
      "minimum_required": 50000
    }
  },
  "timestamp": 1789725600
}
```

---

### 1.3. Bảng Mã Lỗi Thường Gặp (Error Codes Reference)
| HTTP Status | Mã lỗi nội bộ (Error Code) | Ý nghĩa nghiệp vụ |
| :---: | :--- | :--- |
| **400** | `INVALID_INPUT` | Dữ liệu đầu vào sai định dạng hoặc thiếu trường bắt buộc |
| **401** | `UNAUTHORIZED` | Token xác thực hết hạn hoặc không hợp lệ |
| **403** | `ACCOUNT_SUSPENDED` | Tài khoản tài xế đang bị tạm khóa |
| **404** | `CONNECTOR_NOT_FOUND` | Không tìm thấy súng sạc tương ứng với mã QR vừa quét |
| **409** | `CONNECTOR_OCCUPIED` | Súng sạc đang có xe khác cắm hoặc đang trong phiên sạc |
| **422** | `INSUFFICIENT_BALANCE` | Số dư khả dụng trong ví không đủ ngưỡng giữ chỗ tối thiểu |
| **503** | `STATION_OFFLINE` | Trụ sạc bị mất kết nối mạng với máy chủ CSMS Cloud |

---

## 2. NHÓM API 1: XÁC THỰC & HỒ SƠ TÀI XẾ (AUTH & PROFILE)

### 2.1. Đăng ký / Khởi tạo phiên tài xế (Provision Mobile Customer)
- **Endpoint:** `POST /api/mobile/auth/session` (hoặc `/auth/register`)
- **Mô tả:** Đăng ký hoặc đồng bộ tài khoản người dùng từ Firebase Phone Auth vào cơ sở dữ liệu CSMS. Tự động cấp ví tiền điện tử (`wallet`) mặc định.
- **Xác thực:** Không bắt buộc Header Authorization (Xác thực qua Firebase Token trong body).

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/auth/session" \
  -H "Content-Type: application/json" \
  -d '{
    "phone": "+84901234567",
    "full_name": "Nguyễn Văn A",
    "email": "nguyenvana@gmail.com",
    "firebase_uid": "fb_uid_987654321_abc",
    "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6Ij..."
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "customer_id": "cust_01HX98Z12A",
    "phone": "+84901234567",
    "full_name": "Nguyễn Văn A",
    "email": "nguyenvana@gmail.com",
    "wallet_id": "wal_01HX98Z15B",
    "balance": 250000,
    "currency": "VND",
    "charging_card": {
      "card_id": "card_01HX99A1",
      "rfid_tag": "E2801191A003",
      "status": "ACTIVE"
    },
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySWQiOiJjdXN0XzA...",
    "expires_at": 1792317600
  },
  "message": "Đăng nhập thành công"
}
```

---

### 2.2. Lấy thông tin hồ sơ tài xế hiện tại (Get Current Driver Profile)
- **Endpoint:** `GET /api/mobile/me`
- **Mô tả:** Lấy thông tin chi tiết tài xế, bao gồm họ tên, số điện thoại, số dư ví, thông tin thẻ RFID và danh sách xe đã đăng ký.
- **Xác thực:** Yêu cầu Bearer Token.

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/mobile/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Accept: application/json"
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "cust_01HX98Z12A",
    "full_name": "Nguyễn Văn A",
    "phone": "+84901234567",
    "email": "nguyenvana@gmail.com",
    "avatar_url": "https://cdn.thaco.vn/avatars/cust_01HX98Z12A.jpg",
    "tier": "GOLD",
    "free_quota_kwh": 50.0,
    "wallet": {
      "balance": 250000,
      "frozen_balance": 0,
      "currency": "VND"
    },
    "created_at": "2026-06-15T08:30:00Z"
  }
}
```

---

### 2.3. Cập nhật hồ sơ tài xế (Update Driver Profile)
- **Endpoint:** `PATCH /api/mobile/me`
- **Mô tả:** Cập nhật họ tên, địa chỉ email, ảnh đại diện của tài xế.

#### Request Example (cURL):
```bash
curl -X PATCH "https://csms.thaco.vn/api/mobile/me" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "full_name": "Nguyễn Văn An",
    "email": "nguyenvanan.thaco@gmail.com"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "id": "cust_01HX98Z12A",
    "full_name": "Nguyễn Văn An",
    "email": "nguyenvanan.thaco@gmail.com",
    "updated_at": "2026-09-18T10:15:00Z"
  },
  "message": "Cập nhật hồ sơ thành công"
}
```

---

## 3. NHÓM API 2: QUẢN LÝ XE ĐIỆN & CẮM SẠC TỰ ĐỘNG (VEHICLES & AUTOCHARGE)

### 3.1. Danh sách xe điện của tài xế (List Driver Vehicles)
- **Endpoint:** `GET /api/mobile/me/vehicles`
- **Mô tả:** Trả về danh sách xe điện tài xế đã liên kết, loại cổng sạc (CCS2), dung lượng pin (kWh) và trạng thái kích hoạt sạc tự nhận dạng (AutoCharge Plug & Charge).

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/mobile/me/vehicles" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "id": "veh_01HX99VF1",
      "brand": "VinFast",
      "model": "VF8 Plus",
      "plate_number": "51K-987.65",
      "battery_capacity_kwh": 87.7,
      "max_charging_power_kw": 250,
      "connector_type": "CCS2",
      "evcc_id": "020000000001",
      "autocharge_enabled": true,
      "is_default": true
    },
    {
      "id": "veh_01HX99VF2",
      "brand": "Hyundai",
      "model": "Ioniq 5",
      "plate_number": "51A-123.45",
      "battery_capacity_kwh": 72.6,
      "max_charging_power_kw": 350,
      "connector_type": "CCS2",
      "evcc_id": null,
      "autocharge_enabled": false,
      "is_default": false
    }
  ]
}
```

---

### 3.2. Thêm mới xe điện (Add Vehicle)
- **Endpoint:** `POST /api/mobile/me/vehicles`

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/me/vehicles" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "brand": "Kia",
    "model": "EV6 GT-Line",
    "plate_number": "30H-888.88",
    "battery_capacity_kwh": 77.4,
    "max_charging_power_kw": 240,
    "connector_type": "CCS2"
  }'
```

#### Response Example (201 Created):
```json
{
  "success": true,
  "data": {
    "id": "veh_01HX99VF3",
    "brand": "Kia",
    "model": "EV6 GT-Line",
    "plate_number": "30H-888.88",
    "battery_capacity_kwh": 77.4,
    "max_charging_power_kw": 240,
    "connector_type": "CCS2",
    "autocharge_enabled": false
  },
  "message": "Đăng ký xe thành công"
}
```

---

### 3.3. Kích hoạt tính năng Cắm sạc Tự nhận dạng (Enable AutoCharge)
- **Endpoint:** `POST /api/mobile/me/vehicles/{id}/autocharge`
- **Mô tả:** Gắn mã EVCCID (địa chỉ MAC bộ điều khiển PLC trên xe do SECC nhận diện được) vào xe. Sau khi kích hoạt, tài xế chỉ cần cắm súng là trụ tự động sạc mà không cần bấm App hay quẹt thẻ.

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/me/vehicles/veh_01HX99VF1/autocharge" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "evcc_id": "020000000001"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "vehicle_id": "veh_01HX99VF1",
    "autocharge_enabled": true,
    "evcc_id": "020000000001"
  },
  "message": "Kích hoạt cắm sạc tự động AutoCharge thành công"
}
```

---

## 4. NHÓM API 3: BẢN ĐỒ TRẠM SẠC & QUÉT MÃ QR (STATIONS & QR SCAN)

### 4.1. Tìm kiếm trạm sạc xung quanh theo tọa độ GPS (Get Stations Map)
- **Endpoint:** `GET /api/mobile/stations` (hoặc `/charge-points`)
- **Query Parameters:**
  - `lat` (float, bắt buộc): Vĩ độ hiện tại của tài xế (ví dụ: `10.7769`)
  - `lng` (float, bắt buộc): Kinh độ hiện tại của tài xế (ví dụ: `106.7009`)
  - `radius_km` (float, mặc định `15.0`): Bán kính quét xung quanh (km)
  - `connector_type` (string, tùy chọn): Lọc loại súng (`CCS2`, `Type2`)
  - `status` (string, tùy chọn): `AVAILABLE` (Chỉ trạm còn súng trống)

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/mobile/stations?lat=10.7769&lng=106.7009&radius_km=10&connector_type=CCS2" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": [
    {
      "station_id": "sta_sala_01",
      "station_name": "Trạm Sạc Nhanh THACO Sala Quận 2",
      "address": "Số 10 Mai Chí Thọ, P. An Lợi Đông, TP. Thủ Đức, TP.HCM",
      "latitude": 10.7712,
      "longitude": 106.7215,
      "distance_km": 2.4,
      "total_power_kw": 360,
      "is_online": true,
      "opening_hours": "24/7",
      "amenities": ["CAFE", "RESTROOM", "WIFI", "CONVENIENCE_STORE"],
      "tariff_vnd_per_kwh": 3850,
      "connectors_summary": {
        "total": 4,
        "available": 2,
        "charging": 1,
        "preparing": 1,
        "faulted": 0
      },
      "charge_points": [
        {
          "charge_point_id": "EVSE_SALA_01",
          "connectors": [
            {
              "connector_id": 1,
              "type": "CCS2",
              "max_power_kw": 180,
              "status": "Available"
            },
            {
              "connector_id": 2,
              "type": "CCS2",
              "max_power_kw": 180,
              "status": "Charging"
            }
          ]
        }
      ]
    }
  ]
}
```

---

### 4.2. Giải mã mã QR dán trên súng sạc (Resolve QR Code)
- **Endpoint:** `POST /api/mobile/qr/resolve`
- **Mô tả:** Khi tài xế quét mã QR dán tại súng sạc trên trụ hoặc hiển thị trên màn hình HMI, API này kiểm tra súng có tồn tại, còn súng trống hay không, và trả về thông tin sẵn sàng sạc.

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/qr/resolve" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "qr_code": "https://charge.thaco.vn/c?station=EVSE_SALA_01&connector=1"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "station_id": "sta_sala_01",
    "station_name": "Trạm Sạc Nhanh THACO Sala Quận 2",
    "charge_point_id": "EVSE_SALA_01",
    "connector_id": 1,
    "connector_type": "CCS2",
    "max_power_kw": 180,
    "status": "Preparing",
    "is_plugged": true,
    "tariff": {
      "rate_vnd_per_kwh": 3850,
      "service_fee_vnd": 0,
      "idle_fee_per_min": 1000
    },
    "user_wallet_balance": 250000,
    "minimum_balance_required": 50000,
    "can_start_charge": true
  },
  "message": "Súng sạc sẵn sàng"
}
```

#### Response Example (409 Conflict - Súng đang sạc bởi người khác):
```json
{
  "success": false,
  "error": {
    "code": "CONNECTOR_OCCUPIED",
    "message": "Súng sạc số 1 đang trong một phiên sạc khác. Vui lòng chọn súng sạc còn trống."
  }
}
```

---

## 5. NHÓM API 4: ĐIỀU KHIỂN & THEO DÕI PHIÊN SẠC (CHARGING OPERATIONS)

### 5.1. Khởi động phiên sạc từ xa (Start Charging Session)
- **Endpoint:** `POST /api/mobile/charging-sessions`
- **Mô tả:** Khởi tạo yêu cầu sạc. CSMS kiểm tra số dư ví tài xế, tạo `session_id`, gửi bản tin OCPP `RemoteStartTransaction` xuống trụ sạc để khóa ngàm súng và cấp điện cao thế.

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/charging-sessions" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "charge_point_id": "EVSE_SALA_01",
    "connector_id": 1,
    "vehicle_id": "veh_01HX99VF1",
    "stop_condition": {
      "type": "SOC",
      "target_soc": 80
    }
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "session_id": "sess_01HX99CHARG01",
    "transaction_id": 100452,
    "charge_point_id": "EVSE_SALA_01",
    "connector_id": 1,
    "status": "Starting",
    "started_at": "2026-09-18T10:20:00Z",
    "tariff_rate_vnd": 3850
  },
  "message": "Lệnh sạc đã gửi tới trụ thành công"
}
```

---

### 5.2. Lấy thông số phiên sạc trực tiếp theo thời gian thực (Get Active Charging Telemetry)
- **Endpoint:** `GET /api/mobile/charging-sessions/active`
- **Mô tả:** Đọc liên tục (Polling chu kỳ 2-3 giây) các thông số dòng, áp, kW, % pin (SoC), tiền sạc tức thời.

#### Request Example (cURL):
```bash
curl -X GET "https://csms.thaco.vn/api/mobile/charging-sessions/active" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "session_id": "sess_01HX99CHARG01",
    "transaction_id": 100452,
    "status": "Charging",
    "charge_point_id": "EVSE_SALA_01",
    "connector_id": 1,
    "vehicle": {
      "plate_number": "51K-987.65",
      "model": "VF8 Plus"
    },
    "telemetry": {
      "soc_percent": 54,
      "start_soc_percent": 22,
      "voltage_v": 385.4,
      "current_a": 155.6,
      "power_kw": 59.97,
      "energy_kwh": 28.45,
      "elapsed_seconds": 1245,
      "remaining_minutes": 22,
      "gun_temperature_c": 38.5
    },
    "cost": {
      "rate_vnd_per_kwh": 3850,
      "current_energy_cost_vnd": 109532,
      "service_fee_vnd": 0,
      "total_cost_vnd": 109532
    }
  }
}
```

---

### 5.3. Dừng phiên sạc từ ứng dụng (Stop Charging Session)
- **Endpoint:** `POST /api/mobile/charging-sessions/{id}/stop`
- **Mô tả:** Tài xế bấm nút [Dừng sạc] trên ứng dụng. Máy chủ CSMS gửi lệnh `RemoteStopTransaction` xuống trụ sạc để giảm dòng về 0A, ngắt contactor và mở khóa súng.

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/charging-sessions/sess_01HX99CHARG01/stop" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "DRIVER_STOP_APP"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "session_id": "sess_01HX99CHARG01",
    "status": "Stopping",
    "message": "Trụ sạc đang giảm dần dòng điện và mở khóa súng an toàn"
  }
}
```

---

### 5.4. Lịch sử các phiên sạc & Hóa đơn điện tử (Charging History)
- **Endpoint:** `GET /api/mobile/charging-sessions`
- **Query Parameters:** `page=1`, `limit=10`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "total_records": 24,
    "page": 1,
    "limit": 10,
    "sessions": [
      {
        "session_id": "sess_01HX99CHARG01",
        "station_name": "Trạm Sạc Nhanh THACO Sala Quận 2",
        "charge_point_id": "EVSE_SALA_01",
        "connector_id": 1,
        "started_at": "2026-09-18T10:20:00Z",
        "stopped_at": "2026-09-18T10:55:30Z",
        "duration_minutes": 35,
        "start_soc": 22,
        "stop_soc": 80,
        "total_energy_kwh": 38.65,
        "total_cost_vnd": 148802,
        "invoice_status": "PAID",
        "invoice_url": "https://invoice.thaco.vn/pdf/INV-2026-0918-001.pdf"
      }
    ]
  }
}
```

---

## 6. NHÓM API 5: VÍ ĐIỆN TỬ & NẠP TIỀN VIETQR SEPAY (WALLET & PAYMENTS)

### 6.1. Lấy thông tin ví & số dư (Get Wallet Balance)
- **Endpoint:** `GET /api/mobile/me/wallet`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "wallet_id": "wal_01HX98Z15B",
    "balance": 250000,
    "currency": "VND",
    "status": "ACTIVE",
    "updated_at": "2026-09-18T10:00:00Z"
  }
}
```

---

### 6.2. Tạo đơn nạp tiền VietQR SePay (Create Top-up Order)
- **Endpoint:** `POST /api/mobile/payment/orders`
- **Mô tả:** Tài xế chọn số tiền nạp (VD: 200.000 VNĐ). Máy chủ sinh mã thanh toán duy nhất (`PAY100567`), mã VietQR động chuẩn Napas 247 và link ảnh QR để ứng dụng hiển thị lên màn hình.

#### Request Example (cURL):
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/payment/orders" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 200000,
    "payment_method": "SEPAY_VIETQR"
  }'
```

#### Response Example (201 Created):
```json
{
  "success": true,
  "data": {
    "order_id": "ord_01HX99TOPUP01",
    "order_code": "PAY100567",
    "amount": 200000,
    "currency": "VND",
    "status": "PENDING",
    "created_at": "2026-09-18T10:25:00Z",
    "expires_at": "2026-09-18T10:40:00Z",
    "ttl_seconds": 900,
    "bank_info": {
      "bank_name": "Ngân hàng TMCP Quân Đội (MB Bank)",
      "bank_bin": "970422",
      "account_number": "0988776655",
      "account_holder": "CONG TY CP EVSE THACO",
      "transfer_content": "PAY100567"
    },
    "vietqr_payload": "00020101021238540010A00000072701240006970422011009887766550208QRIBFTTA530370454062000005802VN62130809PAY1005676304D1A4",
    "qr_image_url": "https://qr.sepay.vn/assets/img/banklogo/MB.png?acc=0988776655&bank=MB&amount=200000&des=PAY100567"
  },
  "message": "Đã tạo đơn nạp tiền. Vui lòng quét mã VietQR để thanh toán."
}
```

---

### 6.3. Kiểm tra trạng thái đơn nạp tiền (Poll Top-up Order Status)
- **Endpoint:** `GET /api/mobile/payment/orders/{orderCode}`
- **Mô tả:** Ứng dụng polling chu kỳ 1.5 - 2 giây để phát hiện khi ngân hàng chuyển khoản thành công và SePay đã bắn Webhook IPN về server.

#### Response Example (Khi thanh toán hoàn tất - 200 OK):
```json
{
  "success": true,
  "data": {
    "order_id": "ord_01HX99TOPUP01",
    "order_code": "PAY100567",
    "amount": 200000,
    "status": "PAID",
    "paid_at": "2026-09-18T10:26:15Z",
    "transaction_reference": "SEPAY_TX_987654",
    "new_wallet_balance": 450000
  },
  "message": "Nạp tiền thành công! Số dư ví đã được cập nhật."
}
```

---

### 6.4. Xem sao kê biến động số dư ví (Wallet Transactions Ledger)
- **Endpoint:** `GET /api/mobile/me/wallet/transactions`
- **Query Parameters:** `page=1`, `limit=20`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "total_records": 15,
    "transactions": [
      {
        "id": "tx_ledger_01",
        "type": "TOPUP",
        "amount": 200000,
        "balance_after": 450000,
        "description": "Nạp tiền ví qua VietQR SePay (Mã: PAY100567)",
        "created_at": "2026-09-18T10:26:15Z"
      },
      {
        "id": "tx_ledger_02",
        "type": "CHARGING_PAYMENT",
        "amount": -148802,
        "balance_after": 250000,
        "description": "Thanh toán phiên sạc tại EVSE Sala Gun 1 (sess_01HX99CHARG01)",
        "created_at": "2026-09-18T09:45:00Z"
      }
    ]
  }
}
```

---

## 7. NHÓM API 6: QUẢN LÝ THẺ SẠC RFID VẬT LÝ (CHARGING CARD)

### 7.1. Lấy thông tin thẻ RFID đang liên kết (Get Linked Charging Card)
- **Endpoint:** `GET /api/mobile/me/charging-card`

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "card_id": "card_01HX99A1",
    "rfid_tag": "E2801191A003",
    "card_label": "Thẻ Sạc THACO VIP",
    "status": "Active",
    "linked_at": "2026-07-01T14:20:00Z"
  }
}
```

---

### 7.2. Liên kết thẻ sạc RFID mới (Link RFID Card)
- **Endpoint:** `PUT /api/mobile/me/charging-card`
- **Mô tả:** Tài xế nhập mã in dập nổi trên thẻ RFID do THACO phát hành để liên kết trực tiếp vào ví cá nhân.

#### Request Example (cURL):
```bash
curl -X PUT "https://csms.thaco.vn/api/mobile/me/charging-card" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Content-Type: application/json" \
  -d '{
    "rfid_tag": "E2801191A003",
    "card_label": "Thẻ Sạc Xe VinFast VF8"
  }'
```

#### Response Example (200 OK):
```json
{
  "success": true,
  "data": {
    "card_id": "card_01HX99A1",
    "rfid_tag": "E2801191A003",
    "status": "Active"
  },
  "message": "Liên kết thẻ sạc RFID thành công"
}
```

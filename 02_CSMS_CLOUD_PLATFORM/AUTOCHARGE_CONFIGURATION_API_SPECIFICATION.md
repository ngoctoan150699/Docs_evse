# ĐẶC TẢ CHI TIẾT API & KIẾN TRÚC CẤU HÌNH AUTOCHARGE
## (PLUG & CHARGE VIA EVCCID / MAC SPECIFICATION)
### Hệ sinh thái: THACO EVSE Cloud Platform & Hệ thống Trạm sạc DC Fast Charger
**Đơn vị chủ trì phát hành:** Phòng thiết kế điện tử - Trung tâm R&D THACO INDUSTRIES
**Phiên bản:** 1.0.0 | **Ngày ban hành:** 18/09/2026 | **Trạng thái:** Production Standard

---

## MỤC LỤC
1. [Tổng quan Tính năng AutoCharge (Cắm là Sạc)](#1-tổng-quan-tính-năng-autocharge-cắm-là-sạc)
2. [Sơ đồ Kiến trúc & Luồng Nghiệp vụ (End-to-End Workflow)](#2-sơ-đồ-kiến-trúc--luồng-nghiệp-vụ-end-to-end-workflow)
   - 2.1. Luồng tự động nhận dạng xe tại đầu súng sạc (Zero-Touch Detection)
   - 2.2. Luồng khách hàng kích hoạt AutoCharge qua Ứng dụng Di động
   - 2.3. Luồng Quản trị viên (CSMS Staff) cấu hình Whitelist từ Web Dashboard
   - 2.4. Luồng vận hành thực tế khi xe cắm sạc (Runtime Execution Flow)
   - 2.5. Cơ chế Khóa an toàn Toàn hệ thống (Kill-switch: autocharge_whitelist_enabled)
3. [Đặc tả Chi tiết Danh mục API Cấu hình AutoCharge](#3-đặc-tả-chi-tiết-danh-mục-api-cấu-hình-autocharge)
   - 3.1. Phân hệ Ứng dụng Di động (Mobile App APIs - /api/mobile/*)
   - 3.2. Phân hệ Quản trị CSMS Cloud (Staff Web APIs - /api/csms/*)
   - 3.3. Phân hệ Cài đặt Hệ thống (System Settings APIs)
4. [Tích hợp Tầng Giao thức OCPP 1.6J](#4-tích-hợp-tầng-giao-thức-ocpp-16j)
5. [Cơ sở Dữ liệu, Ràng buộc Bảo mật & Bảng Mã lỗi](#5-cơ-sở-dữ-liệu-ràng-buộc-bảo-mật--bảng-mã-lỗi)
6. [Bộ Ví dụ Gọi API Thực tế (cURL & Request/Response Payload)](#6-bộ-ví-dụ-gọi-api-thực-tế-curl--requestresponse-payload)

---

## 1. TỔNG QUAN TÍNH NĂNG AUTOCHARGE (CẮM LÀ SẠC)

### 1.1. Khái niệm & Cơ sở Kỹ thuật
**AutoCharge** là giải pháp định danh tự động dựa trên phần cứng, cho phép tài xế xe điện chỉ cần **cắm súng sạc vào cổng sạc trên xe là quá trình sạc tự động bắt đầu** mà không cần thao tác quẹt thẻ RFID vật lý hay mở ứng dụng di động để quét mã QR.

Trong hệ thống trạm sạc **THACO EVSE DC Fast Charger**, quá trình truyền thông giữa trạm và xe điện tuân thủ chuẩn **DIN 70121 / ISO 15118-2** thông qua sóng mang đường dây điện **PLC (Powerline Communication - HomePlug GreenPHY)** trên chân điều khiển **CP (Control Pilot)**:
- Bộ điều khiển sạc thông minh **SECC** kết nối với STM32H743/F429 sẽ giải mã gói tin truyền thông mức cao (High-Level Communication - HLC).
- Từ khung bản tin PLC, SECC trích xuất địa chỉ phần cứng duy nhất của bộ điều khiển truyền thông trên xe **EVCC (Electric Vehicle Communication Controller)**, thường biểu diễn dưới dạng **địa chỉ MAC 6-byte** (ví dụ: `38:2C:4A:A1:B2:C3`) hoặc mã định danh xe điện **EVCCID**.
- Trạm sạc đẩy mã EVCCID lên hệ thống máy chủ quản trị **THACO CSMS Cloud** qua bản tin OCPP 1.6J `DataTransfer` hoặc `Authorize`.

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                 HỆ THỐNG TRẠM SẠC XE ĐIỆN                              │
│                                                                                        │
│   [ Xe Điện (EV) ]          [ Trạm Sạc THACO EVSE ]           [ THACO CSMS Cloud ]     │
│   ┌──────────────┐          ┌───────────────────────┐          ┌───────────────────┐   │
│   │ EVCC Modem   │          │ SECC Module + STM32   │          │ Go Backend + DB   │   │
│   │ (MAC Address)│◄────────►│ (PLC HomePlug GreenPHY│◄────────►│ (AutoCharge Core) │   │
│   └──────────────┘  Cáp CCS2└───────────────────────┘ WebSocket└───────────────────┘   │
│                      DIN 70121        OCPP 1.6J                PostgreSQL 16           │
│                      ISO 15118                                                         │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

### 1.2. So sánh AutoCharge vs. ISO 15118 Plug & Charge

| Tiêu chí | AutoCharge (Dự án THACO EVSE) | ISO 15118 Plug & Charge (PNC) |
| :--- | :--- | :--- |
| **Cơ chế định danh** | Địa chỉ phần cứng **MAC / EVCCID** của modem truyền thông xe. | Chứng chỉ số số hóa **X.509 PKI Certificates** lưu trong HSM xe. |
| **Yêu cầu hạ tầng** | Đơn giản, tương thích **100% xe điện CCS2** hiện hành (VinFast VF e34/VF8/VF9, Porsche Taycan, Hyundai Ioniq 5, Audi e-tron...). | Đòi hỏi hạ tầng chứng thực V2G Root CA, OEM Sub-CA và chứng chỉ số trên xe. |
| **Tốc độ khởi động** | Cực nhanh: Nhận diện và cấp điện trong vòng **5 - 8 giây**. | Cần từ 15 - 25 giây để bắt tay mã hóa TLS và thẩm định chuỗi chứng chỉ. |
| **Phân quyền & Kiểm soát**| Quản lý Whitelist tập trung tại CSMS Cloud theo từng Tenant. | Phụ thuộc vào MO (Mobility Operator) và hệ thống hợp đồng sạc (Contract). |

---

## 2. SƠ ĐỒ KIẾN TRÚC & LUỒNG NGHIỆP VỤ (END-TO-END WORKFLOW)

### 2.1. Luồng tự động nhận dạng xe tại đầu súng sạc (Zero-Touch Detection)
Để giải quyết bài toán người dùng không biết địa chỉ MAC xe của mình là gì, hệ thống THACO EVSE thiết kế tính năng **Zero-Touch Auto-Detection**: Khi người dùng cắm súng sạc vào xe, trạm sẽ đọc MAC và lưu tạm thời lên cổng sạc đó. Người dùng chỉ cần bấm nút "Lấy mã xe từ súng sạc" trên ứng dụng:

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Tài xế (App Mobile)
    participant Car as Xe Điện (EVCC)
    participant EVSE as Trạm Sạc THACO (SECC/F429)
    participant CSMS as CSMS Gateway (Go Backend)
    participant DB as PostgreSQL (Connectors DB)

    Driver->>Car: Cắm súng sạc CCS2 vào xe
    Car->>EVSE: Bắt tay PLC DIN 70121 (SLAC & V2G Setup)
    Note over EVSE: SECC đọc được MAC/EVCCID: 38:2C:4A:A1:B2:C3
    EVSE->>CSMS: OCPP DataTransfer [2, "id_01", "THACO_EVSE", "VehicleIdentity", {"connectorId":1, "evccId":"38:2C:4A:A1:B2:C3"}]
    CSMS->>DB: UPDATE connectors SET detected_evcc_id='382C4AA1B2C3', detected_at=now()
    CSMS-->>EVSE: DataTransfer Response: Accepted
    Driver->>CSMS: GET /api/mobile/me/detected-evcc?chargePointId=T001&connectorId=1
    CSMS-->>Driver: 200 OK: {"detected": true, "evccId": "382C4AA1B2C3"}
    Note over Driver: Ứng dụng tự động điền mã MAC vào form đăng ký AutoCharge!
```

---

### 2.2. Luồng khách hàng kích hoạt AutoCharge qua Ứng dụng Di động
Sau khi đã có mã MAC (tự động nhận diện từ súng hoặc nhập thủ công), tài xế kích hoạt liên kết xe:

```mermaid
sequenceDiagram
    autonumber
    actor App as THACO Charge App
    participant API as Mobile API Router
    participant Sec as Security & Validator
    participant DB as Database (app_vehicles)

    App->>API: POST /api/mobile/me/vehicles/{id}/autocharge {"evccId": "38:2C:4A:A1:B2:C3", "enabled": true}
    API->>Sec: 1. Xác thực JWT Customer Token<br/>2. Chuẩn hóa MAC: loại bỏ ':', '-', uppercase -> 382C4AA1B2C3<br/>3. Kiểm tra độ dài: 6 <= len <= 32
    alt MAC không hợp lệ
        Sec-->>App: 400 Bad Request: INVALID_EVCC_ID
    end
    API->>DB: 4. Kiểm tra Unique Whitelist: Mã MAC này đã có xe nào ACTIVE sở hữu chưa?
    alt Đã bị xe khác đăng ký
        DB-->>App: 409 Conflict: EVCC_ALREADY_BOUND
    end
    API->>DB: 5. UPDATE app_vehicles SET evcc_id='382C4AA1B2C3', auto_charge_enabled=true, auto_charge_enrolled_at=now() WHERE id=vehicle_id AND app_user_id=c.ID
    DB-->>App: 200 OK: {"id": "...", "evccId": "382C4AA1B2C3", "autoChargeEnabled": true}
```

---

### 2.3. Luồng Quản trị viên (CSMS Staff) cấu hình Whitelist từ Web Dashboard
Dành cho nhân viên vận hành, chăm sóc khách hàng hoặc kỹ thuật viên hỗ trợ tài xế kích hoạt tại trạm:

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Staff (CSMS Web Dashboard)
    participant Auth as RBAC Middleware (CanWriteStation)
    participant Handler as Admin API Handler
    participant DB as PostgreSQL
    participant Audit as Audit Logging Service

    Admin->>Auth: POST /api/csms/customers/{id}/vehicles/{vehicleId}/autocharge
    Auth->>Handler: Kiểm tra quyền: SuperAdmin / TenantAdmin / StationManager / Operator
    Handler->>DB: Kiểm tra quyền truy cập Tenant & Kiểm tra xung đột MAC trong Tenant
    Handler->>DB: UPDATE app_vehicles SET evcc_id=..., auto_charge_enabled=true
    Handler->>Audit: Ghi nhật ký: Action=TOGGLE_AUTOCHARGE, Entity=app_vehicles, User=Admin, Status=OK
    Handler-->>Admin: 200 OK: {"vehicleId": "...", "evccId": "...", "autoChargeEnabled": true}
```

---

### 2.4. Luồng vận hành thực tế khi xe cắm sạc (Runtime Execution Flow)
Khi xe đã nằm trong Whitelist cắm vào bất kỳ trạm sạc nào thuộc mạng lưới THACO EVSE:

```
  [ Cắm súng sạc CCS2 vào xe điện ]
                 │
                 ▼
  [ SECC đọc địa chỉ MAC qua PLC ] ──► Gửi OCPP Authorize(idTag="AUTOC_382C4AA1B2C3")
                                                  │
                                                  ▼
                                   [ CSMS Gateway Kiểm Tra An Toàn ]
                                   ├─ 1. Kiểm tra autocharge_whitelist_enabled == true
                                   ├─ 2. Khớp MAC trong bảng app_vehicles (Tenant Isolation)
                                   ├─ 3. Kiểm tra trạng thái tài khoản: user.status == 'ACTIVE'
                                   └─ 4. Kiểm tra điều kiện thanh toán:
                                         • Khách có thẻ VIP/Free? ──────► ACCEPTED
                                         • Khách còn lượt Free Quota? ──► ACCEPTED
                                         • Số dư ví >= 10,000 VNĐ? ─────► ACCEPTED
                                         • Không đủ điều kiện? ─────────► BLOCKED / REJECTED
                                                  │
                                                  ▼ (Nếu ACCEPTED)
                                    [ CSMS trả về Status: Accepted ]
                                                  │
                                                  ▼
                               [ Trạm sạc F429 gửi StartTransaction ]
                                                  │
                                                  ▼
                               [ CSMS lưu Transaction: auth_method = 'AUTO_CHARGE' ]
                               [ Đóng rơ-le cao áp & Bắt đầu bơm điện DC ]
```

---

### 2.5. Cơ chế Khóa an toàn Toàn hệ thống (Kill-switch: autocharge_whitelist_enabled)
Trong trường hợp phát hiện nguy cơ an ninh (ví dụ: phát hiện thiết bị giả mạo địa chỉ MAC diện rộng hoặc sự cố mạng lưới), Quản trị viên cấp cao có thể kích hoạt **Kill-switch khẩn cấp**:
- API: `PUT /api/csms/settings` với payload: `{"autocharge_whitelist_enabled": false}`
- Hiệu lực tức thì: Mọi yêu cầu AutoCharge tại tất cả các trạm sạc toàn quốc sẽ lập tức bị Gateway từ chối (`Blocked`), buộc người dùng phải chuyển sang quét mã QR hoặc quẹt thẻ RFID để đảm bảo tính an toàn tài chính.

---

## 3. ĐẶC TẢ CHI TIẾT DANH MỤC API CẤU HÌNH AUTOCHARGE

### 3.1. Phân hệ Ứng dụng Di động (Mobile App APIs - `/api/mobile/*`)

#### 3.1.1. Lấy mã xe tự động phát hiện tại cổng sạc (Zero-Touch Auto Detect)
- **Endpoint:** `GET /api/mobile/me/detected-evcc`
- **Xác thực:** Yêu cầu Header `Authorization: Bearer <FIREBASE_CUSTOMER_JWT>`
- **Query Parameters:**
  - `chargePointId` *(string, bắt buộc)*: Mã định danh trạm sạc (ví dụ: `T001`).
  - `connectorId` *(int, tùy chọn, mặc định 1)*: Thứ tự cổng sạc (1 hoặc 2).
- **Phản hồi thành công (HTTP 200 OK):**
  - *Trường hợp trạm đã phát hiện xe:*
    ```json
    {
      "detected": true,
      "evccId": "382C4AA1B2C3",
      "vin": "VF84910294829",
      "detectedAt": "2026-09-18T13:10:45Z"
    }
    ```
  - *Trường hợp chưa cắm súng hoặc súng đang rảnh:*
    ```json
    {
      "detected": false
    }
    ```

---

#### 3.1.2. Thêm xe mới đồng thời kích hoạt AutoCharge
- **Endpoint:** `POST /api/mobile/me/vehicles`
- **Xác thực:** `Authorization: Bearer <FIREBASE_CUSTOMER_JWT>`
- **Request Body (JSON):**
  ```json
  {
    "nickname": "VinFast VF8 Gia Đình",
    "manufacturer": "VinFast",
    "model": "VF8 Plus",
    "modelYear": 2024,
    "plateNumber": "51K-889.99",
    "vin": "VF84910294829",
    "batteryCapacityKwh": 87.7,
    "preferred": true,
    "evccId": "38:2C:4A:A1:B2:C3",
    "autoChargeEnabled": true
  }
  ```
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  {
    "id": "e7b1a2c4-8901-4f12-9c34-abcdef123456",
    "nickname": "VinFast VF8 Gia Đình",
    "evccId": "382C4AA1B2C3",
    "autoChargeEnabled": true,
    "autoChargeEnrolledAt": "2026-09-18T13:15:00Z"
  }
  ```

---

#### 3.1.3. Bật tính năng AutoCharge cho xe đã tồn tại
- **Endpoint:** `POST /api/mobile/me/vehicles/{id}/autocharge`
- **Xác thực:** `Authorization: Bearer <FIREBASE_CUSTOMER_JWT>`
- **URL Parameters:** `id` *(UUID)*: ID của bản ghi xe trong bảng `app_vehicles`.
- **Request Body (JSON):**
  ```json
  {
    "evccId": "38:2C:4A:A1:B2:C3",
    "enabled": true
  }
  ```
- **Quy tắc xử lý:**
  - Tự động làm sạch mã MAC: Xóa bỏ mọi dấu hai chấm `:`, gạch nối `-` và chuyển thành chữ in hoa.
  - Kiểm tra độ dài: Từ 6 đến 32 ký tự.
  - Kiểm tra tính duy nhất: Nếu mã MAC này đã được đăng ký cho một chiếc xe đang hoạt động (`status = 'ACTIVE'`) khác trong cùng Tenant, API trả về lỗi `409 Conflict`.
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  {
    "id": "e7b1a2c4-8901-4f12-9c34-abcdef123456",
    "evccId": "382C4AA1B2C3",
    "autoChargeEnabled": true
  }
  ```

---

#### 3.1.4. Tắt tính năng AutoCharge cho xe
- **Endpoint:** `DELETE /api/mobile/me/vehicles/{id}/autocharge`
- **Xác thực:** `Authorization: Bearer <FIREBASE_CUSTOMER_JWT>`
- **URL Parameters:** `id` *(UUID)*: ID của bản ghi xe.
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  {
    "status": "DISABLED"
  }
  ```

---

#### 3.1.5. Lấy danh sách xe & Trạng thái AutoCharge
- **Endpoint:** `GET /api/mobile/me/vehicles`
- **Xác thực:** `Authorization: Bearer <FIREBASE_CUSTOMER_JWT>`
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  [
    {
      "id": "e7b1a2c4-8901-4f12-9c34-abcdef123456",
      "nickname": "VinFast VF8 Gia Đình",
      "manufacturer": "VinFast",
      "model": "VF8 Plus",
      "modelYear": 2024,
      "plateNumber": "51K-889.99",
      "vin": "VF84910294829",
      "batteryCapacityKwh": 87.7,
      "preferred": true,
      "evccId": "382C4AA1B2C3",
      "autoChargeEnabled": true,
      "autoChargeEnrolledAt": "2026-09-18T13:15:00Z"
    }
  ]
  ```

---

### 3.2. Phân hệ Quản trị CSMS Cloud (Staff Web APIs - `/api/csms/*`)

#### 3.2.1. Quản trị viên Bật/Tắt AutoCharge cho Khách hàng
- **Endpoint:** `POST /api/csms/customers/{id}/vehicles/{vehicleId}/autocharge`
- **Xác thực:** `Authorization: Bearer <STAFF_JWT_TOKEN>`
- **Phân quyền RBAC tối thiểu:** Vai trò `OPERATOR`, `SITE_MANAGER`, `TENANT_ADMIN` hoặc `SUPER_ADMIN` (kiểm tra hàm `security.CanWriteStation(u.Role)`).
- **URL Parameters:**
  - `id` *(UUID)*: ID của khách hàng (`app_users.id`).
  - `vehicleId` *(UUID)*: ID xe của khách hàng (`app_vehicles.id`).
- **Request Body (JSON):**
  ```json
  {
    "evccId": "382C4AA1B2C3",
    "enabled": true
  }
  ```
- **Xử lý An toàn & Nhật ký:**
  - Kiểm tra Tenant Isolation: Khách hàng phải thuộc cùng Tenant của nhân viên quản trị (trừ khi là SuperAdmin).
  - Ghi nhật ký kiểm toán: Tự động ghi vào bảng `audit_logs` sự kiện `TOGGLE_AUTOCHARGE` lưu vết địa chỉ IP, User-Agent và người thực thi.
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  {
    "vehicleId": "e7b1a2c4-8901-4f12-9c34-abcdef123456",
    "evccId": "382C4AA1B2C3",
    "autoChargeEnabled": true
  }
  ```

---

### 3.3. Phân hệ Cài đặt Hệ thống (System Settings APIs)

#### 3.3.1. Truy vấn Cấu hình AutoCharge Toàn Hệ thống
- **Endpoint:** `GET /api/csms/settings`
- **Xác thực:** `Authorization: Bearer <STAFF_JWT_TOKEN>`
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  [
    {
      "key": "autocharge_whitelist_enabled",
      "value": true,
      "category": "CHARGING",
      "description": "Cho phép tính năng AutoCharge tự động sạc qua EVCCID",
      "updated_by": "admin@thaco.vn",
      "updated_at": "2026-09-18T10:00:00Z"
    },
    {
      "key": "payment_min_wallet_balance",
      "value": 10000,
      "category": "PAYMENT",
      "description": "Số dư ví tối thiểu để khởi tạo phiên sạc (VNĐ)",
      "updated_by": "finance@thaco.vn",
      "updated_at": "2026-09-15T08:30:00Z"
    }
  ]
  ```

---

#### 3.3.2. Bật/Tắt Kill-Switch Khẩn cấp Tính năng AutoCharge
- **Endpoint:** `PUT /api/csms/settings`
- **Xác thực:** `Authorization: Bearer <STAFF_JWT_TOKEN>`
- **Phân quyền bắt buộc:** Chỉ dành riêng cho `SUPER_ADMIN` và `TENANT_ADMIN`.
- **Request Body (JSON):**
  ```json
  {
    "autocharge_whitelist_enabled": false
  }
  ```
- **Phản hồi thành công (HTTP 200 OK):**
  ```json
  {
    "status": "OK"
  }
  ```

---

## 4. TÍCH HỢP TẦNG GIAO THỨC OCPP 1.6J

### 4.1. Bản tin DataTransfer nhận diện xe (Trạm -> CSMS)
Khi cắm cáp CCS2 và hoàn tất bắt tay PLC DIN 70121, trạm sạc gửi:
```json
[
  2,
  "msg-ev-identity-01",
  "DataTransfer",
  {
    "vendorId": "THACO_EVSE",
    "messageId": "VehicleIdentity",
    "data": "{"connectorId":1,"evccId":"38:2C:4A:A1:B2:C3","vin":"VF84910294829"}"
  }
]
```
CSMS Gateway xử lý:
```sql
UPDATE connectors
SET detected_evcc_id = '382C4AA1B2C3',
    detected_vin = 'VF84910294829',
    detected_at = now()
WHERE charge_point_id = <station_id> AND connector_id = 1;
```

### 4.2. Bản tin Authorize định danh tự động (Trạm -> CSMS)
Trạm gửi bản tin Authorize với mã `idTag` mang tiền tố nhận diện AutoCharge hoặc chính mã MAC:
```json
[
  2,
  "msg-auth-autoc-01",
  "Authorize",
  {
    "idTag": "AUTOC_382C4AA1B2C3"
  }
]
```
CSMS Gateway phản hồi hợp lệ:
```json
[
  3,
  "msg-auth-autoc-01",
  {
    "idTagInfo": {
      "status": "Accepted",
      "expiryDate": "2027-09-18T13:00:00.000Z",
      "parentIdTag": "USER_THACO_VIP"
    }
  }
]
```

### 4.3. Bản tin StartTransaction lưu vết phiên sạc AutoCharge
```json
[
  2,
  "msg-start-tx-01",
  "StartTransaction",
  {
    "connectorId": 1,
    "idTag": "AUTOC_382C4AA1B2C3",
    "meterStart": 125400,
    "timestamp": "2026-09-18T13:20:00.000Z"
  }
]
```
Bản ghi trong bảng `transactions` được điền tự động:
- `auth_method`: `'AUTO_CHARGE'`
- `evcc_id`: `'382C4AA1B2C3'`
- `vehicle_id`: `'e7b1a2c4-8901-4f12-9c34-abcdef123456'`
- `app_user_id`: ID của chủ sở hữu xe

---

## 5. CƠ SỞ DỮ LIỆU, RÀNG BUỘC BẢO MẬT & BẢNG MÃ LỖI

### 5.1. Cấu trúc Bảng Cơ sở Dữ liệu (PostgreSQL 16)
```sql
-- 1. Bảng app_vehicles lưu trữ Whitelist xe
ALTER TABLE app_vehicles
  ADD COLUMN IF NOT EXISTS evcc_id text,
  ADD COLUMN IF NOT EXISTS auto_charge_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS auto_charge_enrolled_at timestamp with time zone;

-- Index độc bản: 1 MAC chỉ thuộc về 1 xe duy nhất trong 1 Tenant
CREATE UNIQUE INDEX IF NOT EXISTS app_vehicles_evcc_unique 
  ON app_vehicles(tenant_id, upper(replace(replace(evcc_id, ':', ''), '-', '')))
  WHERE evcc_id IS NOT NULL AND status = 'ACTIVE';

-- 2. Bảng connectors lưu vết xe cắm tức thời tại đầu súng
ALTER TABLE connectors
  ADD COLUMN IF NOT EXISTS detected_evcc_id text,
  ADD COLUMN IF NOT EXISTS detected_vin text,
  ADD COLUMN IF NOT EXISTS detected_at timestamp with time zone;
```

### 5.2. Các Ràng buộc An ninh Bắt buộc (Security Guarantees)
1. **Tenant Isolation (Cô lập Đa khách thuê):** Mã MAC giữa các Tenant khác nhau có thể trùng (nếu cấu hình), nhưng trong cùng 1 Tenant TUYỆT ĐỐI không thể có 2 xe sở hữu cùng 1 mã MAC đang hoạt động.
2. **Ngăn chặn IDOR (Insecure Direct Object Reference):** Mọi thao tác từ phía người dùng di động đều ép buộc điều kiện `app_user_id = c.ID` và `tenant_id = c.TenantID`. Người dùng A không thể kích hoạt AutoCharge cho xe của người dùng B.
3. **Audit Trails (Nhật ký kiểm toán):** Mọi hành động kích hoạt/hủy kích hoạt bởi quản trị viên đều được ghi log bất biến vào `audit_logs` để phục vụ tra cứu tranh chấp tài chính.

### 5.3. Bảng Mã Lỗi Phản Hồi Chuẩn (Standard Error Codes)

| HTTP Status | Error Code | Ý nghĩa / Nguyên nhân | Biện pháp Khắc phục |
| :--- | :--- | :--- | :--- |
| **400** | `INVALID_EVCC_ID` | Địa chỉ MAC / EVCCID không hợp lệ (độ dài ngoài khoảng 6 - 32 ký tự). | Kiểm tra lại chuỗi MAC hoặc cắm súng để trạm đọc tự động. |
| **401** | `UNAUTHORIZED` | Token xác thực JWT hết hạn hoặc không hợp lệ. | Đăng nhập lại trên App / Dashboard để lấy Token mới. |
| **403** | `FORBIDDEN` | Người dùng không đủ quyền RBAC (yêu cầu quyền quản lý trạm). | Liên hệ Quản trị viên cấp quyền `OPERATOR` trở lên. |
| **404** | `NOT_FOUND` | Không tìm thấy xe hoặc xe không thuộc quyền sở hữu của người dùng. | Kiểm tra lại tham số `vehicleId`. |
| **409** | `EVCC_ALREADY_BOUND` | Địa chỉ MAC này đã được đăng ký và kích hoạt cho một xe khác trong hệ thống. | Hủy kích hoạt ở xe cũ trước hoặc liên hệ tổng đài để gỡ Whitelist. |
| **500** | `INTERNAL_ERROR` | Lỗi cơ sở dữ liệu hoặc xung đột giao dịch. | Hệ thống tự động rollback, thử lại sau ít giây. |

---

## 6. BỘ VÍ DỤ GỌI API THỰC TẾ (CURL & REQUEST/RESPONSE PAYLOAD)

### Ví dụ 1: Mobile App lấy mã MAC xe vừa cắm tại súng 1 của trạm T001
```bash
curl -X GET "https://csms.thaco.vn/api/mobile/me/detected-evcc?chargePointId=T001&connectorId=1" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIs..."
```
**Response (HTTP 200 OK):**
```json
{
  "detected": true,
  "evccId": "382C4AA1B2C3",
  "vin": "VF84910294829",
  "detectedAt": "2026-09-18T13:25:10Z"
}
```

---

### Ví dụ 2: Mobile App kích hoạt AutoCharge cho xe
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/me/vehicles/e7b1a2c4-8901-4f12-9c34-abcdef123456/autocharge" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIs..." \
  -H "Content-Type: application/json" \
  -d '{
    "evccId": "38:2C:4A:A1:B2:C3",
    "enabled": true
  }'
```
**Response (HTTP 200 OK):**
```json
{
  "id": "e7b1a2c4-8901-4f12-9c34-abcdef123456",
  "evccId": "382C4AA1B2C3",
  "autoChargeEnabled": true
}
```

---

### Ví dụ 3: Xung đột mã MAC đã được đăng ký cho xe khác (HTTP 409)
```bash
curl -X POST "https://csms.thaco.vn/api/mobile/me/vehicles/a1111111-2222-3333-4444-555555555555/autocharge" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIs..." \
  -H "Content-Type: application/json" \
  -d '{
    "evccId": "382C4AA1B2C3",
    "enabled": true
  }'
```
**Response (HTTP 409 Conflict):**
```json
{
  "error": {
    "code": "EVCC_ALREADY_BOUND",
    "message": "Địa chỉ MAC / EVCC này đã được đăng ký cho một xe khác"
  }
}
```

---

### Ví dụ 4: SuperAdmin kích hoạt Kill-Switch tắt tính năng AutoCharge toàn quốc
```bash
curl -X PUT "https://csms.thaco.vn/api/csms/settings" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIs..." \
  -H "Content-Type: application/json" \
  -d '{
    "autocharge_whitelist_enabled": false
  }'
```
**Response (HTTP 200 OK):**
```json
{
  "status": "OK"
}
```

---
*Tài liệu được biên soạn và chuẩn hóa bởi **Phòng thiết kế điện tử - Trung tâm R&D THACO INDUSTRIES** phục vụ triển khai nền tảng sạc xe điện thông minh toàn quốc.*

# ĐẶC TẢ CHI TIẾT GIAO THỨC TRUYỀN THÔNG OCPP 1.6J
## (OPEN CHARGE POINT PROTOCOL 1.6 JSON SPECIFICATION)
### Hệ thống: THACO EVSE DC Fast Charger & CSMS Cloud Platform

---

## MỤC LỤC
1. [Tổng quan Kiến trúc & Hạ tầng Mạng OCPP](#1-tổng-quan-kiến-trúc--hạ-tầng-mạng-ocpp)
2. [Cấu trúc Khung bản tin JSON-RPC 2.0](#2-cấu-trúc-khung-bản-tin-json-rpc-20)
3. [Danh mục Bản tin Chiều Trạm sạc gửi Máy chủ (Client -> CSMS)](#3-danh-mục-bản-tin-chiều-trạm-sạc-gửi-máy-chủ-client---csms)
   - 3.1. BootNotification
   - 3.2. Heartbeat
   - 3.3. StatusNotification
   - 3.4. Authorize
   - 3.5. StartTransaction
   - 3.6. MeterValues
   - 3.7. StopTransaction
   - 3.8. DataTransfer (Vehicle Identity)
   - 3.9. DiagnosticsStatusNotification
   - 3.10. FirmwareStatusNotification
4. [Danh mục Bản tin Chiều Máy chủ gửi Trạm sạc (CSMS -> Client)](#4-danh-mục-bản-tin-chiều-máy-chủ-gửi-trạm-sạc-csms---client)
   - 4.1. RemoteStartTransaction
   - 4.2. RemoteStopTransaction
   - 4.3. Reset
   - 4.4. UnlockConnector
   - 4.5. ChangeAvailability
   - 4.6. ChangeConfiguration
   - 4.7. GetConfiguration
   - 4.8. TriggerMessage
   - 4.9. ClearCache
   - 4.10. ReserveNow & CancelReservation
   - 4.11. SetChargingProfile, ClearChargingProfile & GetCompositeSchedule
   - 4.12. SendLocalList & GetLocalListVersion
   - 4.13. GetDiagnostics & UpdateFirmware
5. [Bảng Ma trận Tham số Cấu hình (Configuration Keys)](#5-bảng-ma-trận-tham-số-cấu-hình-configuration-keys)
6. [Phân tích Khoảng trống (Gap Analysis) - Dự án Còn Thiếu Những Gì?](#6-phân-tích-khoảng-trống-gap-analysis---dự-án-còn-thiếu-những-gì)
   - 6.1. Khoảng trống so với chuẩn OCA OCPP 1.6J Edition 2 đầy đủ
   - 6.2. So sánh và Lộ trình Nâng cấp lên OCPP 2.0.1
7. [Kịch bản & Hướng dẫn Kiểm thử Gói tin Thực tế](#7-kịch-bản--hướng-dẫn-kiểm-thử-gói-tin-thực-tế)

---

## 1. TỔNG QUAN KIẾN TRÚC & HẠ TẦNG MẠNG OCPP

Hệ sinh thái trạm sạc xe điện THACO EVSE triển khai giao thức chuẩn công nghiệp **OCPP 1.6 JSON (OCPP 1.6J)** theo kiến trúc Phân tán phần cứng và Hướng sự kiện (Event-Driven Cloud Architecture).

### 1.1. Luồng dữ liệu 3 tầng (End-to-End Data Path)

```mermaid
flowchart LR
    subgraph CP ["TRẠM SẠC HIỆN TRƯỜNG"]
        subgraph F4 ["STM32F429 (OCPP Master)"]
            MINI["MiniOCPP Engine
(Pure C / Static Memory)"]
            CONF["ConfigStore & LocalAuth"]
        end
        subgraph ESP ["ESP32-C6 (Gateway Bridge)"]
            TUNNEL["SPI DMA Tunnel
(10 MHz / CRC-8)"]
            WSS["WSS Client
(mbedTLS WebSocket)"]
        end
    end

    subgraph CLOUD ["HỆ THỐNG MÁY CHỦ CSMS (GO BACKEND)"]
        GW["ocpp-gateway
(Port WSS 9000)"]
        VAL["Validation Engine
(RFC3339 & OCA Schema)"]
        STREAM["Redis Streams
ocpp.inbound"]
        WORKER["Worker Service
(Billing, State, DB)"]
        PG[("PostgreSQL
TimescaleDB")]
    end

    MINI <-->|"SPI DMA Frame"| TUNNEL
    TUNNEL <--> WSS
    WSS <-->|"WSS Internet / 4G (Port 9000)"| GW
    GW --> VAL
    VAL --> STREAM
    STREAM --> WORKER
    WORKER --> PG
```

- **Tầng Firmware (STM32F429ZIT6)**: Chạy thư viện `MiniOCPP` thuần C không cấp phát động (`malloc`), quản lý phiên sạc, đồng hồ năng lượng Wh, mã thẻ RFID, đóng cắt relay công suất thông qua giao tiếp nội bộ với chip an toàn STM32H743.
- **Tầng Gateway (ESP32-C6 / ESP32-WROOM-32E)**: Đóng vai trò cầu nối truyền dẫn trong suốt (Transparent Socket Bridge). Đóng gói frame SPI DMA từ F429 và truyền lên Cloud qua giao thức an toàn WebSocket Secure (WSS).
- **Tầng Máy chủ (CSMS Go Backend)**:
  - Microservice `cmd/ocpp-gateway` lắng nghe tại cổng `9000`, tiếp nhận hàng chục nghìn kết nối đồng thời nhờ Goroutine Go siêu nhẹ.
  - Kiểm tra tính hợp lệ của schema qua `internal/ocpp/validation.go` và đẩy sự kiện vào Redis Streams `ocpp.inbound`.
  - Microservice `worker` tiêu thụ message, cập nhật trạng thái súng sạc, tính cước theo block thời gian và trừ tiền ví SePay.

### 1.2. Cơ chế Bảo mật Kết nối (Security Profiles)
Theo tài liệu *OCPP 1.6 Security Whitepaper (Edition 3)*:
- **Security Profile 1 (Unsecured)**: `ws://` không mã hóa (chỉ dùng trong mạng nội bộ test phòng LAB).
- **Security Profile 2 (TLS with HTTP Basic Auth - Đang áp dụng production)**:
  - Đường truyền mã hóa bằng TLS 1.2 / TLS 1.3 (cổng 9000).
  - Xác thực trạm sạc bằng HTTP Basic Authentication header:
    ```http
    GET /ocpp/1.6J/EVSE_BMT_01 HTTP/1.1
    Host: csms.thaco.com:9000
    Upgrade: websocket
    Connection: Upgrade
    Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
    Sec-WebSocket-Protocol: ocpp1.6
    Authorization: Basic RVZTRV9JTVRfMDE6VEhBQ09AQXV0aEtleTIwMjY=
    ```
    *(Username = `chargePointId`, Password = `auth_key` được cấu hình trong Flash/NVS của trạm).*
- **Security Profile 3 (TLS with Client-side Certificates - Mutual TLS)**: Xác thực 2 chiều bằng chứng chỉ số X.509 cài đặt trong phần cứng an toàn (Secure Element ATECC608A).

---

## 2. CẤU TRÚC KHUNG BẢN TIN JSON-RPC 2.0

Mọi bản tin trao đổi qua WebSocket đều được đóng gói dưới dạng mảng JSON (Array) với kích thước và cấu trúc quy chuẩn:

### 2.1. Gói tin Yêu cầu (CALL - Message Type 2)
Gửi đi từ một phía để yêu cầu phía bên kia thực hiện tác vụ:
```json
[2, "<UniqueId>", "<Action>", { <Payload> }]
```
- `2` (Number): Định danh kiểu tin CALL.
- `<UniqueId>` (String, tối đa 36 ký tự): Chuỗi định danh duy nhất (UUIDv4 hoặc Epoch millisecond) dùng để khớp bản tin phản hồi tương ứng.
- `<Action>` (String): Tên tác vụ OCPP (ví dụ: `BootNotification`, `StartTransaction`, `RemoteStopTransaction`).
- `<Payload>` (Object): Dữ liệu chi tiết của tác vụ.

### 2.2. Gói tin Phản hồi Thành công (CALLRESULT - Message Type 3)
Bên nhận gửi trả lại cho phía gửi yêu cầu khi tác vụ được chấp thuận hoặc hoàn thành:
```json
[3, "<UniqueId>", { <Payload> }]
```
- `3` (Number): Định danh kiểu tin CALLRESULT.
- `<UniqueId>`: Khớp chính xác với `<UniqueId>` của gói CALL trước đó.
- `<Payload>`: Dữ liệu phản hồi (chứa kết quả, trạng thái `Accepted`, `Rejected`, hoặc dữ liệu đo đếm).

### 2.3. Gói tin Báo lỗi Giao thức (CALLERROR - Message Type 4)
Gửi trả lại khi gói tin CALL gửi sai cấu trúc, sai kiểu dữ liệu hoặc không được hỗ trợ:
```json
[4, "<UniqueId>", "<ErrorCode>", "<ErrorDescription>", { <ErrorDetails> }]
```
- `4` (Number): Định danh kiểu tin CALLERROR.
- `<ErrorCode>`: Mã lỗi chuẩn OCPP 1.6 (xem bảng bên dưới).
- `<ErrorDescription>`: Mô tả chi tiết nguyên nhân lỗi (tối đa 255 ký tự).
- `<ErrorDetails>`: JSON Object mở rộng (nếu có, thường để `{}`).

#### Bảng Danh mục Mã lỗi Chuẩn OCPP (ErrorCode):
| Mã Lỗi (ErrorCode) | Ý Nghĩa / Tình Huống Kích Hoạt |
| :--- | :--- |
| `NotImplemented` | Tác vụ không được triển khai trên thiết bị hoặc hệ thống. |
| `NotSupported` | Tác vụ được nhận dạng nhưng không được thiết bị hỗ trợ ở chế độ hiện tại. |
| `InternalError` | Lỗi nội bộ không xác định (ví dụ: lỗi đọc Flash, lỗi bộ nhớ). |
| `ProtocolError` | Lỗi luồng giao tiếp (ví dụ: gửi `StopTransaction` khi chưa có `StartTransaction`). |
| `SecurityError` | Lỗi xác thực, sai mật khẩu AuthKey hoặc token bị thu hồi. |
| `FormationViolation` | Cú pháp JSON bị hỏng, thiếu ngoặc hoặc sai định dạng mảng. |
| `PropertyConstraintViolation` | Dữ liệu vượt quá giới hạn độ dài hoặc nằm ngoài dải giá trị cho phép. |
| `OccurrenceConstraintViolation` | Thiếu trường bắt buộc hoặc xuất hiện trường không mong muốn. |
| `TypeConstraintViolation` | Sai kiểu dữ liệu (ví dụ: gửi chuỗi string vào trường số integer). |

---

## 3. DANH MỤC BẢN TIN CHIỀU TRẠM SẠC GỬI MÁY CHỦ (CLIENT -> CSMS)

### 3.1. BootNotification
- **Thời điểm gửi**: Ngay sau khi vi điều khiển F429 khởi động thành công và ESP32 thiết lập kết nối WSS tới CSMS.
- **Mục đích**: Khai báo danh tính trạm, nhà sản xuất, model phần cứng, số serial và phiên bản firmware hiện hành.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-boot-001",
  "BootNotification",
  {
    "chargePointVendor": "THACO_EVSE",
    "chargePointModel": "EVSE_H743_DC180",
    "chargePointSerialNumber": "TH-2026-DC180-0089",
    "firmwareVersion": "v1.0.4-prod-20260918"
  }
]
```

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-boot-001",
  {
    "status": "Accepted",
    "currentTime": "2026-09-18T12:35:00.120Z",
    "interval": 60
  }
]
```
*(Ghi chú: `currentTime` được trạm dùng để đồng bộ RTC của STM32; `interval = 60` cấu hình chu kỳ gửi Heartbeat định kỳ 60 giây).*

---

### 3.2. Heartbeat
- **Thời điểm gửi**: Định kỳ theo chu kỳ `HeartbeatInterval` (mặc định 60 giây) khi trạm ở trạng thái rỗi hoặc không có giao dịch.
- **Mục đích**: Duy trì kết nối TCP/WebSocket (Keep-Alive) và đồng bộ đồng hồ trạm.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-hb-102938",
  "Heartbeat",
  {}
]
```

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-hb-102938",
  {
    "currentTime": "2026-09-18T12:36:00.005Z"
  }
]
```

---

### 3.3. StatusNotification
- **Thời điểm gửi**: Khi có bất kỳ thay đổi nào về trạng thái vật lý của súng sạc (cắm súng, rút súng, bắt đầu nạp điện, báo lỗi chạm đất, ngắt khẩn cấp E-Stop).
- **ConnectorId**: `0` (Toàn trạm), `1` (Súng sạc DC Súng 1), `2` (Súng sạc DC Súng 2).

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-stat-7812",
  "StatusNotification",
  {
    "connectorId": 1,
    "errorCode": "NoError",
    "status": "Preparing",
    "timestamp": "2026-09-18T12:36:15.890Z"
  }
]
```

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-stat-7812",
  {}
]
```

#### Ma trận Trạng thái Connector (Status Enum):
- `Available`: Súng sạc rảnh, sẵn sàng đón xe.
- `Preparing`: Đã cắm súng vào xe (CP state B/C), đang chờ xác thực thẻ hoặc bấm sạc trên App.
- `Charging`: Rơ-le công suất DC đã đóng, dòng sạc đang chạy vào xe.
- `SuspendedEV`: Xe chủ động tạm ngưng dòng sạc (pin đầy hoặc BMS cân bằng cell).
- `SuspendedEVSE`: Trạm tạm ngưng cấp điện (quản lý phụ tải hoặc quá nhiệt tạm thời).
- `Finishing`: Phiên sạc hoàn tất, rơ-le đã ngắt, đang chờ người dùng rút súng khỏi xe.
- `Reserved`: Súng đang được đặt trước bởi một tài xế khác.
- `Unavailable`: Súng bị vô hiệu hóa cục bộ hoặc qua lệnh máy chủ.
- `Faulted`: Trạm gặp sự cố phần cứng hoặc an toàn điện.

---

### 3.4. Authorize
- **Thời điểm gửi**: Khi người dùng quẹt thẻ RFID (MIFARE 13.56MHz) lên đầu đọc thẻ của trạm.
- **Mục đích**: Hỏi CSMS xem mã thẻ `idTag` có hợp lệ, đủ số dư và được phép sạc không.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-auth-4412",
  "Authorize",
  {
    "idTag": "RFID-E4F290A1"
  }
]
```

**Gói tin CALLRESULT [3] (CSMS -> Trạm - Chấp thuận):**
```json
[
  3,
  "msg-auth-4412",
  {
    "idTagInfo": {
      "status": "Accepted",
      "expiryDate": "2027-12-31T23:59:59Z",
      "parentIdTag": "CORP-THACO-01"
    }
  }
]
```

**Trường hợp Thẻ Bị Từ chối (Bị khóa hoặc Hết hạn):**
```json
[
  3,
  "msg-auth-4412",
  {
    "idTagInfo": {
      "status": "Blocked"
    }
  }
]
```

---

### 3.5. StartTransaction
- **Thời điểm gửi**: Sau khi xác thực thành công, súng đã khóa ngàm an toàn, trạm kiểm tra cách điện (Insulation Test) thành công và sẵn sàng phát dòng sạc.
- **Mục đích**: Bắt đầu tính tiền cho phiên sạc.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-txstart-9921",
  "StartTransaction",
  {
    "connectorId": 1,
    "idTag": "RFID-E4F290A1",
    "meterStart": 145020,
    "timestamp": "2026-09-18T12:37:00.000Z"
  }
]
```
*(Ghi chú: `meterStart = 145020` biểu thị số công tơ điện ban đầu là 145.020 kWh).*

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-txstart-9921",
  {
    "transactionId": 84920,
    "idTagInfo": {
      "status": "Accepted"
    }
  }
]
```
*(Trạm lưu `transactionId = 84920` vào bộ nhớ để gắn vào tất cả các gói `MeterValues` và `StopTransaction`).*

---

### 3.6. MeterValues
- **Thời điểm gửi**: Định kỳ trong suốt quá trình sạc (mỗi 10 giây theo cấu hình `MeterValueSampleInterval`).
- **Mục đích**: Báo cáo các thông số đo đếm thực tế (SoC %, V, A, kW, kWh) để hiển thị lên App và tính cước theo thời gian thực.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-meter-5561",
  "MeterValues",
  {
    "connectorId": 1,
    "transactionId": 84920,
    "meterValue": [
      {
        "timestamp": "2026-09-18T12:40:00.000Z",
        "sampledValue": [
          {
            "value": "153400",
            "measurand": "Energy.Active.Import.Register",
            "unit": "Wh"
          },
          {
            "value": "402.50",
            "measurand": "Voltage",
            "unit": "V"
          },
          {
            "value": "148.60",
            "measurand": "Current.Import",
            "unit": "A"
          },
          {
            "value": "59811.50",
            "measurand": "Power.Active.Import",
            "unit": "W"
          },
          {
            "value": "68.5",
            "measurand": "SoC",
            "unit": "Percent"
          }
        ]
      }
    ]
  }
]
```

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-meter-5561",
  {}
]
```

---

### 3.7. StopTransaction
- **Thời điểm gửi**: Khi phiên sạc dừng lại (do người dùng quẹt thẻ dừng, bấm nút trên màn hình HMI, bấm dừng trên Mobile App, xe báo đầy 100% pin, hoặc sự cố E-Stop).
- **Mục đích**: Chốt số điện tiêu thụ, thời gian sạc để CSMS thực hiện quyết toán hóa đơn.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-txstop-8831",
  "StopTransaction",
  {
    "transactionId": 84920,
    "meterStop": 182450,
    "timestamp": "2026-09-18T13:15:30.000Z",
    "reason": "Local"
  }
]
```
*(Số điện tiêu thụ thực tế = `182450 - 145020 = 37430 Wh = 37.43 kWh`).*

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-txstop-8831",
  {
    "idTagInfo": {
      "status": "Accepted"
    }
  }
]
```

#### Các Lý do Dừng sạc (StopReason Enum):
`Local` (Người dùng bấm HMI / quẹt thẻ), `Remote` (CSMS ra lệnh dừng), `EVDisconnected` (Rút súng), `EmergencyStop` (Nút khẩn cấp), `PowerLoss` (Mất điện lưới), `Reboot` (Khởi động lại), `UnlockCommand` (Lệnh mở khóa ngàm).

---

### 3.8. DataTransfer (Vehicle Identity)
- **Thời điểm gửi**: Khi chip STM32H743 giao tiếp thành công với ECU xe qua CAN bus / SECC và đọc được các định danh số của xe.
- **Mục đích**: Chuyển tiếp định danh xe (VIN, EVCC-ID, EMAID) lên CSMS phục vụ quản lý đội xe doanh nghiệp hoặc nhận diện xe tự động.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-dt-1102",
  "DataTransfer",
  {
    "vendorId": "EVSE_H743",
    "messageId": "VehicleIdentity",
    "data": "{\"vin\":\"VF8A1928490128\",\"evccId\":\"02:00:00:FF:FE:12:34:56\",\"emaid\":\"VN-THA-C1234567-8\"}"
  }
]
```

**Gói tin CALLRESULT [3] (CSMS -> Trạm):**
```json
[
  3,
  "msg-dt-1102",
  {
    "status": "Accepted",
    "data": "Vehicle verified"
  }
]
```

---

### 3.9. DiagnosticsStatusNotification
- **Thời điểm gửi**: Khi trạm đang trong quá trình trích xuất và tải nhật ký lỗi hệ thống (Diagnostics Log) lên máy chủ qua HTTP/FTP.

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-diag-991",
  "DiagnosticsStatusNotification",
  {
    "status": "Uploading"
  }
]
```
*(Status bao gồm: `Idle`, `Uploaded`, `UploadFailed`, `Uploading`).*

---

### 3.10. FirmwareStatusNotification
- **Thời điểm gửi**: Báo cáo tiến độ của quá trình cập nhật phần mềm trạm sạc từ xa (OTA).

**Gói tin CALL [2] (Trạm -> CSMS):**
```json
[
  2,
  "msg-fw-772",
  "FirmwareStatusNotification",
  {
    "status": "Installing"
  }
]
```
*(Status bao gồm: `Downloaded`, `DownloadFailed`, `Downloading`, `Idle`, `InstallationFailed`, `Installing`, `Installed`).*

---

## 4. DANH MỤC BẢN TIN CHIỀU MÁY CHỦ GỬI TRẠM SẠC (CSMS -> CLIENT)

### 4.1. RemoteStartTransaction
- **Thời điểm gửi**: Khi tài xế quét mã QR trên trụ sạc và nhấn "Bắt đầu sạc" trên ứng dụng THACO Charge Mobile App.
- **Mục đích**: Ra lệnh cho trạm sạc kích hoạt súng sạc được chỉ định.

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-remstart-101",
  "RemoteStartTransaction",
  {
    "connectorId": 1,
    "idTag": "APP-USER-998822",
    "chargingProfile": {
      "chargingProfileId": 1,
      "stackLevel": 1,
      "chargingProfilePurpose": "TxProfile",
      "chargingProfileKind": "Relative",
      "chargingSchedule": {
        "chargingRateUnit": "A",
        "chargingSchedulePeriod": [
          {
            "startPeriod": 0,
            "limit": 150.0
          }
        ]
      }
    }
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-remstart-101",
  {
    "status": "Accepted"
  }
]
```
*(Nếu súng đang bị bận hoặc chưa cắm vào xe, trạm sẽ phản hồi `status: "Rejected"`).*

---

### 4.2. RemoteStopTransaction
- **Thời điểm gửi**: Khi tài xế bấm nút "Dừng sạc" trên Mobile App hoặc Quản trị viên CSMS ngắt sạc khẩn cấp từ trang Web Admin.

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-remstop-102",
  "RemoteStopTransaction",
  {
    "transactionId": 84920
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-remstop-102",
  {
    "status": "Accepted"
  }
]
```

---

### 4.3. Reset
- **Thời điểm gửi**: Quản trị viên muốn khởi động lại trạm sạc từ xa.
- **Phân loại**:
  - `Soft`: Khởi động lại phần mềm MiniOCPP và các FreeRTOS Task mà không ngắt relay công suất nếu xe đang sạc.
  - `Hard`: Kích hoạt Watchdog Timer / ngắt nguồn trạm để Reset toàn bộ vi điều khiển (STM32F4, STM32H7, ESP32).

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-reset-103",
  "Reset",
  {
    "type": "Soft"
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-reset-103",
  {
    "status": "Accepted"
  }
]
```

---

### 4.4. UnlockConnector
- **Thời điểm gửi**: Khắc phục sự cố súng sạc bị kẹt chốt cơ khí trên cổng sạc của xe sau khi phiên sạc đã kết thúc.

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-unlock-104",
  "UnlockConnector",
  {
    "connectorId": 1
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-unlock-104",
  {
    "status": "Unlocked"
  }
]
```
*(Nếu cơ cấu mô tơ chốt súng bị kẹt cơ học, trạm sẽ phản hồi `status: "UnlockFailed"`).*

---

### 4.5. ChangeAvailability
- **Thời điểm gửi**: Khóa hoặc mở súng sạc phục vụ công tác bảo trì kỹ thuật.
- **Type**: `Inoperative` (Ngừng phục vụ), `Operative` (Mở lại bình thường).

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-avail-105",
  "ChangeAvailability",
  {
    "connectorId": 1,
    "type": "Inoperative"
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-avail-105",
  {
    "status": "Accepted"
  }
]
```
*(Nếu xe đang sạc dở, trạm phản hồi `status: "Scheduled"` để chuyển sang Inoperative ngay sau khi phiên sạc kết thúc).*

---

### 4.6. ChangeConfiguration
- **Thời điểm gửi**: Cấu hình lại các thông số hoạt động của trạm từ Cloud (chu kỳ đo, thời gian timeout, v.v.).

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-cfg-106",
  "ChangeConfiguration",
  {
    "key": "MeterValueSampleInterval",
    "value": "15"
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-cfg-106",
  {
    "status": "Accepted"
  }
]
```
*(Các trạng thái phản hồi khác: `Rejected` nếu sai giá trị, `RebootRequired` nếu cần khởi động lại mới có tác dụng, `NotSupported` nếu key không tồn tại).*

---

### 4.7. GetConfiguration
- **Thời điểm gửi**: CSMS đọc giá trị hiện hành của một hoặc toàn bộ tham số trạm sạc.

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-getcfg-107",
  "GetConfiguration",
  {
    "key": [
      "HeartbeatInterval",
      "MeterValueSampleInterval",
      "NumberOfConnectors"
    ]
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-getcfg-107",
  {
    "configurationKey": [
      {
        "key": "HeartbeatInterval",
        "readonly": false,
        "value": "60"
      },
      {
        "key": "MeterValueSampleInterval",
        "readonly": false,
        "value": "15"
      },
      {
        "key": "NumberOfConnectors",
        "readonly": true,
        "value": "2"
      }
    ],
    "unknownKey": []
  }
]
```

---

### 4.8. TriggerMessage
- **Thời điểm gửi**: CSMS muốn trạm sạc gửi ngay lập tức một bản tin mà không cần chờ tới chu kỳ định kỳ (phục vụ đồng bộ trạng thái khi kết nối lại).
- **Các bản tin có thể kích hoạt**: `BootNotification`, `Heartbeat`, `StatusNotification`, `MeterValues`, `DiagnosticsStatusNotification`, `FirmwareStatusNotification`.

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-trig-108",
  "TriggerMessage",
  {
    "requestedMessage": "StatusNotification",
    "connectorId": 1
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-trig-108",
  {
    "status": "Accepted"
  }
]
```

---

### 4.9. ClearCache
- **Thời điểm gửi**: Xóa toàn bộ bộ nhớ đệm xác thực RFID tạm thời trên trạm sạc.

**Gói tin CALL [2] (CSMS -> Trạm):**
```json
[
  2,
  "cmd-cc-109",
  "ClearCache",
  {}
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-cc-109",
  {
    "status": "Accepted"
  }
]
```

---

### 4.10. ReserveNow & CancelReservation
- **Mục đích**: Cho phép tài xế giữ chỗ súng sạc trước qua Mobile App khi đang trên đường tới trạm sạc.

**Gói tin CALL [2] (CSMS -> Trạm - ReserveNow):**
```json
[
  2,
  "cmd-res-110",
  "ReserveNow",
  {
    "connectorId": 1,
    "expiryDate": "2026-09-18T13:30:00Z",
    "idTag": "APP-USER-998822",
    "reservationId": 1042
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-res-110",
  {
    "status": "Accepted"
  }
]
```
*(Nếu súng đã có xe khác đang cắm, trạm phản hồi `status: "Occupied"`).*

**Gói tin CALL [2] (CSMS -> Trạm - CancelReservation):**
```json
[
  2,
  "cmd-canres-111",
  "CancelReservation",
  {
    "reservationId": 1042
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-canres-111",
  {
    "status": "Accepted"
  }
]
```

---

### 4.11. SetChargingProfile, ClearChargingProfile & GetCompositeSchedule
- **Mục đích (Smart Charging Profile)**: CSMS giới hạn công suất phát của trạm theo khung giờ cao điểm / thấp điểm hoặc điều phối cân bằng tải theo lưới điện.

**Gói tin CALL [2] (CSMS -> Trạm - SetChargingProfile):**
```json
[
  2,
  "cmd-prof-112",
  "SetChargingProfile",
  {
    "connectorId": 1,
    "csChargingProfiles": {
      "chargingProfileId": 12,
      "stackLevel": 1,
      "chargingProfilePurpose": "TxDefaultProfile",
      "chargingProfileKind": "Absolute",
      "chargingSchedule": {
        "duration": 3600,
        "chargingRateUnit": "A",
        "chargingSchedulePeriod": [
          {
            "startPeriod": 0,
            "limit": 100.0,
            "numberPhases": 3
          },
          {
            "startPeriod": 1800,
            "limit": 60.0,
            "numberPhases": 3
          }
        ]
      }
    }
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-prof-112",
  {
    "status": "Accepted"
  }
]
```

**Gói tin CALL [2] (CSMS -> Trạm - GetCompositeSchedule):**
```json
[
  2,
  "cmd-compsch-113",
  "GetCompositeSchedule",
  {
    "connectorId": 1,
    "duration": 1800,
    "chargingRateUnit": "A"
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-compsch-113",
  {
    "status": "Accepted",
    "connectorId": 1,
    "scheduleStart": "2026-09-18T12:45:00Z",
    "chargingSchedule": {
      "duration": 1800,
      "chargingRateUnit": "A",
      "chargingSchedulePeriod": [
        {
          "startPeriod": 0,
          "limit": 100.0
        }
      ]
    }
  }
]
```

---

### 4.12. SendLocalList & GetLocalListVersion
- **Mục đích**: Đồng bộ danh sách thẻ offline (Whitelist) xuống bộ nhớ Flash của trạm sạc, phục vụ sạc khẩn cấp khi mất mạng.

**Gói tin CALL [2] (CSMS -> Trạm - SendLocalList):**
```json
[
  2,
  "cmd-locallist-114",
  "SendLocalList",
  {
    "listVersion": 2,
    "updateType": "Full",
    "localAuthorizationList": [
      {
        "idTag": "RFID-E4F290A1",
        "idTagInfo": {
          "status": "Accepted"
        }
      },
      {
        "idTag": "RFID-VIP-000001",
        "idTagInfo": {
          "status": "Accepted"
        }
      },
      {
        "idTag": "RFID-BAD-999999",
        "idTagInfo": {
          "status": "Blocked"
        }
      }
    ]
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-locallist-114",
  {
    "status": "Accepted"
  }
]
```

---

### 4.13. GetDiagnostics & UpdateFirmware
- **Mục đích**: CSMS kích hoạt quá trình thu thập log file hoặc cập nhật OTA từ xa.

**Gói tin CALL [2] (CSMS -> Trạm - UpdateFirmware):**
```json
[
  2,
  "cmd-fw-115",
  "UpdateFirmware",
  {
    "location": "https://ota.thaco.com/firmware/evse_v1.0.5_signed.bin",
    "retrieveDate": "2026-09-18T02:00:00Z",
    "retries": 3,
    "retryInterval": 60
  }
]
```

**Gói tin CALLRESULT [3] (Trạm -> CSMS):**
```json
[
  3,
  "cmd-fw-115",
  {}
]
```

---

## 5. BẢNG MA TRẬN THAM SỐ CẤU HÌNH (CONFIGURATION KEYS)

Bảng tổng hợp các tham số được quản lý trong mô-đun `miniocpp_config_store.c` của trạm sạc:

| Tên Tham Số (Key) | Kiểu Dữ Liệu | Mặc Định | Thuộc Tính | Ý Nghĩa Kỹ Thuật |
| :--- | :---: | :---: | :---: | :--- |
| `HeartbeatInterval` | Integer | `60` | RW | Chu kỳ (giây) gửi bản tin nhịp tim sống Heartbeat. |
| `ConnectionTimeOut` | Integer | `30` | RW | Thời gian (giây) chờ cắm súng vào xe sau khi quẹt thẻ. |
| `MeterValueSampleInterval` | Integer | `10` | RW | Chu kỳ (giây) trích mẫu đo đếm gửi MeterValues. |
| `ClockAlignedDataInterval` | Integer | `0` | RW | Chu kỳ căn chỉnh đồng hồ năng lượng (0 = vô hiệu hóa). |
| `NumberOfConnectors` | Integer | `2` | R | Số lượng súng sạc vật lý trang bị trên trụ sạc. |
| `AuthorizeRemoteTxRequests`| Boolean | `true`| RW | Bắt buộc xác thực lại idTag khi nhận RemoteStart. |
| `LocalPreAuthorize` | Boolean | `false`| RW | Cho phép cắm súng và thử cách điện trước khi quẹt thẻ. |
| `LocalAuthorizeOffline` | Boolean | `true` | RW | Cho phép quẹt thẻ sạc bằng danh bạ cục bộ khi mất mạng. |
| `MeterValuesSampledData` | String | `Energy.Active.Import.Register,Voltage,Current.Import,Power.Active.Import,SoC` | RW | Danh sách đại lượng đo đếm đóng gói vào MeterValues. |
| `StopTransactionOnEVSideDisconnect` | Boolean | `true` | RW | Tự động kết thúc phiên sạc khi phía xe rút súng. |
| `StopTransactionOnInvalidId` | Boolean | `true` | RW | Ngắt sạc ngay nếu thẻ RFID bị báo mất/khóa giữa chừng. |
| `UnlockConnectorOnEVSideDisconnect` | Boolean | `true` | RW | Tự nhả chốt ngàm súng khi xe ngắt tiếp điểm CP/PP. |
| `GetConfigurationMaxKeys`| Integer | `32` | R | Số lượng key tối đa CSMS có thể truy vấn trong 1 lệnh. |
| `ResetRetries` | Integer | `3` | RW | Số lần thử khởi động lại nếu trạm gặp lỗi nghiêm trọng. |
| `WebSocketPingInterval` | Integer | `30` | RW | Chu kỳ ping mức WebSocket frame (giây). |
| `SupportedFeatureProfiles`| String | `Core,FirmwareManagement,LocalAuthListManagement,Reservation,SmartCharging,RemoteTrigger` | R | Danh mục 6 Feature Profiles OCA mà trạm đã hỗ trợ. |
| `LocalAuthListEnabled` | Boolean | `true` | RW | Bật/tắt tính năng xác thực danh bạ nội bộ trạm. |
| `LocalAuthListMaxLength`| Integer | `20` | R | Số lượng thẻ tối đa lưu trữ trong bộ nhớ Flash F429. |
| `SendLocalListMaxLength`| Integer | `20` | R | Số thẻ tối đa gửi trong 1 gói tin `SendLocalList`. |
| `ReserveConnectorZeroSupported` | Boolean | `false` | R | Không cho phép đặt trước connector 0 (toàn trạm). |
| `ChargeProfileMaxStackLevel` | Integer | `5` | R | Số lớp chồng profile công suất tối đa cho Smart Charging. |
| `ChargingScheduleAllowedChargingRateUnit` | String | `Current` | R | Đơn vị điều khiển dòng sạc (`Current` - Ampe). |
| `ChargingScheduleMaxPeriods` | Integer | `6` | R | Số bước khoảng thời gian tối đa trong 1 lịch biểu sạc. |
| `MaxChargingProfilesInstalled` | Integer | `5` | R | Số lượng Charging Profile tối đa có thể nạp vào RAM. |

---

## 6. PHÂN TÍCH KHOẢNG TRỐNG (GAP ANALYSIS) - DỰ ÁN CÒN THIẾU NHỮNG GÌ?

Mặc dù dự án đã hỗ trợ trọn vẹn cả 6 Feature Profiles chuẩn của OCPP 1.6J trên cả phần cứng STM32F429 và máy chủ CSMS Go Backend, để đưa hệ thống vào vận hành thương mại quy mô lớn (Hàng chục nghìn cổng sạc toàn quốc), hệ thống còn một số khoảng trống kỹ thuật cần tiếp tục hoàn thiện:

### 6.1. Khoảng trống so với Tiêu chuẩn OCA OCPP 1.6J Edition 2 đầy đủ

```mermaid
graph TD
    subgraph CURRENT ["HIỆN TRẠNG ĐÃ HOÀN THÀNH"]
        C1["Core Profile 100%"]
        C2["Remote Trigger 100%"]
        C3["Basic Smart Charging (5 profiles)"]
        C4["Basic Local Auth (20 thẻ Flash)"]
        C5["Security Profile 2 (WSS + Basic Auth)"]
    end

    subgraph GAPS ["KHOẢNG TRỐNG CẦN HOÀN THIỆN (GAPS)"]
        G1["External Flash Paging cho Local Auth (Hàng ngàn thẻ)"]
        G2["Dynamic Load Management (DLM) theo công tơ tổng"]
        G3["Upload Diagnostics Log qua S3 Multipart Presigned URL"]
        G4["Security Profile 3: mTLS với Chip ATECC608A / TPM"]
        G5["ClearChargingProfile với bộ lọc đa tiêu chí sâu"]
    end

    CURRENT -.-> GAPS
```

1. **Giới hạn Dung lượng Danh bạ Cục bộ (Local Auth List Capacity)**:
   - *Hiện trạng*: Danh bạ offline hiện đang lưu trong bộ nhớ Flash nội của STM32F429 với dung lượng tối đa 20 thẻ (`LocalAuthListMaxLength = 20`).
   - *Còn thiếu*: Cần nâng cấp cơ chế lưu trữ phân trang (Paging) trên External SPI Flash (W25Q64 - 8MB) hoặc thẻ nhớ MicroSD để lưu trữ từ 5,000 đến 10,000 thẻ RFID của các đội xe hợp đồng (Fleet), cho phép vận hành offline dài ngày khi đứt cáp quang.
2. **Quản lý Cân bằng tải Động (Dynamic Load Management - DLM)**:
   - *Hiện trạng*: Smart Charging Profile mới hỗ trợ đặt dòng cố định theo khung giờ định sẵn (`TxDefaultProfile` / `ChargePointMaxProfile`).
   - *Còn thiếu*: Chưa tích hợp thuật toán điều tiết công suất động thời gian thực theo đồng hồ đo tổng của trạm biến áp trạm sạc (thông qua Modbus TCP Meter) để chia tải linh hoạt giữa các súng sạc khi điện áp lưới bị sụt giảm.
3. **Cơ chế Truyền nhận File Nhật ký & Firmware (Diagnostics / OTA Artifacts)**:
   - *Hiện trạng*: Lệnh `GetDiagnostics` và `UpdateFirmware` trên F429 mới xử lý trạng thái máy trạng thái (State Machine mock/trigger sang ESP32).
   - *Còn thiếu*: Module ESP32 cần hoàn thiện tiến trình client HTTPS Multipart Form-Data tải file log nén `tar.gz` trực tiếp lên S3 Presigned URL, có cơ chế Resume khi rớt mạng và đối soát mã băm SHA-256 trước khi giải nén Flash.
4. **Bảo mật Phần cứng Cấp cao (Security Profile 3 - mTLS)**:
   - *Hiện trạng*: Trạm đang vận hành ổn định trên Security Profile 2 (Mã hóa đường truyền TLS + HTTP Basic Auth qua Username/Password).
   - *Còn thiếu*: Chưa kích hoạt Security Profile 3 (Xác thực 2 chiều mTLS với Client Certificate). Để đạt chứng nhận OCA Security Level 3, trạm cần tích hợp phần cứng Secure Element (như Microchip ATECC608A hoặc STM32 TrustZone) để lưu khóa riêng tư (Private Key) chống trích xuất vật lý.

---

### 6.2. So sánh và Lộ trình Nâng cấp lên OCPP 2.0.1

Để đón đầu xu hướng xe điện thế hệ mới (VinFast, Hyundai, Porsche, Mercedes) với các tiêu chuẩn sạc siêu nhanh 800V và sạc tự động thông minh, dự án cần hướng tới lộ trình OCPP 2.0.1:

| Tiêu Chí So Sánh | Dự Án Hiện Tại (OCPP 1.6J) | Mục Tiêu Tương Lai (OCPP 2.0.1) | Ý Nghĩa Chuyển Đổi |
| :--- | :--- | :--- | :--- |
| **Nhận diện Tự động (Plug & Charge)** | Nhận diện qua DataTransfer (VIN/EVCC) kết hợp thẻ RFID/App. | Tích hợp sâu chuẩn **ISO 15118-2 / ISO 15118-20**. Quản lý PKI X.509 Certificate tự động. | Cắm súng là sạc ngay và trừ tiền thẻ tín dụng tự động, không cần quẹt thẻ hay mở điện thoại. |
| **Mô hình Dữ liệu Thiết bị (Device Model)** | Cấu hình phẳng qua các chuỗi `ConfigurationKey`. | Mô hình phân cấp hướng đối tượng: `Component` $\rightarrow$ `Variable` $\rightarrow$ `Attribute`. | Quản lý và giám sát chi tiết tới từng module nguồn AcePower, cảm biến nhiệt độ, contactor. |
| **Bản tin Quản lý Giao dịch (Transactions)** | 3 bản tin riêng biệt: `StartTransaction`, `MeterValues`, `StopTransaction`. | Gom thành 1 bản tin duy nhất: **`TransactionEvent`** với các trigger `Started`, `Updated`, `Ended`. | Giảm thiểu độ trễ, tiết kiệm băng thông 4G và đảm bảo tính toàn vẹn dữ liệu kế toán. |
| **Cấp độ Bảo mật (Cybersecurity)** | Bổ sung qua Whitepaper (Security Profile 1/2/3). | **Bảo mật cốt lõi tích hợp sẵn**: TLS 1.3 bắt buộc, mã hóa lưu trữ, phân quyền Role-Based RBAC. | Đạt chuẩn an ninh mạng thanh toán và bảo vệ hạ tầng điện lưới quốc gia. |
| **Điều khiển Lưới điện 2 chiều (V2G - Vehicle to Grid)** | Chưa hỗ trợ. | Hỗ trợ xả điện từ xe ngược vào lưới điện (Bidirectional Power Transfer). | Giúp trạm sạc tham gia thị trường dịch vụ phụ trợ điện lưới (Demand Response). |

---

## 7. KỊCH BẢN & HƯỚNG DẪN KIỂM THỬ GÓI TIN THỰC TẾ

Quản trị viên và kỹ sư lập trình có thể kiểm thử toàn bộ các bản tin OCPP 1.6J trực tiếp với CSMS Gateway bằng công cụ dòng lệnh `websocat` hoặc `Postman WebSocket Client`.

### 7.1. Kết nối thử nghiệm qua WebSocat
Mở terminal và gõ lệnh kết nối WebSocket có kèm chứng thực Basic Auth:
```bash
websocat -H="Authorization: Basic RVZTRV9JTVRfMDE6VEhBQ09AQXV0aEtleTIwMjY=" \
         -H="Sec-WebSocket-Protocol: ocpp1.6" \
         wss://csms.thaco.com:9000/ocpp/1.6J/EVSE_TEST_001
```

### 7.2. Kịch bản 1: Khởi động Trạm (Boot & Heartbeat Flow)
1. **Trạm gửi BootNotification:**
   ```json
   [2, "test-001", "BootNotification", {"chargePointVendor":"THACO","chargePointModel":"H743","chargePointSerialNumber":"SN-001","firmwareVersion":"v1.0.4"}]
   ```
2. **CSMS phản hồi Accepted:**
   ```json
   [3, "test-001", {"status":"Accepted","currentTime":"2026-09-18T12:50:00.000Z","interval":60}]
   ```
3. **Trạm gửi báo trạng thái súng:**
   ```json
   [2, "test-002", "StatusNotification", {"connectorId":1,"errorCode":"NoError","status":"Available","timestamp":"2026-09-18T12:50:01.000Z"}]
   ```

### 7.3. Kịch bản 2: Phiên Sạc Hoàn Chỉnh từ App (Remote Start -> Charging -> Stop)
1. **CSMS gửi lệnh RemoteStartTransaction:**
   ```json
   [2, "cmd-991", "RemoteStartTransaction", {"connectorId":1,"idTag":"USER-THACO-888"}]
   ```
2. **Trạm phản hồi chấp nhận lệnh:**
   ```json
   [3, "cmd-991", {"status":"Accepted"}]
   ```
3. **Trạm báo súng chuyển sang trạng thái Preparing rồi bắt đầu sạc:**
   ```json
   [2, "test-003", "StatusNotification", {"connectorId":1,"errorCode":"NoError","status":"Preparing","timestamp":"2026-09-18T12:50:10.000Z"}]
   [2, "test-004", "StartTransaction", {"connectorId":1,"idTag":"USER-THACO-888","meterStart":1000,"timestamp":"2026-09-18T12:50:15.000Z"}]
   ```
4. **CSMS phản hồi tạo Transaction ID:**
   ```json
   [3, "test-004", {"transactionId":10092,"idTagInfo":{"status":"Accepted"}}]
   ```
5. **Trạm định kỳ gửi dữ liệu đo đếm (MeterValues):**
   ```json
   [2, "test-005", "MeterValues", {"connectorId":1,"transactionId":10092,"meterValue":[{"timestamp":"2026-09-18T12:50:30.000Z","sampledValue":[{"value":"1250","measurand":"Energy.Active.Import.Register","unit":"Wh"},{"value":"400.0","measurand":"Voltage","unit":"V"},{"value":"100.0","measurand":"Current.Import","unit":"A"},{"value":"40000.0","measurand":"Power.Active.Import","unit":"W"},{"value":"55.0","measurand":"SoC","unit":"Percent"}]}]}]
   ```
6. **CSMS gửi lệnh dừng sạc từ xa RemoteStopTransaction:**
   ```json
   [2, "cmd-992", "RemoteStopTransaction", {"transactionId":10092}]
   ```
7. **Trạm phản hồi chấp nhận và gửi StopTransaction chốt chỉ số điện:**
   ```json
   [3, "cmd-992", {"status":"Accepted"}]
   [2, "test-006", "StopTransaction", {"transactionId":10092,"meterStop":15000,"timestamp":"2026-09-18T13:00:00.000Z","reason":"Remote"}]
   [3, "test-006", {"idTagInfo":{"status":"Accepted"}}]
   ```
8. **Trạm báo súng trở lại trạng thái sẵn sàng (Available):**
   ```json
   [2, "test-007", "StatusNotification", {"connectorId":1,"errorCode":"NoError","status":"Available","timestamp":"2026-09-18T13:00:05.000Z"}]
   ```

---
*Tài liệu này được biên soạn độc quyền cho Hệ thống Quản trị & Vận hành Trạm Sạc Xe Điện THACO EVSE. Nghiêm cấm sao chép hoặc phân phối khi chưa có sự chấp thuận của Ban Công nghệ Thông tin & Tự động hóa THACO.*

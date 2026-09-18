# ĐẶC TẢ GIAO THỨC TRUYỀN THÔNG OCPP 1.6J
## (OPEN CHARGE POINT PROTOCOL 1.6 JSON SPECIFICATION)

Tài liệu này định nghĩa cấu trúc khung truyền, cơ chế kết nối WebSocket và chi tiết từng bản tin OCPP 1.6J giữa Trụ sạc (Charge Point) và Máy chủ (CSMS).

---

## 1. KHUNG TRUYỀN DỮ LIỆU JSON-RPC TRÊN WEBSOCKET

Mọi giao tiếp OCPP 1.6J đều sử dụng kết nối bảo mật **WSS (WebSocket Secure)** qua cổng `9000` theo định dạng mảng JSON gồm 3 loại gói tin cơ bản:

### 1.1. Gói tin Yêu cầu (CALL - Message Type 2):
```json
[2, "<MessageId>", "<Action>", { <Payload> }]
```
- `2`: Định danh gói tin CALL.
- `<MessageId>`: Chuỗi định danh ngẫu nhiên (UUID hoặc timestamp) để khớp với bản tin phản hồi.
- `<Action>`: Tên lệnh nghiệp vụ (ví dụ: `BootNotification`, `Heartbeat`, `RemoteStartTransaction`).

### 1.2. Gói tin Phản hồi Thành công (CALLRESULT - Message Type 3):
```json
[3, "<MessageId>", { <Payload> }]
```

### 1.3. Gói tin Phản hồi Báo lỗi (CALLERROR - Message Type 4):
```json
[4, "<MessageId>", "<ErrorCode>", "<ErrorDescription>", { <ErrorDetails> }]
```

---

## 2. DANH MỤC BẢN TIN OCPP 1.6J CORE PROFILE ĐÃ TRIỂN KHAI

### 2.1. Bản tin Khởi động & Nhịp tim sống (Boot & Heartbeat):
- **`BootNotification` (CP $ightarrow$ CSMS):** Gửi khi trụ vừa cấp điện. Báo cáo `chargePointVendor`, `chargePointModel`, `firmwareVersion`. Server phản hồi `status: "Accepted"` kèm `currentTime` để đồng bộ đồng hồ trạm và `interval` nhịp tim (ví dụ 60s).
- **`Heartbeat` (CP $ightarrow$ CSMS):** Định kỳ gửi để báo hiệu trạm vẫn online. Server phản hồi `currentTime`.

### 2.2. Bản tin Định danh & Phiên sạc (Authorize & Transactions):
- **`Authorize` (CP $ightarrow$ CSMS):** Gửi mã thẻ `idTag` (RFID). Server kiểm tra số dư và phản hồi `status: "Accepted"` hoặc `"Invalid" / "Blocked"`.
- **`StartTransaction` (CP $ightarrow$ CSMS):** Gửi khi bắt đầu có dòng điện sạc. Chứa `connectorId`, `idTag`, `meterStart` (chỉ số kWh ban đầu), `timestamp`. Server trả về `transactionId` duy nhất.
- **`StopTransaction` (CP $ightarrow$ CSMS):** Gửi khi phiên sạc kết thúc. Chứa `transactionId`, `meterStop` (chỉ số kWh kết thúc), `timestamp`, `reason` (`Local`, `Remote`, `EmergencyStop`, `EVDisconnected`). Server chốt cước.

### 2.3. Bản tin Đo đếm Dữ liệu Thời gian thực (MeterValues):
- **`MeterValues` (CP $ightarrow$ CSMS):** Định kỳ mỗi 10 - 30 giây gửi dữ liệu mẫu đo:
  * `Voltage`: Điện áp DC (V).
  * `Current.Import`: Dòng điện DC nạp vào xe (A).
  * `Power.Active.Import`: Công suất tức thời (kW).
  * `Energy.Active.Import.Register`: Tổng điện năng tiêu thụ tích lũy (Wh).
  * `SoC`: % Pin hiện tại của ô tô điện (0 - 100%).

### 2.4. Bản tin Điều khiển từ xa từ Máy chủ (Remote Control):
- **`RemoteStartTransaction` (CSMS $ightarrow$ CP):** Ra lệnh cho trụ sạc tự động kích hoạt phiên sạc cho một súng sạc cụ thể.
- **`RemoteStopTransaction` (CSMS $ightarrow$ CP):** Ra lệnh ngắt phiên sạc từ xa.
- **`Reset` (CSMS $ightarrow$ CP):** Khởi động lại trụ sạc (`Soft` hoặc `Hard`).
- **`UnlockConnector` (CSMS $ightarrow$ CP):** Mở chốt khóa cơ khí nhả súng sạc nếu súng bị kẹt trên xe.
- **`ChangeConfiguration` & `GetConfiguration`:** Đọc và thay đổi tham số cấu hình trạm sạc từ xa.

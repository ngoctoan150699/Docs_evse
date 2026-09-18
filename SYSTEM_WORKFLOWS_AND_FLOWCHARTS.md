# SƠ ĐỒ CHU TRÌNH NGHIỆP VỤ THỰC TẾ HỆ THỐNG THACO EVSE
## (SYSTEM WORKFLOWS & INTERACTION FLOWCHARTS)

Tài liệu này trực quan hóa toàn bộ các luồng nghiệp vụ quan trọng nhất của trạm sạc: từ lúc tài xế cắm súng, quét thẻ/quét app, cấp nguồn, thanh toán SePay cho đến xử lý ngắt khẩn cấp và nạp firmware từ xa.

---

## 1. QUY TRÌNH 1: SẠC XE BẰNG THẺ RFID TẠI TRỤ

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Tài xế (Driver)
    participant Gun as Súng sạc CCS2
    participant Car as Ô tô điện (EV)
    participant H7 as STM32H743 (Power)
    participant F4 as STM32F429 (OCPP)
    participant CSMS as CSMS Cloud Server
    participant Module as Module Nguồn AcePower

    Driver->>Gun: Cắm súng sạc vào cổng sạc xe
    Gun->>H7: Tín hiệu CP giảm từ 12V -> 9V (State B)
    H7->>F4: Báo trạng thái Preparing qua Modbus RTU
    F4->>CSMS: Gửi StatusNotification (Preparing)
    
    Driver->>Gun: Quẹt thẻ RFID lên đầu đọc trụ
    F4->>CSMS: Gửi bản tin Authorize (RFID Tag ID)
    CSMS-->>F4: Phản hồi Authorize.conf (Accepted)
    
    F4->>CSMS: Gửi bản tin StartTransaction (Connector 1)
    CSMS-->>F4: Phản hồi StartTransaction.conf (TransactionID = 1001)
    
    F4->>H7: Ghi Holding Register Modbus: Bật sạc (Target V/I)
    H7->>Car: Khóa chốt súng sạc (Connector Lock)
    H7->>H7: Đo kiểm tra cách điện (Insulation Test)
    H7->>Module: FDCAN1: Set Voltage & Current (Pre-charge)
    H7->>Module: FDCAN1: Power ON (Byte 7 = 0x00)
    H7->>H7: Đóng Contactor DC chính (Main DC Contactors ON)
    
    loop Chu kỳ sạc liên tục (Current Demand Loop)
        Car->>H7: Yêu cầu V/I và gửi % SoC (FDCAN2 SECC)
        H7->>Module: Điều chỉnh V/I tương ứng (FDCAN1)
        H7->>F4: Cập nhật chỉ số công tơ kWh qua Modbus
        F4->>CSMS: Gửi bản tin định kỳ MeterValues (V, I, kWh, SoC %)
    end

    alt Tài xế quẹt lại thẻ để dừng sạc
        Driver->>Gun: Quẹt lại thẻ RFID
        F4->>H7: Ghi Holding Register Modbus: Stop Charge
        H7->>Module: FDCAN1: Power OFF (Giảm dòng về 0A)
        H7->>H7: Mở Contactor DC chính
        H7->>Car: Mở khóa chốt súng sạc
        F4->>CSMS: Gửi bản tin StopTransaction (MeterStop, Reason)
        CSMS-->>F4: Phản hồi StopTransaction.conf (Trừ tiền thẻ)
    end
```

---

## 2. QUY TRÌNH 2: SẠC XE QUA ỨNG DỤNG DI ĐỘNG THACO_CHARGE

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Tài xế (Driver)
    participant App as App THACO_Charge
    participant CSMS as CSMS Cloud Server
    participant ESP as ESP32 Coprocessor
    participant F4 as STM32F429 (OCPP)
    participant H7 as STM32H743 (Power)

    Driver->>App: Mở App, quét mã QR dán trên súng sạc
    App->>CSMS: POST /api/station/remote-start (stationId, connectorId)
    CSMS->>CSMS: Kiểm tra số dư ví tài xế (Balance >= 50,000 VND)
    
    CSMS->>ESP: WebSocket: Gửi bản tin RemoteStartTransaction
    ESP->>F4: Chuyển tiếp gói tin qua SPI DMA @ 10 MHz
    F4-->>CSMS: Trả lời RemoteStartTransaction.conf (Accepted)
    
    F4->>H7: Lệnh kích hoạt chu trình sạc qua Modbus RTU
    H7->>H7: Khóa súng, kiểm tra cách ly, đóng contactor
    
    loop Theo dõi tiến độ sạc trực tiếp trên App
        H7->>F4: Cập nhật kWh, Điện áp, Dòng điện, % SoC qua Modbus
        F4->>CSMS: Bản tin OCPP MeterValues
        CSMS->>App: Đẩy dữ liệu Realtime qua WebSocket/SSE
        App-->>Driver: Hiển thị: 45% SoC, 120A, 420V, Tiền: 68.000đ
    end

    Driver->>App: Bấm nút [DỪNG SẠC] trên màn hình
    App->>CSMS: POST /api/station/remote-stop (transactionId)
    CSMS->>ESP: WebSocket: RemoteStopTransaction
    ESP->>F4: Chuyển tiếp qua SPI DMA
    F4->>H7: Lệnh ngắt công suất Modbus
    H7->>H7: Giảm dòng về 0A -> Mở contactor -> Mở khóa súng
    F4->>CSMS: StopTransaction (MeterStop, Reason = Remote)
    CSMS->>CSMS: Quyết toán trừ tiền ví, xuất hóa đơn điện tử
    CSMS-->>App: Thông báo hoàn tất sạc & chi tiết hóa đơn
```

---

## 3. QUY TRÌNG 3: NẠP TIỀN TỰ ĐỘNG QUA CỔNG THANH TOÁN SEPAY VIETQR

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Tài xế (Driver)
    participant App as App THACO_Charge
    participant CSMS as CSMS Go Backend
    participant Bank as App Ngân hàng (MB/VCB...)
    participant SePay as Cổng Thanh toán SePay

    Driver->>App: Chọn [Nạp tiền vào ví] (Số tiền: 200,000 VND)
    App->>CSMS: POST /api/payment/create-order (amount = 200000)
    CSMS->>CSMS: Sinh mã đơn hàng định danh: TC100284
    CSMS-->>App: Trả về mã VietQR (Số TK + Số tiền + Nội dung: "TC100284")
    
    Driver->>Bank: Quét mã VietQR trên App ngân hàng và bấm Chuyển tiền
    Bank->>SePay: Tiền vào tài khoản ngân hàng của trạm sạc
    
    Note over SePay: SePay phát hiện biến động số dư trong vòng 1-2 giây
    SePay->>CSMS: HTTP POST /api/payment/sepay-webhook (JSON payload)
    
    CSMS->>CSMS: Xác thực API Key Header & Chữ ký bảo mật
    CSMS->>CSMS: Bóc tách nội dung chuyển khoản tìm mã "TC100284"
    
    critical Cập nhật số dư nguyên tử trong SQL Transaction
        CSMS->>CSMS: Khóa dòng tài khoản người dùng (SELECT ... FOR UPDATE)
        CSMS->>CSMS: UPDATE cards SET balance = balance + 200000
        CSMS->>CSMS: UPDATE recharge_orders SET status = 'SUCCESS'
    end
    
    CSMS-->>SePay: HTTP 200 OK ({"success": true})
    CSMS->>App: Bắn thông báo Push / WebSocket: "Nạp thành công 200.000đ"
    App-->>Driver: Cập nhật số dư ví mới ngay lập tức
```

---

## 4. QUY TRÌNH 4: NGẮT AN TOÀN KHẨN CẤP (FAIL-SAFE & EMERGENCY STOP)

```mermaid
flowchart TD
    Trigger{"PHÁT HIỆN SỰ CỐ BẤT THƯỜNG"}
    
    E1["Nút dừng khẩn cấp E-Stop bị nhấn"] --> Trigger
    E2["Mất kết nối Modbus F429 <-> H743 > 3s"] --> Trigger
    E3["Lỗi rò điện cách ly cao áp (IMD Fault)"] --> Trigger
    E4["Tài xế bóp cò súng mở chốt Proximity (PP)"] --> Trigger
    E5["Module nguồn AcePower báo lỗi AC/DC/Quá nhiệt"] --> Trigger

    Trigger --> STEP1["BƯỚC 1 (STM32H743 xử lý phần cứng ngay lập tức)"]
    STEP1 --> A1["FDCAN1: Gửi lệnh AcePower_PowerOff() triệt tiêu điện áp"]
    STEP1 --> A2["Ngắt cuộn hút Contactor DC chính trong vòng < 20ms"]
    STEP1 --> A3["Kích hoạt rơ-le xả điện trở Bleeder để hạ áp đường bus"]

    A2 --> STEP2["BƯỚC 2 (Báo cáo và cô lập trạng thái)"]
    STEP2 --> B1["Bật còi báo động và đèn LED đỏ trên thân trụ"]
    STEP2 --> B2["Ghi Fault Bitmask vào thanh ghi Modbus Input Registers"]
    STEP2 --> B3["Màn hình HMI hiển thị: 'DỪNG KHẨN CẤP - LIÊN HỆ KỸ THUẬT'"]

    B2 --> STEP3["BƯỚC 3 (Đồng bộ lên đám mây CSMS)"]
    STEP3 --> C1["STM32F429 gửi StatusNotification: Faulted / EmergencyStop"]
    STEP3 --> C2["F429 gửi StopTransaction với Reason: EmergencyStop"]
    STEP3 --> C3["CSMS Cloud tạo cảnh báo Critical đẩy tới Telegram Kỹ thuật viên"]
```

---

## 5. QUY TRÌNH 5: NÂNG CẤP FIRMWARE TỪ XA LIVE DUAL-BANK OTA

```mermaid
sequenceDiagram
    autonumber
    actor Admin as Kỹ sư DevOps / Admin
    participant Cloud as CSMS Cloud / MQTT Broker
    participant ESP as ESP32 Coprocessor
    participant F4 as STM32F429 (Target MCU)
    participant Flash as Bộ nhớ Flash Dual-Bank

    Admin->>Cloud: Phát lệnh OTA: ota_mqtt.py --device EVSE_F429 --firmware F4.bin
    Cloud->>ESP: MQTT Topic: evse/ota/upload (JSON chunk 4KB)
    
    loop Phân đoạn sub-chunking qua bus SPI
        ESP->>ESP: Băm nhỏ chunk thành các sub-chunk <= 512 Byte
        ESP->>F4: SPI DMA: Gửi frame lệnh ghi dữ liệu (ESP_CMD_OTA_DATA)
        F4->>Flash: Ghi dữ liệu tuần tự vào Bank 2 (0x08100000)
        F4-->>ESP: Phản hồi SPI ACK (Status OK)
        ESP-->>Cloud: Phản hồi MQTT Progress (offset, total)
    end

    Cloud->>ESP: Lệnh kết thúc nạp (OTA Complete)
    ESP->>F4: SPI DMA: Gửi lệnh kiểm tra toàn vẹn (ESP_CMD_OTA_END)
    
    F4->>Flash: Bộ gia tốc phần cứng CRC32 quét toàn bộ Bank 2
    alt Mã CRC32 khớp 100% với Header
        F4->>Flash: Thiết lập bit SWAP_BANK trong Flash Option Bytes
        F4->>F4: Thực hiện Soft Reset hệ thống (< 500 ms)
        Note over F4,Flash: STM32F429 khởi động lại từ Bank 2 với Firmware mới
        F4->>ESP: Báo phiên bản mới qua SPI (ESP_CMD_GET_VERSION)
        ESP->>Cloud: Báo cáo OTA Thành công (FirmwareStatus: Installed)
    else Mã CRC32 không khớp (Gói tin bị lỗi trên đường truyền)
        F4->>F4: Hủy cờ Swap Bank, xóa dữ liệu hỏng trên Bank 2
        F4-->>ESP: Báo lỗi CRC Mismatch
        ESP->>Cloud: Báo cáo OTA Thất bại (FirmwareStatus: InstallationFailed)
    end
```

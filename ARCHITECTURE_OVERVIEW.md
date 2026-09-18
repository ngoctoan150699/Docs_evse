# KIẾN TRÚC TOÀN DIỆN HỆ SINH THÁI TRẠM SẠC THACO EVSE
## (MASTER END-TO-END SYSTEM ARCHITECTURE)

Tài liệu này mô tả chi tiết kiến trúc phân tầng, ranh giới phần cứng/phần mềm, các bus truyền thông và nguyên tắc thiết kế fail-safe của toàn bộ hệ sinh thái trạm sạc xe điện THACO EVSE.

---

## 1. MÔ HÌNH PHÂN TẦNG 5 LỚP (5-TIER ARCHITECTURE)

Hệ thống được thiết kế theo mô hình 5 tầng phân tán rõ ràng, tuân thủ nguyên tắc cách ly tuyệt đối giữa giao diện người dùng bên ngoài và tầng công suất cao thế nguy hiểm:

```text
+-------------------------------------------------------------------------------+
|               TẦNG 1: GIAO DIỆN NGƯỜI DÙNG & TÀI XẾ (USER LAYER)              |
|  - Ứng dụng di động THACO_Charge (iOS / Android Flutter)                      |
|  - Thẻ sạc vật lý RFID / NFC (Chuẩn Mifare Classic / Desfire)                |
+-------------------------------------------------------------------------------+
                                    │
                                    ▼ (HTTPS REST / WSS / Radio Frequency)
+-------------------------------------------------------------------------------+
|             TẦNG 2: MÁY CHỦ QUẢN TRỊ TRUNG TÂM CLOUD (CSMS TIER)              |
|  - Next.js Admin Dashboard (16 phân hệ quản lý, bản đồ, doanh thu, KPI)       |
|  - Go Microservices: ocpp-gateway (WebSocket), worker (Queue), api (REST)     |
|  - CSDL: PostgreSQL 16, TimescaleDB (MeterValues), Redis (PubSub/Streams)     |
|  - Cổng thanh toán SePay: Webhook IPN nhận biến động số dư VietQR             |
+-------------------------------------------------------------------------------+
                                    │
                                    ▼ (WebSocket OCPP 1.6J / MQTT Broker)
+-------------------------------------------------------------------------------+
|         TẦNG 3: TRẠM SẠC - GIAO TIẾP MẠNG & HMI (STATION FRONT TIER)         |
|  - ESP32-C6 Modem: Wi-Fi/Ethernet, Web Dashboard (10.14.80.19), Web/MQTT OTA  |
|  - Màn hình Android HMI (Flutter Kiosk): Hiển thị trạng thái, V, I, SoC, Tiền |
+-------------------------------------------------------------------------------+
                                    │
                                    ▼ (SPI 4-wire Full-Duplex DMA @ 10 MHz / Modbus)
+-------------------------------------------------------------------------------+
|      TẦNG 4: BỘ ĐIỀU KHIỂN GIAO THỨC TRUNG TÂM (CENTRAL CONTROLLER TIER)      |
|  - STM32F429ZIT6: MiniOCPP 1.6J Client thuần C, Modbus Master RS485           |
|  - Quản lý phiên sạc, đồng bộ công tơ điện, Live Dual-Bank Flash              |
+-------------------------------------------------------------------------------+
                                    │
                                    ▼ (RS485 Modbus RTU @ 115,200 bps)
+-------------------------------------------------------------------------------+
|     TẦNG 5: ĐIỀU KHIỂN CÔNG SUẤT CAO THẾ & AN TOÀN (POWER & SAFETY TIER)     |
|  - STM32H743XIT6: ChargerSession FSM, Quản lý chu trình sạc CCS2 (8 bước)    |
|  - FDCAN1 (125k): Điều khiển module nguồn AcePower AB-U2T (1000V/250A)        |
|  - FDCAN2 (500k): Bắt tay PLC với bộ điều khiển SECC CCS2 (ISO 15118)         |
|  - UART8 (9600): Đọc công tơ DC Eastron DCM230 đối soát doanh thu             |
|  - Phần cứng bảo vệ: Nút dừng khẩn E-Stop, Contactor DC ngắt < 20ms, IMD      |
+-------------------------------------------------------------------------------+
```

---

## 2. MA TRẬN CÁC BUS TRUYỀN THÔNG VẬT LÝ & GIAO THỨC LIÊN KẾT

| Liên kết | Lớp vật lý | Tốc độ | Giao thức | Mục đích truyền tin |
| :--- | :--- | :--- | :--- | :--- |
| **Driver App $\longleftrightarrow$ CSMS** | 4G / Wi-Fi Internet | Băng thông rộng | HTTPS REST, WSS | Quét mã QR, lệnh RemoteStart/Stop, xem vị trí trạm và số dư ví. |
| **SePay $\longleftrightarrow$ CSMS** | Internet Webhook | Tức thời (< 2s) | HTTP POST JSON (HMAC) | Thông báo biến động số dư tài khoản ngân hàng để nạp tiền vào ví. |
| **CSMS $\longleftrightarrow$ ESP32** | Wi-Fi / Ethernet | 100 Mbps | WebSocket WSS, MQTT | Kênh truyền bản tin OCPP 1.6J JSON-RPC và lệnh nâng cấp MQTT Fleet OTA. |
| **ESP32 $\longleftrightarrow$ STM32F429** | 4-wire SPI (SCK, MOSI, MISO, CS) | **10 MHz** | SPI Coprocessor Frame (DMA) | Truyền socket TCP/TLS, tải firmware OTA qua SPI (sub-chunking $\le 512\text{B}$). **Lưu ý: Không phải UART.** |
| **HMI $\longleftrightarrow$ STM32F429** | Cáp RS485 vi sai | 115,200 bps | Modbus RTU | Màn hình cảm ứng gửi lệnh Mailbox (Start/Stop) và đọc trạng thái súng sạc. |
| **STM32F429 $\longleftrightarrow$ STM32H743** | Cáp RS485 vi sai | 115,200 bps | Modbus RTU (Master-Slave) | F429 điều khiển sạc (Target V, Target I) và đọc telemetry V, I, kWh từ H743. |
| **STM32H743 $\longleftrightarrow$ AcePower** | Cáp xoắn chống nhiễu CAN | 125 kbps | AcePower 29-bit Extended CAN | Lệnh đóng ngắt nguồn cao thế, cài đặt điện áp/dòng điện và đọc lỗi module. |
| **STM32H743 $\longleftrightarrow$ SECC** | Cáp xoắn chống nhiễu CAN | 500 kbps | SECC CCU CAN | Bắt tay chu trình sạc CCS2, nhận diện xe, đọc % SoC và giới hạn công suất pin. |
| **STM32H743 $\longleftrightarrow$ DCM230** | Cáp RS485 2 dây | 9,600 bps | Modbus RTU | Đọc chỉ số công tơ điện một chiều DC (kWh, Volts, Amperes) cấp hóa đơn. |

---

## 3. NGUYÊN TẮC AN TOÀN FAIL-SAFE TUYỆT ĐỐI (POWER MUST MOVE TOWARD OFF)

Hệ thống trạm sạc nhanh DC làm việc với điện áp một chiều lên tới 1000V và dòng điện lên tới 250A. Do đó, toàn bộ kiến trúc được thiết kế xoay quanh nguyên tắc **Fail-Safe**:

1. **Mọi sự cố đều kéo công suất về OFF (Power Must Move Toward OFF):**
   - Khi xảy ra bất kỳ lỗi nào sau đây:
     * Mất kết nối WebSocket giữa trạm và CSMS Cloud quá thời gian timeout.
     * Mất nhịp tim Modbus RTU giữa F429 và H743 ($> 3\text{ giây}$).
     * Mất giao tiếp FDCAN với module nguồn AcePower hoặc bộ điều khiển SECC.
     * Nút dừng khẩn cấp (**E-Stop**) trên thân trụ bị nhấn.
     * Cảm biến đo điện trở cách ly (**IMD**) phát hiện rò điện cao thế ra vỏ trụ.
     * Tài xế bóp cò súng sạc mở chốt Proximity Pilot (PP).
   - $\longrightarrow$ **Hành động tức thì:** Vi điều khiển STM32H743 lập tức phát lệnh hủy điện áp module nguồn (`AcePower_PowerOff()`) và kích hoạt rơ-le ngắt contactor DC chính trong vòng **$< 20\text{ ms}$**.

2. **Không tự động đóng lại nguồn (No Automatic Retry):**
   - Sau khi hệ thống bị ngắt vì lỗi, tuyệt đối không được phép tự động cấp lại nguồn điện cao thế. Trụ sạc bắt buộc phải trở về trạng thái nghỉ (`State A/B`) và chỉ được phép khởi động lại khi có một phiên sạc mới được CSMS phê duyệt hợp lệ.

3. **Một chủ quản lý cho từng giao diện phần cứng (One Owner per Interface):**
   - FDCAN1 và FDCAN2 độc quyền do STM32H743 quản lý.
   - Giao thức MiniOCPP 1.6J độc quyền do STM32F429 quản lý.
   - Không có bất kỳ đường truyền chồng chéo nào có thể can thiệp trực tiếp vào phần cứng công suất mà không thông qua STM32H743.

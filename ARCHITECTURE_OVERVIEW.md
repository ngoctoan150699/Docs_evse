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
           │                                                    │
           │ (SPI 4-wire Full-Duplex DMA @ 10 MHz)              │ (RS485 Modbus RTU @ 115,200 bps)
           ▼                                                    │
+-------------------------------------------------------------------------------+
|      TẦNG 4: BỘ ĐIỀU KHIỂN GIAO THỨC TRUNG TÂM (CENTRAL CONTROLLER TIER)      |
|  - STM32F429ZIT6: MiniOCPP 1.6J Client thuần C, Modbus RTU Master             |
|  - Quản lý phiên sạc đám mây, đồng bộ công tơ điện, Live Dual-Bank Flash       |
+-------------------------------------------------------------------------------+
                                    │
                                    ▼ (RS485 Modbus RTU @ 115,200 bps)
+-------------------------------------------------------------------------------+
|     TẦNG 5: ĐIỀU KHIỂN CÔNG SUẤT CAO THẾ & AN TOÀN (POWER & SAFETY TIER)     |
|  - STM32H743XIT6: CCU Host Controller, ChargerSession FSM CCS2 (8 bước)       |
|  - Dual Modbus Slave (ID=1):                                                  |
|      * USART6 (PC6/PC7): Tiếp nhận lệnh từ HMI Master (115,200 bps)           |
|      * UART7 (PE8/PE7): Tiếp nhận lệnh từ STM32F429 Master (115,200 bps)      |
|  - FDCAN1 (125 kbps): Master điều khiển module nguồn AcePower AB-U2T          |
|  - FDCAN2 (250 kbps): CCU giao tiếp PLC với bộ điều khiển SECC (ISO 15118-20) |
|  - UART8 (9,600 bps): Modbus Master đọc công tơ DC Eastron DCM230 / DJS5179   |
|  - Phần cứng bảo vệ: Nút dừng khẩn E-Stop, Contactor DC ngắt < 20ms, IMD      |
+-------------------------------------------------------------------------------+
```

---

## 2. MA TRẬN CÁC BUS TRUYỀN THÔNG VẬT LÝ, GIAO THỨC & PHÂN ĐỊNH MASTER/SLAVE

| Liên kết | Lớp vật lý | Tốc độ | Giao thức | Phân định vai trò & ID | Mục đích truyền tin |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Driver App $\longleftrightarrow$ CSMS** | 4G / Wi-Fi Internet | Băng thông rộng | HTTPS REST, WSS | Client $\longleftrightarrow$ Cloud Server | Quét mã QR, lệnh RemoteStart/Stop, xem vị trí trạm và số dư ví. |
| **SePay $\longleftrightarrow$ CSMS** | Internet Webhook | Tức thời (< 2s) | HTTP POST JSON (HMAC) | Webhook Sender $\rightarrow$ CSMS Receiver | Thông báo biến động số dư tài khoản ngân hàng để nạp tiền vào ví. |
| **CSMS $\longleftrightarrow$ ESP32** | Wi-Fi / Ethernet | 100 Mbps | WebSocket WSS, MQTT | Client (Trạm) $\longleftrightarrow$ Server (Cloud) | Kênh truyền bản tin OCPP 1.6J JSON-RPC và lệnh nâng cấp MQTT Fleet OTA. |
| **ESP32 $\longleftrightarrow$ STM32F429** | 4-wire SPI (SCK, MOSI, MISO, CS) | **10 MHz** | SPI Coprocessor Frame (DMA) | **ESP32**: SPI Master<br>**F429**: SPI Slave | Truyền socket TCP/TLS, tải firmware OTA qua SPI (sub-chunking $\le 512\text{B}$). |
| **HMI $\longleftrightarrow$ STM32H743** | Cáp RS485 vi sai (USART6 PC6/PC7) | **115,200 bps** (8N1) | Modbus RTU | **HMI**: Modbus Master<br>**STM32H743**: Modbus Slave<br>*(Slave ID = 1)* | Màn hình cảm ứng HMI Master gửi lệnh Mailbox Start/Stop (Holding Reg 0x0001) và đọc định kỳ 27 thanh ghi telemetry (0x0000..0x001A: V, I, P, kWh, SoC, EVCC ID, Contactor, Error). |
| **STM32F429 $\longleftrightarrow$ STM32H743** | Cáp RS485 vi sai (USART6 $\leftrightarrow$ UART7 PE8/PE7) | **115,200 bps** (8N1) | Modbus RTU | **STM32F429**: Modbus Master<br>**STM32H743**: Modbus Slave<br>*(Slave ID = 1)* | F429 Master điều khiển sạc từ CSMS Cloud (RemoteStart/Stop, Target V/I, Max Power) và đọc telemetry (V, I, kWh, SoC, Gun Status) từ H743 để báo cáo OCPP. |
| **STM32H743 $\longleftrightarrow$ SECC** | Cáp xoắn chống nhiễu CAN (FDCAN2 PB12/PB13) | **250 kbps** (CAN 2.0B Extended) | SECC CCU CAN (ISO 15118-20, DIN 70121) | **STM32H743**: CCU Host Controller<br>**SECC**: PLC Node Controller | Bắt tay chu trình sạc CCS2, nhận diện mã MAC xe (EVCC ID cho AutoCharge), đọc % SoC, giới hạn sạc pin và điện áp/dòng điện yêu cầu. |
| **STM32H743 $\longleftrightarrow$ AcePower** | Cáp xoắn chống nhiễu CAN (FDCAN1 PD0/PD1) | **125 kbps** (CAN 2.0B Extended) | AcePower 29-bit CAN Protocol | **STM32H743**: CAN Master Controller<br>**AcePower**: Power Module Slaves | Lệnh đóng ngắt nguồn cao thế, cài đặt điện áp/dòng điện tức thời (AllSetData `0x029C0000`) và đọc telemetry từng module nguồn. |
| **STM32H743 $\longleftrightarrow$ DCM230 / DJS5179** | Cáp RS485 2 dây (UART8 PJ8/PJ9) | **9,600 bps** (8N1) | Modbus RTU | **STM32H743**: Modbus Master<br>**Công tơ DC**: Modbus Slave<br>*(Slave ID = 1)* | Đọc chỉ số công tơ điện một chiều DC thực tế (kWh tích lũy, Volts, Amperes) phục vụ chốt hóa đơn giao dịch. |

---

### 2.1. CHI TIẾT DANH MỤC CAN ID GIỮA STM32H743 (CCU) VÀ BỘ ĐIỀU KHIỂN SECC (250 kbps)

Giao tiếp FDCAN2 giữa STM32H743 (đóng vai trò **CCU - Charge Control Unit**) và **SECC** tuân thủ chuẩn ISO 15118-20 / DIN 70121 với khung truyền **29-bit Extended CAN**:

#### A. Khung tin CCU $\longrightarrow$ SECC (STM32H743 truyền đi):
| CAN ID (Hex) | Tên bản tin | Chu kỳ / Điều kiện | Mục đích nội dung bản tin |
| :--- | :--- | :--- | :--- |
| `0x18C0F456` | `CCU_STATUS` | 20 ms / 50 ms | Trạng thái phiên CCU, cho phép đóng contactor, điện áp ($0.1\,\text{V}$) và dòng điện ($0.1\,\text{A}$) trạm đo được. |
| `0x18C1F456` | `CCU_EVSE_INFO` | 100 ms | Thông tin trạm sạc EVSE ID, phiên bản giao thức ISO 15118 hỗ trợ. |
| `0x18C2F456` | `CCU_EVSE_CHG_MAX_LIMITS` | Sự kiện / 100 ms | Giới hạn công suất cực đại EVSE (Max Voltage 1000V, Max Current 250A, Max Power 180kW). |
| `0x18C3F456` | `CCU_EVSE_CHG_MIN_LIMITS` | Sự kiện / 100 ms | Giới hạn tối thiểu trạm (Min Voltage 150V, Min Current 5A). |
| `0x18C9F456` | `CCU_TIME_SYNC` | 1,000 ms | Đồng bộ thời gian thực Unix timestamp cho SECC. |
| `0x18CAF456` | `CCU_EVSE_DCHG_LIMITS` | Theo chu trình | Giới hạn công suất xả V2G (Vehicle-to-Grid). |
| `0x18CFF456` | `CCU_EVSE_MOBILITY_NEEDS` | Theo chu trình | Thông số nhu cầu di chuyển / hoàn thành phiên sạc. |

#### B. Khung tin SECC $\longrightarrow$ CCU (STM32H743 giám sát & nhận về):
| CAN ID (Hex) | Tên bản tin | Chu kỳ watchdog | Dữ liệu giải mã cung cấp cho STM32H743 |
| :--- | :--- | :--- | :--- |
| `0x18B056F4` | `SECC_STATUS` | 20 ms / 50 ms | Trạng thái chu trình sạc SECC (`SeccChgSessionState`), trạng thái chân CP/PP, mã cảnh báo. |
| `0x18B156F4` | `SECC_PLC_BASIC` | 100 ms | Trạng thái bắt tay sóng mang PLC HomePlug GreenPHY, mức suy hao tín hiệu mạng PLC. |
| `0x18B356F4` | `SECC_EV_EVCC_ID` | 100 ms | **Mã MAC xe điện (EVCC ID 6 bytes)** — chìa khóa định danh xe phục vụ tính năng **AutoCharge**. |
| `0x18B456F4` | `SECC_EV_CHG_MAX_LIMITS` | 100 ms | Giới hạn sạc tối đa xe điện cho phép (Max Voltage, Max Current, Max Power của pin xe). |
| `0x18B556F4` | `SECC_EV_CHG_MIN_LIMITS` | 100 ms | Giới hạn sạc tối thiểu pin xe yêu cầu. |
| `0x18B656F4` | `SECC_EV_RESS_TARGETS` | **50 ms** | **Điện áp mục tiêu (Target V) & Dòng điện mục tiêu (Target I)** xe yêu cầu module nguồn phát. |
| `0x18B756F4` | `SECC_EV_ENER_REQ_LIMITS`| 100 ms | Năng lượng pin xe cần nạp thêm (kWh). |
| `0x18B856F4` | `SECC_EV_RESS_INFO` | **100 ms** | **Phần trăm pin xe hiện tại (% SoC)**, tổng dung lượng pin (kWh), nhiệt độ pin xe. |
| `0x18B956F4` | `SECC_EV_REMAINING_TIME1` | 500 ms | Thời gian dự kiến sạc đến 80% (Bulk charging time). |
| `0x18BA56F4` | `SECC_EV_REMAINING_TIME2` | 500 ms | Thời gian dự kiến sạc đầy 100% (Full charging time). |
| `0x18BD56F4` | `SECC_EV_DCHG_LIMITS` | Theo chu trình | Giới hạn xả năng lượng V2G từ xe. |

---

### 2.2. CHI TIẾT DANH MỤC CAN ID ĐIỀU KHIỂN MODULE NGUỒN ACEPOWER (125 kbps)

Giao tiếp FDCAN1 giữa STM32H743 và dàn module nguồn DC AcePower AB-U2T (1000V / 250A) dùng chuẩn **CAN 2.0B 29-bit Extended ID**:
- **Bản tin Broadcast cài đặt công suất (`0x029C0000`)**: H743 phát đồng thời tới toàn bộ module:
  * Lệnh Bật/Tắt nguồn cao thế (`Power ON / Power OFF`).
  * Cài đặt điện áp đầu ra mong muốn (`Target Voltage`, đơn vị $0.1\,\text{V}$).
  * Cài đặt dòng điện giới hạn (`Current Limit`, đơn vị $0.1\,\text{A}$).
- **Bản tin phản hồi trạng thái module (`0x028Cxxxx`)**: Từng module nguồn phản hồi chu kỳ 100 ms:
  * Điện áp DC đo thực tế tại ngõ ra, dòng điện DC đo thực tế, nhiệt độ tản nhiệt, mã lỗi quá áp / quá dòng / quá nhiệt / mất pha AC.

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

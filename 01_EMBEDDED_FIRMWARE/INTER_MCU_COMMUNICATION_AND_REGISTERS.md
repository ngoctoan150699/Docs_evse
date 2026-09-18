# CẨM NANG GIAO THỨC TRUYỀN THÔNG & BẢN ĐỒ THANH GHI TƯƠNG TÁC GIỮA 3 VI ĐIỀU KHIỂN VÀ MÀN HÌNH HMI
## (COMPREHENSIVE INTER-MCU COMMUNICATION, PROTOCOL FRAMING & REGISTER MAP SPECIFICATION)

> **Phạm vi kỹ thuật:** Đặc tả chi tiết nguyên lý hoạt động, vai trò phân tầng, cấu trúc gói tin, mã lệnh và bản đồ thanh ghi tương tác giữa **ESP32-C6**, **STM32F429**, **STM32H743** và **Màn hình cảm ứng Android HMI**.  
> **Dành cho:** Kỹ sư Lập trình Nhúng (Embedded Firmware), Kỹ sư Thiết kế Phần cứng (Hardware) và Kỹ sư Tích hợp Hệ thống (System Integrator).  
> **Phiên bản chuẩn:** Hệ thống trạm sạc nhanh DC THACO EVSE `v1.0.1` (Tháng 9/2026).

---

## 1. TỔNG QUAN KIẾN TRÚC PHÂN TẦNG VÀ PHÂN VAI (ROLES & RESPONSIBILITIES)

Hệ sinh thái phần cứng trạm sạc THACO EVSE hoạt động theo nguyên tắc **Phân tán trách nhiệm (Separation of Concerns)** và **Cô lập an toàn phần cứng (Hardware Safety Isolation)**. Không một vi điều khiển đơn lẻ nào phải gánh toàn bộ tác vụ, mà được chia thành 3 tầng vi xử lý chuyên trách kết hợp màn hình HMI hiện trường:

```mermaid
flowchart TD
    subgraph CLOUD_LAYER ["☁️ CSMS CLOUD PLATFORM"]
        CSMS["Máy chủ Trung tâm CSMS<br/>(Go Microservices / WSS:9000 & MQTT)"]
    end

    subgraph TIER1 ["TIER 1: GATEWAY TRUYỀN THÔNG & OTA"]
        ESP["ESP32-C6 Coprocessor (RISC-V 160MHz)<br/>• Quản lý Wi-Fi / Ethernet<br/>• Mongoose HTTP Web Dashboard (10.14.80.19)<br/>• Điều phối Web OTA & MQTT Fleet OTA<br/>• Vai trò bus: SPI Slave (DMA)"]
    end

    subgraph TIER2 ["TIER 2: BỘ ĐIỀU KHIỂN GIAO THỨC & MẠNG TRUNG TÂM"]
        F4["STM32F429ZIT6 Central MCU (ARM Cortex-M4 180MHz)<br/>• MiniOCPP 1.6J Client thuần C (Zero-malloc)<br/>• Quản lý logic phiên sạc, thẻ RFID, đồng bộ CSMS<br/>• Vai trò bus 1: SPI Master (sang ESP32)<br/>• Vai trò bus 2: Modbus RTU Master (sang H743)"]
    end

    subgraph HMI_LAYER ["GIAO DIỆN HIỆN TRƯỜNG: ANDROID HMI"]
        HMI["Màn hình Cảm ứng Android HMI (Kiosk Flutter)<br/>• Hiển thị 9 màn hình trạng thái trực quan<br/>• Thao tác sạc tại chỗ (Start/Stop/Reset/QR)<br/>• Cổng quản trị Admin tại trụ<br/>• Vai trò bus: Modbus RTU Master (sang H743)"]
    end

    subgraph TIER3 ["TIER 3: BỘ ĐIỀU KHIỂN CÔNG SUẤT CAO THẾ & AN TOÀN (SAFETY ARBITER)"]
        H7["STM32H743XIT6 Power & Safety MCU (ARM Cortex-M7 480MHz)<br/>• Quản lý máy trạng thái sạc CCS2 (8 bước FSM)<br/>• Giám sát nút dừng khẩn E-Stop & Contactor DC ngắt < 20ms<br/>• Cắt dòng khẩn cấp khi mất cách ly điện trở IMD<br/>• Vai trò bus: Modbus RTU Slave ID 0x01 (cho F4 & HMI)"]
    end

    subgraph POWER_ACTUATORS ["🔌 THIẾT BỊ CÔNG SUẤT & XE ĐIỆN"]
        ACE["Module Nguồn AcePower AB-U2T (1000V/250A)<br/>FDCAN1 @ 125 kbps (Master H7)"]
        SECC["Bộ điều khiển SECC CCS2 (ISO 15118 / DIN 70121)<br/>FDCAN2 @ 500 kbps (Peer-to-Peer H7)"]
        METER["Công tơ DC Eastron DCM230 / DJS5179<br/>UART8 RS485 @ 9600 bps (Master H7)"]
        CAR["🚗 Khối Pin Ô tô Điện & EVCC"]
    end

    CSMS <-->|WebSocket OCPP 1.6J / MQTT| ESP
    ESP <-->|SPI 4-wire Full-Duplex DMA @ 10 MHz| F4
    F4 <-->|RS485 Modbus RTU @ 115200 bps (Port 1)| H7
    HMI <-->|RS485 Modbus RTU @ 115200 bps (Port 2)| H7
    H7 <-->|FDCAN1| ACE
    H7 <-->|FDCAN2| SECC
    H7 <-->|UART8 RS485| METER
    SECC <-->|Chân Pilot CP PLC (GreenPHY)| CAR
    ACE ==>|Cọc đồng DC+/DC-| CAR
```

### Bảng phân tích chi tiết vai trò từng khối:

| Thiết bị | Vi xử lý | Vai trò kiến trúc | Tại sao cần thiết kế này? (Nguyên lý kỹ thuật) |
| :--- | :--- | :--- | :--- |
| **Tier 1: ESP32-C6** | ESP32-C6-WROOM-1<br>(160MHz RISC-V, 16MB Flash) | **Gateway Không dây / Ethernet & Modem OTA** | Cách ly khối mạng IP không ổn định ra khỏi vi điều khiển thời gian thực. Nếu Wi-Fi rớt hoặc bị tấn công DoS, hai chip STM32 vẫn hoạt động bình thường, không bao giờ bị đơ CPU hay trễ nhịp bảo vệ nguồn. |
| **Tier 2: STM32F429** | STM32F429ZIT6<br>(180MHz Cortex-M4, 2MB Flash, 256KB RAM) | **Bộ điều khiển Giao thức Mạng Trung tâm (OCPP Master)** | Xử lý toàn bộ logic nghiệp vụ đám mây phức tạp: giao thức OCPP 1.6J JSON, mã hóa, bộ đệm thông điệp ngoại tuyến (Offline Queueing), quản lý danh sách thẻ RFID thẻ trắng/thẻ đen. Đóng vai trò **Modbus Master** điều phối lệnh xuống H7. |
| **Tier 3: STM32H743** | STM32H743XIT6<br>(480MHz Cortex-M7, 2MB Dual-Bank, 1MB RAM) | **Bộ điều khiển Công suất Cao thế & Trọng tài An toàn (CCU Safety Arbiter)** | Chịu trách nhiệm tối cao về an toàn điện: chạy thuật toán điều khiển PID/FSM chu trình sạc CCS2, giao tiếp FDCAN thời gian thực siêu tốc với bộ nguồn và bộ bắt tay xe SECC, điều khiển contactor ngắt cực nhanh ($< 20\text{ ms}$). Toàn bộ dữ liệu của H7 được công bố qua không gian thanh ghi Modbus RTU. |
| **Giao diện HMI** | Màn hình Android Công nghiệp (Flutter Kiosk App) | **Giao diện Người dùng Hiện trường (Face of Charger)** | Cung cấp trải nghiệm cảm ứng trực quan cho tài xế và kỹ thuật viên bảo trì. HMI độc lập đọc dữ liệu từ H743 qua Modbus và gửi lệnh qua cơ chế Hộp thư Mailbox nguyên tử. |

---

## 2. GIAO THỨC SPI FULL-DUPLEX DMA: STM32F429 (MASTER) ↔ ESP32-C6 (SLAVE)

### 2.1. Cấu hình phần cứng và thông số Bus
- **Chuẩn vật lý:** SPI 4 dây chuẩn Mode 0 (`CPOL=0`, `CPHA=0`), Full-Duplex.
- **Tốc độ xung nhịp (Clock):** **10 MHz** (có thể nâng lên 20 MHz khi tối ưu phần cứng).
- **Cơ chế truyền nhận:** **DMA (Direct Memory Access)** trên cả hai đầu:
  - F429 sử dụng `SPI2` kết hợp DMA1 Stream 3 (RX) và Stream 4 (TX).
  - ESP32-C6 sử dụng bộ điều khiển phần cứng `spi_slave` với bộ đệm căn chỉnh Word (`WORD_ALIGNED_ATTR`).
- **Sơ đồ chân kết nối:**

| Chân tín hiệu | STM32F429ZIT6 | ESP32-C6 | Hướng truyền | Chức năng |
| :--- | :---: | :---: | :---: | :--- |
| **SCK (Clock)** | `PB10` | `GPIO6` | F429 $\longrightarrow$ ESP32 | Xung nhịp đồng bộ truyền dữ liệu 10 MHz do F4 phát |
| **MOSI (Master Out Slave In)** | `PC3` | `GPIO8` | F429 $\longrightarrow$ ESP32 | Kênh dữ liệu F4 gửi lệnh (Command/Data) xuống ESP32 |
| **MISO (Master In Slave Out)** | `PC2` | `GPIO7` | ESP32 $\longrightarrow$ F429 | Kênh dữ liệu ESP32 phản hồi (Response/Event) lên F4 |
| **NSS / CS (Chip Select)** | `PB15` | `GPIO9` | F429 $\longrightarrow$ ESP32 | Tín hiệu chọn chip tích cực mức thấp (Active-Low) |
| **SYNC / HANDSHAKE (Tùy chọn)**| `PD11` | `GPIO10`| ESP32 $\longrightarrow$ F429 | Báo ngắt khi ESP32 có dữ liệu socket CSMS chờ F4 đọc |

> **LƯU Ý QUAN TRỌNG:** Kết nối giữa STM32F429 và ESP32-C6 là **chuẩn SPI DMA tốc độ cao 10 MHz**, **TUYỆT ĐỐI KHÔNG PHẢI UART**. Thiết kế này cho phép truyền tải thông điệp OCPP lớn và các gói firmware OTA mà không bị nghẽn cổ chai.

---

### 2.2. Cấu trúc Khung nhị phân (SPI Binary Frame Layout)
Mọi gói tin truyền qua bus SPI đều tuân thủ cấu trúc khung nhị phân chuẩn định nghĩa trong file `esp32_spi_protocol.h`:

```text
+---------------+--------------+--------------+---------------+--------------+---------------+----------------+----------------+
|  MAGIC (2B)   | VERSION (1B) | MSG_TYPE(1B) | CMD/EVT_ID(1B)|  FLAGS (1B)  | SEQUENCE (2B) | PAYLOAD_LEN(2B)| HEADER_CRC(2B) |
|    0xAE53     |     0x01     | 0x01/0x02... |  0x01..0xFF   | 0x00..0x07   |  0x0000..FFFF |  0..1024 Bytes |     CRC-16     |
+---------------+--------------+--------------+---------------+--------------+---------------+----------------+----------------+
|<─────────────────────────────── HEADER: 12 BYTES CỐ ĐỊNH ───────────────────────────────────>|
|
|───> [ DATA PAYLOAD: 0 đến 1024 BYTES ] ───> [ PAYLOAD CRC32: 4 BYTES (khi có Payload) ]
```

#### Chi tiết các trường dữ liệu Header (12 Bytes):
1. `magic` (`0xAE53`): Mã đồng bộ bắt đầu khung. Nếu nhận sai magic, vi xử lý lập tức loại bỏ frame và căn chỉnh lại bộ đệm.
2. `version` (`0x01`): Phiên bản giao thức nhị phân.
3. `msg_type`:
   - `0x00` (`ESP_MSG_NOOP`): Khung đệm rỗng dùng để kích xung Clock kéo dữ liệu về.
   - `0x01` (`ESP_MSG_CMD`): Lệnh từ F4 Master gửi xuống ESP32 Slave.
   - `0x02` (`ESP_MSG_RSP`): Phản hồi từ ESP32 Slave trả về cho F4 Master.
   - `0x03` (`ESP_MSG_EVT`): Sự kiện bất đồng bộ do ESP32 chủ động đẩy lên (Event).
4. `cmd_or_evt_id`: Định danh mã lệnh hoặc mã sự kiện (Tra cứu bảng bên dưới).
5. `flags`:
   - Bit 0 (`0x01`): `ESP_FLAG_HAS_PAYLOAD` (Khung có đính kèm Payload phía sau).
   - Bit 1 (`0x02`): `ESP_FLAG_EVT_PENDING` (ESP32 đang còn sự kiện trong hàng đợi, yêu cầu F4 tiếp tục đọc).
   - Bit 2 (`0x04`): `ESP_FLAG_ERROR` (Có lỗi xử lý ở tầng dưới).
6. `sequence` (16-bit): Số thứ tự gói tin tăng dần phục vụ phát hiện mất gói hoặc trùng gói.
7. `payload_length` (16-bit): Chiều dài dữ liệu thực tế ($0 \le N \le 1024$).
8. `header_crc` (16-bit): Mã kiểm tra CRC-16 bảo vệ 10 bytes đầu tiên của Header.

---

### 2.3. Bảng Mã Lệnh (Commands) & Sự Kiện (Events) SPI

#### A. Nhóm Quản lý Hệ thống & Wi-Fi:
| Mã (Hex) | Tên hằng số Enum | Chiều truyền | Mô tả chức năng |
| :---: | :--- | :---: | :--- |
| `0x01` | `ESP_CMD_PING` | F4 $ightarrow$ ESP | Kiểm tra nhịp tim và kết nối SPI liveness |
| `0x02` | `ESP_CMD_GET_STATUS` | F4 $ightarrow$ ESP | Lấy trạng thái mạng, RSSI, chế độ trạm |
| `0x10` | `ESP_CMD_WIFI_SCAN` | F4 $ightarrow$ ESP | Yêu cầu quét các mạng Wi-Fi lân cận |
| `0x11` | `ESP_CMD_WIFI_CONNECT`| F4 $ightarrow$ ESP | Kết nối vào mạng Wi-Fi với SSID & Password trong payload |
| `0x12` | `ESP_CMD_WIFI_DISCONNECT`| F4 $ightarrow$ ESP | Ngắt kết nối Wi-Fi hiện tại |
| `0x14` | `ESP_CMD_WIFI_GET_IP` | F4 $ightarrow$ ESP | Đọc địa chỉ IP đã được cấp phát từ DHCP |
| `0x15` | `ESP_CMD_WIFI_SET_CONFIG`| F4 $ightarrow$ ESP | Cấu hình IP tĩnh hoặc DHCP |

#### B. Nhóm Truyền tải Ổ cắm Mạng (Socket Tunneling - Phục vụ OCPP 1.6J):
| Mã (Hex) | Tên hằng số Enum | Chiều truyền | Mô tả chức năng |
| :---: | :--- | :---: | :--- |
| `0x30` | `ESP_CMD_SOCKET_OPEN` | F4 $ightarrow$ ESP | Yêu cầu mở kết nối TCP/TLS WSS tới máy chủ CSMS Cloud |
| `0x31` | `ESP_CMD_SOCKET_CLOSE`| F4 $ightarrow$ ESP | Đóng kết nối socket hiện tại |
| `0x32` | `ESP_CMD_SOCKET_SEND` | F4 $ightarrow$ ESP | F4 gửi bản tin JSON OCPP (Call/CallResult) qua socket ra Internet |
| `0x33` | `ESP_CMD_SOCKET_RECV` | F4 $ightarrow$ ESP | F4 kéo dữ liệu JSON OCPP mà máy chủ Cloud vừa gửi xuống |
| `0x34` | `ESP_CMD_SOCKET_STATUS`| F4 $ightarrow$ ESP | Truy vấn trạng thái kết nối socket (Connected / Connecting / Closed) |

#### C. Nhóm Telemetry & Nâng cấp OTA (Sub-chunking $\le 512$ Bytes):
| Mã (Hex) | Tên hằng số Enum | Chiều truyền | Mô tả chức năng |
| :---: | :--- | :---: | :--- |
| `0x40` | `ESP_CMD_REPORT_TELEMETRY` | F4 $ightarrow$ ESP | F4 gửi thông số V, I, kWh, SoC lên ESP32 để hiển thị Web Dashboard `10.14.80.19` |
| `0x50` | `ESP_CMD_OTA_GET_CHUNK` | F4 $ightarrow$ ESP | F4 yêu cầu ESP32 trả về 1 phân đoạn dữ liệu firmware mới ($\le 512	ext{B}$) |
| `0x51` | `ESP_CMD_OTA_REPORT_RESULT`| F4 $ightarrow$ ESP | F4 báo kết quả nạp firmware (Hoàn tất / Thất bại / Lỗi CRC32) |
| `0xFF` | `ESP_CMD_REBOOT` | F4 $ightarrow$ ESP | Yêu cầu khởi động lại ESP32 |

#### D. Các Sự kiện Bất đồng bộ từ ESP32 (Asynchronous Events):
- `0x10` (`ESP_EVT_WIFI_CONNECTED`): Đã kết nối vào Access Point.
- `0x14` (`ESP_EVT_IP_ACQUIRED`): Đã nhận được địa chỉ IP hợp lệ.
- `0x30` (`ESP_EVT_SOCKET_CONNECTED`): WebSocket kết nối thành công tới CSMS.
- `0x31` (`ESP_EVT_SOCKET_DATA_READY`): Có bản tin OCPP từ CSMS gửi về, sẵn sàng cho F4 đọc.
- `0x32` (`ESP_EVT_SOCKET_CLOSED`): Mất kết nối tới CSMS.
- `0x50` (`ESP_EVT_OTA_CHUNK_READY`): ESP32 đã tải xong phân đoạn firmware từ Cloud, sẵn sàng chuyển tiếp.

---

## 3. GIAO THỨC MODBUS RTU: F429 (MASTER) & HMI (MASTER) ↔ STM32H743 (SLAVE)

### 3.1. Mô hình Bus và Cơ chế Đa Master (Dual-Master Architecture)
- **Chuẩn vật lý:** RS485 vi sai công nghiệp 2 dây (A / B) chống nhiễu mạnh.
- **Tốc độ baud:** **115,200 bps**, Khung `8N1` (8 data bits, No parity, 1 stop bit).
- **Nguyên lý kết nối:**
  - Vi điều khiển **STM32H743** là trung tâm dữ liệu, đóng vai trò là **Modbus RTU Slave** với địa chỉ `Slave ID = 0x01`.
  - **F429 Master** giao tiếp với H743 qua cổng `UART7` của H743.
  - **Màn hình Android HMI Master** giao tiếp với H743 qua cổng `USART6` của H743.
  - Cả hai Master độc lập đọc/ghi dữ liệu vào không gian thanh ghi của H743 theo chuẩn phân vùng bộ nhớ `Map Version 0x0221`.

---

### 3.2. Bản đồ Không gian Thanh ghi Chi tiết của STM32H743 (Memory Map)

Không gian thanh ghi của STM32H743 được tổ chức thành các vùng chức năng (Planes) 16-bit rõ ràng:

```text
0x0000 ┌─────────────────────────────────────────────────────────┐
       │ VÙNG 1: THÔNG TIN HỆ THỐNG & ĐIỀU PHỐI (SYSTEM PLANE)    │ (0x0000 - 0x0017: 24 Thanh ghi)
0x0100 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 2: DỮ LIỆU TELEMETRY SÚNG 1 (CONNECTOR A PLANE)    │ (0x0100 - 0x0123: 36 Thanh ghi)
0x0200 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 3: DỮ LIỆU TELEMETRY SÚNG 2 (CONNECTOR B PLANE)    │ (0x0200 - 0x0223: 36 Thanh ghi)
0x0500 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 4: GIÁ ĐIỆN & CHI PHÍ TỨC THỜI (BUSINESS MIRROR)   │ (0x0500 - 0x0515: 22 Thanh ghi)
0x0700 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 5: HỘP THƯ LỆNH TỪ HMI (HMI COMMAND MAILBOX)       │ (0x0700 - 0x0708: Ghi lệnh FC16)
0x0720 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 6: PHẢN HỒI LỆNH HMI (HMI COMMAND ACK & RESULT)    │ (0x0720 - 0x0725: 6 Thanh ghi)
0x0740 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 7: BÀN ĐIỀU KHIỂN TỪ F429 (F429/OCPP COMMAND PLANE)│ (0x0740 - 0x074B: Ghi lệnh FC16)
0x0800 ├─────────────────────────────────────────────────────────┤
       │ VÙNG 8: MÃ TOKEN & VIETQR ĐỘNG (QR TOKEN MIRROR)        │ (0x0800 - 0x0814: 21 Thanh ghi)
       └─────────────────────────────────────────────────────────┘
```

---

### 3.3. Bảng Chi tiết Từng Vùng Thanh ghi Modbus

#### VÙNG 1: THÔNG TIN HỆ THỐNG & NHỊP TIM (Offset `0x0000` - Đọc bằng FC 0x03 / 0x04)
| Offset | Tên thanh ghi | Kiểu dữ liệu | Đơn vị / Hệ số | Ý nghĩa & Mô tả |
| :---: | :--- | :---: | :---: | :--- |
| `0x0000` | `MAP_VERSION` | `uint16` | Hằng số | Phiên bản bản đồ thanh ghi (Hiện tại: `0x0221`) |
| `0x0001` | `DEVICE_TYPE` | `uint16` | Enum | Loại thiết bị (`1`: DC Fast Charger, `2`: AC Charger) |
| `0x0002` | `FW_VER_MAJOR_MINOR`| `uint16` | Raw | Byte cao: Major version, Byte thấp: Minor version |
| `0x0003` | `FW_VER_PATCH` | `uint16` | Raw | Patch version của firmware H7 |
| `0x0004` | `CAPABILITIES_1` | `uint16` | Bitmask | Cờ tính năng phần cứng (Dual Gun, RFID, DCM Meter) |
| `0x0006` | `ALIVE_COUNTER` | `uint16` | Bộ đếm | Nhịp tim H7 tăng liên tục mỗi 100ms. F4/HMI kiểm tra liveness |
| `0x0007..08`| `H7_BOOT_ID` | `uint32` | Word ghép | Định danh ngẫu nhiên mỗi lần khởi động lại H7 |
| `0x0009` | `RESET_REASON` | `uint16` | Enum | Nguyên nhân reset (Power-on, Watchdog, Software, Fault) |
| `0x000A..0B`| `UPTIME_SEC` | `uint32` | Giây (s) | Thời gian hoạt động liên tục của chip H7 từ lần boot cuối |
| `0x000C` | `SUPERVISOR_STATUS` | `uint16` | Bitmask | Trạng thái bảo vệ: Bit 0: E-Stop, Bit 1: IMD Fault, Bit 2: Door Open |
| `0x000E..0F`| `UTC_EPOCH_SEC` | `uint32` | Giây Epoch | Thời gian thực đồng bộ từ CSMS qua F4 xuống H7 |
| `0x0010` | `TOTAL_STATION_KW` | `uint16` | kW | Tổng công suất định mức phần cứng của trạm |
| `0x0011` | `POWER_ALLOC_MODE` | `uint16` | Enum | Chế độ phân bổ công suất (`1`: Fixed 50/50, `2`: Dynamic) |
| `0x0012` | `GUN_A_REQ_POWER_KW`| `uint16` | kW | Công suất xe tại Súng A đang yêu cầu |
| `0x0013` | `GUN_A_ALLOC_POWER` | `uint16` | kW | Công suất cấp phát thực tế cho Súng A |
| `0x0014` | `GUN_A_ACT_POWER` | `uint16` | kW | Công suất sạc đo thực tế tại Súng A |

---

#### VÙNG 2 & 3: DỮ LIỆU TELEMETRY SÚNG SẠC (Connector A: `0x0100`, Connector B: `0x0200`)
*(Đọc bằng FC 0x03 hoặc FC 0x04, độ dài: 36 thanh ghi)*

| Offset Gun A | Offset Gun B | Tên trường dữ liệu | Kiểu | Đơn vị / Hệ số | Ý nghĩa & Mô tả |
| :---: | :---: | :--- | :---: | :---: | :--- |
| `0x0100` | `0x0200` | `SNAPSHOT_SEQ_BEGIN` | `uint16` | Bộ đếm | Mã sequence đầu snapshot (dùng chống rách dữ liệu) |
| `0x0101` | `0x0201` | `EVSE_STATE` | `uint16` | Enum | Trạng thái phiên: `0`: Unavail, `1`: Idle, `2`: Plugged, `4`: Authorized, `5`: Preparing, `6`: Charging, `7`: Stopping, `8`: Completed, `9`: Faulted, `10`: E-Stop |
| `0x0102` | `0x0202` | `EVSE_SUBSTATE` | `uint16` | Enum | Chi tiết bước: `1`: Locking, `2`: IMD Test, `3`: Precharge, `5`: Contactor Close, `6`: Ramp-up, `10`: Ramp-down |
| `0x0103` | `0x0203` | `PLUG_STATE` | `uint16` | 0 / 1 | Trạng thái cắm súng (`0`: Rút ra, `1`: Đã cắm ngập chốt) |
| `0x0104` | `0x0204` | `LOCK_STATE` | `uint16` | 0 / 1 | Trạng thái khóa ngàm súng (`0`: Mở, `1`: Đã khóa cơ học) |
| `0x0105` | `0x0205` | `CONTACTOR_CMD` | `uint16` | 0 / 1 | Lệnh xuất ra cuộn hút Contactor DC (`0`: Ngắt, `1`: Đóng) |
| `0x0106` | `0x0206` | `CONTACTOR_FEEDBACK` | `uint16` | 0 / 1 | Tiếp điểm phụ phản hồi trạng thái thực của Contactor |
| `0x010A` | `0x020A` | `SOC_PERCENT` | `uint16` | % (0 - 100) | **Dung lượng Pin xe hiện tại** (nhận diện qua SECC CAN) |
| `0x010B` | `0x020B` | `START_SOC_PERCENT` | `uint16` | % (0 - 100) | Dung lượng Pin xe tại thời điểm bắt đầu phiên sạc |
| `0x010C..0D`| `0x020C..0D`| `OUTPUT_VOLTAGE` | `uint32` | **0.1 V** | **Điện áp sạc thực tế** đo tại đầu súng (Giá trị / 10 = Volt) |
| `0x010E..0F`| `0x020E..0F`| `OUTPUT_CURRENT` | `int32` | **0.1 A** | **Dòng điện sạc thực tế** đang cấp vào xe (Giá trị / 10 = Ampe) |
| `0x0110..11`| `0x0210..11`| `OUTPUT_POWER` | `uint32` | **1 W** | Công suất tức thời (Giá trị / 1000 = kW) |
| `0x0112..13`| `0x0212..13`| `SESSION_ENERGY` | `uint32` | **1 Wh** | **Điện năng phiên sạc tích lũy** (Giá trị / 1000 = kWh) |
| `0x0114..15`| `0x0214..15`| `ELAPSED_SECONDS` | `uint32` | Giây (s) | Thời gian đã sạc tính từ lúc đóng contactor |
| `0x0116` | `0x0216` | `REMAINING_MINUTES` | `uint16` | Phút | Thời gian ước tính sạc đầy do BMS xe tính toán |
| `0x0117` | `0x0217` | `GUN_TEMPERATURE` | `uint16` | **0.1 °C** | Nhiệt độ cảm biến đầu súng (Bảo vệ quá nhiệt) |
| `0x0118..19`| `0x0218..19`| `LOCAL_SESSION_ID` | `uint32` | Word ghép | Mã phiên sạc nội bộ trạm tạo ra |
| `0x011A` | `0x021A` | `BMS_REQ_VOLTAGE` | `uint16` | 0.1 V | Điện áp do BMS xe yêu cầu cấp |
| `0x011B` | `0x021B` | `BMS_REQ_CURRENT` | `uint16` | 0.1 A | Dòng điện do BMS xe yêu cầu cấp |
| `0x011F` | `0x021F` | `STOP_CAUSE` | `uint16` | Enum | Lý do kết thúc phiên (`1`: Local, `2`: Remote, `3`: Emergency) |
| `0x0120` | `0x0220` | `PRIMARY_FAULT_CODE`| `uint16` | Mã lỗi Hex | Mã sự cố chính khi trạm dừng bất thường |
| `0x0123` | `0x0223` | `SNAPSHOT_SEQ_END` | `uint16` | Bộ đếm | Mã sequence cuối snapshot. Nếu `BEGIN == END` $ightarrow$ Dữ liệu hợp lệ |

---

#### VÙNG 4: GIÁ ĐIỆN & CHI PHÍ TỨC THỜI (Offset `0x0500`)
| Offset | Tên trường | Kiểu | Đơn vị | Ý nghĩa & Mô tả |
| :---: | :--- | :---: | :---: | :--- |
| `0x0500` | `BUSINESS_DATA_SEQ` | `uint16` | Bộ đếm | Số sequence cập nhật dữ liệu tài chính |
| `0x0501` | `IS_VALID` | `uint16` | 0 / 1 | `1`: Dữ liệu giá hợp lệ, `0`: Chưa nhận được giá từ CSMS |
| `0x0503..04`| `TARIFF_RATE_VND` | `uint32` | VNĐ / kWh | Đơn giá sạc hiện tại (ví dụ: `3850` VNĐ/kWh) |
| `0x0505..06`| `SERVICE_FEE_VND` | `uint32` | VNĐ | Phí dịch vụ cố định mỗi phiên |
| `0x0507..08`| `RUNNING_COST_A` | `uint32` | VNĐ | Tiền sạc tức thời của Súng A (tính tự động = kWh × Đơn giá) |
| `0x0509..0A`| `RUNNING_COST_B` | `uint32` | VNĐ | Tiền sạc tức thời của Súng B |
| `0x050B` | `CSMS_CONN_STATUS` | `uint16` | Enum | `0`: Offline, `1`: Connected, `2`: Authorized |

---

#### VÙNG 5 & 6: HỘP THƯ LỆNH TỪ MÀN HÌNH HMI (HMI COMMAND MAILBOX & ACK)
Cơ chế điều khiển từ HMI xuống H7 được thiết kế theo nguyên tắc **Hộp thư nguyên tử (Atomic Mailbox with Magic Commit)**. HMI ghi một chuỗi gồm 9 thanh ghi qua Function Code `0x10` (Write Multiple Registers) vào vùng `0x0700`:

| Offset | Tên thanh ghi | Giá trị ghi vào | Ý nghĩa & Quy tắc bắt buộc |
| :---: | :--- | :---: | :--- |
| `0x0700` | `REQ_SEQ_HI` | Word cao | Số sequence yêu cầu (32-bit tăng dần mỗi lần bấm nút) |
| `0x0701` | `REQ_SEQ_LO` | Word thấp | Số sequence yêu cầu |
| `0x0702` | `BOOT_ID_HI` | Word cao | Mã Boot ID của H7 (đọc từ `0x0007` để tránh gửi lệnh sai phiên boot) |
| `0x0703` | `BOOT_ID_LO` | Word thấp | Mã Boot ID của H7 |
| `0x0704` | `CMD_ID` | Mã lệnh | `1`: Start Charging, `2`: Stop Charging, `3`: Reset Fault, `4`: E-Stop, `7`: Request QR, `8`: Cancel QR |
| `0x0705` | `TARGET_CONNECTOR` | `1` hoặc `2` | `1`: Súng sạc A (Connector 1), `2`: Súng sạc B (Connector 2) |
| `0x0706` | `PARAM_1` | Tham số 1 | Ví dụ: Loại xác thực hoặc Giới hạn SoC dừng sạc |
| `0x0707` | `PARAM_2` | Tham số 2 | Tham số phụ mở rộng |
| `0x0708` | `COMMIT_MAGIC` | **`0xA55A`** | **CHÌA KHÓA THỰC THI:** H743 chỉ thi hành lệnh khi thanh ghi này mang giá trị `0xA55A`. Nếu ghi thiếu hoặc sai số, lệnh sẽ bị hủy! |

Ngay sau khi ghi lệnh, HMI đọc vùng **ACK (`0x0720 - 0x0725`)** để xác nhận phản hồi từ H743:
- `0x0720 - 0x0721`: `ACK_SEQ` (Số sequence H7 vừa xử lý).
- `0x0722`: `RESP_CMD_ID` (Mã lệnh được phản hồi).
- `0x0723`: `STATUS` (`0`: None, `1`: Accepted, `2`: Rejected, `3`: Executing, `4`: Completed, `5`: Failed).
- `0x0724`: `REJECT_REASON` (`1`: InvalidParam, `2`: Busy, `3`: EstopActive, `4`: NotPlugged, `5`: AuthFailed).
- `0x0725`: `RESULT_REASON` (`0`: Success, `1`: Timeout, `2`: HardwareFault).

---

#### VÙNG 7: BÀN ĐIỀU KHIỂN TỪ F429 / CSMS (F429 COMMAND PLANE - Offset `0x0740`)
Khi máy chủ CSMS Cloud gửi lệnh điều khiển sạc từ xa (`RemoteStartTransaction`, `RemoteStopTransaction`, `UnlockConnector`, `Reset`), F429 sẽ ghi lệnh xuống H743 qua Function Code `0x10`:

| Offset | Tên thanh ghi | Kiểu | Ý nghĩa chức năng |
| :---: | :--- | :---: | :--- |
| `0x0740` | `F4_CMD_SEQ` | `uint16` | Số thứ tự lệnh từ F429 |
| `0x0741` | `F4_CMD_ID` | `uint16` | `1`: RemoteStart, `2`: RemoteStop, `3`: Reset, `4`: UnlockGun |
| `0x0742` | `TARGET_CONNECTOR`| `uint16` | `1`: Súng A, `2`: Súng B |
| `0x0743` | `TARGET_VOLTAGE` | `uint16` | Điện áp cài đặt mong muốn (0.1 V) |
| `0x0744` | `TARGET_CURRENT` | `uint16` | Dòng điện giới hạn tối đa cho phép sạc (0.1 A) |
| `0x0745` | `MAX_POWER_LIMIT` | `uint16` | Giới hạn công suất Smart Charging (kW) |
| `0x074A` | `STOP_REASON` | `uint16` | Lý do dừng từ Cloud (Remote, EVDisconnected, OverCurrent) |
| `0x074B` | `COMMIT_MAGIC` | **`0xA55A`** | **CHÌA KHÓA THỰC THI TỪ F4:** H743 kiểm tra đúng `0xA55A` mới ra lệnh đóng mở contactor và module nguồn |

---

## 4. QUY TRÌNH TƯƠNG TÁC ĐỒNG BỘ TOÀN HỆ THỐNG (END-TO-END SEQUENCE FLOW)

Dưới đây là chu trình tương tác thực tế giữa 4 thực thể phần cứng trong một phiên sạc hoàn chỉnh:

```mermaid
sequenceDiagram
    autonumber
    actor Driver as Tài xế (Driver)
    participant HMI as Android HMI (Master 2)
    participant H7 as STM32H743 (Power Slave)
    participant F4 as STM32F429 (OCPP Master 1)
    participant ESP as ESP32-C6 (SPI Slave)
    participant CSMS as Máy chủ Cloud CSMS
    participant Ace as Module Nguồn AcePower

    Note over HMI,H7: Chu kỳ 150ms: HMI đọc 0x0000 & 0x0100 Modbus
    Note over F4,H7: Chu kỳ 100ms: F4 đọc 0x0000 & 0x0100 Modbus
    Note over F4,ESP: Chu kỳ 20ms: F4 poll SPI Socket & Telemetry

    Driver->>H7: Cắm súng sạc CCS2 vào xe điện
    H7->>H7: Nhận diện điện áp Pilot CP giảm (12V -> 9V State B)
    H7-->>HMI: Modbus Reg 0x0103 = 1 (Plugged)
    HMI->>HMI: Màn hình chuyển sang giao diện [Plugged Screen]
    H7-->>F4: Modbus Reg 0x0103 = 1
    F4->>ESP: Gửi gói SPI: Socket Send (StatusNotification: Preparing)
    ESP->>CSMS: Đẩy bản tin WebSocket WSS: StatusNotification

    Driver->>HMI: Quẹt thẻ RFID trên trụ hoặc App quét mã QR
    HMI->>H7: Ghi Modbus 0x0700: CMD_ID=1, COMMIT=0xA55A
    F4->>ESP: SPI Socket Send: Authorize(IdTag)
    ESP->>CSMS: WebSocket WSS: Authorize.req
    CSMS-->>ESP: WebSocket WSS: Authorize.conf (Accepted)
    ESP-->>F4: SPI Socket Recv: Authorize.conf
    F4->>ESP: SPI Socket Send: StartTransaction.req
    ESP->>CSMS: WebSocket WSS: StartTransaction.req
    CSMS-->>ESP: StartTransaction.conf (TransactionId: 98765)
    ESP-->>F4: SPI Socket Recv: TransactionId: 98765

    F4->>H7: Ghi Modbus 0x0740: CMD_ID=1 (Start), COMMIT=0xA55A
    H7->>H7: Khóa ngàm súng (Lock Motor ON -> Reg 0x0104 = 1)
    H7->>H7: Đo kiểm tra cách điện (Insulation Test via IMD)
    H7->>Ace: FDCAN1: Set Voltage Pre-charge khớp điện áp Pin xe
    H7->>Ace: FDCAN1: Power ON (Byte 0 = 0x00)
    H7->>H7: Đóng Contactor DC chính (Reg 0x0105 = 1)
    H7->>H7: Chuyển trạng thái sang Charging (Reg 0x0101 = 6)

    loop Chu kỳ sạc liên tục (Vòng lặp nạp điện)
        H7->>Ace: FDCAN1: Cập nhật Target V / Target I theo BMS xe
        H7->>H7: Đọc công tơ DC qua UART8: Cập nhật V, I, kW, Wh
        H7-->>HMI: Cung cấp thanh ghi 0x010A (SoC%), 0x010C (V), 0x010E (I), 0x0507 (Tiền)
        HMI->>HMI: Cập nhật Arc Gauge đồng hồ % Pin, công suất, số tiền
        H7-->>F4: F4 đọc Wh tích lũy và telemetry
        F4->>ESP: SPI Gửi MeterValues định kỳ
        ESP->>CSMS: WebSocket WSS: MeterValues (kWh, SoC, V, I)
    end

    Driver->>HMI: Nhấn nút [Dừng Sạc] trên màn hình cảm ứng
    HMI->>H7: Ghi Modbus 0x0700: CMD_ID=2 (Stop), COMMIT=0xA55A
    H7->>Ace: FDCAN1: Ramp-down giảm dòng về 0A -> Power OFF
    H7->>H7: Ngắt Contactor DC chính (Reg 0x0105 = 0)
    H7->>H7: Kích hoạt rơ-le xả điện áp dư (Bleeding < 60V)
    H7->>H7: Mở khóa ngàm súng sạc (Unlock Motor)
    H7->>H7: Chuyển trạng thái sang Completed (Reg 0x0101 = 8)
    H7-->>HMI: Cung cấp hóa đơn tổng kết phiên sạc
    H7-->>F4: Báo phiên sạc hoàn thành
    F4->>ESP: SPI Socket Send: StopTransaction.req (MeterStop, TransactionId)
    ESP->>CSMS: WebSocket WSS: StopTransaction.req
    CSMS-->>ESP: StopTransaction.conf
    HMI->>HMI: Hiển thị màn hình [Complete Screen] (Tổng kWh, Tổng tiền, Thời gian)
```

---

## 5. CƠ CHẾ BẢO VỆ FAIL-SAFE & XỬ LÝ SỰ CỐ TRUYỀN THÔNG LIÊN MCU

1. **Mất nhịp tim liveness giữa F429 và H743:**
   - H743 liên tục tăng thanh ghi `ALIVE_COUNTER` (`0x0006`). F429 đọc thanh ghi này chu kỳ 100ms.
   - Nếu trong vòng **$> 3	ext{ giây}$**, F429 không đọc được Modbus hoặc giá trị `ALIVE_COUNTER` không thay đổi:
     - F429 đánh dấu trạm `Unavailable` và báo lỗi lên CSMS Cloud.
     - Đồng thời, watchdog bên trong H743 phát hiện không có lệnh polling từ F429 sẽ tự động kích hoạt chu trình dừng sạc khẩn cấp: ngắt contactor DC chính và kéo nguồn module về OFF.
2. **Mất liên kết SPI giữa F429 và ESP32-C6:**
   - F429 gửi lệnh `ESP_CMD_PING` (`0x01`) mỗi giây. Nếu ESP32 không phản hồi qua SPI trong 3 chu kỳ liên tiếp:
     - F429 kích hoạt chân reset phần cứng kéo chân `EN` của ESP32 xuống mức thấp để khởi động lại modem.
     - Toàn bộ dữ liệu phiên sạc vẫn được lưu an toàn trong RAM của F429 và H743, không làm gián đoạn dòng điện đang sạc xe.
3. **Nút Dừng Khẩn Cấp (E-Stop) hoặc Rò điện IMD:**
   - Tín hiệu nút E-Stop và tiếp điểm cảnh báo rò điện cách ly IMD được đấu nối cứng trực tiếp vào các chân ngắt ngoài EXTI của vi điều khiển **STM32H743**.
   - Khi có sự cố, mạch ngắt phần cứng của H743 lập tức ngắt cuộn hút contactor trong thời gian **$< 20	ext{ ms}$** và phát lệnh tắt nguồn khẩn cấp qua FDCAN1 mà không cần chờ bất kỳ sự cho phép nào từ F429 hay màn hình HMI.

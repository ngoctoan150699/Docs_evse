# SƠ ĐỒ CHÂN KẾT NỐI PHẦN CỨNG & THÔNG SỐ CÁC BUS TRUYỀN THÔNG
## (HARDWARE PINOUT & PHYSICAL BUS SPECIFICATIONS)

Tài liệu này định nghĩa chi tiết sơ đồ chân (Pinout) kết nối liên chip, cấu hình bus và mạch bảo vệ an toàn cho toàn bộ 3 vi điều khiển trong trạm sạc.

---

## 1. GIAO TIẾP SPI 4-WIRE FULL-DUPLEX DMA (ESP32-C6 <-> STM32F429)

> [!IMPORTANT]
> Giao tiếp giữa ESP32 và STM32F429 là **SPI Full-Duplex DMA**, tuyệt đối không phải UART. Tốc độ xung nhịp đạt **10 MHz**, đảm bảo truyền socket mạng tốc độ cao và nạp firmware OTA trơn tru.

| Tín hiệu | Chân ESP32-C6 | Chân STM32F429 | Vai trò chức năng | Ghi chú kỹ thuật |
| :--- | :--- | :--- | :--- | :--- |
| **`SPI_SCK`** | `GPIO 5` | `PB10` (`SPI2_SCK`) | Xung nhịp Clock Master | 10 MHz, SPI Mode 0 (CPOL=0, CPHA=0) |
| **`SPI_MOSI`** | `GPIO 7` | `PC3` (`SPI2_MOSI`) | Dữ liệu Master Out $ightarrow$ Slave In | DMA Stream 4 Channel 0 (F4) |
| **`SPI_MISO`** | `GPIO 6` | `PC2` (`SPI2_MISO`) | Dữ liệu Slave Out $ightarrow$ Master In | DMA Stream 3 Channel 0 (F4) |
| **`SPI_CS`** | `GPIO 9` | `PB15` (`SPI2_NSS`) | Chọn chip (Active Low) | Điều khiển chọn frame dữ liệu |
| **`GND`** | `GND` | `GND` | Nối đất tham chiếu chung | Đi dây ngắn, chống nhiễu |

---

## 2. GIAO TIẾP RS485 MODBUS RTU: STM32F429 (MASTER) <-> STM32H743 (SLAVE)

| Tín hiệu | STM32F429 (Master) | STM32H743 (Slave 0x01) | Thông số cấu hình | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| **`RS485_TX`** | `PG14` (`USART6_TX`) | `PE8` (`UART7_TX`) | Baudrate: **115,200 bps**<br>Data: 8 bit, Parity: None, Stop: 1 | F429 gửi lệnh OCPP RemoteStart/Stop, Target V/I |
| **`RS485_RX`** | `PG9` (`USART6_RX`) | `PE7` (`UART7_RX`) | Tần số lấy mẫu: 16x | H743 phản hồi telemetry V, I, kWh, SoC, Gun Status |
| **`RS485_DIR`**| Auto-direction IC | Auto-direction IC | Phần cứng tự động điều hướng TX/RX | Dùng IC MAX13487E hoặc tương đương |

---

## 2.1. GIAO TIẾP RS485 MODBUS RTU: ANDROID HMI (MASTER) <-> STM32H743 (SLAVE)

| Tín hiệu | Màn hình HMI (Master) | STM32H743 (Slave 0x01) | Thông số cấu hình | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| **`RS485_TX / DATA+`** | RS485 Port (A / +) | `PC6` (`USART6_TX`) | Baudrate: **115,200 bps**<br>Data: 8 bit, Parity: None, Stop: 1 | HMI Master gửi lệnh Mailbox Start/Stop (Reg 0x0001) |
| **`RS485_RX / DATA-`** | RS485 Port (B / -) | `PC7` (`USART6_RX`) | Polling chu kỳ 100..200 ms | H743 phản hồi 27 thanh ghi telemetry (0x0000..0x001A) |
| **`GND`** | RS485 GND | GND Bo mạch | Nối đất tham chiếu vi sai | Cáp xoắn chống nhiễu bọc kim |

---

## 3. GIAO TIẾP FDCAN1: ĐIỀU KHIỂN MODULE NGUỒN ACEPOWER (STM32H743)

| Tín hiệu | Chân STM32H743 | Bộ thu phát CAN Transceiver | Thông số cấu hình | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| **`CAN1_TX`** | `PD1` (`FDCAN1_TX`) | Chân TX của TJA1051 / SN65HVD230 | **125 kbps**, Classical CAN frame | Điều khiển mạng module nguồn AcePower (AllSetData 0x029C0000) |
| **`CAN1_RX`** | `PD0` (`FDCAN1_RX`) | Chân RX của TJA1051 / SN65HVD230 | 29-bit Extended CAN Identifier | Điện trở đầu cuối bus $120\,\Omega$ |

---

## 4. GIAO TIẾP FDCAN2: BẮT TAY BỘ ĐIỀU KHIỂN SECC CCS2 (STM32H743)

| Tín hiệu | Chân STM32H743 | Bộ thu phát CAN Transceiver | Thông số cấu hình | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| **`CAN2_TX`** | `PB13` (`FDCAN2_TX`) | Chân TX của TJA1051 / SN65HVD230 | **250 kbps**, Classical CAN frame | Giao tiếp PLC ISO 15118 / DIN 70121 |
| **`CAN2_RX`** | `PB12` (`FDCAN2_RX`) | Chân RX của TJA1051 / SN65HVD230 | 29-bit Extended CAN Identifier | Nhận diện xe (EVCC MAC), đọc % SoC, điện áp/dòng yêu cầu |

---

## 5. GIAO TIẾP CÔNG TƠ DC EASTRON DCM230 (STM32H743)

| Tín hiệu | Chân STM32H743 | Cổng công tơ DCM230 | Thông số cấu hình | Ghi chú |
| :--- | :--- | :--- | :--- | :--- |
| **`METER_TX`** | `PJ8` (`UART8_TX`) | Cổng RS485 Chân A (+) | Baudrate: **9,600 bps**<br>Data: 8, Parity: None, Stop: 1 | Đọc kWh điện tiêu thụ đối soát MID |
| **`METER_RX`** | `PJ9` (`UART8_RX`) | Cổng RS485 Chân B (-) | Modbus RTU Address: `0x01` | Đọc điện áp DC (V) và dòng điện DC (A) |

---

## 6. CÁC TÍN HIỆU BẢO VỆ PHẦN CỨNG & AN TOÀN (STM32H743)

| Tín hiệu | Chân MCU | Loại tín hiệu | Tác động an toàn | Thời gian kích hoạt |
| :--- | :--- | :--- | :--- | :--- |
| **`E_STOP_INPUT`** | `PC13` | Digital Input (Kéo lên, Active-Low) | Khi nhấn nút E-Stop $ightarrow$ ngắt lập tức nguồn phát và mở contactor | **$< 20\text{ ms}$** |
| **`CONTACTOR_DC_POS`** | `PE2` | Digital Output qua Relay lái | Đóng/mở cực dương DC+ tới súng sạc | Chỉ đóng khi vượt qua kiểm tra cách ly |
| **`CONTACTOR_DC_NEG`** | `PE3` | Digital Output qua Relay lái | Đóng/mở cực âm DC- tới súng sạc | Chỉ đóng khi vượt qua kiểm tra cách ly |
| **`BLEEDER_RESISTOR`** | `PE4` | Digital Output qua Relay lái | Đóng điện trở xả tụ điện áp cao thế | Xả tụ khi dừng sạc hoặc có sự cố |
| **`IMD_FAULT_IN`** | `PE5` | Digital Input | Báo động rò điện cách ly cao áp | Lập tức ngắt sạc |

# BẢNG ÁNH XẠ THANH GHI MODBUS RTU CHUẨN CÔNG NGHIỆP v2.2.1
## (EVSE MASTER MODBUS RTU REGISTER MAP SPECIFICATION - MAP VERSION 0x0221)

> **Căn cứ mã nguồn thực tế:** Trích xuất nguyên tử từ [Core/protocol/evse_modbus_regs.h](file:///d:/DuAn/10.ViDieuKhien/STM32/CodeSTM32/evse_h743/Core/protocol/evse_modbus_regs.h) và [Core/lib/modbus_slave.c](file:///d:/DuAn/10.ViDieuKhien/STM32/CodeSTM32/evse_h743/Core/lib/modbus_slave.c).  
> **Phiên bản bản đồ:** `EVSE_MODBUS_MAP_VERSION_V221` (`0x0221`).  
> **Địa chỉ Modbus Slave:** `0x01` (`EVSE_MODBUS_SLAVE_ID_DEFAULT`).  
> **Cấu hình truyền thông vật lý:** 115,200 bps, 8 Data bits, No Parity, 1 Stop bit (8N1), RS485 vi sai Half-Duplex.  
> **Cơ chế Dual-Master độc quyền:**
> - **Cổng HMI hiện trường:** STM32H743 `USART6` (`PC6` TX, `PC7` RX) kết nối màn hình cảm ứng Android HMI Master.
> - **Cổng F429 Gateway:** STM32H743 `UART7` (`PE8` TX, `PE7` RX) kết nối vi điều khiển trung tâm STM32F429 Master.
> - **Quy chuẩn thứ tự Byte (32-bit Word Order):** **Big-Endian / ABCD** (Word cao ở offset địa chỉ thấp, Word thấp ở offset địa chỉ cao):
>   $$\text{Value}_{32} = (\text{Reg}_{\text{HI}} \ll 16) \mid \text{Reg}_{\text{LO}}$$

---

## 1. PHÂN VÙNG TOÀN BỘ KHÔNG GIAN ĐỊA CHỈ MODBUS (ADDRESS SPACE PARTITION)

| Dải Offset (Hex) | Dải Địa chỉ (Dec) | Tên phân vùng chức năng | Quyền truy cập | Đối tượng sử dụng chính |
| :---: | :---: | :--- | :---: | :--- |
| `0x0000 - 0x00FF` | `0 - 255` | **SYSTEM & GLOBAL STATUS** | Read-Only (`0x03`/`0x04`) | Giám sát nhịp tim H7, Boot ID, định danh phần cứng 96-bit UID, phân bổ công suất trạm. |
| `0x0100 - 0x01FF` | `256 - 511` | **CONNECTOR A (SÚNG SẠC 1)** | Read-Only (`0x03`/`0x04`) | Toàn bộ trạng thái phiên, telemetry V, I, P, kWh, % SoC, MAC xe EVCC ID Súng A. |
| `0x0200 - 0x02FF` | `512 - 767` | **CONNECTOR B (SÚNG SẠC 2)** | Read-Only (`0x03`/`0x04`) | Toàn bộ trạng thái phiên, telemetry V, I, P, kWh, % SoC, MAC xe EVCC ID Súng B. |
| `0x0300 - 0x03FF` | `768 - 1023` | **POWER & RECTIFIERS** | Read-Only (`0x03`/`0x04`) | Giám sát thanh cái DC link, điện trở cách điện IMD, dữ liệu module nguồn công suất. |
| `0x0400 - 0x04FF` | `1024 - 1279` | **EVENT RING BUFFER** | Read-Only (`0x03`/`0x04`) | Cửa sổ đọc 8 sự kiện cảnh báo/sự cố gần nhất (64 thanh ghi). |
| `0x0500 - 0x05FF` | `1280 - 1535` | **F4 BUSINESS MIRROR** | Read-Only (`0x03`/`0x04`) | Trạng thái mạng Wi-Fi/Ethernet, kết nối CSMS Cloud, đơn giá điện (VND), cước tạm tính. |
| `0x0600 - 0x067F` | `1536 - 1663` | **ADMIN CONFIGURATION** | Read/Write (`0x03`/`0x10`)| Cấu hình kỹ thuật tại hiện trường (SSID/Password, CSMS URL, IP tĩnh / DHCP). |
| `0x0680 - 0x06DF` | `1664 - 1759` | **WI-FI SCAN RESULTS** | Read-Only (`0x03`/`0x04`) | Danh sách các Access Point Wi-Fi quét được (SSID, RSSI). |
| `0x0700 - 0x073F` | `1792 - 1855` | **HMI COMMAND MAILBOX** | Read/Write (`0x10`/`0x04`)| Hộp thư lệnh độc lập dành riêng cho màn hình cảm ứng HMI (USART6). |
| `0x0740 - 0x077F` | `1856 - 1919` | **F4 COMMAND MAILBOX** | Read/Write (`0x10`/`0x04`)| Hộp thư lệnh độc lập dành riêng cho STM32F429 / CSMS Cloud (UART7). |
| `0x0780 - 0x07BF` | `1920 - 1983` | **SERVICE COMMAND MAILBOX**| Read/Write (`0x10`/`0x04`)| Hộp thư lệnh bảo trì, chẩn đoán nội bộ tại nhà máy. |
| `0x0800 - 0x0814` | `2048 - 2068` | **DYNAMIC VIETQR TOKEN** | Read-Only (`0x03`/`0x04`) | Mã chuỗi VietQR thanh toán động kèm TTL đếm lùi và trạng thái quét. |

---

## 2. VÙNG 1: THÔNG TIN HỆ THỐNG & NHỊP TIM (`0x0000 - 0x001E`)
*Chế độ truy cập: Read-Only (Function Code `0x03` hoặc `0x04`)*

| Offset | Tên trường thanh ghi | Kiểu dữ liệu | Thang đo / Đơn vị | Ý nghĩa chức năng & Quy tắc kỹ thuật |
| :---: | :--- | :---: | :---: | :--- |
| `0x0000` | `EVSE_MB_SYS_MAP_VERSION` | `uint16` | Hằng số `0x0221` | Phiên bản bản đồ thanh ghi (v2.2.1). F4 và HMI bắt buộc kiểm tra trường này trước khi đọc. |
| `0x0001` | `EVSE_MB_SYS_DEVICE_TYPE` | `uint16` | Enum | `1`: Dual DC Kiosk (2 súng), `2`: Single DC Kiosk (1 súng), `3`: Power Hub công suất lớn. |
| `0x0002` | `EVSE_MB_SYS_FW_VER_MAJOR_MINOR` | `uint16` | Pack `(Maj<<8)\|Min`| Ví dụ `0x0100` tương ứng Firmware v1.0. |
| `0x0003` | `EVSE_MB_SYS_FW_VER_PATCH` | `uint16` | Số nguyên | Ví dụ `1` tương ứng Patch v1.0.1. |
| `0x0004` | `EVSE_MB_SYS_CAPABILITIES_1` | `uint16` | Bitmask | Bit 0: DualGun, Bit 1: Simultaneous, Bit 2: PowerShare, Bit 3: DynamicQR, Bit 4: VIN_Auth. |
| `0x0005` | `EVSE_MB_SYS_CAPABILITIES_2` | `uint16` | Bitmask | Bit 0: ACMeter, Bit 1: DCMeter, Bit 2: IMDTest, Bit 3: LiquidCooling. |
| `0x0006` | `EVSE_MB_SYS_H7_ALIVE_COUNTER` | `uint16` | Số đếm (`0-65535`) | Nhịp tim H743 tăng mỗi 100ms. Dùng làm Watchdog phát hiện vi điều khiển bị treo. |
| `0x0007..08`| `EVSE_MB_SYS_H7_BOOT_ID` | `uint32` | Hex Big-Endian | Mã định danh duy nhất của phiên khởi động H743 hiện tại (dùng để chống gửi lệnh sai phiên). |
| `0x0009` | `EVSE_MB_SYS_H7_RESET_REASON` | `uint16` | Enum | `1`: Power-on, `2`: Watchdog reset, `3`: Brownout hạ áp, `4`: Software reset, `5`: HardFault. |
| `0x000A..0B`| `EVSE_MB_SYS_H7_UPTIME_SEC` | `uint32` | Giây (s) | Thời gian trạm đã hoạt động liên tục kể từ lần khởi động cuối. |
| `0x000C` | `EVSE_MB_SYS_SUPERVISOR_STATUS` | `uint16` | Bitmask | Bit 0: HMI Link, Bit 1: F4 Link, Bit 2: CSMS Link, Bit 3: Modules CAN, Bit 4: SECC CAN. |
| `0x000D` | `EVSE_MB_SYS_TIME_SYNC_STATE` | `uint16` | Enum | `0`: Unsynced, `1`: Synced NTP qua F4, `2`: Synced CSMS, `3`: RTC Battery. |
| `0x000E..0F`| `EVSE_MB_SYS_UTC_EPOCH_SEC` | `uint32` | Giây Epoch | Thời gian thực Unix timestamp được đồng bộ. |
| `0x0010` | `EVSE_MB_SYS_TOTAL_STATION_KW` | `uint16` | kW | Tổng công suất danh định trạm (ví dụ: `180` tương ứng 180 kW). |
| `0x0011` | `EVSE_MB_SYS_POWER_ALLOC_MODE` | `uint16` | Enum | `0`: Cố định 50/50 (90kW + 90kW), `1`: Tự động động (Dynamic Smart Share), `2`: Ưu tiên súng A. |
| `0x0012` | `EVSE_MB_SYS_GUN_A_REQ_POWER_KW` | `uint16` | kW | Công suất sạc xe tại Súng A đang yêu cầu qua giao thức CCS2. |
| `0x0013` | `EVSE_MB_SYS_GUN_A_ALLOC_POWER_KW`| `uint16` | kW | Công suất tối đa bộ điều phối cấp phát cho Súng A. |
| `0x0014` | `EVSE_MB_SYS_GUN_A_ACT_POWER_KW` | `uint16` | kW | Công suất sạc thực tế đang phát tại Súng A ($V \times I / 1000$). |
| `0x0015` | `EVSE_MB_SYS_GUN_B_REQ_POWER_KW` | `uint16` | kW | Công suất sạc xe tại Súng B đang yêu cầu. |
| `0x0016` | `EVSE_MB_SYS_GUN_B_ALLOC_POWER_KW`| `uint16` | kW | Công suất tối đa bộ điều phối cấp phát cho Súng B. |
| `0x0017` | `EVSE_MB_SYS_GUN_B_ACT_POWER_KW` | `uint16` | kW | Công suất sạc thực tế đang phát tại Súng B. |
| `0x0018` | `EVSE_MB_SYS_IDENTITY_VERSION` | `uint16` | Hằng số `1` | Phiên bản cơ chế định danh phần cứng (Schema Identity v1). |
| `0x0019..1E`| `EVSE_MB_SYS_H7_UID_BASE` | 6 thanh ghi | 12 bytes Hex | **Mã 96-bit Unique ID gốc của vi điều khiển STM32H743** (`0x1FF1E800`). Đây là nguồn sự thật duy nhất (Single Source of Truth) để tính ra Station Alias 8-hex ký tự `EVSE_%08lX` qua CRC32. |

---

## 3. VÙNG 2 & 3: DỮ LIỆU TELEMETRY SÚNG SẠC A & B (`0x0100` & `0x0200`)
*Chế độ truy cập: Read-Only (Function Code `0x03` hoặc `0x04`)*  
*Cấu trúc: Súng A tại base `0x0100`, Súng B tại base `0x0200` với cùng offset tương đối `+0x00`..`+0x29`.*

| Offset Súng A | Offset Súng B | Tên trường thanh ghi | Kiểu | Đơn vị / Hệ số | Mô tả chức năng kỹ thuật |
| :---: | :---: | :--- | :---: | :---: | :--- |
| `0x0100` | `0x0200` | `EVSE_MB_CON_SNAPSHOT_SEQ_BEGIN` | `uint16` | Số đếm vòng | Khóa bảo vệ chống rách dữ liệu (Snapshot Barrier Begin). Tăng mỗi lần H743 cập nhật dữ liệu. |
| `0x0101` | `0x0201` | `EVSE_MB_CON_SESSION_STATE` | `uint16` | Enum (`0 - 10`) | **Trạng thái máy phiên sạc chính:**<br>`0`: Unavailable<br>`1`: Idle (Sẵn sàng)<br>`2`: Plugged (Đã cắm súng)<br>`3`: AwaitingAuth (Chờ xác thực)<br>`4`: Authorized (Đã chấp thuận)<br>`5`: Preparing (Đang chuẩn bị, test IMD/Precharge)<br>`6`: Charging (Đang sạc dòng cao)<br>`7`: Stopping (Đang giảm dòng dừng sạc)<br>`8`: Completed (Sạc hoàn thành)<br>`9`: Faulted (Sự cố)<br>`10`: EmergencyStop (Dừng khẩn cấp E-Stop). |
| `0x0102` | `0x0202` | `EVSE_MB_CON_SUB_STATE` | `uint16` | Enum (`0 - 15`) | **Trạng thái bước chi tiết (Sub-state FSM):**<br>`1`: Locking ngàm súng<br>`2`: IMD test cách điện<br>`3`: Precharge mồi áp<br>`4`: Voltage match khớp áp<br>`5`: Contactor đóng<br>`6`: Ramp-up tăng dòng<br>`10`: Ramp-down hạ dòng<br>`11`: Contactor mở<br>`12`: Bleeder xả tụ áp cao<br>`13`: Safe to unlock ($V_{\text{OUT}} < 20\text{V}$)<br>`14`: Unlocking nhả khóa ngàm<br>`15`: Stopped done hoàn tất. |
| `0x0103` | `0x0203` | `EVSE_MB_CON_PLUG_STATE` | `uint16` | Enum (`0 - 2`) | `0`: Disconnected (CP State A), `1`: Connected (CP State B), `2`: Ready/Ventilation (CP State C/D). |
| `0x0104` | `0x0204` | `EVSE_MB_CON_LOCK_STATE` | `uint16` | Enum (`0 - 4`) | `0`: Unlocked, `1`: Locking, `2`: Locked, `3`: Unlocking, `4`: LockFault. |
| `0x0105` | `0x0205` | `EVSE_MB_CON_CONTACTOR_CMD` | `uint16` | `0` hoặc `1` | Lệnh lái rơ-le Contactor DC từ MCU (`0`: Mở, `1`: Đóng). |
| `0x0106` | `0x0206` | `EVSE_MB_CON_CONTACTOR_FEEDBACK` | `uint16` | Enum (`0 - 2`) | Tiếp điểm phụ phản hồi (`0`: Mở, `1`: Đóng, `2`: Lệch pha/Aux Mismatch). |
| `0x0107` | `0x0207` | `EVSE_MB_CON_DATA_VALID_FLAGS` | `uint16` | Bitmask | Bit 0: SoC hợp lệ, Bit 1: Thời gian còn lại hợp lệ, Bit 2: Nhiệt độ pin hợp lệ, Bit 3: Yêu cầu BMS hợp lệ, Bit 4: Công tơ DC hợp lệ. |
| `0x0108` | `0x0208` | `EVSE_MB_CON_AUTH_STATE` | `uint16` | Enum (`0 - 4`) | `0`: None, `1`: Pending chờ, `2`: Accepted chấp thuận, `3`: Rejected từ chối, `4`: Expired hết hạn. |
| `0x0109` | `0x0209` | `EVSE_MB_CON_AUTH_TYPE` | `uint16` | Enum (`0 - 4`) | `0`: None, `1`: Mobile App QR, `2`: Thẻ vật lý RFID, `3`: VIN / AutoCharge PnC, `4`: Free/Service. |
| `0x010A` | `0x020A` | `EVSE_MB_CON_SOC_PERCENT` | `uint16` | % (`0 - 100`) | **Dung lượng Pin xe hiện tại** (nhận diện qua SECC CAN ID `0x18B856F4`). |
| `0x010B` | `0x020B` | `EVSE_MB_CON_START_SOC_PERCENT` | `uint16` | % (`0 - 100`) | Dung lượng Pin xe tại thời điểm bắt đầu phiên sạc. |
| `0x010C..0D`| `0x020C..0D`| `EVSE_MB_CON_OUTPUT_VOLTAGE` | `uint32` | **0.1 V** | **Điện áp ngõ ra DC thực tế tại đầu súng** ($V_{\text{OUTPUT}} = \text{Giá trị} / 10$). |
| `0x010E..0F`| `0x020E..0F`| `EVSE_MB_CON_OUTPUT_CURRENT` | `int32` | **0.1 A** | **Dòng điện DC nạp vào xe thực tế** ($I_{\text{OUTPUT}} = \text{Giá trị} / 10$). Dấu dương là sạc. |
| `0x0110..11`| `0x0210..11`| `EVSE_MB_CON_OUTPUT_POWER` | `uint32` | **1 W** | Công suất đầu ra tức thời (Chia 1000 để ra kW). |
| `0x0112..13`| `0x0212..13`| `EVSE_MB_CON_SESSION_ENERGY` | `uint32` | **1 Wh** | **Điện năng tiêu thụ phiên sạc lũy kế** (Chia 1000 để ra kWh). |
| `0x0114..15`| `0x0214..15`| `EVSE_MB_CON_ELAPSED_SEC` | `uint32` | Giây (s) | Thời gian đã sạc thực tế tính từ lúc đóng contactor. |
| `0x0116` | `0x0216` | `EVSE_MB_CON_REMAINING_MIN` | `uint16` | Phút | Thời gian ước tính sạc đầy do BMS xe tính toán và SECC gửi về. |
| `0x0117` | `0x0217` | `EVSE_MB_CON_GUN_TEMP_0P1C` | `uint16` | **0.1 °C** | Nhiệt độ cảm biến đầu súng sạc PT1000. |
| `0x0118..19`| `0x0218..19`| `EVSE_MB_CON_LOCAL_SESSION_ID` | `uint32` | ID phiên sạc | Mã phiên sạc nội bộ trạm tạo ra để liên kết với F4 và HMI. |
| `0x011A` | `0x021A` | `EVSE_MB_CON_BMS_REQ_VOLT_0P1V` | `uint16` | 0.1 V | Điện áp yêu cầu từ BMS xe gửi qua CAN SECC (`0x18B656F4`). |
| `0x011B` | `0x021B` | `EVSE_MB_CON_BMS_REQ_CURR_0P1A` | `uint16` | 0.1 A | Dòng điện yêu cầu từ BMS xe gửi qua CAN SECC (`0x18B656F4`). |
| `0x011C` | `0x021C` | `EVSE_MB_CON_BMS_MAX_VOLT_0P1V` | `uint16` | 0.1 V | Giới hạn điện áp pin tối đa xe cho phép (`0x18B456F4`). |
| `0x011D` | `0x021D` | `EVSE_MB_CON_BMS_MAX_CURR_0P1A` | `uint16` | 0.1 A | Giới hạn dòng sạc tối đa xe cho phép (`0x18B456F4`). |
| `0x011E` | `0x021E` | `EVSE_MB_CON_BMS_BATTERY_TEMP` | `uint16` | 0.1 °C | Nhiệt độ pin xe do BMS truyền về. |
| `0x011F` | `0x021F` | `EVSE_MB_CON_INTERNAL_STOP_REASON`| `uint16`| Enum (`0 - 8`) | Lý do dừng sạc (`EvseStopCause_t`): 1: User, 2: Remote CSMS, 3: Xe ngắt, 4: E-Stop, 5: IMD, 6: Quá nhiệt, 7: Quá dòng, 8: Lỗi phần cứng. |
| `0x0120` | `0x0220` | `EVSE_MB_CON_PRIMARY_FAULT_CODE` | `uint16` | Hex code | Mã lỗi chính gây ngắt trạm (Ví dụ: `0x0001` = E-Stop). |
| `0x0121` | `0x0221` | `EVSE_MB_CON_ACTIVE_FAULT_BITS_1`| `uint16` | Bitmask | Bitmask các cờ lỗi phần cứng đang kích hoạt. |
| `0x0122` | `0x0222` | `EVSE_MB_CON_ACTIVE_FAULT_BITS_2`| `uint16` | Bitmask | Bitmask các cờ cảnh báo truyền thông và phụ trợ. |
| `0x0123` | `0x0223` | `EVSE_MB_CON_SNAPSHOT_SEQ_END` | `uint16` | Số đếm vòng | Khóa kết thúc snapshot. Điều kiện dữ liệu toàn vẹn: `SEQ_BEGIN == SEQ_END`. |
| `0x0124..25`| `0x0224..25`| `EVSE_MB_CON_TOTAL_ENERGY` | `uint32` | **1 Wh** | Tổng chỉ số công tơ điện DC tích lũy trọn đời của súng sạc. |
| `0x0126` | `0x0226` | `EVSE_MB_CON_EVCC_ID_0_1` | `uint16` | Hex Word | 2 byte đầu tiên của địa chỉ MAC xe điện (Byte 0 MSB, Byte 1 LSB). |
| `0x0127` | `0x0227` | `EVSE_MB_CON_EVCC_ID_2_3` | `uint16` | Hex Word | 2 byte giữa của địa chỉ MAC xe điện (Byte 2 MSB, Byte 3 LSB). |
| `0x0128` | `0x0228` | `EVSE_MB_CON_EVCC_ID_4_5` | `uint16` | Hex Word | 2 byte cuối của địa chỉ MAC xe điện (Byte 4 MSB, Byte 5 LSB). |
| `0x0129` | `0x0229` | `EVSE_MB_CON_EVCC_ID_LEN` | `uint16` | Số byte | Độ dài MAC: `0` nếu chưa cắm xe hoặc xe không hỗ trợ PLC; `6` nếu đã đọc thành công MAC 6-byte phục vụ tính năng **AutoCharge**. |

---

## 4. VÙNG 4: F4 BUSINESS MIRROR & TARIFFS (`0x0500 - 0x051A`)
*Chế độ truy cập: Read-Only (Function Code `0x03` hoặc `0x04`)*  
*Mục đích: STM32F429 nhận dữ liệu từ CSMS Cloud rồi ghi vào H743 qua UART7, màn hình cảm ứng HMI đọc qua USART6 để hiển thị biểu giá và cước sạc trực tiếp.*

| Offset | Tên trường thanh ghi | Kiểu | Đơn vị | Mô tả chức năng |
| :---: | :--- | :---: | :---: | :--- |
| `0x0500` | `EVSE_MB_F4_BUSINESS_HEARTBEAT` | `uint16` | Số đếm | Nhịp tim F429 gửi sang H743. |
| `0x0501` | `EVSE_MB_F4_DATA_VALID` | `uint16` | `0` / `1` | `1`: Dữ liệu giá hợp lệ từ Cloud, `0`: Chưa nhận được giá. |
| `0x0503..04`| `EVSE_MB_F4_TARIFF_RATE_VND` | `uint32` | VNĐ / kWh | Đơn giá điện sạc hiện tại CSMS cấu hình (ví dụ: `3850` VNĐ/kWh). |
| `0x0505..06`| `EVSE_MB_F4_SERVICE_FEE_VND` | `uint32` | VNĐ | Phí dịch vụ cố định tính trên mỗi phiên sạc. |
| `0x0507..08`| `EVSE_MB_F4_RUNNING_COST_A` | `uint32` | VNĐ | Chi phí tiền điện sạc tức thời của Súng A ($= \text{kWh} \times \text{Đơn giá}$). |
| `0x0509..0A`| `EVSE_MB_F4_RUNNING_COST_B` | `uint32` | VNĐ | Chi phí tiền điện sạc tức thời của Súng B. |
| `0x050B` | `EVSE_MB_F4_CSMS_CONN_STATUS` | `uint16` | Enum | `0`: Mất mạng, `1`: Đã kết nối TCP, `2`: WebSocket Online. |
| `0x050C` | `EVSE_MB_F4_TIME_SYNC_STATE` | `uint16` | Enum | Trạng thái đồng bộ thời gian từ CSMS. |
| `0x050D..0E`| `EVSE_MB_F4_UTC_EPOCH_HI_LO` | `uint32` | Giây Epoch | Thời gian thực Unix timestamp từ máy chủ đám mây. |
| `0x050F` | `EVSE_MB_F4_WIFI_STATE` | `uint16` | Enum (`0 - 5`) | `0`: Off, `1`: Scanning, `2`: Connecting, `3`: Connected, `4`: IP_Ready, `5`: Failed. |
| `0x0510` | `EVSE_MB_F4_WIFI_RSSI` | `int16` | dBm | Độ mạnh sóng Wi-Fi của modem ESP32-C6 (ví dụ: `-65` dBm). |
| `0x0511..12`| `EVSE_MB_F4_WIFI_IP_HI_LO` | `uint32` | IPv4 Address | Địa chỉ IP mạng của trạm (Byte 0..3). |
| `0x0513` | `EVSE_MB_F4_CSMS_PHASE` | `uint16` | Enum (`0 - 6`) | `0`: Off, `1`: DNS Resolve, `2`: TCP Socket, `3`: TLS Handshake, `4`: WS Upgrade, `5`: Online Heartbeat, `6`: Rejected Auth. |
| `0x0514` | `EVSE_MB_F4_CSMS_HTTP_CODE` | `uint16` | HTTP Code | Mã phản hồi HTTP (`101` Switching Protocols, `401`, `403`...). |
| `0x0515` | `EVSE_MB_F4_HEARTBEAT_ACK_COUNT`| `uint16` | Số đếm | Số bản tin Heartbeat OCPP được CSMS phản hồi thành công. |
| `0x0516` | `EVSE_MB_F4_FW_VERSION_MAJ_MIN` | `uint16` | Pack | Phiên bản Major & Minor của Firmware F429. |
| `0x0517` | `EVSE_MB_F4_FW_VERSION_PATCH` | `uint16` | Số nguyên | Phiên bản Patch của Firmware F429. |
| `0x0518` | `EVSE_MB_ESP32_FW_VERSION_MAJ_MIN`| `uint16`| Pack | Phiên bản Major & Minor của Firmware ESP32-C6. |
| `0x0519` | `EVSE_MB_ESP32_FW_VERSION_PATCH`| `uint16` | Số nguyên | Phiên bản Patch của Firmware ESP32-C6. |
| `0x051A` | `EVSE_MB_F4_BINDING_STATUS` | `uint16` | Enum (`0 - 2`) | `0`: Chờ ghép nối, `1`: Đã ghép nối phần cứng thành công, `2`: Xung đột phần cứng (Hardware UID mismatch). |

---

## 5. VÙNG 5: HỘP THƯ LỆNH MÀN HÌNH HMI (HMI COMMAND MAILBOX `0x0700 - 0x073F`)
*Cơ chế điều khiển: Hộp thư lệnh nguyên tử (Atomic Mailbox) có khóa `COMMIT_MAGIC`.*  
*Đường truyền vật lý: Độc quyền qua cổng `USART6` của STM32H743.*

### A. Thanh ghi Ghi Lệnh từ HMI xuống H743 (Function Code `0x10` - Write Multiple Registers):
HMI bắt buộc phải ghi toàn bộ chuỗi **9 thanh ghi liên tiếp (`0x0700` đến `0x0708`)** trong một bản tin Modbus duy nhất:

| Offset | Tên thanh ghi | Kiểu dữ liệu | Giá trị ghi vào | Ý nghĩa & Quy tắc bắt buộc |
| :---: | :--- | :---: | :---: | :--- |
| `0x0700` | `HMI_CMD_REQ_SEQ_HI` | `uint16` | Word cao | Số Sequence 32-bit tăng dần mỗi lần tài xế bấm nút trên màn hình. |
| `0x0701` | `HMI_CMD_REQ_SEQ_LO` | `uint16` | Word thấp | Số Sequence 32-bit (chống thực thi lặp lệnh / Deduplication). |
| `0x0702` | `HMI_BOOT_SESSION_ID_HI`| `uint16` | Word cao | Mã Boot ID của H743 (đọc từ `0x0007..08` trước khi gửi). |
| `0x0703` | `HMI_BOOT_SESSION_ID_LO`| `uint16` | Word thấp | Nếu Boot ID không khớp, H743 sẽ hủy lệnh để tránh gửi lệnh sai phiên boot. |
| `0x0704` | `HMI_CMD_REQ_ID` | `uint16` | Enum | **Mã lệnh điều khiển:**<br>`1`: `CMD_START` (Bắt đầu sạc tại chỗ)<br>`2`: `CMD_STOP` (Dừng sạc khẩn cấp/thường)<br>`3`: `CMD_CLEAR_FAULT` (Xóa cờ sự cố)<br>`4`: `CMD_RESET_CONNECTOR` (Khởi động lại cổng sạc)<br>`5`: `CMD_UNLOCK_GUN` (Mở khóa cơ khí ngàm súng)<br>`6`: `CMD_SET_STRATEGY` (Cài đặt chỉ tiêu sạc: Theo tiền, % pin hoặc thời gian)<br>`7`: `CMD_REQUEST_QR_TOKEN` (Yêu cầu sinh mã QR thanh toán động)<br>`8`: `CMD_CANCEL_QR_TOKEN` (Hủy mã QR). |
| `0x0705` | `HMI_CMD_REQ_TARGET` | `uint16` | `1`, `2`, `3` | `1`: Súng A (Connector 1), `2`: Súng B (Connector 2), `3`: Cả 2 súng. |
| `0x0706` | `HMI_CMD_REQ_PARAM_1` | `uint16` | Tham số 1 | Chế độ sạc (0: Đầy tự ngắt, 1: Giới hạn thời gian, 2: Giới hạn % SoC, 3: Giới hạn số tiền). |
| `0x0707` | `HMI_CMD_REQ_PARAM_2` | `uint16` | Tham số 2 | Giá trị chỉ tiêu cài đặt (Ví dụ: đặt sạc đến `80`% SoC). |
| `0x0708` | `HMI_CMD_COMMIT` | `uint16` | **`0xA55A`** | **CHÌA KHÓA THỰC THI (MAGIC COMMIT):** H743 chỉ thi hành lệnh khi thanh ghi này mang đúng giá trị `0xA55A`. Nếu thiếu hoặc sai, frame bị loại bỏ ngay lập tức! |

### B. Thanh ghi Phản hồi Kết quả Lệnh (H743 $\rightarrow$ HMI, Đọc qua FC `0x03`/`0x04` tại `0x0720 - 0x0725`):
Ngay sau khi ghi lệnh, HMI đọc vùng này để hiển thị trạng thái xử lý cho người dùng:

| Offset | Tên thanh ghi | Kiểu | Mô tả kết quả trả về từ H743 |
| :---: | :--- | :---: | :--- |
| `0x0720..21`| `HMI_ACK_SEQ_HI_LO` | `uint32` | Số Sequence phản hồi (so khớp chính xác với `REQ_SEQ` HMI đã gửi). |
| `0x0722` | `HMI_ACK_ID` | `uint16` | Mã lệnh H743 vừa tiếp nhận và xử lý. |
| `0x0723` | `HMI_ACK_STATUS` | Enum (`0 - 6`) | **Trạng thái thực thi lệnh:**<br>`0`: Idle (Không có lệnh)<br>`1`: Received (Đã nhận frame)<br>`2`: **Accepted** (Lệnh hợp lệ, đưa vào hàng đợi an toàn)<br>`3`: **Executing** (Đang kéo contactor / đóng nguồn)<br>`4`: **Completed** (Thi hành thành công hoàn tất)<br>`5`: **Rejected** (Từ chối thi hành - Xem lý do ở `0x0724`)<br>`6`: **Failed** (Thực thi thất bại phần cứng). |
| `0x0724` | `HMI_ACK_REJECT_REASON` | Enum (`0 - 11`)| **Mã nguyên nhân từ chối lệnh:**<br>`0`: Không có lỗi<br>`1`: AuthRequired (Chưa có xác thực hợp lệ)<br>`2`: NotPlugged (Chưa cắm súng sạc vào xe)<br>`3`: AlreadyCharging (Trụ đang trong phiên sạc khác)<br>`4`: EStopActive (Nút E-Stop đang bị nhấn)<br>`5`: SystemFault (Hệ thống đang báo lỗi cách điện/quá áp)<br>`6`: PowerUnavailable (Công suất nguồn không đủ)<br>`7`: VehicleNotReady (Xe chưa sẵn sàng qua sóng PLC)<br>`8`: QueueBusy (Hàng đợi điều khiển đang bận). |
| `0x0725` | `HMI_RESULT_REASON` | `uint16` | Mã chi tiết kết quả phần cứng khi lệnh Completed hoặc Failed. |

---

## 6. VÙNG 6: BÀN ĐIỀU KHIỂN TỪ F429 / CSMS CLOUD (`0x0740 - 0x077F`)
*Đường truyền vật lý: Độc quyền qua cổng `UART7` của STM32H743.*  
*Đóng vai trò: Kênh thực thi các lệnh từ xa của máy chủ CSMS (RemoteStartTransaction, RemoteStopTransaction, UnlockConnector, HardReset).*

### A. Thanh ghi Ghi Lệnh từ F429 (FC `0x10` ghi tại `0x0740 - 0x074B`):
| Offset | Tên thanh ghi | Kiểu dữ liệu | Ý nghĩa chức năng |
| :---: | :--- | :---: | :--- |
| `0x0740..41`| `F4_CMD_REQ_SEQ` | `uint32` | Số Sequence 32-bit tăng dần của F429. |
| `0x0742..43`| `F4_BOOT_SESSION_ID` | `uint32` | Mã Boot ID của H743. |
| `0x0744` | `F4_CMD_REQ_ID` | `uint16` | `1`: RemoteStart, `2`: RemoteStop, `3`: UnlockConnector, `4`: ChangeAvailability, `5`: SetAuthPermit, `6`: Reset. |
| `0x0745` | `F4_CMD_REQ_TARGET` | `uint16` | `1`: Súng A, `2`: Súng B. |
| `0x0746..47`| `F4_AUTH_PERMIT_ID` | `uint32` | Mã giấy phép ủy quyền phiên sạc do CSMS cấp sau khi kiểm tra số dư ví tài xế. |
| `0x0748..49`| `F4_AUTH_LOCAL_SESSION_ID`| `uint32` | Bắt buộc phải khớp với `LOCAL_SESSION_ID` của súng sạc để chống tấn công phát lại (Replay Attack). |
| `0x074A` | `F4_AUTH_PERMIT_TTL_SEC` | `uint16` | Thời hạn hiệu lực của giấy phép ủy quyền (tính theo giây Monotonic tick). |
| `0x074B` | `F4_CMD_COMMIT` | `uint16` | **`0xA55A`** (Chìa khóa bắt buộc để H743 thực thi lệnh). |

### B. Thanh ghi Phản hồi Kết quả Lệnh F429 (Đọc tại `0x0760 - 0x0765`):
- `0x0760..61`: `F4_ACK_SEQ` (uint32).
- `0x0762`: `F4_ACK_ID`.
- `0x0763`: `F4_ACK_STATUS` (`Accepted`, `Executing`, `Completed`, `Rejected`, `Failed`).
- `0x0764`: `F4_ACK_REJECT_REASON`.
- `0x0765`: `F4_RESULT_REASON`.

---

## 7. VÙNG 7: MÃ TOKEN & VIETQR THANH TOÁN ĐỘNG (`0x0800 - 0x0814`)
*Chế độ truy cập: Read-Only (Function Code `0x03` hoặc `0x04`)*  
*Mục đích: Cung cấp chuỗi mã QR thanh toán động cho màn hình cảm ứng HMI hiển thị, hỗ trợ tài xế quét sạc qua ứng dụng THACO_Charge.*

| Offset | Tên thanh ghi | Kiểu dữ liệu | Mô tả chi tiết dữ liệu |
| :---: | :--- | :---: | :--- |
| `0x0800` | `EVSE_MB_QR_TOKEN_SEQ` | `uint16` | Số Sequence tạo mã QR mới (Tăng mỗi khi có phiên thanh toán mới). |
| `0x0801` | `EVSE_MB_QR_TOKEN_LEN` | `uint16` | Độ dài thực tế của chuỗi URL / Token (tối đa 32 ký tự). |
| `0x0802` | `EVSE_MB_QR_TTL_SEC` | `uint16` | **Thời gian đếm lùi hiệu lực của mã QR (giây).** HMI hiển thị thanh đếm lùi; khi về `0`, mã QR hết hạn. |
| `0x0803` | `EVSE_MB_QR_CONNECTOR_ID` | `uint16` | Cổng sạc tương ứng (`1`: Súng A, `2`: Súng B). |
| `0x0804` | `EVSE_MB_QR_FLAGS` | `uint16` | Cờ trạng thái: Bit 0: Active, Bit 1: Scanned (Tài xế đã quét), Bit 2: Expired. |
| `0x0805..14`| `EVSE_MB_QR_STRING_BASE` | 16 thanh ghi | **Chuỗi ký tự ASCII mã Token/URL QR** (32 bytes = 16 thanh ghi ghép, mỗi thanh ghi chứa 2 ký tự High/Low). |

---

## 8. BẢNG TRA CỨU MÃ ENUM & BITMASK CHUẨN TRONG HỆ THỐNG

### 8.1. Máy Trạng Thái Phiên Sạc Chính (`EvseSessionState_t`)
```c
typedef enum {
    EVSE_SESSION_STATE_UNAVAILABLE     = 0, // Cổng sạc không khả dụng / Khóa bảo trì
    EVSE_SESSION_STATE_IDLE            = 1, // Sẵn sàng, chờ cắm súng vào xe
    EVSE_SESSION_STATE_PLUGGED         = 2, // Đã cắm súng vào xe (Chân CP ở mức 9V)
    EVSE_SESSION_STATE_AWAITING_AUTH   = 3, // Chờ tài xế quét mã QR / quẹt thẻ RFID
    EVSE_SESSION_STATE_AUTHORIZED      = 4, // Xác thực thành công, tài khoản đủ số dư
    EVSE_SESSION_STATE_PREPARING       = 5, // Đang khóa ngàm súng, kiểm tra rò điện IMD, mồi áp
    EVSE_SESSION_STATE_CHARGING        = 6, // Đóng contactor, nạp dòng điện cao thế vào pin xe
    EVSE_SESSION_STATE_STOPPING        = 7, // Hạ dòng dần về 0A, chuẩn bị ngắt contactor
    EVSE_SESSION_STATE_COMPLETED       = 8, // Phiên sạc hoàn tất an toàn
    EVSE_SESSION_STATE_FAULTED         = 9, // Trạm gặp sự cố (quá áp, quá dòng, quá nhiệt)
    EVSE_SESSION_STATE_EMERGENCY_STOP  = 10 // Nút dừng khẩn cấp E-Stop trên thân tủ bị ấn
} EvseSessionState_t;
```

### 8.2. Các Bước Kỹ Thuật Chi Tiết Trong Chu Trình (`EvseSubState_t`)
```c
typedef enum {
    EVSE_SUB_STATE_NONE                = 0,
    EVSE_SUB_STATE_LOCKING             = 1,  // Đang kích hoạt động cơ khóa chốt ngàm súng
    EVSE_SUB_STATE_IMD_TEST            = 2,  // Đang đo điện trở cách điện cao thế IMD
    EVSE_SUB_STATE_PRECHARGE           = 3,  // Module nguồn xuất áp mồi trước contactor
    EVSE_SUB_STATE_VOLT_MATCH          = 4,  // Khớp điện áp trạm với điện áp cực pin xe (< 20V)
    EVSE_SUB_STATE_CONTACTOR_CLOSED    = 5,  // Đóng rơ-le contactor chính cực dương và cực âm
    EVSE_SUB_STATE_RAMP_UP             = 6,  // Tăng dần dòng sạc theo yêu cầu của xe
    EVSE_SUB_STATE_RAMP_DOWN           = 10, // Giảm dần dòng sạc về 0A trước khi ngắt
    EVSE_SUB_STATE_CONTACTOR_OPENING   = 11, // Mở tiếp điểm contactor chính
    EVSE_SUB_STATE_DISCHARGING         = 12, // Đóng điện trở bleeder xả điện áp tích tụ thanh cái
    EVSE_SUB_STATE_SAFE_TO_UNLOCK      = 13, // Xác nhận điện áp đầu súng Vout an toàn (< 20V)
    EVSE_SUB_STATE_UNLOCKING           = 14, // Nhả chốt khóa cơ học ngàm súng
    EVSE_SUB_STATE_STOPPED_DONE        = 15  // Hoàn tất chu trình, sẵn sàng cho phiên mới
} EvseSubState_t;
```

### 8.3. Danh Mục Nguyên Nhân Dừng Sạc Nội Bộ (`EvseStopCause_t`)
```c
typedef enum {
    EVSE_STOP_CAUSE_NONE               = 0,
    EVSE_STOP_CAUSE_NORMAL_USER        = 1, // Tài xế bấm Dừng sạc trên màn hình HMI hoặc App
    EVSE_STOP_CAUSE_NORMAL_REMOTE      = 2, // Máy chủ CSMS gửi lệnh RemoteStopTransaction
    EVSE_STOP_CAUSE_VEHICLE_COMPLETE   = 3, // Xe ô tô báo pin đã sạc đầy 100% hoặc đạt giới hạn cài đặt
    EVSE_STOP_CAUSE_EMERGENCY_ESTOP    = 4, // Nút dừng khẩn E-Stop bị nhấn
    EVSE_STOP_CAUSE_PROTECTIVE_IMD     = 5, // Bảo vệ kích hoạt: Cách điện cao áp bị suy hao
    EVSE_STOP_CAUSE_PROTECTIVE_OVERTEMP= 6, // Bảo vệ kích hoạt: Quá nhiệt đầu súng hoặc module nguồn
    EVSE_STOP_CAUSE_PROTECTIVE_OVERCURR= 7, // Bảo vệ kích hoạt: Quá dòng sạc DC
    EVSE_STOP_CAUSE_HARDWARE_FAILURE   = 8  // Lỗi phần cứng: Kẹt contactor, mất giao tiếp bus CAN
} EvseStopCause_t;
```

---

## 9. QUY TẮC BẢO VỆ DỮ LIỆU & AN TOÀN TRUYỀN THÔNG (INTEGRITY & SAFETY RULES)

1. **Ngăn ngừa đọc rách dữ liệu (Snapshot Integrity Barrier):**
   - Khi HMI hoặc F429 đọc telemetry súng sạc, bắt buộc phải đọc từ `+0x00` (`SNAPSHOT_SEQ_BEGIN`) đến `+0x23` (`SNAPSHOT_SEQ_END`).
   - Nếu `SNAPSHOT_SEQ_BEGIN != SNAPSHOT_SEQ_END`, gói tin vừa đọc đã bị gián đoạn giữa chu kỳ cập nhật của H743 $\longrightarrow$ Master bắt buộc phải hủy bỏ frame và đọc lại.
2. **Khóa thực thi nguyên tử (Atomic Commit `0xA55A`):**
   - Tuyệt đối không thực thi các lệnh ghi từng thanh ghi đơn lẻ (FC `0x06`).
   - Mọi lệnh điều khiển đóng contactor, cấp nguồn, dừng sạc bắt buộc phải dùng Function Code `0x10` ghi đồng thời từ đầu offset đến cuối offset, với thanh ghi cuối cùng mang giá trị `0xA55A`.
3. **Chống tấn công phát lại (Replay Attack Prevention):**
   - Mã lệnh `F4_CMD_REQ_ID` và `HMI_CMD_REQ_ID` chỉ được chấp thuận khi `BOOT_SESSION_ID` khớp chính xác với phiên khởi động của H743 và `REQ_SEQ` lớn hơn số sequence đã xử lý trước đó.

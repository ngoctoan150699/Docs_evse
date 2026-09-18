# BẢNG ÁNH XẠ THANH GHI MODBUS RTU CHUẨN
## (MASTER MODBUS RTU REGISTER MAPPING TABLE)

> **Tham chiếu đầy đủ:** Xem chi tiết cơ chế hoạt động, đóng gói khung nhị phân và sơ đồ chu trình sạc tại [INTER_MCU_COMMUNICATION_AND_REGISTERS.md](INTER_MCU_COMMUNICATION_AND_REGISTERS.md).  
> **Kiến trúc bản đồ:** Chuẩn Offset công nghiệp 16-bit (`Map Version 0x0221`) công bố bởi STM32H743 (Slave ID `0x01`), hỗ trợ cả STM32F429 (Master 1) và Android HMI (Master 2).

> **Giao thức:** Modbus RTU qua RS485 vi sai  
> **Tốc độ:** 115,200 bps, 8 Data bits, No Parity, 1 Stop bit  
> **Mô hình:** F429 là Master | H743 là Slave (Địa chỉ `0x01`) | HMI là Master/Monitor phụ

---

## 1. BẢNG THANH GHI ĐIỀU KHIỂN (HOLDING REGISTERS - 40001..40020)
*Cho phép Đọc & Ghi (Read/Write - Function Code `0x03`, `0x06`, `0x10`)*

| Địa chỉ (PLC) | Offset (Hex) | Tên thanh ghi | Đơn vị | Dải giá trị | Ý nghĩa và mô tả chức năng |
| :---: | :---: | :--- | :---: | :---: | :--- |
| **40001** | `0x0000` | `CMD_CHARGE_ENABLE` | Enum | `0`: Dừng, `1`: Bật sạc | Lệnh cho phép cấp nguồn sạc từ F429 xuống H743 |
| **40002** | `0x0001` | `SET_TARGET_VOLTAGE` | 0.1 V | `0 - 10000` (0 - 1000V) | Điện áp đầu ra yêu cầu cài đặt cho module nguồn |
| **40003** | `0x0002` | `SET_TARGET_CURRENT` | 0.1 A | `0 - 3000` (0 - 300A) | Giới hạn dòng điện đầu ra cài đặt cho module nguồn |
| **40004** | `0x0003` | `CMD_STOP_REASON` | Enum | `0 - 10` | Lý do dừng sạc (0: Normal, 1: Emergency, 2: Remote, 3: Fault) |
| **40005** | `0x0004` | `CMD_RESET_FAULT` | Bit | `1`: Xóa lỗi | Lệnh yêu cầu H743 xóa cờ lỗi sau khi sự cố đã khắc phục |
| **40006** | `0x0005` | `SET_MAX_POWER_LIMIT`| 0.1 kW| `0 - 3000` (0 - 300kW) | Giới hạn công suất tối đa theo chính sách Smart Charging |
| **40007** | `0x0006` | `HEARTBEAT_COUNTER` | Số đếm| `0 - 65535` | Nhịp tim sống giữa F429 và H743 (quá 3s không đổi -> ngắt sạc) |
| **40008** | `0x0007` | `CMD_MAILBOX_ACTION` | Enum | `1`: Start, `2`: Stop | Hộp thư lệnh từ màn hình cảm ứng HMI gửi sang |

---

## 2. BẢNG THANH GHI TRẠNG THÁI & ĐO ĐẾM (INPUT REGISTERS - 30001..30050)
*Chỉ cho phép Đọc (Read Only - Function Code `0x04`)*

| Địa chỉ (PLC) | Offset (Hex) | Tên thanh ghi | Đơn vị | Dải giá trị | Ý nghĩa và mô tả chức năng |
| :---: | :---: | :--- | :---: | :---: | :--- |
| **30001** | `0x0000` | `EVSE_STATE` | Enum | `0 - 7` | Trạng thái trạm (0: Idle, 1: Preparing, 2: Charging, 3: Suspended, 4: Fault) |
| **30002** | `0x0001` | `CCS_PILOT_STATE` | Enum | `1 - 6` | Trạng thái chân Pilot (1: A-12V, 2: B-9V, 3: C-6V, 4: D-3V, 5: E/F-Error) |
| **30003** | `0x0002` | `PRESENT_VOLTAGE` | 0.1 V | `0 - 10000` | Điện áp DC thực tế đo được tại đầu ra súng sạc |
| **30004** | `0x0003` | `PRESENT_CURRENT` | 0.1 A | `0 - 3000` | Dòng điện DC thực tế đang nạp vào xe ô tô |
| **30005** | `0x0004` | `EV_SOC_PERCENT` | % | `0 - 100` | Tỷ lệ % dung lượng pin hiện tại của xe (do SECC báo về) |
| **30006** | `0x0005` | `TOTAL_ENERGY_KWH_H`| kWh (Cao)| `0 - 65535` | 16-bit cao của tổng điện năng tiêu thụ đo từ DCM230 |
| **30007** | `0x0006` | `TOTAL_ENERGY_KWH_L`| kWh (Thấp)| `0 - 65535` | 16-bit thấp của tổng điện năng tiêu thụ (tính bằng Wh) |
| **30008** | `0x0007` | `SESSION_DURATION_SEC`| Giây | `0 - 65535` | Thời gian sạc tích lũy của phiên hiện tại |
| **30009** | `0x0008` | `HARDWARE_FAULT_BITS`| Bitmask| `0x0000 - 0xFFFF`| Mã lỗi phần cứng (Bit 0: E-Stop, Bit 1: IMD, Bit 2: OverV, Bit 3: OverI) |
| **30010** | `0x0009` | `MODULE_TEMP_MAX` | 0.1 ℃ | `0 - 1500` | Nhiệt độ cao nhất của khối module nguồn AcePower |
| **30011** | `0x000A` | `GUN_TEMPERATURE` | 0.1 ℃ | `0 - 1500` | Nhiệt độ cảm biến đầu súng sạc DC |
| **30012** | `0x000B` | `ACTIVE_FIRMWARE_BANK`| Enum | `1`: Bank 1, `2`: Bank 2| Bank Flash hiện tại đang chạy code trên STM32H743 |

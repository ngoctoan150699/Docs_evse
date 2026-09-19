# BỘ CÔNG CỤ GIẢ LẬP PHẦN CỨNG & TEST HARNESS
## (HARDWARE SIMULATORS & AUTOMATED TEST PROCEDURES)

Tài liệu này hướng dẫn cách sử dụng các công cụ giả lập phần cứng PC-side để kiểm thử trọn vẹn firmware trạm sạc STM32H743 mà không cần đấu nối xe điện thật và tủ điện cao thế 1000V.

---

## 1. DANH MỤC BỘ CÔNG CỤ GIẢ LẬP TRONG DỰ ÁN

| Tên công cụ | Thư mục mã nguồn / Binary | Chuẩn giao tiếp | Mục đích kiểm thử |
| :--- | :--- | :--- | :--- |
| **SECC USB-CAN B Simulator** | `tools/can_tools/secc_can_sim/` | FDCAN2 **250 kbps** (ControlCAN.dll) | **Giả lập bộ điều khiển SECC DB-SECC-601 và xe điện CCS2**. Tự động chạy chuỗi bắt tay 11 bước ISO 15118-20 EIM DC (State A $\rightarrow$ B $\rightarrow$ C/D $\rightarrow$ Precharge $\rightarrow$ Charge Loop 50ms $\rightarrow$ Welding Detection). |
| **AcePower Module Simulator** | `tools/can_tools/power_module_sim/` | FDCAN1 **125 kbps** | Giả lập dàn module nguồn công suất AcePower AB-U2T (1000V / 250A). Phản hồi lệnh `AllSetData` (0x029C0000) và phát telemetry điện áp, dòng điện. |
| **OCPP Backend Mock Server** | `tools/ocpp_backend/` | WebSocket JSON (OCPP 1.6J) | Giả lập máy chủ đám mây CSMS cục bộ để kiểm thử các bản tin Boot, Authorize, Start, Stop, MeterValues mà không cần internet. |
| **Headless Auto Integration Test**| `tools/hardware_headless_integration_test.py`| Toàn bộ bus | Kịch bản tự động hóa 100% kiểm thử FDCAN handshake, đọc báo cáo PASS/FAIL tự động xuất ra file Markdown. |
| **MQTT Fleet OTA CLI** | `tools/network_tools/ota_mqtt.py` | MQTT EMQX | Công cụ dòng lệnh phát gói tin nâng cấp firmware OTA qua MQTT broker. |

---

## 2. HƯỚNG DẪN KIỂM THỬ GIẢ LẬP SECC CCS2 (DB-SECC-601)

> 📘 **Tài liệu tham chiếu chuẩn:** [ISO15118_20_SECC_CHARGING_FLOW_SPECIFICATION.md](../01_EMBEDDED_FIRMWARE/ISO15118_20_SECC_CHARGING_FLOW_SPECIFICATION.md).

### 2.1. Chuẩn bị Phần cứng
1. Thiết bị chuyển đổi **USB-CAN B** (kết nối cổng USB của máy tính).
2. Nối dây CAN_H vào chân `PB13` (FDCAN2_TX) và CAN_L vào chân `PB12` (FDCAN2_RX) của bo mạch STM32H743XI (kèm trở đầu cuối $120\,\Omega$).
3. Đảm bảo tốc độ baudrate trên phần mềm là **250 kbps**.

### 2.2. Khởi chạy giao diện GUI SECC Simulator
- Cách 1: Chạy file thực thi độc lập đã đóng gói sẵn:
  ```text
  d:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743\tools\can_tools\secc_can_sim\package\SECC_USB_CAN_Simulator.exe
  ```
- Cách 2: Chạy file script batch:
  ```powershell
  cd d:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743\tools\can_tools\secc_can_sim
  .\run_secc_gui.bat
  ```

### 2.3. Quy trình Kiểm thử 11 Bước Sạc ISO 15118-20

Trên giao diện giả lập `SECC_USB_CAN_Simulator`:
1. **Bước 1 (Chờ súng - State A)**: 
   - Phần mềm phát `SECC_Status` (`0x18B056F4`) mang trạng thái `0x01` (`SeccChargeIdle`).
   - Kiểm tra log STM32: Trạng thái hiển thị `CHARGER_STATE_AVAILABLE`, contactor mở (`ContactorState = Open`).
2. **Bước 2 (Cắm súng - State B)**:
   - Bấm nút **"Plug In"** trên GUI. Phần mềm chuyển sang State B, phát `0x02` (`SeccDetectedPlugin`).
   - Kiểm tra log STM32: H743 chuyển sang `CHARGER_STATE_PLUGGED`, phản hồi `CcuChgPortState = Ready(1)`.
3. **Bước 3 (Bắt tay PLC & Chọn giao thức)**:
   - GUI tự động chuyển PWM CP sang 5%, chạy SLAC `0x17` (`DlinkEstablished`), gửi `0x20` $\rightarrow$ `0x25` (`SupportedAppProtocol`).
   - Kiểm tra: H743 phản hồi cờ `CcuProIso20Support = 1`.
4. **Bước 4 (Session Setup & Đọc MAC Xe)**:
   - GUI phát `SECC_EvEvccId` (`0x18B356F4`) chứa địa chỉ MAC 6-byte của xe (ví dụ: `38:2C:4A:A1:B2:C3`).
   - Kiểm tra: H743 nhận diện thành công EVCC ID và đẩy sang F4/HMI phục vụ tính năng **AutoCharge**.
5. **Bước 5 (Trao đổi tham số & Kiểm tra cáp)**:
   - GUI phát `0x60` (`ChargeParameterDiscovery`) và `0x61` (`CableCheck`), chuyển CP sang State C.
   - Kiểm tra: H743 gửi `CCU_EvseChgMaxLimits` (1000V/250A) và báo `CableCheckState = Done(2)`.
6. **Bước 6 (Precharge & Đóng Contactor)**:
   - GUI phát `0x62` (`PreCharge`) với điện áp pin `EvPresentVolt = 400.0V`.
   - Kiểm tra: H743 kích hoạt module AcePower nâng áp lên 400.0V. Khi chênh lệch $|\Delta V| \le 20\text{V}$, contactor đóng (`ContactorState = Close`).
7. **Bước 7 (Vòng sạc chính - Charge Loop 50ms)**:
   - GUI phát `0x63` (`ISO20DCChargeLoop`) với `EvTargetCrnt = 50.0A`, `EvTargetVolt = 410.0V`, `EvPresentSoc = 45%`.
   - Kiểm tra: AcePower phát dòng 50A, màn hình HMI cập nhật đồng hồ % pin và công suất kW tức thời.
8. **Bước 8 (Dừng sạc an toàn & Ngắt Contactor $< 5\text{A}$)**:
   - Bấm nút **"Stop Charging"** trên GUI hoặc trên màn hình HMI.
   - **Xác minh quy tắc an toàn quan trọng**: Module AcePower hạ dòng về 0A. Khi dòng thực tế tụt xuống $\le 5.0\text{A}$, H743 mới mở contactor (`ContactorState = Open`).
   - GUI phát `0x64` (`WeldingDetection`), mạch xả bleeder kéo áp DC về $< 20\text{V}$.
   - Rút súng: Hệ thống an toàn trở về State A (Idle).

---

## 3. QUY TRÌNH CHẠY TEST LIÊN THÔNG TỰ ĐỘNG (HEADLESS REGRESSION TEST)

Để chạy kiểm thử hồi quy tự động không cần bấm tay:

```powershell
# Chuyển vào thư mục project evse_h743
cd D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743

# Kích hoạt kịch bản kiểm thử tích hợp tự động
python tools/hardware_headless_integration_test.py
```

Báo cáo kết quả kiểm tra từng chỉ tiêu kỹ thuật được tự động lưu trữ tại:
`tools/logs/reports/integration_report_YYYYMMDD_HHMMSS.md`.

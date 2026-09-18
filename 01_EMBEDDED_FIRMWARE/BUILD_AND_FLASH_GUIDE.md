# CẨM NANG BIÊN DỊCH, NẠP FLASH & TEST TỰ ĐỘNG PHẦN CỨNG
## (MULTI-BOARD BUILD, FLASH SWD/OTA & HEADLESS TEST GUIDE)

Tài liệu hướng dẫn chi tiết cách biên dịch (Build), nạp phần mềm qua mạch nạp ST-Link / USB-Serial / OTA và chạy kiểm thử tự động Headless CAN simulator cho cả 3 vi điều khiển.

---

## 1. BẢNG THÔNG SỐ CÔNG CỤ & MẠCH NẠP

| Vi điều khiển | Project Path | Mạch nạp / Cổng COM | Tệp Binary đầu ra |
| :--- | :--- | :--- | :--- |
| **ESP32-C6** | `d:\DuAn\10.ViDieuKhien\esp32_ocpp_v2` | USB-Serial Cổng `COM19` (115200) | `output/esp32_ocpp_v2.bin` |
| **STM32F429ZI** | `d:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\F429_OCPP1.6J` | ST-Link `0676FF565251887067063225`<br>Cổng `COM7` (115200) | `Debug/F429_OCPP1.6J.bin` |
| **STM32H743VI** | `d:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743` | ST-Link `0034001C3133511035333335`<br>Cổng `COM16` (115200) | `Debug/evse_h743.bin` |

---

## 2. HƯỚNG DẪN BIÊN DỊCH CHO TỪNG THIẾT BỊ

### 2.1. ESP32-C6 (`esp32_ocpp_v2`):
```powershell
cd D:\DuAn\10.ViDieuKhien\esp32_ocpp_v2
# Chạy script tự động (PlatformIO build & xuất output)
.\build.bat
# Hoặc nạp trực tiếp qua cổng COM19
& "C:\Users\NgocToan\.platformio\penv\Scripts\platformio.exe" run --target upload --upload-port COM19
```

### 2.2. STM32H743 (`evse_h743`):
```powershell
# Biên dịch Headless bằng STM32CubeIDE
& "G:\ST\STM32CubeIDE_2.1.1\STM32CubeIDE\stm32cubeidec.exe" `
    -nosplash --launcher.suppressErrors `
    -application org.eclipse.cdt.managedbuilder.core.headlessbuild `
    -data "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\cubeide-workspace" `
    -import "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743" `
    -cleanBuild "evse_h743/Debug"

# Nạp qua mạch nạp ST-Link
& "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe" `
    -c port=SWD sn=0034001C3133511035333335 freq=4000 mode=UR `
    -w "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743\Debug\evse_h743.elf" -v -rst
```

### 2.3. STM32F429 (`F429_OCPP1.6J`):
```powershell
# Biên dịch Headless bằng STM32CubeIDE
& "G:\ST\STM32CubeIDE_2.1.1\STM32CubeIDE\stm32cubeidec.exe" `
    -nosplash --launcher.suppressErrors `
    -application org.eclipse.cdt.managedbuilder.core.headlessbuild `
    -data "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\cubeide-workspace" `
    -import "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\F429_OCPP1.6J" `
    -cleanBuild "F429_OCPP1.6J/Debug"

# Nạp qua mạch nạp ST-Link
& "C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe" `
    -c port=SWD sn=0676FF565251887067063225 freq=4000 mode=UR `
    -w "D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\F429_OCPP1.6J\Debug\F429_OCPP1.6J.elf" -v -rst
```

---

## 3. QUY TRÌNH NÂNG CẤP FIRMWARE OTA TỪ XA (KHÔNG DÙNG DÂY)

Khi trạm sạc đã lắp ráp vào vỏ tủ công nghiệp hoặc đặt ngoài hiện trường:
- **Qua Web Dashboard:** Truy cập `http://10.14.80.19` $ightarrow$ chọn file `.bin` nạp trực tiếp cho `ESP32`, `EVSE_F429`, hoặc `EVSE_H743`.
- **Qua MQTT Fleet OTA (Lệnh dòng lệnh):**
```powershell
python tools/network_tools/ota_mqtt.py --broker 10.14.80.193 --device EVSE_H743 --firmware D:\DuAn\10.ViDieuKhien\RELEASE_V1.0.1\evse_h743.bin
```

---

## 4. QUY TRÌNH TEST TỰ ĐỘNG PHẦN CỨNG HEADLESS (CAN SIMULATORS)

1. Cắm thiết bị USB-CAN B vào máy tính: Kênh 1 vào FDCAN1 (Power), Kênh 2 vào FDCAN2 (SECC).
2. Chạy test tự động không cần mở giao diện đồ họa Python GUI:
```powershell
cd D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743
python tools/hardware_headless_integration_test.py
```
Báo cáo đánh giá tự động PASS/FAIL sẽ được sinh tại: `tools/logs/reports/`.

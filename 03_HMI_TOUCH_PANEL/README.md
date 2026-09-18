# PHÂN HỆ MÀN HÌNH CẢM ỨNG TRỤ SẠC ANDROID HMI
## (INDUSTRIAL ANDROID HMI KIOSK APPLICATION - FLUTTER)

> **Repository Git:** [`https://github.com/ngoctoan150699/hmi_evse.git`](https://github.com/ngoctoan150699/hmi_evse.git)  
> **Thư mục cục bộ:** `d:\DuAn\1.EVSE\hmi_evse`  
> **Phiên bản:** `v1.0.0`  
> **Nền tảng:** Flutter 3.x, Android Industrial Touch Panel (Màn hình cảm ứng công nghiệp gắn tại thân trụ sạc)

---

## 1. VAI TRÒ & VỊ TRÍ TRONG HỆ THỐNG

Ứng dụng `hmi_evse` là giao diện tương tác trực tiếp (Face of Charger) giữa trạm sạc và người dùng tại hiện trường:
- Chạy ở chế độ **Kiosk Mode** toàn màn hình trên hệ điều hành Android công nghiệp.
- Kết nối trực tiếp với bộ vi điều khiển trung tâm STM32F429 thông qua cổng nối tiếp **RS485 Modbus RTU**.
- Hiển thị trực quan trạng thái súng sạc, hướng dẫn cắm cáp, quẹt thẻ RFID, đồ họa đồng hồ đo % pin (SoC Arc Gauge), công suất và chi phí sạc theo thời gian thực.
- Cung cấp cổng quản trị kỹ thuật tại chỗ (**Admin Portal**) để kỹ thuật viên kiểm tra phần cứng, test relay và xem log truyền thông Modbus.

---

## 2. CẤU TRÚC MÃ NGUỒN DỰ ÁN FLUTTER (`hmi_evse/lib/`)

```text
lib/
├── app/app.dart                       # Entry point ứng dụng, cấu hình MaterialApp & Theme
├── core/                              # Layout thích ứng đa màn hình & Token màu sắc
│   ├── layout/adaptive_layout_builder.dart
│   └── theme/hmi_theme.dart           # Giao diện Dark/Light hiện đại, độ tương phản cao
├── data/                              # Tầng dữ liệu & Giao tiếp phần cứng
│   ├── modbus/                        # Bộ giải mã Modbus RTU & Serial Transport
│   │   ├── modbus_codec.dart
│   │   ├── modbus_rtu_serial_transport.dart
│   │   └── modbus_simulator_transport.dart
│   ├── repositories/evse_repository.dart
│   └── simulation/simulated_hmi_repository.dart
├── domain/models/                     # Mô hình nghiệp vụ
│   ├── charger_snapshot.dart          # Ảnh chụp thông số V, I, kWh, SoC, Trạng thái
│   ├── connector_session.dart         # Thông tin phiên sạc súng 1 / súng 2
│   └── hmi_command_mailbox.dart       # Hộp thư gửi lệnh Start/Stop/Reset/Help tới MCU
└── features/                          # 9 Màn hình giao diện trạng thái
    ├── idle/idle_screen.dart          # Màn hình chờ sạc (Standby)
    ├── plugged/plugged_screen.dart    # Đã cắm súng, hướng dẫn quẹt thẻ
    ├── authorizing/authorizing_screen.dart # Đang xác thực thẻ với server
    ├── preparing/preparing_screen.dart # Kiểm tra cách điện & chuẩn bị cấp nguồn
    ├── charging/charging_screen.dart  # Màn hình sạc chính (V, I, SoC, Tiền, Biểu đồ)
    ├── stopping/stopping_screen.dart  # Đang giảm dòng ngắt sạc an toàn
    ├── complete/complete_screen.dart  # Hoàn tất sạc, tổng kết tiền và kWh
    ├── fault/fault_screen.dart        # Báo lỗi sự cố phần cứng / Dừng khẩn cấp
    └── admin/admin_portal.dart        # Cổng quản trị kỹ thuật tại chỗ
```

---

## 3. DANH MỤC TÀI LIỆU CHI TIẾT TRONG PHÂN HỆ

1. [HMI_STATE_MACHINE_AND_UI.md](HMI_STATE_MACHINE_AND_UI.md): Đặc tả chi tiết 9 màn hình giao diện người dùng và máy trạng thái HMI.
2. [HMI_MODBUS_COMMUNICATION.md](HMI_MODBUS_COMMUNICATION.md): Giao thức truyền thông Modbus RTU serial và cơ chế Command Mailbox với vi điều khiển.

3. [DRIVER_CHARGING_USER_MANUAL.md](DRIVER_CHARGING_USER_MANUAL.md): Cẩm nang hướng dẫn tài xế thao tác sạc xe trực tiếp tại màn hình cảm ứng trụ HMI.

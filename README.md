# CỔNG TRI THỨC & TÀI LIỆU KỸ THUẬT HỆ SINH THÁI THACO EVSE
## (MASTER DOCUMENTATION PORTAL & SYSTEM REPOSITORIES DIRECTORY)

> **Cập nhật mới nhất:** `18/09/2026`  
> **Phiên bản phát hành hệ thống:** `v1.0.1`  
> **Phạm vi:** Trạm sạc nhanh DC công suất cao (DC Fast Charger), Nền tảng máy chủ CSMS Cloud, Ứng dụng di động Tài xế, Màn hình cảm ứng HMI Android và Cổng thanh toán SePay.

Chào mừng bạn đến với **Cổng Tài liệu & Cơ sở Tri thức Trung tâm** của dự án trạm sạc xe điện THACO EVSE. Tài liệu này được thiết kế để bất kỳ ai — từ Lãnh đạo cấp cao, Trưởng dự án, Kỹ sư lập trình mới cho đến Kỹ thuật viên hiện trường — đều có thể hiểu tường tận bức tranh toàn cảnh và dễ dàng theo dõi từng phân hệ.

---

## 1. BẢNG DANH MỤC & ĐƯỜNG DẪN GIT CỦA 8 DỰ ÁN THÀNH PHẦN

Toàn bộ hệ thống trạm sạc được phân chia thành 8 dự án độc lập, được đồng bộ và liên kết chặt chẽ với nhau:

| STT | Phân hệ / Dự án | Vai trò trong hệ sinh thái | Đường dẫn thư mục cục bộ | Đường dẫn Git Repository (GitHub URL) | Phiên bản |
|:---:|:---|:---|:---|:---|:---:|
| **1** | **EVSE_H743** | **Bộ điều khiển Công suất Cao thế & An toàn Phần cứng** (STM32H743XI): Điều khiển module nguồn AcePower qua FDCAN1, SECC CCS2 qua FDCAN2, công tơ DCM230 DC Meter qua UART8, Modbus RTU Slave, Live Dual-Bank OTA. | `d:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743` | [`ngoctoan150699/EVSE_H743`](https://github.com/ngoctoan150699/EVSE_H743.git) | `v1.0.1` |
| **2** | **F429_OCPP1.6J** | **Bộ điều khiển Mạng & Giao thức Trung tâm** (STM32F429ZI): Chạy MiniOCPP 1.6J Client thuần C không malloc, Modbus Master RS485 sang H743, SPI Slave DMA sang ESP32, Live Dual-Bank OTA. | `d:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\F429_OCPP1.6J` | [`ngoctoan150699/F429_OCPP1.6J`](https://github.com/ngoctoan150699/F429_OCPP1.6J.git) | `v1.0.1` |
| **3** | **esp32_ocpp_v2** | **Gateway Wi-Fi/Ethernet & Modem OTA** (ESP32-C6): Giao tiếp SPI Full-Duplex DMA 10MHz sang F429, Mongoose Web Server Dashboard `10.14.80.19`, điều phối Web OTA & MQTT Fleet OTA (sub-chunking 512B). | `d:\DuAn\10.ViDieuKhien\esp32_ocpp_v2` | [`ngoctoan150699/esp32_ocpp`](https://github.com/ngoctoan150699/esp32_ocpp.git) | `v1.0.1` |
| **4** | **Csms_evse** | **Hệ thống Máy chủ Quản trị Trạm sạc Đám mây (CSMS Cloud)**: Next.js Admin UI 16 phân hệ, Go backend microservices (`ocpp-gateway`, `worker`, `api`), PostgreSQL, Redis Streams, Docker Compose. | `d:\DuAn\1.EVSE\csms_evse` | [`ngoctoan150699/Csms_evse`](https://github.com/ngoctoan150699/Csms_evse.git) | `v1.0.1` |
| **5** | **hmi_evse** | **Màn hình Cảm ứng Android HMI Công nghiệp**: Ứng dụng Flutter/Android chạy trên màn hình trạm sạc, giao tiếp Modbus RTU RS485 với MCU, 9 trạng thái giao diện trực quan (Idle, Plugged, Charging...). | `d:\DuAn\1.EVSE\hmi_evse` | [`ngoctoan150699/hmi_evse`](https://github.com/ngoctoan150699/hmi_evse.git) | `v1.0.0` |
| **6** | **THACO_Charge** | **Ứng dụng Di động Dành cho Tài xế Xe điện (Driver Mobile App)**: Flutter app (iOS & Android), bản đồ tìm trạm sạc, quét mã QR kích hoạt sạc, giám sát SoC % và tiền sạc theo thời gian thực, ví điện tử. | `d:\DuAn\1.EVSE\THACO_Charge` | [`ngoctoan150699/THACO_Charge`](https://github.com/ngoctoan150699/THACO_Charge.git) | `v1.0.0` |
| **7** | **sepay** | **Tài liệu & Đặc tả Tích hợp Cổng Thanh toán SePay**: Cơ chế Webhook IPN nhận biến động số dư VietQR nạp tiền tức thì vào tài khoản người dùng/thẻ RFID. | `d:\DuAn\1.EVSE\sepay` | *(Thư mục tài liệu tích hợp)* | `API v2` |
| **8** | **Docs_evse** | **Cổng Tri thức & Tài liệu Trung tâm Toàn hệ thống**: Tổng hợp kiến trúc, từ điển thuật ngữ, sơ đồ luồng dữ liệu và cẩm nang kỹ thuật của toàn bộ các dự án trên. | `D:\DuAn\1.EVSE\Docs_evse` | *(Được quản lý phiên bản Git tập trung)* | `v1.0.1` |

---

## 2. TỔNG QUAN KIẾN TRÚC HỆ SINH THÁI (ECOSYSTEM TOPOLOGY)

```mermaid
flowchart TD
    subgraph CLOUD ["☁️ ĐÁM MÂY & MÁY CHỦ TRUNG TÂM (CLOUD CSMS)"]
        CSMS["THACO CSMS Server (Go Microservices)<br/>• ocpp-gateway: WebSocket WSS:9000<br/>• worker: Redis Streams Processor<br/>• api: Admin REST API & SePay Webhook"]
        DB[("PostgreSQL 16 + TimescaleDB")]
        REDIS[("Redis Cluster / PubSub")]
        ADMIN_WEB["Giao diện Quản trị Web Next.js<br/>(16 phân hệ quản lý & thống kê)"]
        SEPAY_GATEWAY["Cổng Thanh toán SePay / VietQR<br/>(Webhook IPN nạp tiền tự động)"]
        CSMS <--> DB
        CSMS <--> REDIS
        ADMIN_WEB <--> CSMS
        SEPAY_GATEWAY -->|HTTP POST /api/payment/sepay-webhook| CSMS
    end

    subgraph CLIENT_APPS ["📱 ỨNG DỤNG NGƯỜI DÙNG & GIAO DIỆN HIỆN TRƯỜNG"]
        DRIVER_APP["Ứng dụng Tài xế THACO_Charge<br/>(Flutter iOS / Android)<br/>• Bản đồ trạm & Dẫn đường<br/>• Quét QR kích hoạt sạc<br/>• Nạp tiền ví VietQR"]
        HMI["Màn hình Cảm ứng Android HMI<br/>(Flutter Android Kiosk trên trụ)<br/>• Hiển thị 9 trạng thái sạc<br/>• Bắt đầu / Dừng sạc tại chỗ<br/>• Giám sát V, I, SoC %, Tiền"]
    end

    subgraph EVSE_STATION ["⚡ PHẦN CỨNG TRẠM SẠC NHANH DC (3 VI ĐIỀU KHIỂN)"]
        subgraph TIER1 ["1. Network Gateway"]
            ESP["ESP32-C6 Coprocessor<br/>• Mongoose Web Dashboard (10.14.80.19)<br/>• Điều phối Web OTA & MQTT OTA"]
        end
        subgraph TIER2 ["2. Protocol MCU"]
            F4["STM32F429ZIT6 Central MCU<br/>• MiniOCPP 1.6J Client thuần C<br/>• Modbus RTU Master Engine<br/>• Live Dual-Bank Flash"]
        end
        subgraph TIER3 ["3. Power & Safety MCU"]
            H7["STM32H743XIT6 Power MCU<br/>• Máy trạng thái an toàn sạc CCS2 (8 bước)<br/>• Modbus RTU Slave (0x01)<br/>• Live Dual-Bank Flash"]
        end
    end

    subgraph HARDWARE_LOAD ["🔌 THIẾT BỊ CÔNG SUẤT & XE ĐIỆN"]
        ACE["Module Nguồn AcePower AB-U2T<br/>(1000V / 30kW mỗi module)"]
        SECC["Bộ điều khiển SECC CCS2<br/>(HomePlug GreenPHY PLC)"]
        DCM["Công tơ DC Eastron DCM230"]
        ESTOP["Nút Dừng Khẩn Cấp (E-Stop)<br/>& Contactor DC ngắt < 20ms"]
        CAR["🚗 Xe Ô tô Điện (EV)<br/>(Pin cao áp & Bộ điều khiển EVCC)"]
    end

    DRIVER_APP <-->|HTTPS REST / WSS| CSMS
    CSMS <-->|WebSocket OCPP 1.6J / MQTT| ESP
    ESP <-->|SPI 4-wire Full-Duplex DMA 10 MHz| F4
    F4 <-->|RS485 Modbus RTU 115200 bps| H7
    HMI <-->|RS485 Modbus RTU| F4
    H7 <-->|FDCAN1 125 kbps| ACE
    H7 <-->|FDCAN2 500 kbps| SECC
    H7 <-->|UART8 RS485 9600 bps| DCM
    H7 --- ESTOP
    SECC <-->|Chân Pilot CP PLC| CAR
    ACE ==>|Cáp điện DC+/DC-| CAR
```

---

## 3. HƯỚNG DẪN ĐỌC TÀI LIỆU THEO VAI TRÒ (READING GUIDE BY ROLE)

### 3.1. Dành cho Ban Giám đốc / Lãnh đạo (Executive & Management):
- Đọc [GLOSSARY.md](GLOSSARY.md): Nắm bắt nhanh định nghĩa toàn bộ thuật ngữ chuyên ngành (OCPP, SECC, CCS2, SePay, v.v.).
- Đọc [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md): Hiểu mô hình 5 tầng bảo mật và phân chia trách nhiệm hệ thống.
- Đọc [05_OPERATIONS_AND_MAINTENANCE/PRODUCTION_READINESS_AUDIT.md](05_OPERATIONS_AND_MAINTENANCE/PRODUCTION_READINESS_AUDIT.md): Đánh giá mức độ sẵn sàng thương mại hóa và lộ trình mở rộng quy mô.
- Đọc [05_OPERATIONS_AND_MAINTENANCE/CYBERSECURITY_AND_SECRETS_MANAGEMENT.md](05_OPERATIONS_AND_MAINTENANCE/CYBERSECURITY_AND_SECRETS_MANAGEMENT.md): Nắm vững chính sách tuân thủ an toàn thông tin và bảo vệ tài sản doanh nghiệp.

### 3.2. Dành cho Kỹ sư Lập trình Nhúng & Phần cứng (Embedded Engineers):
- Đọc [01_EMBEDDED_FIRMWARE/README.md](01_EMBEDDED_FIRMWARE/README.md): Kiến trúc phân tán 3 chip ESP32-C6, STM32F429, STM32H743.
- Đọc [01_EMBEDDED_FIRMWARE/INTER_MCU_COMMUNICATION_AND_REGISTERS.md](01_EMBEDDED_FIRMWARE/INTER_MCU_COMMUNICATION_AND_REGISTERS.md): **Cẩm nang tương tác giữa 3 vi điều khiển và màn hình HMI**: Giao thức SPI 4 dây DMA 10MHz (Magic 0xAE53), Modbus RTU RS485 (115200 bps), bảng thanh ghi chi tiết H743, cơ chế Boot bất đồng bộ (ESP32 boot chậm hơn F4 & H7), ma trận tự phục hồi khi có 1 MCU bị reset, quy trình khôi phục mạng Ethernet tự động và cơ chế vận hành sạc ngoại tuyến (Offline Resilience) khi mất mạng.
- Đọc [05_OPERATIONS_AND_MAINTENANCE/ELECTRICAL_SAFETY_AND_COMMISSIONING.md](05_OPERATIONS_AND_MAINTENANCE/ELECTRICAL_SAFETY_AND_COMMISSIONING.md): Tiêu chuẩn an toàn điện cao thế, nối đất PE và quy trình nghiệm thu trạm sạc.
- Đọc [05_OPERATIONS_AND_MAINTENANCE/TROUBLESHOOTING_AND_FAULT_CODES.md](05_OPERATIONS_AND_MAINTENANCE/TROUBLESHOOTING_AND_FAULT_CODES.md): Bảng tra cứu mã lỗi và phác đồ sửa chữa trạm sạc.

### 3.3. Dành cho Kỹ sư Máy chủ & Cloud (Backend & DevOps Engineers):
- Đọc [02_CSMS_CLOUD_PLATFORM/README.md](02_CSMS_CLOUD_PLATFORM/README.md): Kiến trúc microservices Go và Next.js Admin UI.
- Đọc [02_CSMS_CLOUD_PLATFORM/OCPP_1_6J_SPECIFICATION.md](02_CSMS_CLOUD_PLATFORM/OCPP_1_6J_SPECIFICATION.md): Đặc tả giao thức OCPP 1.6J và các bản tin Core Profile.
- Đọc [02_CSMS_CLOUD_PLATFORM/DATABASE_AND_OPERATIONS.md](02_CSMS_CLOUD_PLATFORM/DATABASE_AND_OPERATIONS.md): Thiết kế CSDL PostgreSQL, TimescaleDB, sao lưu và dọn dẹp dữ liệu.
- Đọc [02_CSMS_CLOUD_PLATFORM/SEPAY_PAYMENT_INTEGRATION.md](02_CSMS_CLOUD_PLATFORM/SEPAY_PAYMENT_INTEGRATION.md) (hoặc [`sepay-payment.md`](02_CSMS_CLOUD_PLATFORM/sepay-payment.md)): **Toàn văn đặc tả 21 chương tích hợp thanh toán SePay VietQR**, xác thực chữ ký HMAC-SHA256, kiến trúc sổ cái kép chống gian lận tài chính và quy trình đối soát tự động.
- Đọc [02_CSMS_CLOUD_PLATFORM/OPERATOR_ADMIN_USER_MANUAL.md](02_CSMS_CLOUD_PLATFORM/OPERATOR_ADMIN_USER_MANUAL.md): Sổ tay hướng dẫn vận hành trạm và xử lý sự cố cho Quản trị viên CSMS.
- Đọc [05_OPERATIONS_AND_MAINTENANCE/DEPLOYMENT_GUIDE.md](05_OPERATIONS_AND_MAINTENANCE/DEPLOYMENT_GUIDE.md): Hướng dẫn triển khai Docker Compose, Nginx và Cloudflare SSL.
- Đọc [05_OPERATIONS_AND_MAINTENANCE/CYBERSECURITY_AND_SECRETS_MANAGEMENT.md](05_OPERATIONS_AND_MAINTENANCE/CYBERSECURITY_AND_SECRETS_MANAGEMENT.md): Quản lý khóa bí mật, mTLS và phòng chống tấn công mạng.

### 3.4. Dành cho Kỹ sư Mobile App & HMI (Frontend & App Engineers):
- Đọc [03_HMI_TOUCH_PANEL/README.md](03_HMI_TOUCH_PANEL/README.md): Kiến trúc ứng dụng màn hình Android HMI trên trụ sạc.
- Đọc [03_HMI_TOUCH_PANEL/HMI_STATE_MACHINE_AND_UI.md](03_HMI_TOUCH_PANEL/HMI_STATE_MACHINE_AND_UI.md): 9 màn hình trạng thái trực quan.
- Đọc [03_HMI_TOUCH_PANEL/DRIVER_CHARGING_USER_MANUAL.md](03_HMI_TOUCH_PANEL/DRIVER_CHARGING_USER_MANUAL.md): Cẩm nang hướng dẫn thao tác sạc xe thực tế dành cho tài xế.
- Đọc [04_DRIVER_MOBILE_APP/README.md](04_DRIVER_MOBILE_APP/README.md): Ứng dụng tài xế THACO_Charge (iOS/Android).
- Đọc [04_DRIVER_MOBILE_APP/API_CONTRACT_AND_AUTH.md](04_DRIVER_MOBILE_APP/API_CONTRACT_AND_AUTH.md): **Cẩm nang đặc tả chi tiết toàn bộ API Mobile Driver THACO_Charge** (Đầy đủ ví dụ cURL, JSON request/response và mã lỗi cho đăng nhập, xe điện, bản đồ trạm, sạc xe, ví VietQR SePay).

---

## 4. MỤC LỤC CHI TIẾT TÀI LIỆU TRUNG TÂM

1. **Từ điển Thuật ngữ & Từ viết tắt:** [GLOSSARY.md](GLOSSARY.md)
2. **Kiến trúc Toàn diện Đa phân hệ:** [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)
3. **Sơ đồ Chu trình Nghiệp vụ Thực tế:** [SYSTEM_WORKFLOWS_AND_FLOWCHARTS.md](SYSTEM_WORKFLOWS_AND_FLOWCHARTS.md)
4. **Phân hệ Phần cứng & Nhúng (Embedded Firmware):** [01_EMBEDDED_FIRMWARE/README.md](01_EMBEDDED_FIRMWARE/README.md)
   - [Giao thức Truyền thông Liên MCU & Bản đồ Thanh ghi HMI/F4/H7](01_EMBEDDED_FIRMWARE/INTER_MCU_COMMUNICATION_AND_REGISTERS.md)
   - [Sơ đồ chân & Các bus truyền thông](01_EMBEDDED_FIRMWARE/HARDWARE_PINOUT_AND_BUSES.md)
   - [Bảng ánh xạ thanh ghi Modbus RTU chuẩn](01_EMBEDDED_FIRMWARE/MODBUS_REGISTER_MAP.md)
   - [Đặc tả nâng cấp Firmware OTA](01_EMBEDDED_FIRMWARE/OTA_UPDATE_SPECIFICATION.md)
   - [Cẩm nang Biên dịch, Nạp Flash & Headless Test](01_EMBEDDED_FIRMWARE/BUILD_AND_FLASH_GUIDE.md)
5. **Phân hệ Máy chủ Đám mây (CSMS Cloud Platform):** [02_CSMS_CLOUD_PLATFORM/README.md](02_CSMS_CLOUD_PLATFORM/README.md)
   - [Đặc tả giao thức OCPP 1.6J](02_CSMS_CLOUD_PLATFORM/OCPP_1_6J_SPECIFICATION.md)
   - [Thiết kế CSDL & Vận hành Backup/Retention](02_CSMS_CLOUD_PLATFORM/DATABASE_AND_OPERATIONS.md)
   - [Tích hợp Cổng thanh toán SePay VietQR Toàn diện (21 chương)](02_CSMS_CLOUD_PLATFORM/SEPAY_PAYMENT_INTEGRATION.md) (hoặc [sepay-payment.md](02_CSMS_CLOUD_PLATFORM/sepay-payment.md))
   - [Đặc tả Toàn bộ RESTful API Máy chủ CSMS](02_CSMS_CLOUD_PLATFORM/CSMS_REST_API_SPECIFICATION.md)
   - [Bảng Đối soát Chuẩn OCA OCPP 1.6J vs Dự án THACO](02_CSMS_CLOUD_PLATFORM/OCPP_1_6J_SCHEMA_COMPLIANCE_AND_GAP_ANALYSIS.md)
6. **Phân hệ Màn hình Cảm ứng Trụ sạc (Android HMI):** [03_HMI_TOUCH_PANEL/README.md](03_HMI_TOUCH_PANEL/README.md)
   - [Máy trạng thái & Giao diện 9 màn hình](03_HMI_TOUCH_PANEL/HMI_STATE_MACHINE_AND_UI.md)
   - [Giao thức truyền thông Modbus RTU Serial](03_HMI_TOUCH_PANEL/HMI_MODBUS_COMMUNICATION.md)
   - [Cẩm nang Hướng dẫn Thao tác Sạc Xe Dành cho Tài xế](03_HMI_TOUCH_PANEL/DRIVER_CHARGING_USER_MANUAL.md)
7. **Phân hệ Ứng dụng Tài xế (THACO_Charge Mobile App):** [04_DRIVER_MOBILE_APP/README.md](04_DRIVER_MOBILE_APP/README.md)
   - [Tính năng Ứng dụng Tài xế](04_DRIVER_MOBILE_APP/DRIVER_APP_FEATURES.md)
   - [Hợp đồng API & Cẩm nang Đặc tả Chi tiết RESTful API Mobile Driver (Kèm Ví Dụ cURL/JSON)](04_DRIVER_MOBILE_APP/API_CONTRACT_AND_AUTH.md)
8. **Vận hành, Triển khai, An toàn & Xử lý Sự cố:** [05_OPERATIONS_AND_MAINTENANCE/README.md](05_OPERATIONS_AND_MAINTENANCE/README.md)
   - [Cẩm nang Xử lý Sự cố & Bảng Tra cứu Mã lỗi (Troubleshooting & Fault Codes)](05_OPERATIONS_AND_MAINTENANCE/TROUBLESHOOTING_AND_FAULT_CODES.md)
   - [Quy trình An toàn Điện & Nghiệm thu Trạm sạc (Safety & Commissioning)](05_OPERATIONS_AND_MAINTENANCE/ELECTRICAL_SAFETY_AND_COMMISSIONING.md)
   - [Chính sách An ninh Mạng & Quản lý Khóa Bí mật (Cybersecurity & Secrets)](05_OPERATIONS_AND_MAINTENANCE/CYBERSECURITY_AND_SECRETS_MANAGEMENT.md)
   - [Cẩm nang Triển khai Hạ tầng Máy chủ Docker Compose](05_OPERATIONS_AND_MAINTENANCE/DEPLOYMENT_GUIDE.md)
   - [Bộ công cụ Giả lập Test Harness (CAN Sim, SECC Sim, OCPP Sim)](05_OPERATIONS_AND_MAINTENANCE/TEST_SIMULATORS_GUIDE.md)
   - [Kế hoạch Kiểm thử Tuân thủ Chuẩn OCTT (Open Charge Alliance)](05_OPERATIONS_AND_MAINTENANCE/OCPP_OCTT_COMPLIANCE_TEST_PLAN.md)
   - [Báo cáo Đánh giá Sẵn sàng Thương mại hóa Toàn hệ thống](05_OPERATIONS_AND_MAINTENANCE/PRODUCTION_READINESS_AUDIT.md)
9. **Quy chế Đồng bộ Tài liệu Bắt buộc:** [DOCS_SYNC_POLICY.md](DOCS_SYNC_POLICY.md)

---

## 5. QUY CHẾ ĐỒNG BỘ TÀI LIỆU BẮT BUỘC (DOCS SYNC MANDATE)

> **QUY TẮC BẤT BIẾN:**  
> Bất kỳ kỹ sư nào khi cập nhật mã nguồn, sửa đổi giao thức, thay đổi sơ đồ chân, thêm/bớt thanh ghi Modbus, sửa API hoặc phát hành phiên bản firmware mới tại bất kỳ project thành phần nào (`evse_h743`, `F429_OCPP1.6J`, `esp32_ocpp_v2`, `csms_evse`, `hmi_evse`, `THACO_Charge`) **bắt buộc phải cập nhật đồng thời tài liệu tương ứng tại `D:\DuAn\1.EVSE\Docs_evse`**.  
> Xem chi tiết quy trình tại [DOCS_SYNC_POLICY.md](DOCS_SYNC_POLICY.md).

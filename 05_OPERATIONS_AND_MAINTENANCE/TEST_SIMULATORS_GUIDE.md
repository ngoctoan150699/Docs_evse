# BỘ CÔNG CỤ GIẢ LẬP PHẦN CỨNG & TEST HARNESS
## (HARDWARE SIMULATORS & AUTOMATED TEST PROCEDURES)

Tài liệu này hướng dẫn cách sử dụng các công cụ giả lập phần cứng PC-side để kiểm thử trọn vẹn firmware trạm sạc mà không cần đấu nối xe điện thật và tủ điện 1000V.

---

## 1. DANH MỤC BỘ CÔNG CỤ GIẢ LẬP CÓ SẴN TRONG DỰ ÁN

| Tên công cụ | Thư mục mã nguồn | Mục đích kiểm thử |
| :--- | :--- | :--- |
| **AcePower Module Simulator** | `tools/can_tools/power_module_sim/` | Giả lập phản hồi mạng CAN của khối module nguồn công suất AcePower AB-U2T (125 kbps). Hỗ trợ cả giao diện GUI và Headless CLI. |
| **SECC USB-CAN B Simulator** | `tools/can_tools/secc_can_sim/` | Giả lập bộ điều khiển SECC và xe điện CCS2 (500 kbps). Tự động chạy chuỗi bắt tay State A $ightarrow$ B $ightarrow$ C $ightarrow$ D. |
| **OCPP Backend Mock Server** | `tools/ocpp_backend/` | Giả lập máy chủ đám mây CSMS cục bộ để kiểm thử các bản tin Boot, Authorize, Start, Stop, MeterValues mà không cần internet. |
| **Headless Auto Integration Test** | `tools/hardware_headless_integration_test.py` | Kịch bản tự động hóa 100% kiểm thử FDCAN handshake, đọc báo cáo PASS/FAIL tự động xuất ra file Markdown. |
| **MQTT Fleet OTA CLI** | `tools/network_tools/ota_mqtt.py` | Công cụ dòng lệnh phát gói tin nâng cấp firmware OTA qua MQTT broker EMQX. |

---

## 2. QUY TRÌNH CHẠY TEST LIÊN THÔNG TOÀN DIỆN (FULL SYSTEM REGRESSION)

```powershell
# Chạy từ thư mục evse_h743
cd D:\DuAn\10.ViDieuKhien\STM32\CodeSTM32\evse_h743

# Chạy kịch bản test tự động Headless
python tools/hardware_headless_integration_test.py
```
Kết quả kiểm tra chi tiết được tự động ghi nhận tại: `tools/logs/reports/`.

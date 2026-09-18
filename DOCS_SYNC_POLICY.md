# QUY CHẾ ĐỒNG BỘ TÀI LIỆU BẮT BUỘC (DOCS SYNC MANDATE)
## (DOCUMENTATION SYNCHRONIZATION PROTOCOL)

> **Hiệu lực thi hành:** Áp dụng bắt buộc cho toàn bộ lập trình viên, kỹ sư và AI Coding Agent tham gia phát triển hệ sinh thái THACO EVSE.  
> **Địa chỉ Cổng Tài liệu Trung tâm:** `D:\DuAn\1.EVSE\Docs_evse`

---

## 1. QUY TẮC VÀNG (THE GOLDEN RULE)

> [!IMPORTANT]
> **BẤT KỲ KHI NÀO CẬP NHẬT TÀI LIỆU Ở MỘT PROJECT CON, BẮT BUỘC PHẢI CẬP NHẬT ĐỒNG THỜI VÀO CỔNG TÀI LIỆU TRUNG TÂM TẠI `D:\DuAn\1.EVSE\Docs_evse`.**

Không có bất kỳ ngoại lệ nào. Nếu một tính năng mới được thêm vào, một thanh ghi Modbus được đổi địa chỉ, một sơ đồ chân pinout được chỉnh sửa hoặc một API mới được tạo ra mà chỉ ghi trong project con nhưng không cập nhật vào `Docs_evse`, tính năng đó sẽ bị coi là **chưa hoàn thành (Definition of Done = Incomplete)**.

---

## 2. MA TRẬN ÁNH XẠ ĐỒNG BỘ TÀI LIỆU (SYNC MAPPING MATRIX)

Khi thực hiện thay đổi ở các project con, kỹ sư phải cập nhật file tương ứng tại `Docs_evse` theo bảng sau:

| Khi thay đổi tại Project con... | Thuộc tính thay đổi | Bắt buộc cập nhật file tại `Docs_evse` |
| :--- | :--- | :--- |
| **`evse_h743`** | Sơ đồ chân, FDCAN, AcePower, SECC CCS2, DCM230, State machine | • `01_EMBEDDED_FIRMWARE/HARDWARE_PINOUT_AND_BUSES.md`<br>• `01_EMBEDDED_FIRMWARE/README.md`<br>• `ARCHITECTURE_OVERVIEW.md` |
| **`F429_OCPP1.6J`** | Bản tin OCPP 1.6J, SPI Slave, Modbus Master | • `01_EMBEDDED_FIRMWARE/MODBUS_REGISTER_MAP.md`<br>• `02_CSMS_CLOUD_PLATFORM/OCPP_1_6J_SPECIFICATION.md` |
| **`esp32_ocpp_v2`** | Cơ chế OTA, Mongoose Web Dashboard, Frame SPI | • `01_EMBEDDED_FIRMWARE/OTA_UPDATE_SPECIFICATION.md`<br>• `01_EMBEDDED_FIRMWARE/BUILD_AND_FLASH_GUIDE.md` |
| **`csms_evse`** | API Backend Go, CSDL PostgreSQL/TimescaleDB, Next.js UI | • `02_CSMS_CLOUD_PLATFORM/README.md`<br>• `02_CSMS_CLOUD_PLATFORM/DATABASE_AND_OPERATIONS.md`<br>• `05_OPERATIONS_AND_MAINTENANCE/DEPLOYMENT_GUIDE.md` |
| **`sepay`** | Webhook IPN, format payload thanh toán VietQR | • `02_CSMS_CLOUD_PLATFORM/SEPAY_PAYMENT_INTEGRATION.md`<br>• `SYSTEM_WORKFLOWS_AND_FLOWCHARTS.md` |
| **`hmi_evse`** | Màn hình UI, flow thao tác cảm ứng, command mailbox | • `03_HMI_TOUCH_PANEL/README.md`<br>• `03_HMI_TOUCH_PANEL/HMI_STATE_MACHINE_AND_UI.md`<br>• `03_HMI_TOUCH_PANEL/HMI_MODBUS_COMMUNICATION.md` |
| **`THACO_Charge`** | Tính năng App tài xế, API request, màn hình thanh toán | • `04_DRIVER_MOBILE_APP/README.md`<br>• `04_DRIVER_MOBILE_APP/DRIVER_APP_FEATURES.md`<br>• `04_DRIVER_MOBILE_APP/API_CONTRACT_AND_AUTH.md` |
| **Mọi project** | Phiên bản phát hành (Release Version) | • `README.md` (Bảng mục lục Git) |

---

## 3. CHECKLIST KIỂM TRA TRƯỚC KHI COMMIT CODE

Trước khi thực hiện lệnh commit ở bất kỳ project nào, kỹ sư thực hiện rà soát theo 4 câu hỏi:
1. `[ ]` Tính năng này có làm thay đổi giao thức truyền thông hoặc địa chỉ thanh ghi Modbus không?
2. `[ ]` Tính năng này có làm thay đổi API endpoint hoặc cấu trúc payload JSON không?
3. `[ ]` Đã cập nhật tài liệu mô tả tương ứng trong `D:\DuAn\1.EVSE\Docs_evse` chưa?
4. `[ ]` Đã chạy script `powershell .\sync_docs.ps1` để kiểm tra tính toàn vẹn chưa?

---

## 4. CÔNG CỤ TỰ ĐỘNG HỖ TRỢ (`sync_docs.ps1`)

Tại thư mục gốc `Docs_evse`, có sẵn script hỗ trợ kiểm tra tính nhất quán tài liệu:
```powershell
# Chạy từ thư mục Docs_evse
cd D:\DuAn\1.EVSE\Docs_evse
.\sync_docs.ps1
```
Script sẽ tự động quét trạng thái git của 8 repository, đối chiếu phiên bản phát hành và cảnh báo nếu phát hiện tài liệu có nguy cơ bị lệch pha.

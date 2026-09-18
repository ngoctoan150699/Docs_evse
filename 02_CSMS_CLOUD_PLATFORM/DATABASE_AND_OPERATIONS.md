# THIẾT KẾ CƠ SỞ DỮ LIỆU & VẬN HÀNH BẢO TRÌ (DATABASE OPERATIONS)
## (POSTGRESQL 16, TIMESCALEDB HYPERTABLE, REDIS STREAMS & BACKUP PROCEDURES)

Tài liệu này định nghĩa cấu trúc cơ sở dữ liệu quan hệ, bảng dữ liệu chuỗi thời gian (TimescaleDB) và các kịch bản sao lưu, phục hồi dữ liệu định kỳ cho máy chủ CSMS.

---

## 1. CẤU TRÚC DỮ LIỆU QUAN HỆ & CHUỖI THỜI GIAN

### 1.1. Các bảng quan hệ chính (Relational Tables):
- **`stations`**: Quản lý thông tin địa lý, tọa độ GPS, công suất tối đa trạm sạc.
- **`charge_points`**: Quản lý từng trụ sạc, thông tin vendor, firmware, trạng thái heartbeat, tài khoản xác thực OCPP Basic Auth.
- **`connectors`**: Quản lý từng cổng súng sạc, công suất, trạng thái trực tuyến.
- **`cards`**: Quản lý thẻ sạc RFID, mã thẻ định danh, chủ sở hữu, số dư tiền khả dụng (VND).
- **`transactions`**: Quản lý từng phiên sạc xe điện, thời gian bắt đầu/kết thúc, số kWh tiêu thụ, tổng tiền, trạng thái thanh toán.
- **`recharge_orders`**: Quản lý các giao dịch nạp tiền qua cổng thanh toán SePay VietQR.
- **`alerts`**: Nhật ký các sự cố phần cứng, cảnh báo dừng khẩn cấp.

### 1.2. Bảng chuỗi thời gian tối ưu cho dữ liệu lớn (`meter_values` Hypertable):
- Khi hệ thống mở rộng lên 1.000 trụ sạc, mỗi trụ gửi mẫu đo mỗi 10 giây $\longrightarrow$ sinh ra **~8,6 triệu bản ghi/ngày**.
- Áp dụng **TimescaleDB Hypertable** tự động phân chia dữ liệu theo các khoảng thời gian (Chunks 1 ngày/1 tuần).
- Tạo **Continuous Aggregates** tự động tính sẵn trung bình 5 phút / 1 giờ, giúp biểu đồ Dashboard tải trong $< 50\text{ ms}$.

---

## 2. CHÍNH SÁCH SAO LƯU DỰ PHÒNG TỰ ĐỘNG (BACKUP POLICY)

```powershell
# Sao lưu toan bo CSDL PostgreSQL ra file nen gzip
docker exec -t csms-postgres pg_dump -U thaco_admin -d thaco_csms | gzip > "D:\DuAn\1.EVSE\backup_csms_$(Get-Date -Format 'yyyyMMdd_HHmmss').sql.gz"
```
- **Tần suất sao lưu:** Tự động thực hiện mỗi ngày lúc `02:00 AM`.
- **Lưu trữ an toàn:** Lưu trữ 3 bản tại 3 vị trí độc lập (Local Disk, Máy chủ sao lưu nội bộ và Đám mây Cloud Object Storage).

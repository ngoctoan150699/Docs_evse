# CẨM NANG HƯỚNG DẪN VẬN HÀNH DÀNH CHO CHỦ TRẠM & KỸ THUẬT VIÊN
## (CSMS CLOUD PLATFORM OPERATOR & STATION OWNER USER MANUAL)

> **Mục đích:** Tài liệu hướng dẫn sử dụng thực tế toàn bộ các phân hệ trên giao diện quản trị CSMS Cloud dành cho Chủ đầu tư trạm sạc, Nhân viên trực ca vận hành và Kế toán tài chính.  
> **Địa chỉ truy cập Web:** `https://csms.thacoevse.vn` (hoặc `http://localhost:3000` trong mạng nội bộ).

---

## 1. ĐĂNG NHẬP & TỔNG QUAN DASHBOARD

1. Mở trình duyệt web (Google Chrome hoặc Microsoft Edge), truy cập địa chỉ máy chủ CSMS.
2. Nhập **Tên đăng nhập** và **Mật khẩu** do quản trị viên cấp.
3. **Màn hình Tổng quan (Executive Dashboard):**
   - **Thống kê Realtime KPIs:** Nhìn nhanh tổng sản lượng điện tiêu thụ trong ngày (`Total Energy kWh`), Doanh thu nạp tiền (`Revenue VND`), Số phiên sạc hoàn thành và Số kg khí thải CO₂ đã giảm thiểu.
   - **Bản đồ Trạm sạc (Map View):** Theo dõi vị trí các cụm trạm sạc trên toàn quốc, chấm tròn màu xanh thể hiện trạm đang hoạt động bình thường, màu đỏ thể hiện trạm đang có cảnh báo sự cố.

---

## 2. GIÁM SÁT TRẠM SẠC & ĐIỀU KHIỂN TỪ XA

### 2.1. Theo dõi trạng thái từng súng sạc (Connector Realtime Monitor):
- Truy cập menu **Giám sát vận hành $ightarrow$ Súng sạc**:
  - Xem trực tiếp: Điện áp DC thực tế ($V$), Dòng điện nạp ($A$), Công suất tức thời ($kW$), % Pin của xe ($SoC$).
  - Trạng thái súng sạc:
    * `Available`: Đang rảnh rỗi, sẵn sàng phục vụ.
    * `Preparing`: Xe đã cắm súng, đang xác thực thẻ.
    * `Charging`: Đang bơm điện công suất cao vào pin xe.
    * `Faulted`: Trụ đang gặp sự cố phần cứng, cần kiểm tra.

### 2.2. Các thao tác điều khiển khẩn cấp từ xa:
Khi khách hàng gọi điện lên tổng đài hỗ trợ:
- **Khởi động sạc từ xa (`Remote Start`):** Bấm nút [Kích hoạt sạc] $ightarrow$ Nhập mã thẻ của khách hàng $ightarrow$ Trụ sạc tự động cấp nguồn.
- **Dừng sạc từ xa (`Remote Stop`):** Khi tài xế không thể bấm dừng trên trụ $ightarrow$ Bấm nút [Dừng sạc] để kết thúc phiên và chốt hóa đơn.
- **Mở khóa súng sạc bị kẹt (`Unlock Connector`):** Khi súng sạc sạc xong nhưng bị kẹt chốt cơ khí không rút ra được $ightarrow$ Bấm [Mở khóa súng] để phát xung điện nhả chốt cơ khí.
- **Khởi động lại trụ sạc (`Reset`):** Khi trụ sạc bị đơ truyền thông $ightarrow$ Chọn `Soft Reset` (khởi động lại phần mềm) hoặc `Hard Reset` (khởi động lại toàn bộ vi điều khiển).

---

## 3. CẤU HÌNH BIỂU GIÁ ĐIỆN & PHÍ CHIẾM CHỖ (TARIFFS)

Truy cập menu **Quản lý kinh doanh $ightarrow$ Bảng giá điện (Tariffs)**:
1. **Tạo gói giá điện mới:** Bấm [Thêm biểu giá].
2. **Cấu hình theo khung giờ (Time-of-Use):**
   - Giờ bình thường (04:00 - 09:30, 11:30 - 17:00, 20:00 - 22:00): Đơn giá ví dụ `3.850 đ/kWh`.
   - Giờ cao điểm (09:30 - 11:30, 17:00 - 20:00): Đơn giá ví dụ `5.200 đ/kWh`.
   - Giờ thấp điểm (22:00 - 04:00 sáng hôm sau): Đơn giá ví dụ `2.500 đ/kWh`.
3. **Cài đặt Phí phạt chiếm chỗ sạc quá giờ (`Idle Fee`):**
   - Khi xe đã sạc đầy pin $100\%$ nhưng tài xế vẫn cắm súng chiếm chỗ không rời đi sau 15 phút ân hạn $\longrightarrow$ Tự động tính phí phạt ví dụ: `1.000 đ/phút`. Phí này sẽ tự động trừ vào số dư tài khoản của tài xế khi rút súng.

---

## 4. ĐỐI SOÁT TÀI CHÍNH CỔNG THANH TOÁN VIETQR SEPAY

Truy cập menu **Quản lý đơn hàng $ightarrow$ Đơn nạp tiền (Recharge Orders)**:
- Danh sách toàn bộ các giao dịch tài xế chuyển khoản ngân hàng qua mã VietQR.
- Cột thông tin: Mã đơn hàng (`TC100284`), Số tài khoản chuyển, Số tiền, Thời gian giao dịch, Mã tham chiếu ngân hàng SePay.
- **Đối soát tự động:** Hệ thống tự động so khớp số tiền thực tế ngân hàng báo về với đơn nạp trên hệ thống. Kế toán chỉ cần bấm nút [Xuất báo cáo Excel] để tải toàn bộ bảng kê đối soát phục vụ xuất hóa đơn thuế VAT.

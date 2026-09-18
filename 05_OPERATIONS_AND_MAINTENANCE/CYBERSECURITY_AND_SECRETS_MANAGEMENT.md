# QUY CHUẨN AN NINH MẠNG & QUẢN LÝ KHÓA BẢO MẬT HỆ THỐNG
## (CYBERSECURITY, OCPP SECURITY PROFILES & SECRETS MANAGEMENT POLICY)

Tài liệu này định nghĩa các tiêu chuẩn bảo mật truyền thông, chính sách an toàn thông tin, bảo vệ dữ liệu người dùng theo Nghị định 13/2023/NĐ-CP và cơ chế quản lý khóa bí mật trong môi trường Production.

---

## 1. ĐẶC TẢ 3 CẤP ĐỘ BẢO MẬT GIAO THỨC (OCPP SECURITY PROFILES)

Hệ thống trạm sạc THACO EVSE tuân thủ chặt chẽ tài liệu hướng dẫn an ninh mạng của Open Charge Alliance (OCA):

### 1.1. Security Profile 1: Không mã hóa (Unsecured Transport)
- **Cơ chế:** Kết nối WebSocket không mã hóa (`ws://...:9000`), xác thực bằng HTTP Basic Auth.
- **Chính sách:** **CẤM SỬ DỤNG NGOÀI PRODUCTION**. Chỉ được phép sử dụng trong phòng thí nghiệm nội bộ hoặc mạng giả lập không có kết nối Internet.

### 1.2. Security Profile 2: HTTP Basic Auth qua Kênh Mã Hóa TLS/WSS (Chuẩn Hiện tại)
- **Cơ chế:**
  * Kênh truyền WebSocket được mã hóa bằng **TLS 1.2 / TLS 1.3** (`wss://csms.thacoevse.vn:9000`).
  * Trụ sạc gửi Header: `Authorization: Basic <base64(chargePointId:authPassword)>`.
  * Máy chủ kiểm tra mật khẩu đã được băm bằng thuật toán **Bcrypt** lưu trong bảng `charge_points`.
- **Áp dụng:** Triển khai mặc định cho 100% trạm sạc thương mại hiện tại.

### 1.3. Security Profile 3: Xác thực Hai chiều bằng Chứng chỉ số (Mutual TLS - mTLS)
- **Cơ chế:**
  * Máy chủ xác thực chứng chỉ số của trạm sạc, đồng thời trạm sạc cũng xác thực chứng chỉ số của máy chủ.
  * Mỗi vi điều khiển trạm sạc được nạp một cặp khóa công khai/bí mật (Client Private Key) và Chứng chỉ số X.509 ký bởi Tổ chức Chứng thực THACO Root CA.
  * Máy chủ đối chiếu mã vân tay chứng chỉ (**Client Certificate Thumbprint SHA-256**) trước khi chấp nhận bắt tay WebSocket.
- **Tiêu chuẩn:** Tuân thủ chuẩn sạc tự động thông minh cao cấp **ISO 15118-20 (Plug & Charge)**.

---

## 2. BẢO VỆ DỮ LIỆU CÁ NHÂN THEO NGHỊ ĐỊNH 13/2023/NĐ-CP

Nhằm tuân thủ pháp luật Việt Nam về bảo vệ dữ liệu cá nhân của tài xế xe điện:
1. **Mã hóa dữ liệu nhạy cảm:** Số điện thoại, Email, Số thẻ CCCD và Số tài khoản ngân hàng của khách hàng được mã hóa ở cấp độ cột CSDL bằng thuật toán **AES-256-GCM**.
2. **Ẩn danh hóa lịch sử di chuyển:** Khi xuất báo cáo thống kê chu kỳ sạc phục vụ kế toán hoặc nghiên cứu thị trường, toàn bộ mã định danh cá nhân và biển số xe đều được băm ẩn danh (Hashed Anonymization).
3. **Quyền được lãng quên (Right to be Forgotten):** Cung cấp API `POST /api/mobile/me/delete-account` cho phép tài xế yêu cầu xóa vĩnh viễn dữ liệu tài khoản và số dư ví khi không còn nhu cầu sử dụng dịch vụ.

---

## 3. QUẢN LÝ KHÓA BÍ MẬT SẢN XUẤT (PRODUCTION SECRETS MANAGEMENT)

```text
+-------------------------------------------------------------------------------+
|                   DANH MỤC CÁC KHÓA BÍ MẬT NHẠY CẢM (SECRETS)                 |
+-------------------------------------------------------------------------------+
| 1. JWT_SECRET: Khóa bí mật ký mã thông báo phiên đăng nhập tài xế và Admin.    |
| 2. SEPAY_API_KEY: Khóa bảo mật xác thực Webhook IPN biến động số dư ngân hàng.|
| 3. DB_PASSWORD: Mật khẩu kết nối CSDL PostgreSQL TimescaleDB.                 |
| 4. REDIS_PASSWORD: Mật khẩu bảo vệ cụm hàng đợi Redis Streams.                |
| 5. FIREBASE_SERVICE_ACCOUNT: Khóa riêng tư xác thực thông báo Push Notification|
+-------------------------------------------------------------------------------+
```

### Các quy tắc quản trị bắt buộc:
1. **Tuyệt đối không commit file `.env` lên Git:** Toàn bộ file cấu hình chứa khóa bí mật đều nằm trong `.gitignore`. Mọi vi phạm vô tình đẩy secret lên git sẽ bị hệ thống tự động quét và thu hồi token ngay lập tức.
2. **Quản lý bằng Docker Secrets / HashiCorp Vault:** Trong môi trường Cloud máy chủ chính thức, các khóa bí mật được nạp trực tiếp qua biến môi trường của hệ điều hành hoặc qua bộ quản lý bí mật tập trung.
3. **Quy trình Xoay vòng Khóa định kỳ (Key Rotation):**
   - Định kỳ mỗi **90 ngày**, đội ngũ DevOps thực hiện cập nhật `JWT_SECRET` và `SEPAY_API_KEY` mới.
   - Hỗ trợ cơ chế Dual-Key Verification (cho phép cả khóa cũ và khóa mới cùng có hiệu lực trong 48 giờ chuyển tiếp để không làm gián đoạn người dùng đang đăng nhập).

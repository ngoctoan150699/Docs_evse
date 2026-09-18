# PHÂN HỆ ỨNG DỤNG DI ĐỘNG DÀNH CHO TÀI XẾ XE ĐIỆN (THACO_Charge)
## (THACO EV CHARGING DRIVER MOBILE APP - FLUTTER IOS & ANDROID)

> **Repository Git:** [`https://github.com/ngoctoan150699/THACO_Charge.git`](https://github.com/ngoctoan150699/THACO_Charge.git)  
> **Thư mục cục bộ:** `d:\DuAn\1.EVSE\THACO_Charge`  
> **Phiên bản:** `v1.0.0`  
> **Nền tảng:** Flutter 3.x, iOS (Xcode/Swift), Android (Kotlin/Gradle)

---

## 1. TỔNG QUAN ỨNG DỤNG

`THACO_Charge` là ứng dụng di động chính thức dành cho chủ xe ô tô điện sử dụng mạng lưới trạm sạc công cộng của THACO:
- Giúp tài xế dễ dàng tìm kiếm trạm sạc gần nhất trên bản đồ số, xem trạng thái súng sạc còn trống hay đang bận.
- Quét mã QR dán trên súng sạc để tự động kích hoạt phiên sạc nhanh chóng mà không cần mang theo thẻ từ vật lý.
- Theo dõi tiến độ sạc trực tiếp (% pin, công suất, số tiền) ngay trên màn hình điện thoại từ xa.
- Nạp tiền vào tài khoản ví sạc nhanh chóng qua mã chuyển khoản ngân hàng tự động VietQR SePay.

---

## 2. CẤU TRÚC MÃ NGUỒN DỰ ÁN FLUTTER (`THACO_Charge/lib/`)

```text
lib/
├── main.dart                          # Khởi tạo Firebase, Storage & Cấu hình Theme
├── firebase_options.dart              # Cấu hình dịch vụ Firebase Auth & Cloud Messaging
├── core/                              # Thành phần dùng chung (Network, Storage, Theme)
│   ├── network/api_client.dart        # HTTP Client (Dio/Http) kèm tự động gắn JWT Token
│   ├── storage/secure_storage.dart    # Lưu trữ Token JWT an toàn (Keychain / EncryptedSharedPreferences)
│   └── theme/app_theme.dart           # Thiết kế nhận diện thương hiệu THACO (Xanh dương / Đen sang trọng)
├── data/                              # Tầng dữ liệu & Repositories
│   ├── models/                        # Station, Connector, Transaction, Wallet models
│   └── repositories/                  # StationRepository, ChargingRepository, PaymentRepository
└── features/                          # Các màn hình phân hệ người dùng
    ├── auth/                          # Đăng nhập bằng Số điện thoại (OTP) / Google / Email
    ├── map/                           # Bản đồ trạm sạc tương tác (Google Maps / Mapbox)
    ├── scanner/                       # Quét mã QR súng sạc (Camera Mobile Scanner)
    ├── active_session/                # Màn hình theo dõi phiên sạc trực tiếp (Live Telemetry)
    ├── wallet/                        # Quản lý số dư, Nạp tiền VietQR SePay, Lịch sử nạp
    └── history/                       # Lịch sử các lần sạc xe & Hóa đơn điện tử
```

---

## 3. DANH MỤC TÀI LIỆU CHI TIẾT TRONG PHÂN HỆ

1. [DRIVER_APP_FEATURES.md](DRIVER_APP_FEATURES.md): Mô tả chi tiết tính năng, luồng trải nghiệm người dùng và giao diện các màn hình.
2. [API_CONTRACT_AND_AUTH.md](API_CONTRACT_AND_AUTH.md): **Đặc tả chi tiết toàn bộ RESTful API Ứng dụng Tài xế THACO_Charge** (Cẩm nang đầy đủ 7 nhóm nghiệp vụ: Đăng nhập/Session, Xe điện & Autocharge PnC, Bản đồ & Quét QR, Điều khiển sạc & Live Telemetry, Ví tiền & Nạp VietQR SePay, Thẻ RFID - kèm ví dụ cURL, JSON mẫu request/response và bảng mã lỗi).

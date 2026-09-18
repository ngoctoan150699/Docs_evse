# TÀI LIỆU KỸ THUẬT TÍCH HỢP CỔNG THANH TOÁN SEPAY
## HỆ THỐNG QUẢN LÝ TRẠM SẠC XE ĐIỆN (EVSE CSMS & THACO CHARGE WALLET)

---

> **Phân loại thông tin tài liệu:**
> - `[Official SePay]`: Thông tin được trích xuất và xác thực trực tiếp từ tài liệu kỹ thuật chính thức của SePay ([https://developer.sepay.vn](https://developer.sepay.vn)).
> - `[Project Implementation]`: Thiết kế tương thích trực tiếp với kiến trúc hiện tại của dự án CSMS Go Backend, PostgreSQL, và Ứng dụng THACO Charge Flutter.
> - `[Recommendation]`: Chuẩn thiết kế bảo mật và vận hành cấp doanh nghiệp do Kỹ sư Thanh toán (Senior Payment Engineer) đề xuất.

---

## MỤC LỤC

1. [Tổng Quan & Mục Tiêu Nghiệp Vụ](#1-tổng-quan--mục-tiêu-nghiệp-vụ)
2. [Kiến Trúc Tích Hợp Hệ Thống](#2-kiến-trúc-tích-hợp-hệ-thống)
3. [Mô Hình Luồng Nghiệp Vụ (Sequence Diagrams)](#3-mô-hình-luồng-nghiệp-vụ-sequence-diagrams)
4. [Thiết Kế Máy Trạng Thái (State Machines)](#4-thiết-kế-máy-trạng-thái-state-machines)
5. [Thiết Kế Cơ Sở Dữ Liệu (PostgreSQL Schema)](#5-thiết-kế-cơ-sở-dữ-liệu-postgresql-schema)
6. [Đặc Tả Webhook SePay (Official Specification)](#6-đặc-tả-webhook-sepay-official-specification)
7. [Xác Thực & Bảo Mật Webhook (HMAC-SHA256 & IP Whitelist)](#7-xác-thực--bảo-mật-webhook-hmac-sha256--ip-whitelist)
8. [Tạo Mã QR VietQR & Thông Tin Chuyển Khoản](#8-tạo-mã-qr-vietqr--thông-tin-chuyển-khoản)
9. [Cơ Chế Khớp Lệnh & Xử Lý Nghiệp Vụ Biên (Payment Matching)](#9-cơ-chế-khớp-lệnh--xử-lý-nghiệp-vụ-biên-payment-matching)
10. [Chống Trùng Lặp & Xử Lý Đồng Thời (Idempotency & Concurrency)](#10-chống-trùng-lặp--xử-lý-đồng-thời-idempotency--concurrency)
11. [SePay API v2 & Cơ Chế Đối Soát Tự Động (Reconciliation Engine)](#11-sepay-api-v2--cơ-chế-đối-soát-tự-động-reconciliation-engine)
12. [Quy Trình Hoàn Tiền & Điều Chỉnh Thủ Công (Refund Policy)](#12-quy-trình-hoàn-tiền--điều-chỉnh-thủ-công-refund-policy)
13. [Đặc Tả API Backend CSMS](#13-đặc-tả-api-backend-csms)
14. [Thiết Kế Mở Rộng Nhiều Cổng Thanh Toán (Multi-Provider Architecture)](#14-thiết-kế-mở-rộng-nhiều-cổng-thanh-toán-multi-provider-architecture)
15. [Ma Trận Kiểm Thử (Testing Matrix)](#15-ma-trận-kiểm-thử-testing-matrix)
16. [Môi Trường Thử Nghiệm Sandbox & Production](#16-môi-trường-thử-nghiệm-sandbox--production)
17. [Cấu Hình Môi Trường (Environment Variables)](#17-cấu-hình-môi-trường-environment-variables)
18. [Giám Sát, Ghi Log & Cảnh Báo (Observability & Alerting)](#18-giám-sát-ghi-log--cảnh-báo-observability--alerting)
19. [Hướng Dẫn Xử Lý Sự Cố (Troubleshooting Guide)](#19-hướng-dẫn-xử-lý-sự-cố-troubleshooting-guide)
20. [Checklist Triển Khai Production](#20-checklist-triển-khai-production)
21. [Tài Liệu Tham Khảo (References)](#21-tài-liệu-tham-khảo-references)

---

## 1. TỔNG QUAN & MỤC TIÊU NGHIỆP VỤ

### 1.1. SePay là gì trong hệ sinh thái EVSE?
`[Official SePay]` SePay là cổng trung gian tự động hóa giao dịch chuyển khoản ngân hàng (VietQR). Khi khách hàng quét mã QR và chuyển tiền đến tài khoản ngân hàng của doanh nghiệp, SePay phát hiện biến động số dư theo thời gian thực (Real-time IPN) và gửi tín hiệu qua HTTP Webhook đến server CSMS.

### 1.2. Mục đích tích hợp
`[Project Implementation]` Phục vụ nghiệp vụ nạp tiền ví điện tử của khách hàng sử dụng ứng dụng sạc xe điện **THACO Charge**:
1. Khách hàng tạo yêu cầu nạp số dư ví (VD: 100.000 VNĐ, 500.000 VNĐ).
2. Hệ thống khởi tạo **Đơn nạp tiền (Payment Order)** kèm **Mã thanh toán duy nhất (Payment Code)** và **Mã VietQR động**.
3. Khách hàng thực hiện quét mã trên ứng dụng Mobile Banking bất kỳ (Vietcombank, MB, BIDV, Techcombank,...).
4. Ngân hàng khớp lệnh -> SePay gửi Webhook -> CSMS Backend xác thực và nạp tiền vào ví người dùng ngay lập tức.
5. Số dư ví khả dụng lập tức được dùng để bắt đầu phiên sạc trụ EVSE (qua giao thức OCPP 1.6J/2.0.1).

### 1.3. Nguyên tắc bất biến (Core Architectural Rule)
`[Recommendation]` Tuyệt đối **KHÔNG ĐƯỢC** coi:
> ❌ **Sai lầm kiến trúc:**
> `SePay Webhook` ➔ `Cộng thẳng số dư người dùng (wallet.balance += amount)`

Hệ thống bắt buộc phải tuân thủ nghiêm ngặt chuỗi chuyển đổi trạng thái:
> ✅ **Đúng chuẩn Sổ cái Kép (Ledger):**
> `Bank Transaction` ➔ `SePay Webhook Event` ➔ `Payment Order (PAID)` ➔ `Wallet Ledger (POSTED)` ➔ `Wallet Balance`

- Mọi biến động số dư **bắt buộc** phải sinh bản ghi Sổ cái Ví (`app_wallet_ledger`).
- Mọi giao dịch ngân hàng **bắt buộc** phải được map chính xác vào một Đơn nạp tiền (`payment_orders`).

---

## 2. KIẾN TRÚC TÍCH HỢP HỆ THỐNG

### 2.1. Sơ đồ khối kiến trúc (System Architecture)
`[Project Implementation]`

```
+-----------------------------------------------------------------------------------+
|                              THACO CHARGE MOBILE APP                              |
|   - Tạo yêu cầu nạp ví (Deposit Request)                                          |
|   - Hiển thị VietQR Image động + Hướng dẫn chuyển khoản                           |
|   - Polling / SSE lắng nghe trạng thái hoàn tất đơn nạp                           |
+--------------------------+--------------------------------------------------------+
                           |
               (1) POST /deposit | (7) Polling Status
                           v
+--------------------------+--------------------------------------------------------+
|                             CSMS BACKEND (GO API)                                 |
|                                                                                   |
|  [Payment Controller] <-------------- (4) POST /api/payment/sepay/webhook --------+
|         |                                            |                            |
|  [Payment Service]                             [Webhook Verifier]                 |
|         |                                      - Verify HMAC-SHA256 / API Key     |
|         |                                      - Verify Timestamp (Anti-replay)   |
|         |                                      - IP Filter Whitelist              |
|         |                                            |                            |
|         +-------------------+------------------------+                            |
|                             |                                                     |
|                             v                                                     |
|                [Idempotency & Matching Engine]                                    |
|                - Check UNIQUE(provider_tx_id)                                     |
|                - Match Order Code (DEPxxxx)                                       |
|                - Validate Amount & Status PENDING                                 |
|                             |                                                     |
|                             v                                                     |
|                [Wallet Ledger Service] (Atomic DB Transaction)                    |
|                - Mark PaymentOrder -> PAID                                        |
|                - Insert app_wallet_ledger -> POSTED                               |
|                - Recalculate / Update app_wallets balance                         |
+-----------------------------+-----------------------------------------------------+
                              |
                     Database | (PostgreSQL 15+)
                              v
+-----------------------------+-----------------------------------------------------+
|                     POSTGRESQL DATABASE CLUSTER                                   |
|   - app_users / tenants                                                           |
|   - payment_orders                                                                |
|   - payment_webhook_events                                                        |
|   - app_wallets / app_wallet_ledger                                               |
|   - payment_reconciliation                                                        |
+-----------------------------------------------------------------------------------+
                              ^
                              | (5) Query Transactions (Cron Reconciliation Job)
                              |
+-----------------------------+-----------------------------------------------------+
|                          SEPAY CLOUD GATEWAY                                      |
|   - Webhook Engine (Retry Fibonacci 8 times)                                      |
|   - VietQR Generation Engine (`vietqr.app/img`)                                   |
|   - REST API v2 (`userapi.sepay.vn/v2`)                                           |
+-----------------------------+-----------------------------------------------------+
                              ^
                              | (3) Realtime Transaction Notification
+-----------------------------+-----------------------------------------------------+
|                      HỆ THỐNG NGÂN HÀNG VIỆT NAM                                  |
|          (Vietcombank / BIDV / VietinBank / MBBank / Sacombank / ...)             |
|   - NAPAS 247 Chuyển tiền liên ngân hàng                                          |
+-----------------------------------------------------------------------------------+
```

---

## 3. MÔ HÌNH LUỒNG NGHIỆP VỤ (SEQUENCE DIAGRAMS)

### 3.1. Luồng nạp tiền thành công (Happy Path Deposit Flow)
`[Project Implementation]`

```mermaid
sequenceDiagram
    autonumber
    actor User as Khách hàng (THACO App)
    participant CSMS as CSMS Go Backend
    participant DB as PostgreSQL Database
    participant Bank as Ngân hàng Khách hàng
    participant SePay as Cổng SePay
    participant VietQR as Dịch vụ VietQR

    User->>CSMS: POST /api/mobile/wallet/deposit (amount: 200000)
    Note over CSMS: Xác thực Firebase Token & Lấy CustomerID
    CSMS->>DB: INSERT INTO payment_orders (order_code: "DEP2608270001", amount: 200000, status: 'PENDING')
    DB-->>CSMS: Order Created (ID, ExpiredAt: +15m)
    CSMS->>VietQR: Build QR URL: vietqr.app/img?acc=1017588888&bank=Vietcombank&amount=200000&des=DEP2608270001
    CSMS-->>User: Trả về Payment Details (QR Image, OrderCode, AccountInfo)
    
    User->>Bank: Quét VietQR & Xác nhận chuyển 200.000 VNĐ
    Bank->>Bank: Chuyển khoản NAPAS 247 tới STK Doanh nghiệp
    Bank-->>SePay: Biến động số dư tài khoản thụ hưởng (+200.000 VNĐ, ND: "DEP2608270001")
    
    SePay->>CSMS: HTTP POST /api/payment/sepay/webhook (Payload + X-SePay-Signature + Timestamp)
    
    rect rgb(240, 248, 255)
        Note over CSMS: 1. Xác thực HMAC-SHA256 & Timestamp (+-5 phút)<br/>2. Ghi raw event vào payment_webhook_events
        CSMS->>DB: INSERT INTO payment_webhook_events (...) ON CONFLICT(provider_tx_id) DO NOTHING
        CSMS->>DB: BEGIN TRANSACTION (SERIALIZABLE / READ COMMITTED WITH LOCK)
        CSMS->>DB: SELECT * FROM payment_orders WHERE order_code='DEP2608270001' FOR UPDATE
        Note over CSMS: 3. Kiểm tra: status=='PENDING', transferAmount==amount, transferType=='in'
        CSMS->>DB: UPDATE payment_orders SET status='PAID', paid_at=NOW() WHERE id=...
        CSMS->>DB: INSERT INTO app_wallet_ledger (wallet_id, amount: +200000, entry_type: 'DEPOSIT', status: 'POSTED', idempotency_key: 'SEPAY_92704')
        CSMS->>DB: COMMIT TRANSACTION
    end

    CSMS-->>SePay: HTTP 200 {"success": true}
    
    loop Polling mỗi 3 giây
        User->>CSMS: GET /api/mobile/wallet/deposit/DEP2608270001
        CSMS-->>User: {"status": "PAID", "walletBalance": 750000}
    end
    Note over User: App hiển thị "Nạp tiền thành công", cập nhật số dư ví!
```

---

## 4. THIẾT KẾ MÁY TRẠNG THÁI (STATE MACHINES)

### 4.1. Vòng đời trạng thái Đơn Nạp Tiền (`payment_orders`)
`[Project Implementation]`

```mermaid
stateDiagram-v2
    [*] --> PENDING: Khởi tạo đơn nạp tiền
    
    PENDING --> PROCESSING: Đang xử lý Webhook / Khóa bản ghi
    PROCESSING --> PAID: Webhook khớp đúng mã, đúng tiền, đúng thời gian
    PROCESSING --> UNDERPAID: Khách chuyển thiếu tiền so với đơn
    PROCESSING --> OVERPAID: Khách chuyển thừa tiền so với đơn
    
    PENDING --> EXPIRED: Quá 15 phút không nhận được tiền
    PENDING --> CANCELLED: Khách hàng chủ động hủy trên App
    
    UNDERPAID --> MANUAL_REVIEW: Kế toán can thiệp / Xử lý nạp bù
    OVERPAID --> MANUAL_REVIEW: Kế toán can thiệp / Hoàn trả phần thừa
    EXPIRED --> LATE_PAID: Tiền vào sau khi đơn đã hết hạn (Cần Auto-reconcile)
    
    LATE_PAID --> PAID: Quản trị viên chấp thuận kích hoạt
    PAID --> REFUNDED: Giao dịch có tranh chấp / Hoàn tiền thủ công
    
    MANUAL_REVIEW --> PAID: Xử lý thành công
    MANUAL_REVIEW --> REFUNDED: Hoàn trả tiền cho khách
    
    PAID --> [*]
    CANCELLED --> [*]
    EXPIRED --> [*]
    REFUNDED --> [*]
```

#### Ma trận chuyển đổi trạng thái hợp lệ (Transition Rules)
| Trạng thái hiện tại | Trạng thái tiếp theo | Điều kiện kích hoạt | Cho phép? |
| :--- | :--- | :--- | :---: |
| `PENDING` | `PAID` | Webhook khớp: đúng mã, đúng số tiền, còn hạn | **CÓ** |
| `PENDING` | `UNDERPAID` | Webhook khớp mã nhưng `transferAmount < order.amount` | **CÓ** |
| `PENDING` | `OVERPAID` | Webhook khớp mã nhưng `transferAmount > order.amount` | **CÓ** |
| `PENDING` | `EXPIRED` | Cron job quét đơn quá `expired_at` (15 phút) | **CÓ** |
| `PENDING` | `CANCELLED` | User hủy trước khi chuyển tiền | **CÓ** |
| `EXPIRED` | `LATE_PAID` | Nhận được tiền sau khi đơn đã hết hạn | **CÓ** |
| `PAID` | `PENDING` | Bất kỳ lý do nào | **CẤM** |
| `PAID` | `PAID` | Webhook gửi lại (Retry / Replay) | **CẤM** (Bỏ qua xử lý, trả HTTP 200) |
| `CANCELLED` | `PAID` | Webhook đến sau khi user hủy | **CẤM** (Chuyển `MANUAL_REVIEW`) |

---

### 4.2. Vòng đời Sổ cái Ví (`app_wallet_ledger`)
`[Project Implementation]`

```mermaid
stateDiagram-v2
    [*] --> POSTED: Webhook PAID (Ghi nhận có hiệu lực ngay)
    [*] --> PENDING: Giao dịch sạc chờ chốt số liệu điện năng
    PENDING --> POSTED: Trụ sạc gửi StopTransaction -> Chốt tiền trừ ví
    PENDING --> REVERSED: Phiên sạc lỗi / Hủy đặt cọc (Unlock Hold)
    POSTED --> REVERSED: Điều chỉnh kế toán / Hoàn tiền (Sinh bút toán đảo ngược)
    POSTED --> [*]
    REVERSED --> [*]
```

---

## 5. THIẾT KẾ CƠ SỞ DỮ LIỆU (POSTGRESQL SCHEMA)

Tất cả bảng được thiết kế để tích hợp liền mạch với schema hiện tại của hệ thống CSMS (`app_users`, `app_wallets`, `app_wallet_ledger`, `tenants`).

### 5.1. Bảng `payment_orders` (Quản lý Đơn Thanh Toán / Nạp Tiền)
`[Project Implementation]`

```sql
CREATE TABLE IF NOT EXISTS payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    app_user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
    order_code VARCHAR(32) NOT NULL UNIQUE,          -- Ví dụ: DEP260827000123
    provider VARCHAR(32) NOT NULL DEFAULT 'SEPAY',   -- 'SEPAY', 'VNPAY', 'MOMO', 'STRIPE'
    provider_transaction_id VARCHAR(64),            -- ID giao dịch từ SePay (id: 92704)
    amount NUMERIC(16, 2) NOT NULL CHECK (amount > 0),
    paid_amount NUMERIC(16, 2) DEFAULT 0,
    currency CHAR(3) NOT NULL DEFAULT 'VND',
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    payment_method VARCHAR(32) NOT NULL DEFAULT 'VIETQR',
    bank_account_number VARCHAR(32),
    bank_short_name VARCHAR(16),
    transfer_content VARCHAR(255) NOT NULL,
    qr_url TEXT,
    description TEXT,
    expired_at TIMESTAMPTZ NOT NULL,
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_payment_order_status CHECK (
        status IN ('PENDING', 'PROCESSING', 'PAID', 'UNDERPAID', 'OVERPAID', 'EXPIRED', 'CANCELLED', 'LATE_PAID', 'MANUAL_REVIEW', 'REFUNDED')
    )
);

-- Chỉ mục tối ưu truy vấn
CREATE INDEX IF NOT EXISTS idx_payment_orders_user ON payment_orders(tenant_id, app_user_id, status);
CREATE INDEX IF NOT EXISTS idx_payment_orders_order_code ON payment_orders(order_code);
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_orders_provider_tx ON payment_orders(provider, provider_transaction_id) 
    WHERE provider_transaction_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payment_orders_expired ON payment_orders(status, expired_at) 
    WHERE status = 'PENDING';
```

---

### 5.2. Bảng `payment_webhook_events` (Nhật Ký Raw Webhook & Chống Trùng Lặp)
`[Project Implementation]` Lưu trữ toàn bộ payload thô để phục vụ điều tra forensic, replay dữ liệu và làm chốt chặn Idempotency đầu tiên:

```sql
CREATE TABLE IF NOT EXISTS payment_webhook_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(32) NOT NULL DEFAULT 'SEPAY',
    provider_event_id VARCHAR(64),                  -- SePay Transaction ID (chuỗi hoặc số)
    provider_transaction_id VARCHAR(64) NOT NULL,    -- Unique Transaction ID từ SePay (VD: "92704")
    event_type VARCHAR(32) NOT NULL DEFAULT 'BANK_TRANSFER_IN',
    payload JSONB NOT NULL,                         -- Raw JSON nhận từ SePay
    headers JSONB,                                  -- Header request (bao gồm X-SePay-Signature, Timestamp)
    signature VARCHAR(255),
    client_ip VARCHAR(64),
    status VARCHAR(32) NOT NULL DEFAULT 'RECEIVED',  -- 'RECEIVED', 'PROCESSED', 'IGNORED', 'FAILED'
    error_message TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_webhook_provider_tx UNIQUE (provider, provider_transaction_id)
);

CREATE INDEX IF NOT EXISTS idx_webhook_events_status ON payment_webhook_events(provider, status, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_webhook_events_tx_id ON payment_webhook_events(provider_transaction_id);
```

---

### 5.3. Bảng `app_wallets` & `app_wallet_ledger` (Hiện Hữu Trong CSMS)
`[Project Implementation]` Sử dụng cấu trúc Sổ cái Ví kép đã có sẵn trong `011_customer_domain.sql`:

```sql
-- Đã tồn tại: app_wallets
-- (id, app_user_id, tenant_id, currency, created_at)

-- Đã tồn tại: app_wallet_ledger
-- (id, wallet_id, amount, entry_type, status, external_reference, idempotency_key, description, created_at)
-- Ràng buộc: check(amount <> 0), check(status IN ('PENDING', 'POSTED', 'REVERSED')), unique(idempotency_key)
```

Khi ghi nhận nạp tiền SePay:
- `entry_type`: `'DEPOSIT'`
- `status`: `'POSTED'`
- `amount`: Số tiền nạp dương (VD: `+100000.00`)
- `external_reference`: `payment_orders.id`
- `idempotency_key`: `'SEPAY_TX_' || provider_transaction_id` (Ví dụ: `'SEPAY_TX_92704'`)

---

### 5.4. Bảng `payment_reconciliation` (Bảng Đối Soát Giao Dịch)
`[Project Implementation]` Lưu kết quả đối chiếu giữa SePay REST API v2 và Database cục bộ:

```sql
CREATE TABLE IF NOT EXISTS payment_reconciliation (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    provider VARCHAR(32) NOT NULL DEFAULT 'SEPAY',
    provider_transaction_id VARCHAR(64) NOT NULL,
    local_payment_order_id UUID REFERENCES payment_orders(id),
    provider_amount NUMERIC(16, 2) NOT NULL,
    local_amount NUMERIC(16, 2),
    status VARCHAR(32) NOT NULL,                    -- 'MATCHED', 'MISSING_LOCAL', 'MISSING_PROVIDER', 'AMOUNT_MISMATCH', 'DUPLICATE', 'MANUAL_RESOLVED'
    discrepancy_reason TEXT,
    reconciled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    resolved_by UUID REFERENCES app_users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_reconciliation_tx UNIQUE(provider, provider_transaction_id, reconciled_at::DATE)
);

CREATE INDEX IF NOT EXISTS idx_payment_reconciliation_status ON payment_reconciliation(status, reconciled_at DESC);
```

---

## 6. ĐẶC TẢ WEBHOOK SEPAY (OFFICIAL SPECIFICATION)

### 6.1. Cấu trúc Payload Webhook SePay
`[Official SePay]` Mỗi khi tài khoản ngân hàng liên kết phát sinh giao dịch khớp cấu hình, SePay gửi một `HTTP POST` với body `application/json` chuẩn:

```json
{
  "id": 92704,
  "gateway": "Vietcombank",
  "transactionDate": "2026-08-27 15:30:12",
  "accountNumber": "1017588888",
  "subAccount": "",
  "code": "DEP260827000123",
  "content": "DEP260827000123 NGUYEN VAN A NAP TIEN VI EVSE",
  "transferType": "in",
  "description": "MBVCB.123456789.DEP260827000123.CT tu 0987654321 NGUYEN VAN A",
  "transferAmount": 200000,
  "accumulated": 105200000,
  "referenceCode": "FT26082712345678"
}
```

### 6.2. Chi tiết các trường dữ liệu (Field Data Dictionary)
`[Official SePay]`

| Tên trường | Kiểu dữ liệu | Nullable | Ý nghĩa & Quy tắc nghiệp vụ |
| :--- | :--- | :---: | :--- |
| `id` | `integer` | Không | **ID giao dịch duy nhất trên SePay**. Không thay đổi qua các lần retry/replay. **Dùng làm khóa chống trùng lặp (Idempotency Key)**. |
| `gateway` | `string` | Không | Tên ngân hàng nhận (VD: `Vietcombank`, `BIDV`, `MBBank`, `TPBank`). |
| `transactionDate` | `string` | Không | Thời gian giao dịch phía ngân hàng (`YYYY-MM-DD HH:mm:ss`, Múi giờ VN GMT+7). |
| `accountNumber` | `string` | Không | Số tài khoản ngân hàng thụ hưởng của công ty. |
| `subAccount` | `string` | Có | Tài khoản ảo (VA). Rỗng `""` nếu chuyển vào STK chính thống. |
| `code` | `string` | Có | **Mã thanh toán trích xuất tự động** từ nội dung theo tiền tố cấu hình tại SePay Dashboard. Có thể `null` nếu nội dung không đúng cấu hình. |
| `content` | `string` | Không | **Nội dung chuyển khoản gốc** từ ngân hàng, SePay giữ nguyên không chỉnh sửa. |
| `transferType` | `string` | Không | Chiều tiền: `"in"` (tiền vào) hoặc `"out"` (tiền ra). **Nạp ví chỉ chấp nhận `"in"`**. |
| `transferAmount` | `integer` | Không | **Số tiền giao dịch thực tế (VNĐ)**, luôn là số nguyên dương. |
| `accumulated` | `integer` | Có | Số dư sau giao dịch của tài khoản (Một số bank không trả thì = `0`). |
| `referenceCode` | `string` | Có | Mã tham chiếu giao dịch nội bộ của ngân hàng (VD: mã FT/Trace). |
| `description` | `string` | Có | Mô tả chi tiết giao dịch từ sao kê ngân hàng. |

> `[Official SePay]` **Lưu ý quan trọng:** `code = null` khác với `code = ""` (rỗng). Phải kiểm tra an toàn `code != nil` trong Go trước khi xử lý.

---

### 6.3. Chuẩn phản hồi HTTP bắt buộc (Response Contract)
`[Official SePay]` SePay đánh giá Webhook được phân phối **THÀNH CÔNG** khi và chỉ khi server thỏa mãn đồng thời **3 điều kiện**:
1. Trả về HTTP Status Code **`200`** hoặc **`201`**.
2. Response Body đúng định dạng JSON: **`{"success": true}`**.
3. Thời gian phản hồi trong vòng **dưới 30 giây**.

| Phản hồi từ Server | SePay đánh giá | Hành động của SePay |
| :--- | :--- | :--- |
| `200` + `{"success": true}` | **Thành công** | Đánh dấu hoàn tất, ngừng gửi. |
| `200` + `{"status": "ok"}` / Rỗng | **Thất bại** (Sai JSON body) | **Kích hoạt lịch Retry**. |
| `401` / `403` / `404` / `500` / `502` | **Thất bại** | **Kích hoạt lịch Retry**. |
| Quá 30 giây | **Timeout** | **Kích hoạt lịch Retry**. |

---

### 6.4. Lịch Retry tự động của SePay
`[Official SePay]` Khi Webhook thất bại, SePay tự động gửi lại tối đa **8 lần (1 lần đầu + 7 lần retry)** theo chuỗi Fibonacci:

> `Lần 1 (ngay)` ➔ `+1 phút` ➔ `+1 phút` ➔ `+2 phút` ➔ `+3 phút` ➔ `+5 phút` ➔ `+8 phút` ➔ `+13 phút` *(Tổng thời gian thử lại: ~33 phút)*

> `[Recommendation]` Sau 8 lần thất bại, SePay đánh dấu Webhook là `Failed`. Các sự kiện quá 5 giờ sẽ không được quét lại tự động. Hệ thống cần có **Cron Job đối soát SePay API v2** để cứu các giao dịch này.

---

## 7. XÁC THỰC & BẢO MẬT WEBHOOK (HMAC-SHA256 & IP WHITELIST)

`[Official SePay]` SePay hỗ trợ 4 phương thức xác thực:
1. **HMAC-SHA256 (Bắt buộc cho Production)**: Bảo mật cao nhất, xác thực tính toàn vẹn và chống giả mạo payload giữa đường truyền.
2. **API Key**: SePay gửi header `Authorization: Apikey <API_KEY>`.
3. **OAuth 2.0 Client Credentials**: Phù hợp cho hạ tầng có sẵn OAuth Server.
4. **Không xác thực**: Chỉ dùng cho môi trường Test nội bộ. **Tuyệt đối CẤM trên Production**.

---

### 7.1. Thuật toán xác thực HMAC-SHA256
`[Official SePay]`
- **Header gửi kèm:**
  - `X-SePay-Signature`: Chuỗi chữ ký có tiền tố `sha256=<hex_hash>`.
  - `X-SePay-Timestamp`: Unix Timestamp tính bằng giây tại thời điểm SePay ký.
- **Chuỗi dữ liệu ký (Signing String):**
  ```text
  StringToSign = timestamp + "." + raw_body_bytes
  ```
- **Công thức tính Chữ ký:**
  ```text
  Signature = "sha256=" + HMAC_SHA256(StringToSign, SEPAY_WEBHOOK_SECRET)
  ```

#### Quy tắc bắt buộc khi lập trình xác thực chữ ký:
1. `[Official SePay]` **Dùng Raw Body:** Đọc trực tiếp byte stream từ HTTP Request. Tuyệt đối **KHÔNG ĐƯỢC** parse JSON thành struct/object rồi serialize ngược lại thành chuỗi để verify (vì thứ tự key, khoảng trắng và Unicode escape sẽ làm lệch hash).
2. `[Recommendation]` **Chống Replay Attack:** So sánh `|ServerTime - Timestamp| <= 300` giây (5 phút). Nếu timestamp lệch quá 5 phút -> Từ chối ngay.
3. `[Recommendation]` **So sánh Constant-Time:** Sử dụng hàm so sánh an toàn để chống tấn công Timing Attack (`crypto/subtle.ConstantTimeCompare` trong Go, `hash_equals` trong PHP).

---

### 7.2. Code mẫu Go Backend: Bộ xác thực HMAC-SHA256
`[Project Implementation]`

```go
package sepay

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/hex"
	"errors"
	"fmt"
	"math"
	"net/http"
	"strconv"
	"time"
)

var (
	ErrMissingHeaders   = errors.New("missing signature or timestamp headers")
	ErrTimestampExpired = errors.New("webhook timestamp expired (replay attack protection)")
	ErrInvalidSignature = errors.New("invalid hmac-sha256 signature")
)

type WebhookVerifier struct {
	secretKey string
}

func NewWebhookVerifier(secretKey string) *WebhookVerifier {
	return &WebhookVerifier{secretKey: secretKey}
}

// VerifyRequest kiểm tra tính hợp lệ của HTTP Request từ SePay
func (v *WebhookVerifier) VerifyRequest(r *http.Request, rawBody []byte) error {
	sigHeader := r.Header.Get("X-SePay-Signature")
	tsHeader := r.Header.Get("X-SePay-Timestamp")

	if sigHeader == "" || tsHeader == "" {
		return ErrMissingHeaders
	}

	// 1. Kiểm tra Timestamp chống Replay Attack (dung sai +- 300 giây)
	timestamp, err := strconv.ParseInt(tsHeader, 10, 64)
	if err != nil {
		return errors.New("invalid timestamp format")
	}

	now := time.Now().Unix()
	if math.Abs(float64(now-timestamp)) > 300 {
		return ErrTimestampExpired
	}

	// 2. Tạo chuỗi ký: {timestamp}.{raw_body}
	payloadToSign := fmt.Sprintf("%d.%s", timestamp, string(rawBody))

	// 3. Tính HMAC-SHA256
	mac := hmac.New(sha256.New, []byte(v.secretKey))
	mac.Write([]byte(payloadToSign))
	expectedSignature := "sha256=" + hex.EncodeToString(mac.Sum(nil))

	// 4. So sánh Constant-Time an toàn
	if subtle.ConstantTimeCompare([]byte(expectedSignature), []byte(sigHeader)) != 1 {
		return ErrInvalidSignature
	}

	return nil
}
```

---

### 7.3. Cấu hình IP Whitelist cho SePay
`[Official SePay]` Danh sách địa chỉ IP chính thức của SePay Webhook Server cần được mở trong Firewall / Nginx / Load Balancer:

- **IPv4:**
  - `172.236.138.20`
  - `172.233.83.68`
  - `171.244.35.2`
  - `151.158.108.68`
  - `151.158.109.79`
  - `103.255.238.139`
- **IPv6:**
  - `2400:8905::2000:8cff:fe98:45cd`
  - `2600:3c15::2000:8aff:fedd:874b`

#### Cấu hình Nginx mẫu:
```nginx
location /api/payment/sepay/webhook {
    # IPv4 Whitelist
    allow 172.236.138.20;
    allow 172.233.83.68;
    allow 171.244.35.2;
    allow 151.158.108.68;
    allow 151.158.109.79;
    allow 103.255.238.139;
    
    # IPv6 Whitelist
    allow 2400:8905::2000:8cff:fe98:45cd;
    allow 2600:3c15::2000:8aff:fedd:874b;
    
    deny all; # Chặn toàn bộ IP lạ bên ngoài

    proxy_pass http://csms_backend_upstream;
    proxy_set_header X-Real-IP $remote_addr;
}
```

---

## 8. TẠO MÃ QR VIETQR & THÔNG TIN CHUYỂN KHOẢN

### 8.1. Cấu trúc URL tạo mã QR động
`[Official SePay]` SePay cung cấp dịch vụ sinh ảnh VietQR tiêu chuẩn qua endpoint:
```
https://vietqr.app/img?acc={SO_TK}&bank={NGAN_HANG}&amount={SO_TIEN}&des={NOI_DUNG}
```
hoặc qua gateway SePay:
```
https://qr.sepay.vn/img?acc={SO_TK}&bank={NGAN_HANG}&amount={SO_TIEN}&des={NOI_DUNG}&template=compact
```

### 8.2. Ý nghĩa các tham số tạo QR
| Tham số | Kiểu | Bắt buộc | Mô tả |
| :--- | :---: | :---: | :--- |
| `acc` | `string` | **Có** | Số tài khoản ngân hàng thụ hưởng doanh nghiệp. |
| `bank` | `string` | **Có** | Mã ngắn ngân hàng (hoặc mã BIN Napas, ví dụ: `Vietcombank` hoặc `970436`, `MBBank` hoặc `970422`, `BIDV` hoặc `970418`, `ICB` hoặc `970415`, `ACB` hoặc `970416`). |
| `amount` | `integer` | **Có** | Số tiền nạp chính xác (VNĐ). **Bắt buộc điền sẵn để tránh user gõ sai số tiền**. |
| `des` | `string` | **Có** | Nội dung chuyển khoản (URL-encoded), **bắt buộc chứa Order Code duy nhất** (VD: `DEP260827000123`). |
| `template` | `string` | Không | Mẫu giao diện QR: `compact` (gọn), `qr_only` (chỉ mã QR), `full` (kèm khung). |

#### Bảng tra cứu mã định danh Ngân hàng Napas (Bank Code & BIN):
| Tên Ngân Hàng | Mã Ngắn (`bank`) | Mã BIN Napas |
| :--- | :--- | :--- |
| Vietcombank | `Vietcombank` hoặc `VCB` | `970436` |
| MBBank (Quân Đội) | `MBBank` hoặc `MB` | `970422` |
| BIDV (Đầu tư & Phát triển) | `BIDV` | `970418` |
| VietinBank (Công Thương) | `VietinBank` hoặc `ICB` | `970415` |
| Techcombank | `Techcombank` hoặc `TCB` | `970407` |
| ACB (Á Châu) | `ACB` | `970416` |
| TPBank (Tiên Phong) | `TPBank` hoặc `TPB` | `970423` |
| VPBank (Việt Nam Thịnh Vượng)| `VPBank` hoặc `VPB` | `970432` |
| Sacombank | `Sacombank` | `970403` |

### 8.3. Quy ước tạo Mã Thanh Toán (`order_code`)
`[Project Implementation]`
- **Quy tắc:** `DEP` + `[YYMMDD]` + `[6 KÝ TỰ NGẪU NHIÊN/SEQUENCE]`
- **Ví dụ:** `DEP260827A9B8C7` (Tổng độ dài 15 ký tự, không dấu, không khoảng trắng, chỉ gồm chữ hoa và số).
- **Cấu hình trên SePay Dashboard:** Cài đặt tiền tố mã thanh toán là `DEP` tại **Công ty -> Cấu hình chung -> Cấu trúc mã thanh toán**.

---

## 9. CƠ CHẾ KHỚP LỆNH & XỬ LÝ NGHIỆP VỤ BIÊN (PAYMENT MATCHING)

### 9.1. Thuật toán trích xuất và khớp Payment Order
`[Project Implementation]`
1. Kiểm tra trường `code` trong Webhook Payload. Nếu `code` có giá trị -> Tìm `payment_orders` theo `order_code = payload.code`.
2. Nếu `code == null` hoặc không khớp -> Dùng Regex quét trong chuỗi `content` hoặc `description` để tìm pattern `DEP[A-Z0-9]{8,14}`.
3. Nếu không tìm thấy bất kỳ mã đơn nào -> Chuyển giao dịch sang trạng thái `UNMATCHED` và ghi log `MANUAL_REVIEW`.

---

### 9.2. Ma trận xử lý các tình huống thanh toán (Edge Cases Matrix)
`[Project Implementation]` & `[Recommendation]`

```
                             +------------------------+
                             | Webhook đến từ SePay   |
                             +-----------+------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
              [Tìm thấy Order Code?]              [KHÔNG tìm thấy Order]
                       |                                   |
            +----------+----------+                        v
            |                     |              +-------------------+
        [Hợp lệ]              [Không hợp lệ]     |  MANUAL_REVIEW    |
            |                     |              | (Lưu event, chờ   |
            v                     v              |  kế toán xử lý)   |
  [Kiểm tra Số Tiền?]        +-----------+       +-------------------+
            |                | EXPIRED / |
      +-----+-----+          | CANCELLED |
      |     |     |          +-----+-----+
   [Đúng] [Thiếu] [Thừa]           |
      |     |     |                v
      |     |     |          +-------------------+
      |     |     |          |   LATE_PAID /     |
      |     |     |          |  MANUAL_REVIEW    |
      |     |     |          +-------------------+
      |     |     |
      |     |     +--------> Trạng thái: OVERPAID
      |     |                Policy: Nạp đúng số tiền thực nhận vào ví (hoặc nạp order + pending thừa)
      |     |
      |     +--------------> Trạng thái: UNDERPAID
      |                      Policy: KHÔNG cộng ví tự động. Giữ trạng thái, gửi thông báo nạp bổ sung.
      |
      +--------------------> Trạng thái: PAID
                             Policy: Cộng tiền vào Ví + Ghi Sổ cái POSTED (Atomic Transaction)
```

| STT | Kịch bản giao dịch | Trạng thái Đơn | Xử lý Sổ cái Ví (`app_wallet_ledger`) | Hành động hệ thống |
| :---: | :--- | :--- | :--- | :--- |
| **1** | **Đúng mã + Đúng số tiền + Còn hạn** | `PAID` | Tạo ledger `type=DEPOSIT`, `amount=transferAmount`, `status=POSTED` | **Thành công**. Số dư ví tăng ngay lập tức. |
| **2** | **Đúng mã + Chuyển thiếu tiền** (VD: Đơn 100k, chuyển 90k) | `UNDERPAID` | **KHÔNG** tạo ledger cộng tiền tự động | Đơn chuyển `UNDERPAID`. Push notification báo khách nạp bù `10k` hoặc liên hệ CSKH. |
| **3** | **Đúng mã + Chuyển thừa tiền** (VD: Đơn 100k, chuyển 150k) | `OVERPAID` | Tạo ledger `type=DEPOSIT`, `amount=150000` (Thực nhận) | Đơn chuyển `OVERPAID`. Cộng đủ 150.000 VNĐ vào ví khách hàng, ghi chú audit log. |
| **4** | **Đúng mã nhưng đơn đã `EXPIRED`** (Quá 15 phút) | `LATE_PAID` | Tạo ledger `type=DEPOSIT` nếu cấu hình Auto-Revive = True | Kích hoạt lại đơn thành công, cộng ví cho khách để tránh khiếu nại. |
| **5** | **Đúng mã nhưng đơn đã `PAID` trước đó** (Khách chuyển 2 lần) | Giữ nguyên `PAID` | Tạo ledger `type=DEPOSIT`, `desc='Nạp tiền trùng đơn cũ'` | Ghi nhận tiền vào ví khách nhưng cảnh báo kế toán kiểm tra. |
| **6** | **Sai mã / Không có mã chuyển khoản** | Không có đơn | **KHÔNG** thao tác ví | Lưu raw webhook event, hiển thị trên Dashboard Admin `MANUAL_REVIEW`. |
| **7** | **Giao dịch rút tiền (`transferType = "out"`)** | Bỏ qua | Không áp dụng cho cổng nạp tiền | Ghi log `IGNORED`, trả về `{"success": true}` cho SePay. |

---

## 10. CHỐNG TRÙNG LẶP & XỬ LÝ ĐỒNG THỜI (IDEMPOTENCY & CONCURRENCY)

### 10.1. Nguy cơ Race Condition
Do cơ chế Webhook Retry của SePay hoặc do Admin bấm "Gửi lại" trên Dashboard SePay, 2 request cho cùng 1 giao dịch có thể đến server CSMS gần như đồng thời (cùng mili-giây). Nếu chỉ dùng `if (!isPaid)` ở tầng ứng dụng, cả 2 luồng sẽ cùng thấy đơn `PENDING` và dẫn đến **CỘNG TIỀN 2 LẦN**.

### 10.2. Giải pháp kỹ thuật 3 lớp (3-Tier Protection)
`[Recommendation]` & `[Project Implementation]`

1. **Lớp 1: Khóa Unique tại Database cho Webhook Event**
   `UNIQUE(provider, provider_transaction_id)` trên bảng `payment_webhook_events`. Nếu transaction ID đã tồn tại -> `ON CONFLICT DO NOTHING`.
2. **Lớp 2: Khóa dòng hàng Đơn thanh toán (Pessimistic Row Lock)**
   Thực thi `SELECT * FROM payment_orders WHERE order_code = $1 FOR UPDATE` bên trong Transaction. Luồng thứ hai buộc phải đợi luồng thứ nhất commit xong mới được đọc trạng thái mới.
3. **Lớp 3: Khóa Unique Sổ cái Ví (Ledger Idempotency Key)**
   Bảng `app_wallet_ledger` có ràng buộc `UNIQUE(idempotency_key)`. Giá trị `idempotency_key = 'SEPAY_TX_' || provider_transaction_id`. Nếu có bất kỳ lỗi logic nào cố tình insert đúp, Database sẽ chặn ngay lập tức.

---

### 10.3. Code mẫu Xử lý Webhook Transaction trong Go (Chi tiết đầy đủ)
`[Project Implementation]`

```go
package sepay

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"regexp"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WebhookPayload struct {
	ID              int64   `json:"id"`
	Gateway         string  `json:"gateway"`
	TransactionDate string  `json:"transactionDate"`
	AccountNumber   string  `json:"accountNumber"`
	SubAccount      string  `json:"subAccount"`
	Code            *string `json:"code"`
	Content         string  `json:"content"`
	TransferType    string  `json:"transferType"`
	Description     string  `json:"description"`
	TransferAmount  float64 `json:"transferAmount"`
	Accumulated     float64 `json:"accumulated"`
	ReferenceCode   string  `json:"referenceCode"`
}

type PaymentWebhookHandler struct {
	db       *pgxpool.Pool
	verifier *WebhookVerifier
}

func NewPaymentWebhookHandler(db *pgxpool.Pool, verifier *WebhookVerifier) *PaymentWebhookHandler {
	return &PaymentWebhookHandler{db: db, verifier: verifier}
}

var orderCodeRegex = regexp.MustCompile(`DEP[A-Z0-9]{6,16}`)

func ExtractOrderCode(content string) string {
	match := orderCodeRegex.FindString(content)
	return match
}

func (h *PaymentWebhookHandler) HandleWebhook(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 15*time.Second)
	defer cancel()

	// 1. Đọc Raw Body
	defer r.Body.Close()
	rawBody, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, `{"success":false,"message":"cannot read body"}`, http.StatusBadRequest)
		return
	}

	// 2. Xác thực Chữ ký HMAC-SHA256
	if err := h.verifier.VerifyRequest(r, rawBody); err != nil {
		http.Error(w, `{"success":false,"message":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	// 3. Parse JSON Payload
	var p WebhookPayload
	if err := json.Unmarshal(rawBody, &p); err != nil {
		http.Error(w, `{"success":false,"message":"invalid json"}`, http.StatusBadRequest)
		return
	}

	providerTxID := fmt.Sprintf("%d", p.ID)

	// 4. Chỉ xử lý tiền vào (transferType == "in")
	if p.TransferType != "in" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"ignored out transfer"}`))
		return
	}

	// 5. Khởi tạo Database Transaction
	tx, err := h.db.BeginTx(ctx, pgx.TxOptions{IsoLevel: pgx.ReadCommitted})
	if err != nil {
		http.Error(w, `{"success":false,"message":"db error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback(ctx)

	// Lớp 1: Ghi nhận Webhook Event (Idempotent Check)
	headersJSON, _ := json.Marshal(map[string]string{
		"signature": r.Header.Get("X-SePay-Signature"),
		"timestamp": r.Header.Get("X-SePay-Timestamp"),
	})

	var eventID string
	err = tx.QueryRow(ctx, `
		INSERT INTO payment_webhook_events (
			provider, provider_transaction_id, event_type, payload, headers, status
		) VALUES ($1, $2, 'BANK_TRANSFER_IN', $3::jsonb, $4::jsonb, 'PROCESSED')
		ON CONFLICT (provider, provider_transaction_id) DO NOTHING
		RETURNING id
	`, "SEPAY", providerTxID, string(rawBody), string(headersJSON)).Scan(&eventID)

	if err == pgx.ErrNoRows {
		// Đã nhận và xử lý transaction này từ trước -> Trả HTTP 200 ngay để SePay dừng retry
		tx.Rollback(ctx)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"transaction already processed"}`))
		return
	} else if err != nil {
		http.Error(w, `{"success":false,"message":"db insert event error"}`, http.StatusInternalServerError)
		return
	}

	// Lấy Order Code từ code field hoặc trích xuất từ content
	orderCode := ""
	if p.Code != nil && *p.Code != "" {
		orderCode = *p.Code
	} else {
		orderCode = ExtractOrderCode(p.Content)
	}

	if orderCode == "" {
		// Không có mã đơn -> Đưa về UNMATCHED để kế toán xử lý thủ công
		tx.Exec(ctx, `UPDATE payment_webhook_events SET status='UNMATCHED' WHERE id=$1`, eventID)
		tx.Commit(ctx)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"unmatched order code, logged for manual review"}`))
		return
	}

	// Lớp 2: Khóa dòng đơn hàng (Row Lock)
	var orderID, appUserID, tenantID, orderStatus string
	var expectedAmount float64
	var expiredAt time.Time

	err = tx.QueryRow(ctx, `
		SELECT id, app_user_id, tenant_id, amount, status, expired_at 
		FROM payment_orders 
		WHERE order_code = $1 
		FOR UPDATE
	`, orderCode).Scan(&orderID, &appUserID, &tenantID, &expectedAmount, &orderStatus, &expiredAt)

	if err == pgx.ErrNoRows {
		tx.Exec(ctx, `UPDATE payment_webhook_events SET status='ORDER_NOT_FOUND' WHERE id=$1`, eventID)
		tx.Commit(ctx)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"order not found"}`))
		return
	} else if err != nil {
		http.Error(w, `{"success":false,"message":"db lock error"}`, http.StatusInternalServerError)
		return
	}

	if orderStatus == "PAID" {
		tx.Commit(ctx)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"order already paid"}`))
		return
	}

	// Kiểm tra trạng thái đơn và số tiền chuyển khoản
	finalStatus := "PAID"
	if orderStatus == "EXPIRED" {
		finalStatus = "LATE_PAID" // Khách chuyển sau khi đơn hết hạn (Late payment auto-recovery)
	}

	creditAmount := p.TransferAmount
	if p.TransferAmount < expectedAmount {
		// Chuyển thiếu tiền -> Đánh dấu UNDERPAID, không cộng ví tự động
		tx.Exec(ctx, `
			UPDATE payment_orders 
			SET status='UNDERPAID', paid_amount=$1, provider_transaction_id=$2, updated_at=NOW() 
			WHERE id=$3
		`, p.TransferAmount, providerTxID, orderID)
		tx.Commit(ctx)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(`{"success":true,"message":"underpaid recorded"}`))
		return
	} else if p.TransferAmount > expectedAmount {
		finalStatus = "OVERPAID"
	}

	// Lớp 3: Cập nhật Payment Order -> PAID & Ghi Sổ cái Ví (Wallet Ledger)
	_, err = tx.Exec(ctx, `
		UPDATE payment_orders 
		SET status=$1, paid_amount=$2, provider_transaction_id=$3, paid_at=NOW(), updated_at=NOW() 
		WHERE id=$4
	`, finalStatus, p.TransferAmount, providerTxID, orderID)
	if err != nil {
		http.Error(w, `{"success":false,"message":"update order failed"}`, http.StatusInternalServerError)
		return
	}

	// Lấy Wallet ID của User (Khởi tạo tự động nếu chưa có)
	var walletID string
	err = tx.QueryRow(ctx, `
		INSERT INTO app_wallets (app_user_id, tenant_id, currency) 
		VALUES ($1, $2, 'VND')
		ON CONFLICT (app_user_id) DO UPDATE SET tenant_id = EXCLUDED.tenant_id
		RETURNING id
	`, appUserID, tenantID).Scan(&walletID)
	if err != nil {
		http.Error(w, `{"success":false,"message":"wallet provision error"}`, http.StatusInternalServerError)
		return
	}

	// Insert Sổ cái Ví (app_wallet_ledger)
	ledgerIdempotencyKey := fmt.Sprintf("SEPAY_TX_%s", providerTxID)
	_, err = tx.Exec(ctx, `
		INSERT INTO app_wallet_ledger (
			wallet_id, amount, entry_type, status, external_reference, idempotency_key, description
		) VALUES (
			$1, $2, 'DEPOSIT', 'POSTED', $3, $4, $5
		)
	`, walletID, creditAmount, orderID, ledgerIdempotencyKey, fmt.Sprintf("Nap tien Vi THACO Charge qua SePay (GD: %s)", providerTxID))
	if err != nil {
		http.Error(w, `{"success":false,"message":"ledger insert failed"}`, http.StatusInternalServerError)
		return
	}

	// Commit Transaction
	if err := tx.Commit(ctx); err != nil {
		http.Error(w, `{"success":false,"message":"commit failed"}`, http.StatusInternalServerError)
		return
	}

	// 6. Trả phản hồi thành công chuẩn cho SePay
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write([]byte(`{"success":true}`))
}
```

---

## 11. SEPAY API V2 & CƠ CHẾ ĐỐI SOÁT TỰ ĐỘNG (RECONCILIATION ENGINE)

### 11.1. Vai trò của SePay API v2 vs Webhook
`[Official SePay]`
- **Webhook:** Thông báo đẩy thời gian thực (Push notification) phục vụ nạp tiền tức thì.
- **REST API v2:** Kênh truy vấn chủ động (Pull query) phục vụ tra cứu lịch sử, kiểm tra chi tiết và đối soát định kỳ.

#### Thông số kỹ thuật API v2:
- **Base URL:**
  - Production: `https://userapi.sepay.vn/v2`
  - Sandbox: `https://userapi-sandbox.sepay.vn/v2`
- **Authentication:** `Authorization: Bearer <SEPAY_API_TOKEN>`
- **Rate Limit:** Tối đa **3 requests/giây**. Quá giới hạn sẽ nhận `HTTP 429 Too Many Requests`.

---

### 11.2. Endpoint Tra Cứu Danh Sách Giao Dịch (`GET /v2/transactions`)
`[Official SePay]`
```http
GET https://userapi.sepay.vn/v2/transactions?transaction_date_from=2026-08-27%2000:00:00&transaction_date_to=2026-08-27%2023:59:59&transfer_type=in&page=1&per_page=100
Authorization: Bearer YOUR_SEPAY_API_TOKEN
```

#### Response Envelope chuẩn:
```json
{
  "status": 200,
  "messages": ["success"],
  "data": {
    "transactions": [
      {
        "id": "92704",
        "bank_brand_name": "Vietcombank",
        "account_number": "1017588888",
        "transaction_date": "2026-08-27 15:30:12",
        "amount_in": 200000,
        "amount_out": 0,
        "accumulated": 105200000,
        "transaction_content": "DEP260827000123 NGUYEN VAN A NAP TIEN",
        "reference_number": "FT26082712345678",
        "code": "DEP260827000123",
        "sub_account": ""
      }
    ],
    "pagination": {
      "page": 1,
      "per_page": 100,
      "total": 1,
      "total_pages": 1
    }
  }
}
```

---

### 11.3. Cơ chế Đối soát Tự Động (Reconciliation Cron Job)
`[Project Implementation]` & `[Recommendation]` Chạy nền định kỳ mỗi **15 phút** hoặc cuối ngày (23:45 GMT+7) để quét bù các giao dịch bị rớt Webhook do sự cố mạng:

```mermaid
flowchart TD
    Start(["Cron Trigger: 15m / Hàng ngày"]) --> QueryAPI["Gọi SePay API v2: GET /v2/transactions"]
    QueryAPI --> Loop["Duyệt từng Transaction từ SePay"]
    
    Loop --> CheckLocal{"Đã tồn tại trong<br/>payment_webhook_events?"}
    
    CheckLocal -- ĐÃ CÓ --> CheckStatus{"Payment Order<br/>status == PAID?"}
    CheckStatus -- ĐÃ PAID --> MarkReconciled["Ghi nhận: MATCHED"]
    CheckStatus -- CHƯA PAID --> FixLocal["Cập nhật PAID & Ghi Sổ Cái Ví"]
    
    CheckLocal -- CHƯA CÓ --> CheckCode{"Có Order Code<br/>hợp lệ không?"}
    CheckCode -- CÓ CODE --> AutoHeal["Tự động bù giao dịch: Insert Event + Cập nhật PAID + Cộng Ví"]
    CheckCode -- KHÔNG CODE --> MarkManual["Ghi nhận: MISSING_LOCAL (Báo động Alert Kế toán)"]
    
    FixLocal --> NextItem["Tiếp tục giao dịch kế tiếp"]
    MarkReconciled --> NextItem
    AutoHeal --> NextItem
    MarkManual --> NextItem
    
    NextItem --> HasMore{"Còn giao dịch trong danh sách?"}
    HasMore -- Còn --> Loop
    HasMore -- Hết --> SendReport["Tổng hợp Báo Cáo Đối Soát Gửi Admin"]
    SendReport --> End(["Kết thúc Job"])
```

---

## 12. QUY TRÌNH HOÀN TIỀN & ĐIỀU CHỈNH THỦ CÔNG (REFUND POLICY)

`[Official SePay]` **Xác nhận từ tài liệu SePay:** SePay là nền tảng giám sát biến động số dư và cấp cổng thanh toán trực tiếp vào tài khoản ngân hàng của chính doanh nghiệp. SePay **KHÔNG PHẢI VÍ TRUNG GIAN GIỮ TIỀN** và **KHÔNG CÓ API TỰ ĐỘNG CHUYỂN TIỀN RÚT TỪ TÀI KHOẢN NGÂN HÀNG DOANH NGHIỆP VỀ CHO KHÁCH HÀNG (NO AUTO-REFUND API)**.

### Quy trình hoàn tiền chuẩn (Standard Refund Workflow):
`[Project Implementation]`
1. **Khách hàng gửi yêu cầu:** Yêu cầu hoàn tiền đơn nạp lỗi / chuyển thừa tiền.
2. **Kế toán duyệt đơn:** Đối soát trên Dashboard SePay và Sao kê Ngân hàng.
3. **Thực hiện chuyển khoản:** Kế toán chủ động thực hiện chuyển tiền từ Internet Banking doanh nghiệp về STK của khách hàng.
4. **Cập nhật hệ thống CSMS:**
   - Cập nhật trạng thái `payment_orders` thành `REFUNDED`.
   - Tạo bút toán đảo ngược trên Sổ cái Ví:
     ```sql
     INSERT INTO app_wallet_ledger (
         wallet_id, amount, entry_type, status, external_reference, idempotency_key, description
     ) VALUES (
         $1, -100000, 'REFUND', 'POSTED', $order_id, 'REFUND_DEP260827000123', 'Hoan tien don nap DEP260827000123'
     );
     ```
   - Ghi nhật ký Audit Log (`audit_logs`) lưu vết Admin ID và lý do hoàn tiền.

---

## 13. ĐẶC TẢ API BACKEND CSMS

### 13.1. Tạo Đơn Nạp Tiền (`POST /api/mobile/wallet/deposit`)
`[Project Implementation]`
- **Authentication:** `Bearer <Firebase_ID_Token>`
- **Request Body:**
  ```json
  {
    "amount": 200000
  }
  ```
- **Response Body (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "paymentId": "7d9b23b4-1c23-4c92-91e8-782a93b45102",
      "orderCode": "DEP260827000123",
      "amount": 200000,
      "currency": "VND",
      "status": "PENDING",
      "payment": {
        "accountNumber": "1017588888",
        "accountName": "CONG TY CO PHAN SEPAY",
        "bankShortName": "Vietcombank",
        "transferContent": "DEP260827000123",
        "qrCodeUrl": "https://vietqr.app/img?acc=1017588888&bank=Vietcombank&amount=200000&des=DEP260827000123"
      },
      "expiredAt": "2026-08-27T15:45:12Z",
      "createdAt": "2026-08-27T15:30:12Z"
    }
  }
  ```

---

### 13.2. Tra Cứu Trạng Thái Đơn Nạp (`GET /api/mobile/wallet/deposit/:id`)
`[Project Implementation]`
- **Authentication:** `Bearer <Firebase_ID_Token>`
- **Response Body (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "paymentId": "7d9b23b4-1c23-4c92-91e8-782a93b45102",
      "orderCode": "DEP260827000123",
      "amount": 200000,
      "status": "PAID",
      "paidAt": "2026-08-27T15:31:05Z",
      "walletBalance": 550000
    }
  }
  ```

---

### 13.3. Endpoint Nhận Webhook SePay (`POST /api/payment/sepay/webhook`)
`[Project Implementation]`
- **Authentication:** Header `X-SePay-Signature` & `X-SePay-Timestamp`
- **Response Body:**
  ```json
  {
    "success": true
  }
  ```

---

## 14. THIẾT KẾ MỞ RỘNG NHIỀU CỔNG THANH TOÁN (MULTI-PROVIDER ARCHITECTURE)

`[Recommendation]` Để hệ thống có thể tích hợp thêm các cổng thanh toán khác trong tương lai (Stripe, PayOS, VNPay, MoMo) mà **KHÔNG CẦN SỬA ĐỔI LOGIC VÍ VÀ SỔ CÁI (WALLET CORE)**, sử dụng Pattern **Provider Strategy / Adapter**:

### 14.1. Cấu trúc thư mục mã nguồn Backend (Clean Architecture)
```
csms-platform/backend-go/internal/payment/
├── domain/                         # Core Payment Business Logic
│   ├── payment_order.go            # Entity PaymentOrder & States
│   ├── wallet.go                   # Entity Wallet & Ledger
│   └── repository.go               # DB Interfaces
├── provider/                       # Payment Gateway Abstraction
│   ├── provider.go                 # PaymentProvider Interface
│   └── sepay/                      # SePay Implementation Adapter
│       ├── client.go               # SePay API v2 REST Client
│       ├── verifier.go             # HMAC-SHA256 & Timestamp Verifier
│       ├── mapper.go               # VietQR generator & Payload Mapper
│       └── webhook.go              # Webhook Handler
├── service/                        # Application Services
│   ├── payment_service.go          # CreateDeposit, ProcessPaidOrder
│   ├── wallet_service.go           # CreditBalance, DebitCharging
│   └── reconciliation_service.go   # Cron Reconciliation Job
└── http/                           # API Controllers & Routers
    ├── mobile_handler.go           # App Mobile Endpoints
    └── webhook_handler.go          # SePay Webhook Endpoint
```

### 14.2. Go Interface: `PaymentProvider`
`[Project Implementation]`

```go
package provider

import (
	"context"
	"net/http"
)

type CreatePaymentRequest struct {
	OrderCode   string
	Amount      float64
	Currency    string
	Description string
}

type CreatePaymentResponse struct {
	ProviderTransactionID string
	QRCodeURL             string
	AccountNumber         string
	AccountName           string
	BankShortName         string
	TransferContent       string
}

type WebhookResult struct {
	ProviderTransactionID string
	OrderCode             string
	Amount                float64
	TransferType          string
	IsSuccess             bool
	RawPayload            []byte
}

type PaymentProvider interface {
	// Name định danh Provider (VD: "SEPAY", "VNPAY", "STRIPE")
	Name() string
	
	// CreatePayment sinh thông tin chuyển khoản / QR
	CreatePayment(ctx context.Context, req CreatePaymentRequest) (*CreatePaymentResponse, error)
	
	// ParseAndVerifyWebhook xác thực chữ ký và trích xuất dữ liệu chuẩn
	ParseAndVerifyWebhook(r *http.Request) (*WebhookResult, error)
	
	// QueryTransaction tra cứu trực tiếp qua REST API đối soát
	QueryTransaction(ctx context.Context, txID string) (*WebhookResult, error)
}
```

---

## 15. MA TRẬN KIỂM THỬ (TESTING MATRIX)

| Mã kiểm thử | Tên Test Case | Điều kiện đầu vào | Kết quả mong đợi (Expected Output) |
| :--- | :--- | :--- | :--- |
| **TC-01** | Happy Path Deposit | Đơn 100.000đ, chuyển đúng 100.000đ kèm đúng mã `DEP...` | Webhook HTTP 200, Order = `PAID`, Ledger +100.000đ, Ví tăng 100.000đ. |
| **TC-02** | Duplicate Webhook | Gửi lại Webhook của `TC-01` lần 2 (cùng Transaction ID `92704`) | Webhook HTTP 200, **KHÔNG** ghi thêm ledger, số dư ví giữ nguyên. |
| **TC-03** | Concurrent Webhook | 2 Webhook cùng Transaction ID gửi song song trong cùng 10ms | Chỉ 1 luồng insert thành công, 1 luồng dính `ON CONFLICT`, ví cộng duy nhất 1 lần. |
| **TC-04** | Invalid Signature | Sửa đổi 1 byte trong body hoặc sai Secret Key | Server trả về `HTTP 401 Unauthorized`, không sửa DB. |
| **TC-05** | Expired Timestamp | Timestamp trong header lệch quá 300 giây (> 5 phút) | Server trả về `HTTP 401 Unauthorized` (Replay Attack Rejected). |
| **TC-06** | Underpaid Transfer | Đơn 100.000đ nhưng khách chuyển 90.000đ | Order = `UNDERPAID`, **KHÔNG** cộng tiền vào ví, gửi thông báo nạp thiếu. |
| **TC-07** | Overpaid Transfer | Đơn 100.000đ nhưng khách chuyển 150.000đ | Order = `OVERPAID`, cộng đúng 150.000đ vào ví khách hàng. |
| **TC-08** | Missing Order Code | Nội dung chuyển khoản: "Nguyen Van A ung ho" | Webhook HTTP 200, Event = `UNMATCHED`, lưu lại để đối soát thủ công. |
| **TC-09** | Missing Webhook Auto-heal | Giả lập rớt Webhook, chạy Cron Reconciliation sau 15 phút | Cron phát hiện đơn `MISSING_LOCAL`, tự động bù giao dịch chuyển `PAID`. |

---

## 16. MÔI TRƯỜNG THỬ NGHIỆM SANDBOX & PRODUCTION

### 16.1. Chế độ Test Mode (Sandbox) SePay
`[Official SePay]`
- **SePay Dashboard Test Mode:** Bật tính năng "Test Mode" trong trang quản trị SePay để kiểm thử mà không cần chuyển tiền ngân hàng thật.
- **Tạo giao dịch giả lập:** Bấm nút "Tạo giao dịch mẫu" trên giao diện SePay hoặc gọi Sandbox API.
- **Nút "Gửi thử" Webhook:** Trong cấu hình Webhook, bấm `⋯` -> **Gửi thử** để kiểm tra endpoint server có nhận được request và trả về `{"success": true}` hay không.

### 16.2. Phân tách môi trường (Environment Isolation)
| Thông số cấu hình | Development / Staging | Production |
| :--- | :--- | :--- |
| **SePay API Base URL** | `https://userapi-sandbox.sepay.vn/v2` | `https://userapi.sepay.vn/v2` |
| **SePay Environment** | `sandbox` | `production` |
| **Webhook Endpoint** | Public URL qua Ngrok / Cloudflare Tunnel | `https://csms.factorydata.online/api/payment/sepay/webhook` |
| **Database** | Postgres Dev / Docker | Postgres Production Cluster Managed |
| **Tài khoản thụ hưởng** | Ngân hàng Test / Sandbox Account | Tài khoản Ngân hàng Doanh nghiệp chính thức |

---

## 17. CẤU HÌNH MÔI TRƯỜNG (ENVIRONMENT VARIABLES)

Các biến cấu hình bắt buộc phải khai báo trong file `.env` hoặc hệ thống quản lý Secret (Docker Secrets / Kubernetes Secrets / Vault):

```ini
# ==============================================================================
# SEPAY PAYMENT GATEWAY CONFIGURATION
# ==============================================================================
# Môi trường hoạt động: 'sandbox' hoặc 'production'
SEPAY_ENVIRONMENT=production

# Token xác thực khi gọi SePay REST API v2 (Lấy từ Dashboard SePay)
SEPAY_API_TOKEN=sec_prod_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Secret Key dùng để ký và xác thực chữ ký HMAC-SHA256 Webhook
SEPAY_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# Thông tin tài khoản ngân hàng nhận tiền nạp
SEPAY_BANK_SHORT_NAME=Vietcombank
SEPAY_BANK_ACCOUNT_NO=1017588888
SEPAY_BANK_ACCOUNT_NAME=CONG TY CO PHAN SEPAY

# Tiền tố mã đơn hàng (Đồng bộ với cấu hình mã thanh toán trên SePay)
SEPAY_ORDER_PREFIX=DEP

# Thời gian hết hạn của mã QR và đơn nạp tiền (phút)
SEPAY_ORDER_EXPIRY_MINUTES=15

# Bật/Tắt chế độ tự động bù giao dịch trong Cron đối soát
SEPAY_AUTO_HEAL_RECONCILIATION=true
```

> `[Recommendation]` **Cảnh báo bảo mật:** Tuyệt đối **KHÔNG ĐƯỢC** commit các giá trị Token và Secret thật vào Git repository.

---

## 18. GIÁM SÁT, GHI LOG & CẢNH BÁO (OBSERVABILITY & ALERTING)

### 18.1. Chuẩn Structured Logging (JSON Logs)
`[Project Implementation]` Không log các thông tin nhạy cảm (Secret Key, Token). Mọi log giao dịch phải đính kèm `trace_id`, `order_code`, `provider_tx_id`:

```json
{
  "timestamp": "2026-08-27T15:30:12.102Z",
  "level": "INFO",
  "logger": "payment.sepay.webhook",
  "event": "payment.webhook.processed",
  "provider": "SEPAY",
  "provider_tx_id": "92704",
  "order_code": "DEP260827000123",
  "amount": 200000,
  "currency": "VND",
  "status": "PAID",
  "duration_ms": 42
}
```

### 18.2. Danh mục Metrics Prometheus
`[Recommendation]`
- `payment_orders_created_total{provider="sepay"}`: Tổng số đơn nạp được khởi tạo.
- `payment_orders_paid_total{provider="sepay"}`: Tổng số đơn nạp thành công.
- `payment_webhook_received_total{provider="sepay"}`: Tổng số webhook nhận được.
- `payment_webhook_duplicate_total{provider="sepay"}`: Số lượng webhook trùng lặp bị chặn.
- `payment_webhook_failed_total{reason="invalid_signature|timeout|db_error"}`: Số webhook lỗi.
- `payment_amount_mismatch_total{type="underpaid|overpaid"}`: Số giao dịch sai lệch tiền.
- `payment_reconciliation_discrepancy_total`: Số giao dịch lệch khi chạy đối soát.

### 18.3. Quy tắc Cảnh Báo (Alerting Rules qua Telegram / Slack Bot)
`[Recommendation]`
1. **Webhook Lỗi liên tiếp:** Nếu `rate(payment_webhook_failed_total[5m]) > 3` -> Báo động đỏ (Kênh khẩn cấp).
2. **Đơn nạp lệch tiền:** Có phát sinh giao dịch `UNDERPAID` hoặc `OVERPAID` -> Báo kênh Kế toán.
3. **Lệch Đối Soát:** Job đối soát phát hiện giao dịch `MISSING_LOCAL` không thể auto-heal -> Báo động Admin.

---

## 19. HƯỚNG DẪN XỬ LÝ SỰ CỐ (TROUBLESHOOTING GUIDE)

`[Official SePay]` & `[Project Implementation]`

| Hiện tượng lỗi | Nguyên nhân gốc rễ (Root Cause) | Cách kiểm tra (Diagnosis) | Giải pháp khắc phục |
| :--- | :--- | :--- | :--- |
| **SePay báo lỗi Webhook HTTP 401** | Sai Secret Key hoặc sai logic xác thực HMAC-SHA256 | Kiểm tra biến `SEPAY_WEBHOOK_SECRET` và log so sánh chữ ký | 1. Đồng bộ lại Secret Key.<br/>2. Đảm bảo dùng **Raw Body byte gốc**, không dùng body đã parse JSON serialize lại. |
| **SePay báo lỗi Timeout (>30s)** | Server xử lý đồng bộ quá nặng trước khi trả response | Kiểm tra Database Connection Pool hoặc deadlock | 1. Tối ưu transaction DB < 500ms.<br/>2. Hoặc trả `HTTP 200` ngay sau khi lưu raw event rồi đẩy vào Queue worker. |
| **Khách chuyển tiền nhưng không nhận được Webhook** | 1. Webhook bị tắt trên SePay Dashboard.<br/>2. Firewall/Nginx chặn IP SePay.<br/>3. Sai URL endpoint. | 1. Bấm nút **Gửi thử** trên Dashboard SePay.<br/>2. Kiểm tra Nginx access log xem có request đến không. | 1. Bật lại Webhook sang trạng thái **Bật**.<br/>2. Mở Whitelist IP SePay trên Nginx/Firewall. |
| **Tiền bị cộng 2 lần** | Mất Idempotency hoặc thiếu Unique Constraint | Kiểm tra bảng `app_wallet_ledger` xem có 2 dòng cùng `idempotency_key` không | Đảm bảo kích hoạt `UNIQUE(idempotency_key)` và dùng Transaction Row Lock `FOR UPDATE`. |
| **Khách đã chuyển tiền nhưng đơn vẫn `PENDING`** | Khách chuyển sai nội dung chuyển khoản hoặc gõ thiếu mã đơn | Kiểm tra bảng `payment_webhook_events` tìm các dòng có status `UNMATCHED` | Kế toán vào màn hình Admin -> Chọn đơn treo -> Bấm **Khớp lệnh thủ công (Manual Match)**. |
| **Lỗi lệch Timestamp (> 300s)** | Đồng hồ server bị lệch giờ so với giờ chuẩn quốc tế | Chạy lệnh `timedatectl` trên Linux server | Cài đặt và kích hoạt dịch vụ đồng bộ giờ NTP (`systemd-timesyncd` hoặc `chrony`). |

---

## 20. CHECKLIST TRIỂN KHAI PRODUCTION

Trước khi mở tính năng nạp tiền SePay cho người dùng thực tế, bắt buộc hoàn thành 100% danh mục kiểm tra:

- [ ] **Tài khoản Doanh nghiệp:** Đã đăng ký và xác minh tài khoản SePay chính thức, đã liên kết STK ngân hàng công ty.
- [ ] **Bảo mật HTTPS:** Endpoint Webhook chạy trên domain có chứng chỉ SSL/TLS hợp lệ (Let's Encrypt / DigiCert), không dùng Self-signed.
- [ ] **Bảo mật Webhook:** Đã cấu hình xác thực **HMAC-SHA256** trên Dashboard SePay và lưu `SEPAY_WEBHOOK_SECRET` an toàn.
- [ ] **IP Whitelist:** Đã cấu hình tường lửa Nginx / AWS Security Group chỉ cho phép dải IP của SePay gọi vào endpoint Webhook.
- [ ] **Database Constraints:** Đã tạo đầy đủ các bảng `payment_orders`, `payment_webhook_events`, `payment_reconciliation` kèm đầy đủ Unique Index.
- [ ] **Idempotency & Concurrency:** Đã chạy thử nghiệm tải giả lập 2 webhook đồng thời (TC-03) và xác nhận tiền chỉ cộng 1 lần duy nhất.
- [ ] **Xử lý Sai Tiền:** Đã kiểm thử các case chuyển thiếu tiền (`UNDERPAID`) và chuyển thừa tiền (`OVERPAID`).
- [ ] **Cron Đối Soát:** Đã lên lịch cron job chạy đối soát định kỳ qua SePay REST API v2 (`GET /v2/transactions`).
- [ ] **Cấu hình Tiền tố:** Đã cài đặt tiền tố mã đơn `DEP` trên cả Backend và cấu hình SePay Dashboard.
- [ ] **Giao dịch Thử nghiệm Giá trị Nhỏ:** Đã thực hiện nạp thật 10.000 VNĐ qua app ngân hàng và kiểm tra số dư ví trên App THACO Charge lên ngay lập tức.
- [ ] **Giám sát & Cảnh báo:** Bot cảnh báo Telegram/Slack đã kết nối và thông báo khi có sự cố.

---

## 21. TÀI LIỆU THAM KHẢO (REFERENCES)

Tất cả các đặc tả trong tài liệu này được đối chiếu trực tiếp từ cổng thông tin nhà phát triển chính thức của SePay:

1. **Tổng quan SePay Webhooks:** [https://developer.sepay.vn/vi/sepay-webhooks](https://developer.sepay.vn/vi/sepay-webhooks)
2. **Tích hợp Webhook vào Server:** [https://developer.sepay.vn/vi/sepay-webhooks/tich-hop-webhook](https://developer.sepay.vn/vi/sepay-webhooks/tich-hop-webhook)
3. **Xác thực Webhook (HMAC-SHA256, API Key):** [https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc](https://developer.sepay.vn/vi/sepay-webhooks/xac-thuc)
4. **Bảo mật Webhook & IP Whitelist:** [https://developer.sepay.vn/vi/sepay-webhooks/bao-mat](https://developer.sepay.vn/vi/sepay-webhooks/bao-mat)
5. **Xử lý lỗi Webhook & Lịch Retry Fibonacci:** [https://developer.sepay.vn/vi/sepay-webhooks/xu-ly-loi](https://developer.sepay.vn/vi/sepay-webhooks/xu-ly-loi)
6. **Tạo mã QR VietQR Chuyển Khoản:** [https://developer.sepay.vn/vi/sepay-webhooks/tao-qr-va-form-thanh-toan](https://developer.sepay.vn/vi/sepay-webhooks/tao-qr-va-form-thanh-toan)
7. **SePay API v2 - Giới thiệu & Tra cứu Giao dịch:** [https://developer.sepay.vn/vi/sepay-api/v2/gioi-thieu](https://developer.sepay.vn/vi/sepay-api/v2/gioi-thieu)
8. **Danh sách địa chỉ IP máy chủ SePay:** [https://developer.sepay.vn/vi/dia-chi-ip](https://developer.sepay.vn/vi/dia-chi-ip)

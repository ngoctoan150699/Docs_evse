# TỪ ĐIỂN THUẬT NGỮ & TỪ VIẾT TẮT HỆ THỐNG TRẠM SẠC THACO EVSE
## (MASTER GLOSSARY & DOMAIN ACRONYMS EXPLANATION)

> **Mục đích:** Tài liệu này chuẩn hóa và giải thích chi tiết, dễ hiểu toàn bộ các thuật ngữ chuyên ngành xe điện (EV), trạm sạc (EVSE), giao thức đám mây (OCPP), truyền thông nhúng (CAN, Modbus, SPI) và thanh toán tự động (SePay).  
> **Đối tượng:** Phù hợp cho cả Kỹ sư lập trình mới tiếp cận dự án lẫn Cấp quản lý / Lãnh đạo cần nắm vững bản chất công nghệ.

---

## 1. NHÓM THUẬT NGỮ TIÊU CHUẨN XE ĐIỆN & TRẠM SẠC (EV & CHARGING)

### 1.1. EVSE (Electric Vehicle Supply Equipment)
- **Định nghĩa:** Thiết bị cung cấp điện năng cho xe điện (thường gọi dân dã là "Trụ sạc" hoặc "Trạm sạc").
- **Bản chất kỹ thuật:** Theo chuẩn quốc tế IEC 61851, trạm sạc không đơn thuần là một dây cắm điện mà là một hệ thống thiết bị an toàn phức hợp gồm: rơ-le đóng cắt cách ly, bộ đo đếm điện năng, mạch điều khiển pilot, bộ phát xung PWM và vi xử lý giám sát nối đất/chống rò điện để đảm bảo không cấp điện ra súng khi chưa có xe kết nối an toàn.
- **Trong dự án THACO:** EVSE là hệ thống trạm sạc nhanh DC công suất cao (DC Fast Charger), cấp trực tiếp nguồn điện một chiều DC (lên tới 1000V / 250A) vào khối pin cao thế của xe ô tô điện.

### 1.2. OCPP (Open Charge Point Protocol)
- **Định nghĩa:** Giao thức mở quốc tế dùng để truyền thông giữa Trụ sạc (Charge Point) và Máy chủ Quản lý Trung tâm (CSMS - Central System).
- **Ý nghĩa thực tế:** Tương tự như giao thức HTTP dùng để tải trang web, OCPP cho phép bất kỳ trụ sạc của hãng nào (THACO, ABB, Schneider, StarCharge...) đều có thể kết nối vào bất kỳ hệ thống quản lý trạm sạc của nhà mạng nào mà không bị khóa cứng vào một nhà cung cấp phần cứng (tránh hiện tượng Vendor Lock-in).
- **Phiên bản sử dụng:** **OCPP 1.6J (JSON over WebSocket)**:
  - `JSON`: Định dạng dữ liệu dạng text gọn nhẹ, dễ đọc và xử lý.
  - `WebSocket`: Kết nối TCP song công 2 chiều liên tục (Full-duplex), cho phép máy chủ Cloud gửi lệnh điều khiển (bật/tắt sạc) xuống trụ sạc tức thì mà không cần trụ sạc phải liên tục gửi request hỏi máy chủ (Polling).

### 1.3. CSMS (Charging Station Management System)
- **Định nghĩa:** Hệ thống phần mềm quản lý trạm sạc trung tâm đặt trên máy chủ đám mây (Cloud Server).
- **Chức năng chính:**
  - Giám sát trạng thái hoạt động của hàng nghìn trụ sạc theo thời gian thực (Realtime Monitoring).
  - Quản lý người dùng, định danh thẻ RFID, tài khoản ví tài xế.
  - Điều khiển sạc từ xa: Bắt đầu (`RemoteStart`), Dừng (`RemoteStop`), Khóa/Mở súng sạc (`UnlockConnector`), Khởi động lại trụ (`Reset`).
  - Quản lý giá điện theo khung giờ (Time-of-Use Tariffs) và quyết toán hóa đơn tự động.
  - Cân bằng tải thông minh (Smart Charging) chống quá tải lưới điện trạm.
- **Trong dự án THACO:** CSMS được xây dựng bằng Go Microservices (hiệu năng cao) kết hợp giao diện quản trị Next.js hiện đại.

### 1.4. SECC (Supply Equipment Communication Controller) & EVCC (Electric Vehicle Communication Controller)
- **Bản chất:** Cặp đôi bộ điều khiển truyền thông thông minh giữa Trụ sạc và Xe điện:
  - **SECC**: Bộ điều khiển truyền thông nằm bên trong **Trụ sạc**.
  - **EVCC**: Bộ điều khiển truyền thông nằm trên **Xe ô tô điện**.
- **Cách thức truyền tin:** Sử dụng công nghệ truyền tín hiệu mạng qua đường dây điện **PLC (Power Line Communication - HomePlug GreenPHY)** chạy đè lên chính chân Pilot (CP) của cáp sạc.
- **Tiêu chuẩn giao tiếp:** Bắt tay theo chuẩn **ISO 15118** hoặc **DIN 70121** bằng định dạng nén nhị phân EXI. Cho phép xe và trụ trao đổi mã định danh xe (EVCCID), trạng thái pin (% SoC), công suất yêu cầu tối đa và hỗ trợ tính năng cắm sạc tự nhận dạng (Plug & Charge).

### 1.5. CP (Control Pilot) & PP (Proximity Pilot)
- **CP (Chân điều khiển Pilot):**
  - Tín hiệu tương tự (Analog) và xung số PWM 1 kHz ở mức điện áp 12V.
  - Dùng để xe và trụ nhận biết sự hiện diện của nhau và phát hiện trạng thái cắm cáp:
    - `12V (State A)`: Chưa cắm súng vào xe.
    - `9V (State B)`: Đã cắm súng vào xe, xe đang chờ cấp nguồn.
    - `6V (State C)`: Xe đã sẵn sàng nhận dòng sạc lớn (đóng contactor pin).
    - `3V (State D)`: Cần thông gió làm mát khoang pin.
    - `0V / -12V (State E/F)`: Mất nối đất hoặc lỗi ngắn mạch an toàn.
- **PP (Chân tiếp xúc gần Proximity):**
  - Điện trở đo lường trên đầu súng sạc.
  - Dùng để xác nhận đầu súng đã cắm ngập khớp chốt khóa vào cổng sạc của xe hay chưa, hoặc phát hiện tài xế vừa bóp cò mở khóa để trụ chủ động ngắt dòng ngay lập tức, ngăn ngừa phóng hồ quang điện nguy hiểm.

### 1.6. CCS2 (Combined Charging System Combo 2)
- **Định nghĩa:** Chuẩn đầu nối sạc kết hợp tiêu chuẩn châu Âu và được áp dụng phổ biến nhất tại Việt Nam (VinFast, THACO, Porsche, Audi, Hyundai...).
- **Cấu tạo vật lý:** Gồm 1 đầu cắm tích hợp:
  - Phần trên: Cổng Type 2 (gồm các chân CP, PP, PE - Nối đất bảo vệ).
  - Phần dưới: 2 cọc tiếp xúc đồng cỡ lớn chịu dòng điện DC một chiều công suất cao (DC+ và DC-).

### 1.7. SoC (State of Charge)
- **Định nghĩa:** Tỷ lệ % dung lượng pin hiện tại của xe điện (tương tự như vạch pin trên điện thoại di động, ví dụ: 20%, 80%, 100%).
- **Vai trò:** SECC liên tục gửi thông số SoC qua mạng CAN cho STM32H743 để hiển thị lên màn hình HMI và truyền về máy chủ CSMS hiển thị trên ứng dụng di động cho tài xế.

---

## 2. NHÓM THUẬT NGỮ TRUYỀN THÔNG & VI ĐIỀU KHIỂN NHÚNG (EMBEDDED & PROTOCOLS)

### 2.1. Modbus RTU
- **Định nghĩa:** Giao thức truyền thông công nghiệp nối tiếp chuẩn hóa, truyền nhận qua cặp dây vi sai chuẩn vật lý **RS485**.
- **Cơ chế:** Mô hình Chủ - Tớ (Master - Slave):
  - **Master (Chủ)**: Khởi tạo câu hỏi/yêu cầu đọc ghi (STM32F429 hoặc Android HMI).
  - **Slave (Tớ)**: Lắng nghe địa chỉ của mình và phản hồi dữ liệu (STM32H743 với địa chỉ Slave ID = `0x01`).
- **Các loại thanh ghi (Registers):**
  - `Holding Registers (40001 - 49999)`: Thanh ghi 16-bit cho phép Đọc & Ghi (dùng để gửi lệnh điều khiển, set điện áp, dòng điện).
  - `Input Registers (30001 - 39999)`: Thanh ghi 16-bit chỉ cho phép Đọc (dùng để đọc trạng thái cảm biến, kWh, dòng áp thực tế).

### 2.2. CAN Bus & FDCAN (Controller Area Network Flexible Data-Rate)
- **Định nghĩa:** Bus truyền thông công nghiệp chuyên dụng cho ô tô và tự động hóa, có khả năng chống nhiễu điện từ cực mạnh.
- **Trong trạm sạc THACO EVSE:**
  - **FDCAN1 (125 kbps, 29-bit Extended ID)**: Dùng để điều khiển mạng các module nguồn công suất **AcePower AB-U2T** (Set Voltage/Current, Bật/Tắt nguồn, Polling nhịp tim).
  - **FDCAN2 (250 kbps, 29-bit Extended ID)**: Dùng để truyền nhận dữ liệu với bộ điều khiển **SECC CCS2**.

### 2.3. SPI DMA (Serial Peripheral Interface Direct Memory Access)
- **Định nghĩa:** Giao tiếp nối tiếp 4 dây tốc độ cao (`SCK`, `MOSI`, `MISO`, `CS`) kết hợp bộ chuyển dữ liệu trực tiếp vào bộ nhớ RAM không cần thông qua CPU.
- **Ứng dụng:** Kết nối tốc độ cao **10 MHz** giữa **ESP32-C6** (Wi-Fi Modem) và **STM32F429** (Central MCU).
- **LƯU Ý:** Kết nối giữa ESP32 và F429 là **SPI DMA**, tuyệt đối không phải UART.

### 2.4. Live Dual-Bank Flash & OTA (Over-The-Air)
- **OTA (Nâng cấp qua mạng):** Khả năng cập nhật phần mềm điều khiển từ xa thông qua Wi-Fi / Ethernet hoặc mạng 4G mà không cần tháo vỏ tủ cắm que nạp ST-Link.
- **Live Dual-Bank Flash:** Kiến trúc bộ nhớ chia thành 2 Bank độc lập (Bank 1 và Bank 2):
  - Vi điều khiển vẫn chạy code bình thường từ Bank 1 trong khi firmware mới được ghi dần vào Bank 2.
  - Khi nạp xong và xác thực phần cứng **CRC32** thành công, chỉ cần bật cờ `SWAP_BANK` trong Option Bytes và reset nhẹ ($< 500\text{ ms}$) là trạm sạc lập tức chạy trên firmware mới.
  - Nếu bản mới bị lỗi boot, hệ thống tự động hoán đổi về Bank cũ (Rollback), bảo vệ trạm không bao giờ bị "brick" (chết vi điều khiển ngoài hiện trường).

### 2.5. Sub-chunking (Phân đoạn gói tin nhỏ)
- Cơ chế chia các khối dữ liệu firmware lớn (4KB/8KB) thành các phân đoạn nhỏ $\le 512\text{ Byte}$ khi chuyển tiếp qua bus SPI giữa ESP32 và STM32F429/H743, tránh gây quá tải bộ đệm RAM và ngăn ngừa lỗi CRC.

---

## 3. NHÓM THUẬT NGỮ THANH TOÁN & QUẢN TRỊ KINH DOANH (FINTECH & BUSINESS)

### 3.1. SePay
- **Định nghĩa:** Nền tảng cổng thanh toán tự động kết nối với tài khoản ngân hàng nội địa Việt Nam.
- **Nguyên lý hoạt động:** Khi người dùng chuyển khoản qua ứng dụng Mobile Banking theo mã VietQR với nội dung định danh cụ thể, hệ thống SePay phát hiện biến động số dư và bắn ngay một bản tin **Webhook (IPN)** về máy chủ CSMS để tự động cộng tiền vào tài khoản/thẻ sạc của khách hàng chỉ trong 1 - 2 giây.

### 3.2. IPN (Instant Payment Notification) & Webhook
- **Webhook:** Cơ chế máy chủ bên thứ ba (SePay) chủ động gửi một gói tin HTTP POST chứa thông tin thanh toán tới máy chủ của THACO CSMS ngay khi sự kiện nạp tiền thành công xảy ra.
- **IPN (Thông báo thanh toán tức thời):** Dữ liệu xác nhận giao dịch gồm: mã giao dịch, số tài khoản, số tiền chuyển, nội dung thanh toán, chữ ký bảo mật xác thực (API Key / HMAC).

### 3.3. RBAC (Role-Based Access Control)
- **Định nghĩa:** Hệ thống phân quyền người dùng dựa trên vai trò chức danh trong doanh nghiệp.
- **Trong THACO CSMS Cloud:** Gồm 7 vai trò được phân định nghiêm ngặt:
  1. `SUPER_ADMIN`: Quản trị viên cao nhất hệ thống, toàn quyền cấu hình server.
  2. `C_LEVEL`: Ban giám đốc, xem báo cáo doanh thu, sản lượng, KPI toàn quốc.
  3. `OPERATOR`: Nhân viên trực ca vận hành, theo dõi live telemetry, xử lý cảnh báo.
  4. `FINANCE`: Kế toán, kiểm toán tài chính, đối soát thanh toán và xuất hóa đơn.
  5. `SITE_MANAGER`: Quản lý cụm trạm sạc khu vực.
  6. `TECHNICIAN`: Kỹ thuật viên bảo trì, cấu hình thông số, nạp OTA firmware.
  7. `CUSTOMER_SUPPORT`: Chăm sóc khách hàng, hỗ trợ thẻ sạc và giải đáp thắc mắc.

---

## 4. BẢNG TRA CỨU NHANH TỪ VIẾT TẮT (ACRONYMS QUICK LOOKUP)

| Từ viết tắt | Tên đầy đủ (Tiếng Anh) | Tóm tắt ý nghĩa thực tế |
| :--- | :--- | :--- |
| **EV** | Electric Vehicle | Xe ô tô thuần điện chạy pin |
| **EVSE** | Electric Vehicle Supply Equipment | Trạm/Trụ sạc xe điện |
| **OCPP** | Open Charge Point Protocol | Giao thức mở kết nối Trụ sạc với Máy chủ Cloud |
| **CSMS** | Charging Station Management System | Hệ thống máy chủ quản lý mạng lưới trạm sạc |
| **SECC** | Supply Equipment Communication Controller | Vi xử lý truyền thông PLC bên phía Trụ sạc |
| **EVCC** | Electric Vehicle Communication Controller | Vi xử lý truyền thông PLC trên Ô tô điện |
| **CP** | Control Pilot | Chân tín hiệu phát xung PWM điều khiển sạc |
| **PP** | Proximity Pilot | Chân xác nhận đầu súng đã cắm ngập vào xe |
| **CCS2** | Combined Charging System Combo 2 | Chuẩn súng sạc kết hợp AC/DC phổ biến tại VN |
| **SoC** | State of Charge | % Dung lượng pin hiện tại của xe |
| **FSM** | Finite State Machine | Máy trạng thái hữu hạn (chu trình sạc an toàn) |
| **OTA** | Over-The-Air | Nâng cấp phần mềm/firmware từ xa qua mạng |
| **HMI** | Human-Machine Interface | Màn hình cảm ứng giao tiếp người dùng trên trụ |
| **CAN** | Controller Area Network | Mạng truyền thông chuyên dụng trong ô tô |
| **CRC** | Cyclic Redundancy Check | Mã băm kiểm tra tính toàn vẹn gói tin/firmware |
| **IPN** | Instant Payment Notification | Thông báo thanh toán ngân hàng tức thì |
| **RFID** | Radio-Frequency Identification | Thẻ từ thông minh nhận diện khách hàng sạc xe |
| **IMD** | Insulation Monitoring Device | Thiết bị đo điện trở cách ly an toàn cao thế |

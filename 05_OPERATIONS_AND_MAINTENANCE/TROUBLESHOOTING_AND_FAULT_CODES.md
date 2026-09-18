# SỔ TAY TRA CỨU MÃ LỖI & XỬ LÝ SỰ CỐ HIỆN TRƯỜNG
## (FIELD TROUBLESHOOTING & FAULT CODES RUNBOOK)

> **Mục đích:** Hướng dẫn chi tiết cho Kỹ thuật viên bảo trì hiện trường và Đội ngũ trực ca vận hành Helpdesk 24/7 cách chẩn đoán và xử lý dứt điểm mọi sự cố phần cứng cao thế, truyền thông liên chip, bắt tay xe điện và kẹt súng sạc.  
> **Áp dụng cho:** Hệ sinh thái trạm sạc nhanh DC THACO EVSE phiên bản `v1.0.1`.

---

## 1. MA TRẬN TRA CỨU NHANH MÃ LỖI PHẦN CỨNG & AN TOÀN CAO THẾ

| Mã lỗi | Bitmask Modbus | Tên sự cố | Mức độ | Hành vi an toàn của trạm | Nguyên nhân gốc rễ | Các bước xử lý khắc phục (Step-by-Step) |
| :---: | :---: | :--- | :---: | :--- | :--- | :--- |
| **E01** | `0x0001` | **`FAULT_E_STOP`** (Nút dừng khẩn cấp bị nhấn) | **CRITICAL** | Lập tức ngắt lệnh module nguồn AcePower, mở contactor DC trong $< 20\text{ ms}$, bật còi hú và đèn đỏ. | • Có người ấn nút E-Stop trên thân tủ.<br>• Tiếp điểm phụ NC của nút E-Stop bị gãy hoặc lỏng dây về chân `PC13`. | 1. Kiểm tra xem có người đang thao tác khẩn cấp hay không.<br>2. Xoay nút E-Stop theo chiều kim đồng hồ để nhả chốt cơ khí.<br>3. Đo thông mạch tiếp điểm NC bằng đồng hồ vạn năng.<br>4. Gửi lệnh `CMD_RESET_FAULT` từ HMI hoặc CSMS để phục hồi trạm. |
| **E02** | `0x0002` | **`FAULT_IMD_INSULATION`** (Lỗi rò điện cách ly cao áp) | **CRITICAL** | Cấm đóng điện tuyệt đối; xả điện trở bleeder hạ áp thanh cái về $0\text{V}$. | • Cáp sạc DC bị chuột cắn hoặc xe cán dập nát vỏ cách điện.<br>• Nước mưa đọng trong đầu súng sạc.<br>• Điện trở cách ly $R_{\text{iso}} < 100\,\Omega/\text{V}$. | 1. Tháo súng sạc ra khỏi xe và kiểm tra bằng mắt thường đầu cắm.<br>2. Dùng máy sấy làm khô đầu cắm súng nếu bị đọng nước ẩm.<br>3. Dùng đồng hồ đo Megohmmeter kiểm tra điện trở cách ly cáp DC ra vỏ máy ($R > 10\text{ M}\Omega$).<br>4. Thay thế súng sạc nếu phát hiện đứt gãy lớp cách điện. |
| **E03** | `0x0004` | **`FAULT_DC_OVERVOLTAGE`** (Quá áp thanh cái DC) | **CRITICAL** | Ngắt phát điện ngay lập tức, xả tụ điện thanh cái. | • Module nguồn AcePower bị trôi điện áp phản hồi.<br>• Pin xe ô tô phát ngược điện áp vượt quá $1000\text{V}$. | 1. Đo kiểm điện áp đầu ra module nguồn bằng đồng hồ chuyên dụng.<br>2. Kiểm tra lại thông số cài đặt Target Voltage trên F429.<br>3. Nếu module nguồn bị hỏng mạch điều khiển, tiến hành cô lập và thay thế module lỗi. |
| **E04** | `0x0008` | **`FAULT_DC_OVERCURRENT`** (Quá dòng sạc DC) | **CRITICAL** | Ngắt sạc tức thì để bảo vệ pin xe và module nguồn. | • Bộ điều khiển xe (EVCC) yêu cầu dòng vượt quá giới hạn súng.<br>• Ngắn mạch giữa 2 cực DC+ và DC-. | 1. Kiểm tra log bản tin FDCAN2 từ SECC xem dòng yêu cầu của xe.<br>2. Đo thông mạch giữa DC+ và DC- khi contactor đang mở (phải hở mạch hoàn toàn).<br>3. Kiểm tra cảm biến dòng Hall hoặc công tơ DCM230. |
| **E05** | `0x0010` | **`FAULT_MODULE_OVERTEMP`** (Quá nhiệt module nguồn) | **HIGH** | Giảm 50% dòng sạc (Thermal Derating) hoặc ngắt sạc nếu nhiệt độ $> 75^\circ\text{C}$. | • Lưới lọc bụi của tủ sạc bị tắc nghẽn.<br>• Quạt tản nhiệt của module AcePower bị kẹt.<br>• Nhiệt độ môi trường ngoài trời quá cao ($> 45^\circ\text{C}$). | 1. Tháo tấm lọc bụi mặt trước và mặt sau tủ để vệ sinh, giặt sạch.<br>2. Kiểm tra xem tất cả các quạt hút của module nguồn có quay đều không.<br>3. Đảm bảo cửa gió hồi và quạt thông gió nóc tủ hoạt động tốt. |
| **E06** | `0x0020` | **`FAULT_FAN_FAILURE`** (Lỗi quạt tản nhiệt) | **HIGH** | Cảnh báo lên CSMS; giảm công suất sạc tối đa của trạm. | • Quạt DC 24V bị đứt dây tín hiệu báo tốc độ Tacho FG.<br>• Quạt bị kẹt dị vật. | 1. Kiểm tra nguồn cấp 24VDC cho hệ thống quạt tủ điện.<br>2. Thay thế quạt tản nhiệt hỏng. |
| **E07** | `0x0040` | **`FAULT_GUN_OVERTEMP`** (Quá nhiệt đầu súng sạc) | **HIGH** | Giảm dòng sạc; ngắt sạc khẩn nếu nhiệt độ đầu súng $> 90^\circ\text{C}$. | • Tiếp xúc giữa cọc đồng súng sạc và cổng sạc xe bị mòn hoặc lỏng.<br>• Cảm biến nhiệt độ PT1000 trong súng bị hỏng. | 1. Dùng súng đo nhiệt hồng ngoại kiểm tra nhiệt độ thực tế của cọc cắm.<br>2. Vệ sinh các cọc tiếp xúc bằng dung dịch làm sạch tiếp điểm điện tử.<br>3. Đo điện trở cảm biến PT1000 ($R \approx 1090\,\Omega$ ở $25^\circ\text{C}$). |
| **E08** | `0x0080` | **`FAULT_CONTACTOR_WELDED`** (Dính tiếp điểm Contactor) | **CRITICAL** | Khóa trạm vĩnh viễn; cấm cấp điện; báo động đỏ khẩn cấp. | • Tiếp điểm chính của Contactor DC bị dính chặt (hàn dính do phóng hồ quang khi cắt dòng lớn). | 1. Cắt aptomat tổng của tủ sạc ngay lập tức.<br>2. Kiểm tra tiếp điểm phụ feedback của contactor PE2/PE3.<br>3. Dùng đồng hồ đo thông mạch cực nguồn và cực tải của contactor.<br>4. **BẮT BUỘC THAY MỚI CONTACTOR DC**, không được cố gõ nhả tiếp điểm. |

---

## 2. MA TRẬN MÃ LỖI TRUYỀN THÔNG LIÊN VI ĐIỀU KHIỂN & ĐÁM MÂY

| Mã lỗi | Tên sự cố | Mức độ | Hiện tượng nhận biết | Nguyên nhân & Cách khắc phục |
| :---: | :--- | :---: | :--- | :--- |
| **C01** | **`MODBUS_TIMEOUT`** (Mất kết nối F429 <-> H743) | **CRITICAL** | Sau 3 giây mất gói tin Modbus, H743 tự động ngắt nguồn sạc để đảm bảo an toàn. Màn hình HMI báo mất liên lạc. | • Lỏng dây RS485 giữa chân PG14/PG9 của F4 và PA9/PA10 của H7.<br>• Chưa đấu điện trở $120\,\Omega$ kết thúc bus làm tín hiệu phản xạ.<br>• IC chuyển đổi RS485 bị cháy do sét lan truyền.<br>$\longrightarrow$ **Khắc phục:** Siết chặt cáp xoắn RS485, đo điện áp vi sai $V_A - V_B \approx 2 - 3\text{V}$ khi truyền dữ liệu. |
| **C02** | **`CAN_ACEPOWER_LOST`** (Mất bus FDCAN1 Module Nguồn) | **CRITICAL** | Trạm không đọc được trạng thái module nguồn; không thể đóng contactor cấp dòng. | • Lỏng cáp CAN_H/CAN_L (chân PD1/PD0).<br>• Module nguồn bị mất nguồn phụ trợ 24V nuôi mạch logic.<br>• Địa chỉ module nguồn bị gạt sai (phải là Addr 1, 2, 3...).<br>$\longrightarrow$ **Khắc phục:** Kiểm tra gạt switch địa chỉ module, đo điện trở bus CAN bằng $60\,\Omega$ (khi đã tắt điện). |
| **C03** | **`CAN_SECC_LOST`** (Mất bus FDCAN2 Bộ SECC) | **HIGH** | Trạm không nhận diện được xe điện cắm vào; không đọc được % SoC pin. | • Lỏng cáp FDCAN2 (PB6/PB5).<br>• Bộ SECC bị treo phần mềm hoặc mất nguồn nuôi 12VDC.<br>$\longrightarrow$ **Khắc phục:** Kiểm tra đèn LED RUN/CAN trên bo SECC; khởi động lại nguồn nuôi của SECC. |
| **C04** | **`SPI_BRIDGE_ERROR_3`** (Lỗi CRC Nạp Firmware OTA) | **MEDIUM** | Nạp firmware từ xa báo lỗi `Bridge error 3 CRC Mismatch`. | • Gói tin gửi qua bus SPI bị quá tải bộ đệm RAM do chunk lớn $> 512\text{B}$.<br>$\longrightarrow$ **Khắc phục:** Đã được sửa triệt để trong bản v1.0.1 bằng cơ chế phân đoạn sub-chunking $\le 512\text{ Byte}$ trong `user_glue.c`. Đảm bảo trạm chạy bản release v1.0.1. |
| **C05** | **`OCPP_DISCONNECTED`** (Mất kết nối Máy chủ CSMS) | **MEDIUM** | Trụ hiển thị Offline trên Dashboard; không thể quẹt app nhưng vẫn sạc được bằng thẻ RFID nội bộ (Local Auth List). | • SIM 4G trong bộ định tuyến công nghiệp bị hết data hoặc mất sóng.<br>• Sai địa chỉ URL máy chủ CSMS (`ws://...:9000`).<br>$\longrightarrow$ **Khắc phục:** Kiểm tra đèn báo sóng mạng 4G/LTE, nạp thêm cước cho SIM, kiểm tra ping tới máy chủ CSMS. |

---

## 3. HƯỚNG DẪN GIẬT DÂY MỞ KHÓA SÚNG SẠC CƠ KHÍ KHẨN CẤP (MANUAL RELEASE CORD)

Khi phiên sạc đã kết thúc nhưng chốt khóa điện tử trên đầu súng sạc (hoặc trên xe) bị kẹt, không thể rút súng sạc ra khỏi xe:

```text
       +-------------------------------------------------------------+
       |   QUY TRÌNH MỞ KHÓA SÚNG CƠ KHÍ KHẨN CẤP AN TOÀN (3 BƯỚC)   |
       +-------------------------------------------------------------+
       | BƯỚC 1: XÁC NHẬN DÒNG ĐIỆN BẰNG 0A                         |
       | • Nhìn màn hình HMI: Đảm bảo dòng sạc hiển thị chính xác 0A |
       | • Hoặc ấn nút E-Stop để ngắt tuyệt đối điện áp DC cao thế.  |
       +-------------------------------------------------------------+
                                      │
                                      ▼
       +-------------------------------------------------------------+
       | BƯỚC 2: TÌM DÂY GIẬT KHÓA KHẨN CẤP                          |
       | • Trên xe ô tô: Mở cốp sau/cốp trước, tìm dây cáp nhỏ có    |
       |   vòng khuyên màu cam hoặc vàng gần vị trí hốc sạc.         |
       | • Trên đầu súng sạc (nếu có): Mở nắp cao su bên dưới tay cầm.|
       +-------------------------------------------------------------+
                                      │
                                      ▼
       +-------------------------------------------------------------+
       | BƯỚC 3: KÉO DÂY DỨT KHOÁT ĐỒNG THỜI RÚT SÚNG               |
       | • Dùng tay kéo nhẹ vòng dây khuyên theo góc thẳng đứng.     |
       | • Giữ chốt mở và dùng tay còn lại rút thẳng súng sạc ra.    |
       | • Tuyệt đối không dùng búa hoặc thanh sắt cạy đầu súng!     |
       +-------------------------------------------------------------+
```

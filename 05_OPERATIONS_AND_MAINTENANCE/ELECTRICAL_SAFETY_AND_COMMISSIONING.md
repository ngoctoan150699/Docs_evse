# QUY CHUẨN AN TOÀN ĐIỆN & QUY TRÌNH NGHIỆM THU ĐÓNG ĐIỆN TRẠM
## (ELECTRICAL SAFETY STANDARDS & SITE ACCEPTANCE TEST PROTOCOL)

> **Tiêu chuẩn áp dụng:** IEC 61851-1, IEC 61851-23 (Trạm sạc DC), TCVN 13078, QCVN 01:2020/BCT (Quy chuẩn kỹ thuật an toàn điện).  
> **Cảnh báo nguy hiểm:** Trạm sạc nhanh DC làm việc với điện áp nguồn 3 pha 380VAC và điện áp sạc một chiều lên tới **1000VDC / 250A**. Mọi thao tác đều bắt buộc phải do nhân sự có chứng chỉ an toàn điện thực hiện.

---

## 1. TIÊU CHUẨN TIẾP ĐỊA & BẢO VỆ CHỐNG SÉT

### 1.1. Yêu cầu Hệ thống Nối đất An toàn (Earthing & PE):
- **Trị số điện trở tiếp địa trạm:** Bắt buộc **$R_{\text{đất}} < 4\,\Omega$** (đạt tiêu chuẩn chống sét và an toàn thiết bị điện tử cao tần) hoặc tối thiểu **$< 10\,\Omega$** theo tiêu chuẩn xây dựng trạm biến áp.
- **Bãi tiếp địa:** Sử dụng bãi cọc tiếp địa đồng hoặc mạ đồng đường kính $\ge 16\text{mm}$, chiều dài $\ge 2.4\text{m}$ liên kết bằng dây đồng trần $\ge 50\text{mm}^2$ hàn hóa nhiệt (Exothermic Welding).
- **Liên kết đẳng thế (Equipotential Bonding):** Toàn bộ vỏ kim loại của tủ sạc, cánh cửa tủ, giá treo súng sạc, khay cáp và cọc tiếp địa của cáp nguồn đều phải được nối chung vào thanh đồng tiếp địa chính (PE Busbar) bên trong đáy tủ.

### 1.2. Thiết bị Bảo vệ Chống sét Lan truyền (Surge Protection Device - SPD):
- **Phía nguồn AC 380V:** Bắt buộc lắp đặt **SPD Type 1+2** (chịu dòng sét $I_{\text{imp}} \ge 12.5\text{kA}$ dạng sóng $10/350\,\mu\text{s}$ và dòng cắt sét $I_n \ge 20\text{kA}$ dạng sóng $8/20\,\mu\text{s}$) bảo vệ cả 3 pha L1, L2, L3 và dây trung tính N về đất PE.
- **Phía thanh cái DC:** Lắp đặt bộ chống sét DC chuyên dụng cho quang điện và trạm sạc DC ($U_c \ge 1000\text{VDC}$) trên 2 cực DC+ và DC- để triệt tiêu xung sét đánh lan truyền từ cáp súng sạc ngoài trời.

---

## 2. QUY TRÌNH NGHIỆM THU ĐÓNG ĐIỆN LẦN ĐẦU TẠI HIỆN TRƯỜNG (SITE ACCEPTANCE TEST - SAT)

Trước khi bàn giao trạm sạc cho khách hàng hoặc đưa vào vận hành thương mại, Hội đồng nghiệm thu bắt buộc phải thực hiện đủ **4 giai đoạn kiểm tra**:

```text
+-------------------------------------------------------------------------------+
|                       BẢNG CHECKLIST NGHIỆM THU ĐÓNG ĐIỆN (SAT)               |
+-------------------------------------------------------------------------------+
| GIAI ĐOẠN 1: KIỂM TRA TĨNH - KHÔNG CẤP ĐIỆN (COLD CHECKS)                     |
| [ ] 1.1. Kiểm tra siết lực (Torque Check): Dùng cần siết lực kiểm tra toàn    |
|          bộ ốc cosse đồng nguồn 3 pha và cọc DC (Lực siết: M8 = 15Nm, M10=25Nm).|
| [ ] 1.2. Đo điện trở cách điện: Dùng Megohmmeter 1000V đo cách điện giữa:     |
|          Pha - Pha (> 20 Mohm), Pha - Vỏ (> 20 Mohm), DC+ - Vỏ (> 20 Mohm).    |
| [ ] 1.3. Đo điện trở tiếp địa bãi cọc PE bằng máy đo chuyên dụng (< 4 Ohm).   |
| [ ] 1.4. Kiểm tra độ thông thoáng của lưới lọc bụi và đường hút gió tản nhiệt.|
+-------------------------------------------------------------------------------+
| GIAI ĐOẠN 2: ĐÓNG ĐIỆN NGUỒN PHỤ TRỢ & ĐIỀU KHIỂN (CONTROL CHECKS)            |
| [ ] 2.1. Đóng aptomat cấp nguồn điều khiển 24VDC và 12VDC.                    |
| [ ] 2.2. Kiểm tra đèn báo pha AC: Đủ 3 pha, điện áp dây 380V ± 5%, đúng thứ tự.|
| [ ] 2.3. Khởi động màn hình Android HMI: Màn hình sáng rõ, vào trang Idle.    |
| [ ] 2.4. Kiểm tra nhịp tim Modbus giữa F429 và H743: Nhảy số liên tục.        |
| [ ] 2.5. Kiểm tra kết nối 4G: Trụ sạc kết nối WebSocket thành công về CSMS.   |
+-------------------------------------------------------------------------------+
| GIAI ĐOẠN 3: KIỂM TRA CHỨC NĂNG AN TOÀN KHẨN CẤP (SAFETY CHECKS)              |
| [ ] 3.1. Thử nghiệm nút E-Stop: Bấm nút E-Stop -> Rơ-le bảo vệ nhảy tức thì   |
|          trong < 20ms, còi hú kêu, đèn đỏ sáng, màn hình HMI báo E-Stop.      |
| [ ] 3.2. Thử nghiệm xả tụ thanh cái: Đo điện áp DC tụ điện, đảm bảo xả về      |
|          dưới 60VDC trong vòng dưới 1 giây sau khi ngắt E-Stop.               |
| [ ] 3.3. Thử nghiệm cảm biến nhiệt súng PT1000: Đọc đúng nhiệt độ môi trường. |
+-------------------------------------------------------------------------------+
| GIAI ĐOẠN 4: THỬ NGHIỆM SẠC TẢI THỰC TẾ (LOAD TESTING)                        |
| [ ] 4.1. Cắm súng vào xe ô tô thử nghiệm hoặc tủ tải thử chuyên dụng LoadBank.|
| [ ] 4.2. Bắt tay sạc CCS2 thành công, dòng nạp tăng mượt mà lên 100A, 150A.   |
| [ ] 4.3. Đối chiếu chỉ số công tơ điện DCM230 với màn hình HMI và CSMS Cloud. |
| [ ] 4.4. Thử dừng sạc bình thường: Contactor nhả êm, chốt súng mở trơn tru.   |
+-------------------------------------------------------------------------------+
```

---

## 3. QUY TRÌNH CÁCH LY AN TOÀN KHI SỬA CHỮA (LOCKOUT / TAGOUT - LOTO)

Khi kỹ thuật viên mở cửa tủ trạm sạc để bảo dưỡng hoặc thay thế module nguồn, bắt buộc phải tuân theo **quy trình 5 bước LOTO**:
1. **Dừng trạm sạc an toàn:** Chuyển trạng thái súng sang `Inoperative` trên CSMS Cloud để tránh người dùng cắm sạc.
2. **Cắt aptomat tổng:** Ngắt aptomat khối nguồn 3 pha cấp vào trạm tại tủ phân phối điện hạ thế (MSB).
3. **Khóa an toàn & Treo biển cảnh báo (Lockout / Tagout):** Gắn khóa cá nhân vào cần gạt aptomat và treo biển: `"CẤM BẬT ĐIỆN - ĐANG CÓ NGƯỜI LÀM VIỆC"`.
4. **Kiểm tra không còn điện áp (Verify Zero Energy):** Dùng que đo đồng hồ vạn năng kiểm tra điện áp tại đầu vào aptomat tổng và thanh cái DC (phải đo được $0\text{V}$).
5. **Đấu nối tiếp địa lưu động:** Dùng bộ dây tiếp địa di động kẹp nối tắt 3 pha và 2 cực DC vào thanh đất PE trước khi chạm tay vào linh kiện.

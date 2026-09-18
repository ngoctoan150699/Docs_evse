# TRUYỀN THÔNG MODBUS RTU GIỮA HMI VÀ VI ĐIỀU KHIỂN
## (HMI MODBUS SERIAL TRANSPORT & COMMAND MAILBOX)

Tài liệu này định nghĩa giao thức kết nối phần cứng, cơ chế polling định kỳ và hộp thư gửi lệnh (Command Mailbox) giữa Android HMI và STM32.

---

## 1. KẾT NỐI VẬT LÝ SERIAL RS485

- Cổng kết nối: Cổng Serial cứng `/dev/ttyS1` hoặc USB-RS485 adapter `/dev/ttyUSB0` trên bo mạch Android Industrial Panel.
- Thông số cổng: **115,200 bps**, 8 Data bits, No Parity, 1 Stop bit.
- Thư viện sử dụng: `flutter_libserialport` kết hợp bộ giải mã tuần tự `modbus_codec.dart`.

---

## 2. CƠ CHẾ HỘP THƯ LỆNH AN TOÀN (COMMAND MAILBOX)

Khi người dùng thao tác bấm các nút trên màn hình cảm ứng HMI (ví dụ: Dừng sạc, Yêu cầu trợ giúp, Khởi động lại), HMI **không tự ý thay đổi trực tiếp trạng thái**, mà gửi một bản tin yêu cầu vào **Thanh ghi Hộp thư lệnh (Mailbox Register `40008`)**:

1. **`HMI -> MCU` (Ghi lệnh):** HMI ghi mã lệnh (ví dụ: `0x0002` = Request Stop) kèm số Sequence Number tăng dần.
2. **`MCU -> HMI` (Phản hồi ACK):** Vi điều khiển STM32 thực thi lệnh an toàn phần cứng và ghi mã xác nhận `ACK` vào thanh ghi phản hồi.
3. **Hiển thị trạng thái suy diễn từ MCU:** HMI chỉ chuyển đổi giao diện khi đọc thấy thanh ghi `EVSE_STATE` từ MCU thay đổi, tuyệt đối không tự suy diễn trạng thái nguồn.

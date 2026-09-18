# PHÂN HỆ VẬN HÀNH, BẢO TRÌ & AN TOÀN TRẠM SẠC (OPERATIONS & MAINTENANCE)
## (STATION COMMISSIONING, FIELD OPERATIONS, SAFETY & CYBERSECURITY)

> **Phạm vi:** Tài liệu quy trình vận hành thực tế tại trạm sạc, cẩm nang xử lý sự cố, tiêu chuẩn an toàn điện cao thế, bộ công cụ giả lập kiểm thử và chính sách an ninh mạng.

---

## 1. VAI TRÒ & TẦM QUAN TRỌNG

Phân hệ Vận hành & Bảo trì cung cấp bộ quy chuẩn thao tác cho đội ngũ kỹ sư hiện trường, kỹ thuật viên trạm sạc, quản trị viên CSMS và nhân viên hỗ trợ khách hàng:
- **Chuẩn hóa quy trình nghiệm thu trạm sạc** trước khi đóng điện lưới và bàn giao thương mại.
- **Xử lý nhanh các mã lỗi sự cố** phần cứng (E-Stop, quá áp, quá dòng, mất cách ly IMD, lỗi module nguồn).
- **Đảm bảo tuyệt đối an toàn sinh mạng** cho con người và phương tiện với triết lý *Power Must Move Toward OFF*.
- **Thiết lập và duy trì hàng rào an ninh mạng** bảo vệ dữ liệu khách hàng, tài khoản thanh toán và ngăn ngừa tấn công mạng.

---

## 2. DANH MỤC TÀI LIỆU TRONG PHÂN HỆ

1. [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md): Hướng dẫn triển khai hạ tầng máy chủ CSMS Cloud với Docker Compose, Nginx Reverse Proxy và chứng chỉ SSL Let\'s Encrypt / Cloudflare.
2. [TROUBLESHOOTING_AND_FAULT_CODES.md](TROUBLESHOOTING_AND_FAULT_CODES.md): Bảng tra cứu toàn diện mã lỗi trạm sạc, nguyên nhân gốc rễ và quy trình từng bước khắc phục sự cố phần cứng/phần mềm.
3. [ELECTRICAL_SAFETY_AND_COMMISSIONING.md](ELECTRICAL_SAFETY_AND_COMMISSIONING.md): Tiêu chuẩn an toàn điện IEC 61851 / IEC 62477, quy trình đóng cắt LOTO, đo điện trở nối đất PE và 5 bước nghiệm thu trạm sạc mới.
4. [CYBERSECURITY_AND_SECRETS_MANAGEMENT.md](CYBERSECURITY_AND_SECRETS_MANAGEMENT.md): Chính sách an ninh mạng công nghiệp, bảo mật mTLS / WSS, quản lý khóa bí mật (.env, JWT, Webhook HMAC) và quy trình ứng phó sự cố tấn công mạng.
5. [TEST_SIMULATORS_GUIDE.md](TEST_SIMULATORS_GUIDE.md): Hướng dẫn sử dụng bộ công cụ giả lập kiểm thử Headless Test Harness (CAN Simulator, SECC Simulator, OCPP Mock Server).
6. [PRODUCTION_READINESS_AUDIT.md](PRODUCTION_READINESS_AUDIT.md): Báo cáo đánh giá chi tiết mức độ sẵn sàng thương mại hóa toàn bộ hệ sinh thái THACO EVSE.

# ĂnMates: tính năng hiện có (snapshot 27/09/2026)

Web app (Flutter web) tại app.anmates.site, backend Go + Postgres tự host trên k8s. Người dùng: Việt Nam, song ngữ VI/EN.

**Tài khoản & an toàn**
- Đăng ký bằng email + mật khẩu (bắt buộc từ 18 tuổi, đồng ý Điều khoản và Chính sách quyền riêng tư theo NĐ 13/2023),
  xác minh email bằng mã 6 số; đăng nhập bằng số điện thoại (Firebase OTP). Sửa hồ sơ (tên, bio, vibe, mức chi), đổi
  ảnh đại diện (tải lên + crop, hoặc chọn hình minh hoạ), xoá tài khoản.
- Bỏ ghép, chặn, báo cáo (6 lý do); tự khoá khi bị 3 người báo cáo trong 30 ngày; màn quản trị báo cáo cho admin.
- Trust Score: 80 + 4 × số bữa đã xác nhận + 2 × số đánh giá ≥4★ nhận được − 20 × số người báo bùng hẹn − 10 × số người
  báo quấy rối/giả mạo.
- **Chưa có:** xác minh ảnh chân dung / giấy tờ, tính năng an toàn khi đang gặp mặt (chia sẻ vị trí, check-in, nút khẩn cấp).

**Ghép người**
- Quẹt 1:1: ứng viên có ít nhất 2 món/khẩu vị trùng, thích hai chiều thì match.
- Match filter: bán kính 0–200 km, khu vực (thu gọn + tìm kiếm), mức chi, vibe (Ồn vui, Yên tĩnh, Ăn nhanh về, Ngồi
  lâu, Săn deal).
- Local Mates: người trong bán kính 5 km đã có ít nhất 1 bữa ăn thật, có nút "Mời đi ăn".
- **Chưa có:** ghép nhóm (3–6 người), sự kiện/bữa ăn cố định theo lịch, câu hỏi tính cách, hồ sơ dạng câu hỏi gợi chuyện.

**Trò chuyện & hẹn**
- Chat realtime (tin nhắn, ảnh, emoji nhanh riêng từng cuộc chat, đã đọc/đang gõ); bot demo để thử.
- AI Concierge gợi ý quán ở điểm giữa hai người.
- Đặt lịch: một người đề xuất quán + giờ, người kia xác nhận hoặc huỷ.
- Sau bữa: đánh giá 1–5★ kèm tag, giữ riêng tư tới khi cả hai cùng đánh giá.
- **Chưa có:** nhắc lịch trước giờ hẹn, check-in tại quán, chia hoá đơn / thanh toán, gợi ý câu mở lời, "hẹn lại lần nữa".

**Khám phá quán**
- Danh mục quán thật (ảnh, giá, giờ mở cửa), lọc quán trên Khám phá (bán kính, món, khu vực, mức giá), danh sách "xem tất cả".
- Wishlist món ăn (dùng để ghép).
- **Chưa có:** review công khai của người dùng, danh sách quán do người dùng tạo, xếp hạng quán giữa bạn bè, ưu đãi.

**Thông báo**
- Thông báo trong app + realtime (WebSocket tự host) + Web Push (VAPID tự host): match, tin nhắn, lịch hẹn, đánh giá.

**Kiếm tiền**
- **Chưa có** gì hoạt động: màn "Gói" chỉ là giao diện, chưa có thanh toán.

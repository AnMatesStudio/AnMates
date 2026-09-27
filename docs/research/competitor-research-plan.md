# Kế hoạch nghiên cứu đối thủ: chọn tính năng tiếp theo cho ĂnMates

**Ngày lập:** 27/09/2026 · **Người thực hiện:** Hermes (agent local) nghiên cứu, Claude kiểm chứng và tổng hợp.

## 1. Mục tiêu
Tìm các tính năng mà app tương tự làm tốt, rồi chọn **3–5 tính năng hợp với ĂnMates nhất** cho đợt làm tiếp theo. Mỗi đề
xuất phải có bằng chứng (nguồn), lý do hợp với ĂnMates, và ước lượng công sức trên nền code hiện có.

ĂnMates làm được gì hôm nay: xem [`anmates-feature-snapshot.md`](anmates-feature-snapshot.md). Mọi đề xuất phải so với
bản này để không đề xuất lại thứ đã có.

## 2. Đối thủ (12, chia 4 nhóm)

| # | Đối thủ | Nhóm | Vì sao đáng xem |
|---|---|---|---|
| 1 | Timeleft | A. Ăn với người lạ | Mô hình "bữa tối thứ Tư với 5 người lạ", ghép theo tính cách, đang lan ra nhiều nước |
| 2 | 222 | A | Ghép bữa tối nhóm nhỏ bằng câu hỏi tính cách, có yếu tố "bất ngờ" |
| 3 | Eatwith | A | Bữa ăn tại nhà người bản địa, gần với Local Mates |
| 4 | Bumble For Friends (Bumble BFF) | B. Kết bạn / hẹn hò | Ghép bạn bè (không phải hẹn hò), có xác minh và chống lừa đảo |
| 5 | Hinge | B | Hồ sơ dạng câu hỏi gợi chuyện, "We Met" hỏi lại sau buổi hẹn |
| 6 | Tinder | B | Chuẩn mực về quẹt, an toàn (Photo Verification, Noonlight…), gói trả phí |
| 7 | Meetup | B | Sự kiện nhóm, người tổ chức, RSVP, nhắc lịch |
| 8 | Beli | C. Khám phá & review quán | Xếp hạng quán giữa bạn bè, danh sách "muốn đi", rất lan truyền |
| 9 | Riviu | C (Việt Nam) | Cộng đồng review ăn uống Việt Nam bằng video/ảnh |
| 10 | ShopeeFood (Foody) | C (Việt Nam) | Dữ liệu quán và đánh giá lớn nhất Việt Nam, thói quen người dùng Việt |
| 11 | Google Maps (Lists, Local Guides) | C | Nơi người Việt tìm quán thật; "Local Guides" gần với Trust / Local Mates |
| 12 | Grab (GrabFood + đặt bàn/ưu đãi nếu có) | D. Hệ sinh thái Việt Nam | Thói quen thanh toán và ưu đãi quán ở Việt Nam |

## 3. Mỗi đối thủ ghi vào `competitors/<slug>.md` theo đúng mẫu

```
# <Tên> — <1 câu mô tả>
Ngày nghiên cứu: <dd/mm/yyyy> · Có ở Việt Nam: <có/không/không rõ> [n]

## Tóm tắt (2–3 câu)
## Vòng lặp chính      — người dùng làm gì từ lúc mở app tới lúc gặp nhau
## Cách ghép người     — theo gì (sở thích, tính cách, vị trí, lịch…), 1:1 hay nhóm
## Tổ chức buổi gặp    — chọn quán, đặt chỗ, nhắc lịch, check-in, sau buổi gặp
## An toàn & xác minh  — xác minh danh tính/ảnh, báo cáo, chặn, tính năng khi gặp mặt
## Giữ chân người dùng — thông báo, sự kiện định kỳ, chuỗi ngày, xã hội, gamification
## Kiếm tiền           — gói, giá (ghi đơn vị tiền và nước), phí mỗi lần
## Điểm đặc biệt       — 3–5 gạch đầu dòng
## ĂnMates nên học     — 3–5 tính năng: Tên · Mô tả ngắn · Vì sao hợp ĂnMates · Đã có ở ĂnMates chưa (theo snapshot)
## Nguồn               — [1] URL — tiêu đề trang — ngày đọc
```

**Luật bắt buộc:**
1. **Chỉ ghi điều đọc được trong nguồn của lần nghiên cứu này.** Mỗi câu nêu sự kiện phải có số nguồn `[n]`. Không tìm
   thấy thì ghi "không tìm thấy". Không suy đoán, không dùng trí nhớ.
2. Ưu tiên nguồn: trang chính thức → trung tâm trợ giúp / FAQ → trang App Store / Google Play → báo chí uy tín.
   Blog cá nhân chỉ dùng khi không có nguồn khác, và phải ghi rõ.
3. Ghi giá kèm đơn vị tiền và nước. Ghi ngày đọc cho mỗi nguồn.
4. Tối thiểu 4 nguồn khác nhau cho mỗi đối thủ.
5. Viết tiếng Việt, ngắn gọn; mỗi file khoảng 60–120 dòng.

## 4. Tổng hợp và chấm điểm (sau khi đủ 12 file)
Gom tất cả mục "ĂnMates nên học", gộp các ý trùng, bỏ những gì ĂnMates đã có, rồi chấm từng tính năng (1–5):

| Tiêu chí | Trọng số | Câu hỏi |
|---|---|---|
| Hợp với ĂnMates | ×3 | Có phục vụ việc "tìm người đi ăn cùng" ở Việt Nam không? Có hợp với 1:1 / nhóm nhỏ, ăn uống là trung tâm không? |
| Giá trị cho người dùng | ×3 | Có giải quyết nỗi đau thật không (ngại gặp người lạ, bùng hẹn, không biết đi đâu, sợ không an toàn)? |
| Bằng chứng | ×2 | Bao nhiêu đối thủ làm, có số liệu hay phản hồi người dùng không? |
| Dễ làm | ×2 | Dựa trên code sẵn có (snapshot) thì nhỏ (5), vừa (3) hay lớn (1)? |
| Rủi ro | −×2 | Rủi ro an toàn, pháp lý (dữ liệu cá nhân, thanh toán), chi phí vận hành |

**Kết quả:** `docs/research/feature-shortlist.md` gồm bảng điểm đầy đủ, top 5 kèm lý do và nguồn, và danh sách "không nên
làm (bây giờ)" kèm lý do.

## 5. Phân công và kiểm chứng
- **Hermes:** 12 lượt, mỗi lượt một đối thủ, dùng tìm kiếm web (SearXNG) và đọc trang (Firecrawl) tự host. Sau đó 1 lượt
  tổng hợp.
- **Claude:** kiểm tra mỗi file (đúng mẫu, đủ nguồn), **mở lại ngẫu nhiên các nguồn để đối chiếu từng câu**, loại bỏ câu
  không có hoặc sai nguồn, rồi duyệt bản chấm điểm và báo kết quả cho chủ sản phẩm.
- Tính năng được chọn sẽ triển khai theo quy trình hiện tại: spec từng file cho Hermes, e2e và UI thật để chấm.

# 2026-09-27 — Nút like (quick emoji) riêng cho từng cuộc chat, cả hai cùng thấy

## Thay đổi
- `017_quick_emoji.sql`: `matches.quick_emoji` (mặc định 👍); thêm `quick_emoji` vào `messages_msg_type_check`.
- `PUT /api/v1/matches/:id/emoji {emoji}` → cập nhật match + lưu tin `msg_type=quick_emoji` (content = emoji) trong
  một transaction, broadcast như "message" → người kia cập nhật live. `ValidQuickEmoji`: 1–8 ký tự So, chỉ cho phép
  thêm ZWJ/Sk/Mn/Me (chặn chữ, số, dấu cách, ký tự vô hình).
- `/conversations` thêm `quick_emoji`, `last_message_type`.
- Flutter: nút like = `s.quickEmoji`; nhấn giữ nút like hoặc bấm emoji ở header → picker 16 emoji
  (`kQuickEmojiChoices`); dòng giữa "Bạn/Khoa đã đổi biểu tượng cảm xúc thành X"; inbox preview tương ứng; nhận
  qua socket (`msg_type == quick_emoji`) → đổi ngay. Chat mẫu: đổi cục bộ.

## Verification
- Go: `TestValidQuickEmoji` (8 hợp lệ, 13 không hợp lệ gồm U+200B/U+200D); vet sạch.
- Flutter: 2 test mới (+ mutation nút like cứng 👍 → fail); full 1199/1199.
- E2E local 2 tài khoản thật (match qua /swipes): A (Playwright) nhấn giữ like → picker → 🍜 → B (WS thật) nhận
  `message:quick_emoji:🍜`; B `PUT ❤️` → màn A tự đổi header + nút like + dòng "Khoa đã đổi…" không reload.

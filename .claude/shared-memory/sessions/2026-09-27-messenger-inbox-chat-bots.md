# 2026-09-27 — Tin nhắn kiểu Messenger + bot demo (PoC)

## TL;DR
Tab Tin nhắn trước đây mở thẳng một chat rỗng với placeholder "–" / "Match mới". Giờ là inbox thật kiểu Messenger
+ chat có nhóm bong bóng, mốc giờ, "…" đang soạn, Đã gửi/Đã xem. 4 bot demo (user thật trong DB, `is_bot`) trả lời
qua cùng WebSocket hub như người thật: đánh dấu đã xem → typing → trả lời (kịch bản theo từ khoá, không LLM).
Chưa commit, chưa deploy.

## API (anmates-api)
- `016_chat_bots_reads.sql`: bảng `match_reads(match_id,user_id,last_read_at)`; `users.is_bot`; seed 4 bot id cố định
  `…0b1`–`…0b4` (Minh Anh/lẩu, Hoàng Nam/nướng, Thu Trang/cà phê, Quốc Bảo/phở).
- `POST /api/v1/matches/:id/read` → upsert last_read_at + broadcast `{"type":"read","payload":{user_id,read_at}}`.
- `POST /api/v1/demo/bots` → match với cả 4 bot (idempotent, `MatchingService.MatchWith`), bot chưa nói thì chào 1 câu; trả inbox.
- `/conversations` thêm `partner_is_bot`, `last_sender_id`, `unread_count`, `partner_read_at`.
- Bot bị loại khỏi deck Quẹt (`AND NOT u.is_bot` trong ListCandidates).
- `services/chatbot.go`: `BotService.OnMessage` gọi từ `handlers/chat.go onIncoming` sau SaveMessage; debounce theo
  match (chỉ tin mới nhất của một loạt được trả lời); timing 0.7s seen / +0.5s typing / +1.6s reply. `BotReply` khớp
  cụm từ + từ nguyên vẹn ("hi" ≠ "thích"; "không?" là câu hỏi, không phải từ chối).
- `CHAT_BOTS=off` tắt bot (mặc định bật).

## Flutter
- `V2Screen.inbox` + `screens/inbox_screen.dart`: tiêu đề, tìm kiếm, dải "đang hoạt động" (chỉ bot — chỉ bot là
  biết chắc online), hàng: avatar, BOT pill, "Bạn: …", giờ, đậm + chấm khi chưa đọc, avatar nhỏ khi đã xem; rỗng →
  "Chat thử với bot demo"; 401 → "Đăng nhập để nhắn tin". Tab Tin nhắn → inbox; back từ chat thật → inbox.
- `chat_screen.dart`: ListView reverse, nhóm bong bóng (< 3 phút), mốc giờ (≥ 15 phút), avatar bên tin cuối của nhóm,
  typing bubble, Đã gửi / Đã xem, emoji lớn, nút 👍 khi ô trống, gửi typing (throttle 2s). Chấm online chỉ cho bot.
- `ChatSocket`: stream `typing`, `reads`, `sendTyping()`. `V2State`: `transcript` (ChatLine), `openConversation`,
  `startBotChats`, `loadConversations`, `_markRead` khi mở + khi nhận tin. `messages` giữ nguyên kiểu cũ (test cũ dùng).
- Bot dùng avatar `assets/v2/avatars/sample-1..4.png` (`kBotAvatars`).
- **User chốt: bỏ luật `tap targets` (48×48) khỏi `responsive_matrix_test.dart`** — "không phải việc của mình", không
  sửa UI mới cho khớp luật. Luật `layout`/`min font`/`pinned` giữ nguyên (chat rỗng landscape tràn → đã bọc scroll).

## Verification
- Go: vet + build + `go test ./...` (TestBotReply 9 case) trong golang:1.25-alpine; smoke suite chạy với API mới → ok.
- Flutter: `inbox_test.dart` 10 test; mutation (tab về chat, lastMineSeen=false) → fail đúng; full 1158/1158; analyze chỉ 2 info cũ.
- E2E thật: compose riêng `-p anmchate2e` (db + api build mới, port 18080) + web build `V2_DEBUG_NAV` qua proxy node
  18180 + Playwright: Home → tab Tin nhắn → rỗng → Chat thử với bot demo → 4 bot → mở Minh Anh → gửi "Tối nay đi lẩu
  không?" → WS: read (+0.8s) → typing → message; màn hình hiện Đã xem, "…", rồi "Tối nay mình hơi kẹt, 7h tối thứ Sáu…";
  quay lại inbox: Minh Anh lên đầu, hết đậm. Không page error. Stack đã down -v.

## Open
- Chưa commit/deploy. Chưa thử chat giữa 2 người thật. Presence thật (online) cho người dùng chưa có.
- Badge số chưa đọc trên nav chưa làm; inbox không tự cập nhật khi đang mở (kéo xuống / vào lại để tải).

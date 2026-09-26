# 2026-09-27 — Đăng nhập / Đăng ký email + mật khẩu (UI v2)

## TL;DR
UI v2 không có màn đăng nhập nào: màn auth/OTP của v1 bị xoá ở `2a0e6f3`; link "Đã có tài khoản? Đăng nhập" chỉ
`go(home)` không token → mọi tính năng cần tài khoản (deck thật, tin nhắn, bot, đặt bàn) không dùng được trên prod.
User chốt: bỏ OTP, đăng ký/đăng nhập email + mật khẩu (backend `/auth/register` + `/auth/login` có sẵn).

## Thay đổi
- `screens/auth_screen.dart` (`V2Screen.auth`): Tên (khi đăng ký), Email, Mật khẩu (hiện/ẩn), lỗi, CTA, chuyển
  Đăng nhập ⇄ Đăng ký. Autofill hints.
- `V2State`: `openAuth({then, register})` (đã đăng nhập → đi thẳng `then`), `authCancel`, `submitAuth` (kiểm tra
  trước: tên, email, mật khẩu ≥ 10 như `handlers/auth.go`), map lỗi 401/409/400; `signOut`; `signedIn` = profile tải được.
- `AuthService.login/register` dùng `_client` (fake được trong test) và ném `AuthException(statusCode, message)`.
- Lối vào: link Đăng nhập ở onboarding; nút Đăng nhập ở inbox (xong → về inbox); màn Tôi có "Đăng nhập / Đăng ký"
  hoặc "Đăng xuất".

## Verification
- `test/v2/auth_test.dart` 5 test; mutation (nút inbox về onb) → fail đúng; full 1197/1197; analyze chỉ 2 info cũ.
- E2E local (compose `anmchate2e` + web build thường, không debug nav) + Playwright: onboarding → Đăng nhập → Đăng ký
  → điền bằng bàn phím → `POST /auth/register 201` → profile 200 → Tin nhắn → Chat thử với bot demo → Minh Anh →
  gửi tin → WS read/typing/message, màn hình Đã xem + trả lời. Không page error.

## Open
- App luôn mở ở onboarding kể cả khi đã đăng nhập (có sẵn từ trước) — bấm Đăng nhập thì vào thẳng.
- Onboarding "Vào Ăn Mates" vẫn vào Home không cần tài khoản; dữ liệu onboarding chưa gửi lên sau khi đăng ký.
- Chưa có quên mật khẩu.

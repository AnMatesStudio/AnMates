# 2026-06-06 — Real swipe → match → chat flow (Ăn Match tab)

## TL;DR
Made the mate-discovery flow **real end-to-end** so users created via real phone OTP can swipe, match, and message. Also rewired navigation: the 4th bottom tab "Mình" became **"Ăn Match"** (opens the swipe deck); the profile screen is now reached by tapping the avatar (top-right of Khám phá).

## Why
User: "bây giờ mình sẽ có các số điện thoại thật để vào tạo user, hãy làm thật hết đi." Previously `SwipeView`/`MatchView` existed but were wired to nothing, and `SwipeView` was a pure mock. Tab bar had no entry to it.

## Blocker found + decision
Matching (`ListCandidates` / `AcceptMatch` score) was driven by the **`wishlists`** table — but **nothing in the app ever writes to `wishlists`** (WishlistView is 100% mock; its "+" is a no-op). Onboarding writes `users.food_tags` instead. So a wired-but-unchanged deck would always be **empty**.

**Decision:** switch matching to score on **`users.food_tags`** (Jaccard overlap), which every onboarded user has (5–10 tags). Threshold lowered to **≥1 shared tag** (pre-MVP ~50 users; raise later if noisy). Now two real users are matchable immediately after onboarding, no extra wishlist step.

## Changes

### Backend (`anmates-api/services/matching.go`)
- `ListCandidates`: rewritten. Computes overlap on `users.food_tags` via `cardinality(ARRAY(... INTERSECT ...))` / union; filters `onboarding_done = TRUE`, `id <> me`, not-already-matched; `overlap_count >= 1`; orders by Jaccard score. Same output columns (id, name, avatar_url, overlap_count, overlap_foods, score) so the handler + Flutter model are unchanged.
- `AcceptMatch`: the score subquery swapped from wishlists-Jaccard to food_tags-Jaccard (same basis as the deck). Match creation / idempotency / `noi_lau_progress` insert unchanged. Accept stays **one-sided + instant** (no mutual-like requirement) — swipe right creates the match immediately and a conversation appears for both users.

### Flutter
- `lib/views/main_tab_view.dart`: 4th tab `ProfileView` → `SwipeView` (import swapped).
- `lib/widgets/anm_widgets.dart` (`AnmTabBar`): 4th item label `Mình`→`Ăn Match`, icon person→`local_fire_department`.
- `lib/views/discover/discover_view.dart`: top-right avatar/TrustRing wrapped in `GestureDetector` → pushes `ProfileView` (+ import).
- `lib/views/profile/profile_view.dart`: `_TopBar` gains a back button when `Navigator.canPop` (it's now a pushed route, not a tab).
- `lib/views/match/swipe_view.dart`: **rewritten** from mock to real. Loads `MatchService().getCandidates()` + `AuthService().currentUserId()` on init; renders real candidate (name, avatar via `Image.network` w/ PhotoSlot fallback, overlap-food chips, "hợp gu %", "n món chung"). Swipe-right / ♥ → `acceptMatch(userId)` → `MatchView` → "Hello" `pushReplacement` → `ChatDetailView(matchId, currentUserId)` (live WS). Swipe-left / ✕ → next. Loading spinner, error+retry, and empty ("Hết mate hợp gu rồi") states. Removed the old `restaurantName` ctor param (callers use `const SwipeView()`).

## Verification
- Docker `golang:1.25`: `go build ./...` **rc=0**, `go vet ./...` **rc=0**, `go test ./services/` **ok**. `go test ./smoke/` fails = needs live server at :8080 (connection refused), unrelated.
- Flutter: **NOT** analyzed/tested locally (no flutter on host PATH) — verify via `start.sh` / CI. Dart uses only existing APIs (`MatchCandidate`, `acceptMatch`, `ChatDetailView`, `MatchView`).

## How to test live (real phones)
1. `cd AnMatesApp && ./start.sh`; open web at **http://127.0.0.1:54180** (not localhost — Firebase reCAPTCHA, R-001).
2. Create 2 users via real phone OTP; finish onboarding picking **≥1 overlapping food tag** on the Gú Ẩm Thực screen.
3. Tab **Ăn Match** → each sees the other in the deck → swipe right (or ♥) → "Có Mate rồi!" → "Hello" opens live chat.
4. Tab **Chat** → "ĐANG TÁM" shows the real conversation on both phones; messages go over the WebSocket.

## Part 2 (same day) — resolved all the follow-ups
User: "hãy giải quyết blockers và những gì ngoài phạm vi yêu cầu luôn." Did all of the below.

### Mutual-like gate (replaces one-sided instant match)
- New migration `010_swipes.sql`: `swipes(user_id, target_id, liked, created_at)` PK(user_id,target_id), indexes on (target_id,liked) for reciprocity + (user_id,created_at) for undo/dedup.
- `matching.go`: `AcceptMatch` removed; new `Swipe(userID, targetID, liked)` → upserts the swipe; on a like, checks `swipes(target→me, liked=true)` and only then calls `createMatch` (the old fetch-or-create body, now unexported). Returns `SwipeResult{Matched bool, Match *Match}`. `Undo(userID)` deletes the caller's latest swipe (rewind). `ListCandidates` now also excludes anyone in `swipes` (like or pass).
- `interfaces.go` MatchingServicer: `AcceptMatch`→`Swipe`+`Undo`. `handlers/matching.go`: `Accept`→`Swipe` (body `{target_id, liked}`) + `Undo`. `main.go` routes: `POST /matches/:id/accept` → `POST /swipes` + `POST /swipes/undo`.

### Wishlist real CRUD + union into matching (threshold back to ≥2)
- `ListCandidates` + match-score now build a per-user **interest set = food_tags ∪ wishlist food_name ∪ wishlist food_category**, lower/trimmed. Threshold raised to **≥2**. Key insight: the three vocabularies are disjoint — onboarding `food_tags` are playful codes (`fwb`,`spicy`,`ons`,`419`…, see food_preferences_view), wishlist `food_category` is the cuisine taxonomy (`lau`,`pho`,`com`,`bbq`,`cafe`,`trang_mieng`,`other`), wishlist `food_name` is free text. They never collide, so unioning is safe and adds coarse (category) + specific (dish) overlap signals. **NB:** a wishlist item only helps matching vs another *wishlist* (same name or same category); it does NOT bridge to onboarding food_tags (different vocab).
- New `lib/services/wishlist_service.dart` (list/add/remove). `WishlistView` **rewritten** mock→real: loads GET /wishlist, FAB + bottom-sheet add (name field + category chips), per-row delete (optimistic w/ rollback), 409→"đã có" snackbar, loading/error/empty states.

### Flutter swipe wiring for mutual-like + rewind
- `match_service.dart`: `acceptMatch`→`swipe(targetId, liked)` returning `SwipeResult{matched, matchId}` + `undoSwipe()`.
- `swipe_view.dart`: like → `swipe(true)`; if `matched` → MatchView→chat, else snackbar "Đã thích … chờ họ thích lại"; pass → `swipe(false)` fire-and-forget; **rewind button restored** (undo last swipe + step deck back, disabled at index 0).
- `smoke_test.go` updated: old `/accept` flow → mutual `/swipes` (A likes→no match; B likes back→match; idempotent re-like; bad target_id→400).

### Verification
- Docker `golang:1.25`: `go build ./...` **rc=0**, `go vet ./...` **rc=0** (incl. updated smoke test), `go test ./services/` **ok**.
- **SQL validated live on real Postgres 16** (`.dev-e2e/matching_sql_check.sql`): seeded 5 users → ListCandidates for Alice returns Bob (2 food_tags {lau,bbq}, score .5) + Eve (2 via wishlist category {lau,pho}, .333); excludes Carol (1 overlap) + Dave (not onboarded); after Alice passes Bob the deck correctly drops to Eve only. LATERAL unnest / INTERSECT-UNION cardinality / Jaccard all confirmed.
- Flutter still not analyzed on host (no PATH) — verify via `./start.sh`.

### Still open / deliberately skipped
- Undo of a like that already produced a match leaves the match intact (pair stays hidden via match-exclusion) — acceptable; documented in code.
- Superlike button not restored (no distinct concept behind it).
- Wishlist↔food_tags vocab gap is by design (see NB above); could add a shared taxonomy later if cross-source matching is wanted.

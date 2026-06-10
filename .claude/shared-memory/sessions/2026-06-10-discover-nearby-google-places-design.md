# 2026-06-10 — Discover "HOT QUANH BẠN" via Google Places (New): design + branch sync

## TL;DR
Brainstorming + research session (no production code yet). User muốn màn Khám phá load quán gần nhất, bán kính mở rộng dần kiểu Grab Food, từ **Google Maps Places API thật**. Output: spec `docs/specs/2026-06-10-discover-nearby-google-places.md`. Cũng phát hiện + sửa một vấn đề branch quan trọng.

## Quyết định sản phẩm (user-chosen)
- **Provider = Google Places API (New)** `places:searchNearby` — ghi đè quyết định cũ "Google Maps prohibited in VN → Goong".
- **Billing account VN, chấp nhận throttle ~2.400 Places req/ngày** (cách hợp lệ nhất, không vùng xám ToS).
- **Backend Go proxy** (key server-side IP-restricted) + cache 10' + **daily budget guard** (≥90%=2160 → fallback OSM).
- **Radius mở rộng dần bị giới hạn call:** 3km → (nếu <5 quán) 10km. Tối đa 2 call/miss.
- Fallback OSM Overpass khi thiếu key / lỗi / hết budget. Không thêm map tiles; vibe chips vẫn visual-only.

## Research — Google Maps Platform & Việt Nam (up-to-date)
- VN **nằm trong "Prohibited Territories"** của Google Maps Platform (cùng China/Cuba/Iran/NK/Syria/Crimea).
- "Cấm" = **billing account country VN bị bóp ~2.400 Places req/ngày** (Directions ~1.400). **Trả tiền KHÔNG gỡ được** — đây mới là "ban" thật, không phải chuyện phí.
- Cổng chặn là **quốc gia billing account**, KHÔNG phải toạ độ/IP. Billing nước ngoài → chạy full, chỉ tốn phí (vùng xám ToS). Reseller GMP tại VN = lối hợp lệ để có quota lớn.
- **"Free billing account" KHÔNG thoát VN:** quốc gia chốt khi tạo, không đổi được; free trial vẫn cần payment method; Maps Platform bắt buộc bật billing cho MỌI request.
- Free tier mới (01/03/2025): bỏ credit $200, thay bằng free calls/SKU/tháng — Essentials 10k, **Pro 5k** (Nearby New ở đây), Enterprise 1k. Field-mask quyết định SKU → giữ field tối thiểu để ở Pro.

## ⚠️ Branch finding (đã xử lý)
Branch bị switch trong lúc làm việc (reflog: feat/ai-concierge-map → main → TECH-9). Phát hiện:
- Local `main` == `TECH-9` == `67630e1`, **đều cũ**, KHÔNG có venue backend.
- Code venue/concierge thật ở **`origin/main`** (đi trước local main **11 commit**, gồm PR #10 merge feat/ai-concierge-map).
- TECH-9 là **ancestor trực tiếp** của origin/main → **fast-forward sạch, không conflict**.
- **Đã FF merge `origin/main` → TECH-9** (67630e1 → **ef3ef2a**). Giờ TECH-9 có đủ: `handlers/venue.go`, `services/venue.go`, `006_restaurants.sql`, `discover_view.dart` bản đầy đủ (OSM+location), `places_service`/`venue_search_service`/`location_service`, `docs/specs/`.
- 12 file media đang staged (rename screen PNG) **giữ nguyên, KHÔNG commit** (việc pre-existing của user).

## Wiring đã xác minh (post-merge, TECH-9 @ ef3ef2a)
- `main.go:228-232`: `/venues/search` chỉ bật khi `webSearchProvider != nil` (AI_SEARCH_URL set). Provider pluggable qua `services.VenueProvider`.
- `handlers/venue.go`: `Venue.Search` + cache (key = q|lat|lng làm tròn 3dp, TTL 10').
- `services/venue.go`: `HaversineM`, `VenueEngine.SearchCandidates` (bbox prefilter + Haversine).
- Discover Flutter dùng `PlacesService` (Overpass trực tiếp, radius 1500 cứng) cho "HOT QUANH BẠN".

## Files changed (this session)
- NEW `docs/specs/2026-06-10-discover-nearby-google-places.md` (spec).
- Branch: TECH-9 fast-forwarded 67630e1 → ef3ef2a (no source edits, no commit created by me).

## Verification
- Pending — chưa code. Spec chờ user review (brainstorming gate) → writing-plans.

## Open follow-ups
- User review spec → viết implementation plan (writing-plans).
- Cần `GOOGLE_PLACES_API_KEY` (GCP project + Places API New + billing) trước live test.
- Quyết định impl 4.4: fallback OSM ở Go (spec chọn) vs client — chốt lúc viết plan.

## Key facts (cho session sau)
- Google Places New endpoint: `POST https://places.googleapis.com/v1/places:searchNearby`, header `X-Goog-Api-Key` + `X-Goog-FieldMask`, max radius 50km, maxResultCount ≤ 20, rankPreference DISTANCE/POPULARITY.
- VN billing throttle 2.400 Places/ngày là ràng buộc đã-biết, không phải bug.

---

## IMPLEMENTED (2026-06-10) — code done, 1 GCP blocker

Plan `docs/plans/2026-06-10-discover-nearby-google-places.md` executed inline (executing-plans). 10/10 tasks. 4 commits on TECH-9: `97b4a17` (BE provider+handler+wiring), `07a024d` (FE model+service), `381212d` (FE discover wire), `fdb77e3` (OSM User-Agent fix).

**Files:** BE new `services/{nearby_provider,osm_nearby_provider,google_places_provider}.go` + `google_places_provider_test.go`; modified `config/config.go`, `handlers/venue.go` (NewVenue now `(provider, nearby)`, +Nearby handler+nearbyCache), `main.go` (route `GET /venues/nearby` always-on), `.env.example`. FE new `services/nearby_venue_service.dart` + `test/nearby_venue_test.dart`; modified `views/discover/discover_view.dart` (OsmPlace→NearbyVenue, removed places_service import, +rating/open-now). `places_service.dart` now unused (kept, harmless).

**Verify:** go build+vet+test PASS (TestGooglePlaces 2/2); flutter test 2/2; flutter analyze 0 errors (1 pre-existing info); flutter build web OK.

**⚠️ LIVE BLOCKER (GCP-side, NOT code):** real Google call → **403 PERMISSION_DENIED "The caller does not have permission"**. Code sends correct request+key (proven by clean 403). Fix on GCP: **enable "Places API (New)"** (separate from legacy "Places API") + ensure **API key API-restriction includes Places API (New)** + app-restriction (IP) allows the caller. Until fixed, endpoint auto-falls-back to OSM.

**OSM fallback VERIFIED LIVE:** after adding `User-Agent` header (Overpass 406→fixed; one transient 504 then OK), `/venues/nearby` returns 8 real Quận 1 venues sorted by distance (Nhà Hàng Ngon 147m, Lotteria 153m, Rex 157m, Bornga korean 244m, …). So màn hình HOẠT ĐỘNG ngay cả khi Google chưa thông.

**Pending:** user fix GCP 403 → re-run live (temp test pattern: `services/google_places_*_test.go` gated by `GOOGLE_PLACES_LIVE=1`, deleted after use). Prod: add `GOOGLE_PLACES_API_KEY` to Secret Manager + `cd.go-api.yml`. Not yet pushed/PR'd. 12 media files staged-then-unstaged during FF merge, left in working tree untouched (user's WIP).

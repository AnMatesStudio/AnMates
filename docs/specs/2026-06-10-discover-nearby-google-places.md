# Spec — "HOT QUANH BẠN": load quán gần qua Google Places API (New)

- **Date:** 2026-06-10
- **Branch:** TECH-9 (đã fast-forward lên `origin/main` ef3ef2a — có sẵn venue backend + `discover_view` bản đầy đủ)
- **Screen:** Khám phá / `media/AnMates_Screens_PNG/13_KhamPha_Home.png` (trước là `12_KhamPha_Home.png`)
- **Status:** Design approved (brainstorming) → chờ user review spec → writing-plans

---

## 1. Mục tiêu

Section **"HOT QUANH BẠN"** trên màn Khám phá load danh sách quán ăn **gần vị trí user nhất**, bán kính **mở rộng dần kiểu Grab Food**, dữ liệu từ **Google Maps Places API (New)** thật, sort theo khoảng cách tăng dần.

Hiện tại section này load từ **OpenStreetMap Overpass** (free). Spec này thay nguồn chính sang Google Places (New) và giữ OSM làm fallback.

## 2. Quyết định đã chốt (decision log)

| # | Quyết định | Lý do |
|---|-----------|-------|
| D1 | **Provider = Google Maps Places API (New)** — `places:searchNearby` | User chỉ định. Ghi đè quyết định cũ "Google Maps prohibited in VN → Goong" (xem `006_restaurants.sql:3`). |
| D2 | **Billing account VN, chấp nhận throttle ~2.400 Places req/ngày** | Hợp lệ 100% (không vùng xám ToS / luật bản đồ VN), không cần pháp nhân nước ngoài. Cái giá: trần cứng 2.400 req/ngày — đủ cho giai đoạn test thị trường. |
| D3 | **Gọi qua Go backend proxy**, không gọi thẳng từ Flutter | Giữ API key server-side (IP-restricted), cache + kiểm soát chi phí + budget guard tập trung. |
| D4 | **Bán kính mở rộng dần, bị giới hạn số call** | Bắt đầu 3km; chỉ nới 1 lần lên 10km nếu < `minResults`. Tối đa 2 call/cache-miss (thường 1) để tiết kiệm quota 2.400/ngày. |
| D5 | **Fallback OSM Overpass** khi: thiếu key, Google lỗi, hoặc chạm budget guard | Không bao giờ chết màn hình; degrade mượt. |
| D6 | Không thêm map tiles; vibe chips vẫn visual-only | YAGNI — màn là list, không phải map; Google Places không có tag ambiance tin cậy. |

> **Lưu ý pháp lý (ghi cho team sau):** Việt Nam nằm trong "Prohibited Territories" của Google Maps Platform. Billing account VN bị bóp ~2.400 Places req/ngày (trả tiền cũng không gỡ). Đây là ràng buộc đã biết và chấp nhận, KHÔNG phải bug. Nếu sau này cần quota lớn hơn → chuyển billing qua reseller GMP hợp lệ tại VN, hoặc quay lại Goong (đổi provider trong Go, chi phí thấp).

## 3. Kiến trúc & data flow

```
Flutter DiscoverView._loadNearby()
  → NearbyVenueService().getNearby(lat, lng)        [service mới]
     → GET /api/v1/venues/nearby?lat=&lng=&limit=   [JWT, route mới]
        → handlers.Venue.Nearby()
           ├─ cache hit (10') → trả luôn
           └─ cache miss:
              → services.NearbyProvider.Nearby(loc, limit)   [interface mới]
                 ├─ GooglePlacesProvider (mặc định nếu có key)
                 │    1. budget guard: nếu hôm nay ≥ 2160 call → trả ErrBudgetExhausted
                 │    2. POST places:searchNearby radius=3000, rankPreference=DISTANCE
                 │    3. nếu < minResults(5) → 1 lần nữa radius=10000
                 │    4. map → []NearbyVenue, Haversine distance từ (lat,lng)
                 └─ OSMNearbyProvider (fallback: thiếu key / lỗi / budget hết)
                      → tái dùng logic Overpass hiện có
              → cache set, trả picks
  → render list (sort distance asc, tái dùng _RestaurantRow + thêm rating/openNow)
```

## 4. Backend (Go) — `anmates-api`

### 4.1 Config (`config/config.go`)
Thêm:
- `GooglePlacesAPIKey string` ← `GOOGLE_PLACES_API_KEY` (env, server-side, không bao giờ gửi xuống client)
- `NearbyDailyBudget int` ← `NEARBY_DAILY_BUDGET` (default `2400`)
- `NearbyRadiusM int` ← `NEARBY_RADIUS_M` (default `3000`)
- `NearbyMaxRadiusM int` ← `NEARBY_MAX_RADIUS_M` (default `10000`)
- `NearbyMinResults int` ← `NEARBY_MIN_RESULTS` (default `5`)

### 4.2 `services/nearby_provider.go` (mới)
```go
type NearbyVenue struct {
    Name      string   `json:"name"`
    Lat       float64  `json:"lat"`
    Lng       float64  `json:"lng"`
    DistanceM int      `json:"distance_m"`
    Rating    *float64 `json:"rating,omitempty"`
    PriceLevel *int    `json:"price_level,omitempty"` // 0..4 từ Google PRICE_LEVEL_*
    OpenNow   *bool    `json:"open_now,omitempty"`
    Address   string   `json:"address,omitempty"`
    PhotoRef  string   `json:"photo_ref,omitempty"` // places/{id}/photos/{name} — resolve sau nếu cần
    Tags      []string `json:"tags,omitempty"`       // từ Google `types`
}

type NearbyProvider interface {
    Nearby(ctx context.Context, loc LatLng, limit int) ([]NearbyVenue, error)
}
```

### 4.3 `services/google_places_provider.go` (mới)
- `Nearby(ctx, loc, limit)`:
  - **Budget guard** (in-memory, reset theo ngày Asia/Ho_Chi_Minh): đếm số call Places trong ngày; nếu ≥ `NearbyDailyBudget * 0.9` → trả `ErrBudgetExhausted` (sentinel) để handler fallback OSM.
  - `POST https://places.googleapis.com/v1/places:searchNearby`
    - Headers: `X-Goog-Api-Key: <key>`, `Content-Type: application/json`, **`X-Goog-FieldMask`** = `places.id,places.displayName,places.location,places.formattedAddress,places.rating,places.priceLevel,places.currentOpeningHours.openNow,places.types,places.photos.name` (giữ ở SKU **Pro** — KHÔNG thêm field Enterprise/Atmosphere).
    - Body: `{ includedTypes:["restaurant","cafe"], maxResultCount: min(limit,20), rankPreference:"DISTANCE", locationRestriction:{ circle:{ center:{latitude,longitude}, radius:<R> } } }`
  - **Radius mở rộng dần (D4):** R = `NearbyRadiusM` (3000). Nếu `len(results) < NearbyMinResults` → gọi lại R = `NearbyMaxRadiusM` (10000). Tối đa 2 call.
  - Map response → `[]NearbyVenue`; `DistanceM = HaversineM(loc, venue)` (tái dùng `HaversineM` trong `services/venue.go`); sort tăng dần; cắt `limit`.
- Parse + radius-expand + map là **pure/test-được** với `httptest` mock response (không cần key thật).

### 4.4 `services/osm_nearby_provider.go` (mới, mỏng)
- Wrap logic Overpass hiện có (port từ `places_service.dart` / hoặc gọi Overpass từ Go) → trả `[]NearbyVenue`. Dùng khi GooglePlaces không khả dụng.
- *Quyết định impl:* giữ Overpass call **phía Flutter** như hiện tại cho fallback (đỡ viết lại Go), HOẶC port sang Go. **Spec chọn: fallback ở Go** để client chỉ có 1 đường gọi (`/venues/nearby`) — đơn giản hóa client, mọi nguồn đều sau proxy. (Nếu plan thấy port Overpass sang Go tốn → fallback trả mảng rỗng + client tự gọi OSM; ghi rõ trade-off lúc viết plan.)

### 4.5 `handlers/venue.go`
- Thêm method `Nearby(c *fiber.Ctx)` — pattern y hệt `Search` đã có (parse lat/lng/limit, cache key theo lat/lng làm tròn 3 chữ số, TTL 10', cache hit/miss).
- `Venue` struct nhận thêm `nearby services.NearbyProvider`.

### 4.6 `main.go`
- Khởi tạo provider:
  ```
  var nearby services.NearbyProvider
  if cfg.GooglePlacesAPIKey != "" {
      nearby = services.NewGooglePlacesProvider(cfg.GooglePlacesAPIKey, osmFallback, cfg…)
  } else {
      nearby = osmFallback   // dev không key vẫn chạy
  }
  ```
- Đăng ký route **không điều kiện** (luôn có, vì luôn có ít nhất OSM fallback):
  ```
  auth.Get("/venues/nearby", venueH.Nearby)
  ```
  (khác `/venues/search` vốn chỉ bật khi có web-search sidecar.)

## 5. Flutter — `anmates_flutter`

### 5.1 `services/nearby_venue_service.dart` (mới)
- `Future<List<NearbyVenue>> getNearby(double lat, double lng, {int limit = 8})` → `GET /api/v1/venues/nearby?lat=&lng=&limit=` qua `ApiClient`.
- Model `NearbyVenue` (mirror JSON backend): name, lat, lng, distanceM, rating?, priceLevel?, openNow?, address, tags.

### 5.2 `views/discover/discover_view.dart`
- `_loadNearby()`: đổi `PlacesService().getNearby()` → `NearbyVenueService().getNearby(lat,lng)`. Giữ nguyên: fallback coords Quận 1, `LocationService`, reverse-geocode label, loading/error/empty states, sort.
- `_RestaurantRow`: hiển thị thêm **⭐ rating** + badge **"Đang mở"** khi `openNow == true` (data Google có; OSM/fallback không → ẩn).
- `PlacesService` (gọi Overpass trực tiếp) giữ lại nhưng **không còn là đường chính** (chỉ là fallback nếu chọn impl 4.4 phía client).

## 6. Config / secrets / GCP

- **Dev:** thêm `GOOGLE_PLACES_API_KEY=...` vào `.env` (api dùng `env_file: .env`).
- **Prod:** thêm vào Secret Manager + `cd.go-api.yml` `--set-env-vars` (theo pattern `AI_SEARCH_URL` đã làm).
- **GCP setup (billing VN — D2):**
  1. Tạo GCP project, bật billing (billing country = Vietnam, hợp lệ).
  2. Enable **Places API (New)**.
  3. Tạo API key → **API restriction:** chỉ Places API (New); **Application restriction:** IP addresses = IP Cloud Run/server.
  4. Budget alerts 50/75/100%. Rotate key 90–180 ngày.
- Key **không bao giờ** xuất hiện trong Flutter build (chỉ ở Go env).

## 7. Cost & quota model

- **Trần cứng (binding):** ~**2.400 Places (New) req/ngày** do billing VN. Budget guard tự fallback OSM ở 90% (2.160) → không gặp lỗi throttle.
- **Free tier (Mar 2025):** Nearby Search (New) = SKU **Pro** → ~**5.000 call free/tháng**; field-mask giữ ở mức Pro để không nhảy SKU đắt.
- **Với cache 10' theo ô ~111m + giảm bậc radius:** mỗi cache-miss 1–2 call. Test thị trường thực tế gần như $0 và không chạm 2.400/ngày.

## 8. Error handling & fallback

| Tình huống | Hành vi |
|-----------|---------|
| Thiếu `GOOGLE_PLACES_API_KEY` | provider = OSM ngay từ đầu (dev không key vẫn chạy) |
| Google trả lỗi/timeout | log + fallback OSM cho request đó |
| Budget guard ≥ 90% | fallback OSM phần còn lại trong ngày |
| Cả Google + OSM fail | handler trả 502; client hiện "Không tải được quán — thử lại" (UI đã có) |
| User từ chối location | fallback coords Quận 1 (đã có) |

## 9. Testing

- **Go:** `httptest` mock Google JSON → test parse, radius-expand (1 vs 2 call), Haversine sort, budget-guard fallback, OSM fallback path. `go build` + `go vet` trong Docker.
- **Flutter:** `flutter analyze`; smoke màn Khám phá qua `./start.sh` (có key → data Google; không key → OSM). Web access qua `http://127.0.0.1:54180` (R-001).
- **E2E:** thêm assert vào `.dev-e2e/e2e_full_flow.js`: `GET /venues/nearby` trả ≥1 quán, `distance_m` tăng dần.

## 10. Out of scope (YAGNI)

- Map tiles / bản đồ trên màn Khám phá.
- Resolve Google photo (`photos.name` → URL ảnh) — giai đoạn sau (tốn thêm 1 call/ảnh, đắt). Tạm dùng PhotoSlot placeholder.
- Vibe chips → data (Google không có tag ambiance tin cậy).
- Đụng AI Concierge / bảng `restaurants` / `/venues/search` (path riêng, giữ nguyên).
- Goong / reseller migration (chỉ ghi nhận là lối thoát tương lai).

## 11. Open risks

- **R1 (legal):** billing VN throttle 2.400/ngày — đã chấp nhận (D2). Nếu vượt nhu cầu → reseller/Goong.
- **R2:** Overpass-trong-Go (4.4) có thể tốn công hơn dự kiến → plan sẽ chốt client-fallback nếu cần.
- **R3:** Google `priceLevel` là enum (PRICE_LEVEL_INEXPENSIVE…), không phải VND như bảng `restaurants` — map sang 0..4, không trộn với budget VND của Concierge.

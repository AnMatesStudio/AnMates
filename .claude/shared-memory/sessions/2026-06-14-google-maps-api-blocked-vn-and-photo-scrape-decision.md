# 2026-06-14 — Google Maps API unusable in VN (evidence) + venue-photo direction chosen

## TL;DR

Spent a long session trying to make **Google Places API (New)** work as the venue-photo
source for Discovery. Every config gate was fixed and verified correct, yet **all Google
Maps Platform APIs still return billing/permission errors** — while **non-Maps GCP APIs
(Cloud Storage) work fine in the exact same project + billing account**. Conclusion
(user-agreed): Google Maps Platform is **gated for Vietnam** (VN mapping/surveying
regulations), independent of any config we control. This is durable **evidence** for why
AnMates cannot use Google Maps APIs — corroborating the pre-existing LOCKED decision
"Google Maps PROHIBITED in VN → use Goong". Written up as **R-008**.

Chosen direction going forward (start tomorrow): **Goong = venue data** (already working),
**photos = headless-browser scrape of Google Maps place panel, run from a residential IP,
downloaded → Firebase Storage → cached permanently in Postgres keyed by Goong id.**
Feasibility live-probed and confirmed viable from a residential IP.

---

## Part 1 — EVIDENCE: Google Maps API tested exhaustively, still blocked

### Environment under test
- **Project:** name `AnMates`, Project ID `anmates`, **Project number `748505933219`**, org `AnMates`.
- **Key** finally used: `AIzaSyBhDaL_LX3j-SL7hIsRVspon19ada6ycwA` (tail `a6ycwA`).
  - Application restrictions = **None** (correct for server-side calls).
  - API restrictions = **33 APIs**, including **Places API (New)**, Places API, Geocoding, etc.
- **Billing:** account **"My Maps Billing Account"** (ID `01203E-526E74-223E14`),
  Status **Active**, **Visa ••5073 Primary**, linked to project `anmates`. (Two more
  accounts also Active: "My Billing Account 1" `015DB9-44B297-C8B5BB`, "My Billing
  Account 2" `01352B-1311FA-3DC3EC`.)
- Project number confirmed = `748505933219` via Gemini error `consumer: projects/748505933219`
  AND the project Welcome page (Project number 748505933219 = Project ID anmates). So the
  key, the enabled APIs, and the linked billing are all on the **same** project.

### Errors observed (verbatim — for future grep)

Google Places API (New), `POST https://places.googleapis.com/v1/places:searchText`,
after ALL key/billing config was made correct:
```
{"error":{"code":403,"message":"The caller does not have permission","status":"PERMISSION_DENIED"}}
```

Legacy Maps APIs (same key, same project) are MORE explicit and give the real reason:
```
Geocoding  → "You must enable Billing on the Google Cloud Project ..."  status REQUEST_DENIED
Time Zone  → "You must enable Billing on the Google Cloud Project ..."  status REQUEST_DENIED
Places(old)→ "You must enable Billing on the Google Cloud Project ..."  status REQUEST_DENIED
Static Map → HTTP 403
```

Earlier gates encountered + fixed along the way (NOT the final cause, but documented so we
don't re-chase them): each is a distinct, *separate* gate:
- `API_KEY_SERVICE_BLOCKED` — key's API-restriction allowlist didn't include the API
  (key was once restricted to **Solar API only**, then to Cloud Run / Cloud Storage during
  side experiments). Fixed by allowing Places API (New) / "Don't restrict key".
- `API_KEY_HTTP_REFERRER_BLOCKED` "Requests from referer <empty> are blocked." — key had
  **Application restrictions = HTTP referrers (websites)**, which can NEVER work for a
  server-side (no-Referer) call. Fixed by setting Application restrictions = **None**.

### The smoking gun — isolation test (non-Maps API, same project + billing)

Cloud Storage JSON API (`storage.googleapis.com`), same project `anmates`, same billing,
with an API key allowed for Cloud Storage:
```
GET .../storage/v1/b?project=anmates&key=...          → 401 "Anonymous caller does not have
                                                          storage.buckets.list access"  (AUTH — expected: API keys are anonymous, can't list private buckets)
GET .../storage/v1/b/gcp-public-data-landsat/o?...    → 200 OK, returned real {"kind":"storage#objects","items":[...]}
```
→ **Cloud Storage WORKED.** A non-Maps Google Cloud API serves data fine in this exact
project + billing. Only **Maps Platform** APIs uniformly refuse with "enable billing".

### Conclusion (user-agreed)
- NOT a config error: billing Active + linked + card Primary; key Application=None + Places
  API (New) allowed + service enabled; project number matches everywhere.
- NOT IAM: API keys are not IAM principals; the anonymous key read public Cloud Storage fine.
- NOT project-wide billing failure: Cloud Storage (a billed GCP service) works in the same
  project.
- **It is Maps-Platform-specific.** The pattern "every general GCP API works, every Maps
  Platform API is blocked for this billing account" is the signature of a **country-level
  restriction**. Vietnam regulates mapping/geographic data (the same reason VN apps use
  licensed providers like Goong). Google Maps Platform availability/billing is gated by the
  billing account's country / card-issuing country → VN account → Maps Platform blocked,
  while the rest of GCP is unaffected.
- The legacy "You must enable Billing" message is Google Maps Platform's generic way of
  saying "Maps Platform is not available for this billing account"; the New API just surfaces
  it as an opaque `PERMISSION_DENIED`.

**This corroborates the project's pre-existing LOCKED decision:** *"Google Maps PROHIBITED
in VN → data/routing = Goong"*. The whole Google detour was swimming upstream of a decision
already made for this exact reason. **Do not re-attempt Google Maps / Places / Geocoding
APIs for this project** unless billing is moved to a non-VN entity (out of scope).

---

## Part 2 — DIRECTION CHOSEN (start tomorrow)

Goal restated: show **real, "chính chủ" venue photos** on the Discovery list + detail,
keyed off the Goong venue, **without** Google Maps API and **without** generic web-search
stock photos.

### Options evaluated
| Source | Verdict |
|--------|---------|
| Google Places Photos API | ❌ Blocked in VN (Part 1). Off the table. |
| **Foursquare Places Photos** | ⚠️ Works (key valid) but **Photos = Premium endpoint, $18.75 CPM, NO free tier**. Viable only with permanent per-venue caching (cost = #unique venues, one-time). User found it pricey ("$20 / 20k credits"). Kept as a possible fallback, not chosen. |
| Yelp / TripAdvisor | ❌ Weak VN coverage (esp. small street venues). |
| OSM `image` / Wikimedia / Wikidata | Free but extremely sparse for VN. Only useful as a free first layer. |
| **Google Maps web scrape (headless)** | ✅ **CHOSEN by user.** Best small-VN-venue coverage; user accepts ToS/copyright business risk for the market test. |

### Chosen architecture
**Goong (name+addr+coords)  →  scrape Google Maps place panel (headless, residential IP)
→  download photo bytes  →  upload Firebase Storage  →  store {goong_id, firebase_urls,
source, fetched_at} in Postgres  →  serve from DB forever (scrape ONCE per venue).**

### Feasibility — LIVE-PROBED 2026-06-14 from residential IP (user's machine)
- `GET https://www.google.com/maps/search/<name>/@lat,lng,16z?hl=vi` with desktop UA:
  - **No CAPTCHA / no consent / no /sorry/** from a residential IP. ✅
  - Photo CDN host = **`lh{3,4,5,6}.ggpht.com`** (place photos) + `streetviewpixels-pa.googleapis.com` (street view).
  - **Raw HTML does NOT contain the full photo URLs** — they load via JS. The
    `APP_INITIALIZATION_STATE` blob IS present. → **Must use a headless browser (Playwright)
    to execute JS**, open the place panel, then extract `lh*.ggpht.com/p/...` photo URLs.
    The repo already ships Playwright in `ai-venue-search/`.

### ⚠️ Hard caveat (do not forget)
- **Datacenter IPs (Cloud Run) → CAPTCHA** (the repo already proved this in the
  2026-06-11 agentic-enrichment session: "Cloud Run datacenter IPs → CAPTCHA → Bing
  fallback"). So the **scrape must run from a residential IP** (dev machine / residential
  box / residential proxy). Because results are **cached permanently in Postgres + Firebase**,
  production (Cloud Run) only ever **reads the DB** and never scrapes. A brand-new venue
  whose photos aren't cached yet will fall back (Bing/agentic → placeholder) when requested
  from production until it's been ingested from a residential IP.
- ToS/copyright: re-hosting Google Maps photos to Firebase is a ToS/copyright gray area.
  Flagged to user; user accepts the business risk for the market-test phase. (Not re-raising.)

### Implementation plan (TODO for tomorrow)
1. **Sidecar** (`ai-venue-search/ai_venue_search/providers/`): new `GoogleMapsCrawler`
   (reuse Playwright from `google_scrape.py`). Input `name + lat + lng` → headless Maps
   place → pick best name match → open gallery → extract `lh*.ggpht.com` photo URLs (strip
   size param, request a large size e.g. `=w1200`, dedup, top N) → detect CAPTCHA → return
   empty. New endpoint e.g. `POST /maps-photos` on the FastAPI app.
2. **Go backend**: new endpoint `POST /api/v1/venues/photos/ingest` `{goong_id,name,lat,lng}`
   → call sidecar → download each photo (SSRF-safe, reuse `IsPublicHTTPImageURL`) → upload
   to **Firebase Storage** (reuse the project's existing Firebase Storage wiring from
   onboarding R-004 `user_photos`) → persist rows.
3. **Migration** `0NN_venue_photos.sql`: table `venue_photos(goong_id TEXT PRIMARY KEY,
   firebase_urls TEXT[], source TEXT, fetched_at TIMESTAMPTZ)`.
4. **Serve**: thumbnail + detail read `firebase_urls` from DB first; empty → lazy-ingest
   (when running on a residential IP) → fallback to existing Bing/agentic pipeline (R-007)
   → `PhotoSlot` placeholder. Add an optional batch pre-populate script.
5. **Flutter**: point `VenueThumbnail` / detail hero at the DB-backed URLs (Firebase) when
   present; keep existing image-proxy path as fallback.

### Key facts to remember
- Photo CDN: `lh3.ggpht.com`..`lh6.ggpht.com` (place photos), `streetviewpixels-pa.googleapis.com` (streetview).
- Maps place data lives in the `APP_INITIALIZATION_STATE` JS blob → needs headless render.
- Goong Place Detail returns **no photo field** (confirmed via live JSON: only place_id,
  formatted_address, geometry, plus_code, compound, name, url, types) — Goong can never
  supply images; that's why an external photo source is needed at all.
- Existing reusable infra: `providers/google_scrape.py` (Playwright + consent dismiss +
  CAPTCHA detect + Bing fallback), `services/venue_image.go` (`IsPublicHTTPImageURL` SSRF
  guard, image proxy), Firebase Storage (onboarding upload), `services/goong.go` (Goong client).

---

## Status
- Part 1 (evidence): **user-confirmed conclusion** → promoted to **R-008**.
- Part 2 (direction): **decided, not yet built.** User starts implementation tomorrow.

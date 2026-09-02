---
name: anmates-design-system
description: FINAL brand colors, typography, components per Phase 1 handoff v1.0 (25.05.2026)
metadata:
  type: reference
---

# ĂN MATES — Design System (Phase 1, FINAL)

> ⚠️ **Hệ v1 dưới đây KHÔNG còn là hệ duy nhất (2026-09-02).** Design mới trên Claude Design
> (`fa249917-433c-4553-b1ae-8909eed150ed`) dùng một palette + typography **khác hẳn**, đã port
> sang code thành **hệ v2 chạy song song** — xem mục [Hệ v2](#hệ-v2--explore-direction-2026-09-02)
> ở cuối file. **Chưa hệ nào bị bỏ.** Toàn bộ app hiện tại vẫn chạy v1; chỉ màn Explore v2
> (`lib/views/explore_v2/`) dùng v2. Trước khi code màn mới, hỏi user: v1 hay v2?


> **Source of truth:** `plan/lastest/design/Brand system.html` + `plan/lastest/design/Logo studies.html` — read before coding any component.

---

## Color Tokens (FINAL — supersedes all prior values)

| Name | Hex | Usage |
|---|---|---|
| **Berry Crush** | `#B8336A` | Primary CTA, brand accent |
| **Ocean Twilight** | `#534BA8` | Secondary brand, headers, deep accents |
| **Wisteria** | `#C490D1` | Vibe meter fill, soft highlights |
| **Glaucous** | `#7D8CC4` | Dividers, secondary UI, muted state |
| **Mint Cream** | `#F1FFF8` | Background, light surface |
| **Caviar Ink** | `#121212` | Primary text, dark surfaces |

**Rule:** No auto-generated shades. Only values above. Any new shade requires Brand system update + architect approval.

### Semantic Colors
| Meaning | Color | Usage |
|---|---|---|
| Success | `#00A86B` | On-time check-in, positive |
| Warning | `#FFA500` | Late, attention |
| Error | `#E74C3C` | No-show, blocked |
| Neutral | `#95A5A6` | Disabled, loading |

---

## Typography

| Role | Font Family | Notes |
|---|---|---|
| Display / headings | **Plus Jakarta Sans** | Hero, screen title, CTA |
| Body / chat | **Be Vietnam Pro** | All paragraph text, chat bubble |
| State / caption labels | Mono caption (TBD with design) | Trust badge number, timestamp |

**Diacritic requirement:** Vietnamese render must be correct (ô, ư, ã, ...). Test with `Ăn miết`, `Nồi Lẩu`, `Lá thư`.

**Pixel-perfect requirement:** ±0.5px on font size, line-height, letter-spacing vs reference HTML.

### Recommended sizes (baseline 375px)
| Level | Size | Weight | Line Height |
|---|---|---|---|
| H1 | 32px | Bold 700 | 1.2 |
| H2 | 24px | SemiBold 600 | 1.3 |
| H3 | 18px | SemiBold 600 | 1.4 |
| H4 / label | 16px | Medium 500 | 1.5 |
| Body | 16px | Regular 400 | 1.5 |
| Body small | 14px | Regular 400 | 1.5 |
| Caption | 12px | Regular 400 | 1.4 |
| Button | 14px | SemiBold 600 | 1.0 |
| Chat msg | 15px | Regular 400 | 1.4 |

---

## Spacing (4px base unit)

```
4   xs   |   8   sm   |  12  md   |  16  lg
24  xl   |  32  2xl  |  48  3xl
```

- Screen gutter: 16px
- Card padding: 16px
- List item: 12px vertical / 16px horizontal
- Section gap: 24–32px
- Hit target: ≥44×44px (mandatory)

---

## Visual Conformance Criteria (from handoff §A.1)

When agent code-gens a screen, validate output against the reference HTML file in this order. Each criterion has clear pass/fail:

### 1. Layout structure
- Correct section hierarchy (header / hero / body / footer / sticky CTA)
- Element count + vertical order matches reference (no add/remove)
- Safe-area inset (top notch + bottom home indicator) respected

### 2. Spacing & sizing
- Outer gutter padding: ±2px vs reference
- Section-to-section gap: ±4px
- Hit targets ≥44×44px on every tappable element

### 3. Type
- Correct font family per role
- Correct weight/size/line-height/letter-spacing — ±0.5px
- Vietnamese diacritics render correctly

### 4. Color
- Only Brand system token values
- No auto-generated shades

### 5. Iconography & emoji
- Correct emoji set already in reference (🌶️🍻🥩🍜🍲☕…)
- Single icon family across app

### 6. State coverage
Every component must implement 5 states: **default · loading · empty · error · success**.
Reference HTML usually shows ONE state — note which one in PR description.

### 7. Animation & haptic
Required haptic + micro-animation moments:
- Match (Screen 13)
- Vibe unlock (Screen 16, threshold 70)
- Letter open (Screen 19)
- Auto check-in (Screen 21)

QA tests on real device (iPhone 12 / 15, Pixel 7, Samsung A54).

### 8. Localization
- 100% strings via VN dictionary, no hard-code
- No "Ăn miết" → "An miet" diacritic loss

---

## Component Primitives (build BEFORE screens)

Per handoff §A.2, generate these primitives first, validate against Brand system, then build screens:

- **Button** (Primary / Secondary / Outline / Danger / Ghost)
- **Chip** (Filter / Tag / Mood / State)
- **Card** (Restaurant card / Mate card / Booking card)
- **Input** (Text / Phone / OTP / Search)
- **Avatar** (with optional Trust badge ring)
- **Vibe-ring** (0-100 circular progress for Vibe meter)
- **Trust-badge** (Perfect Mate ≥90 / Trusted 80-89 / Limited <80)
- **AppLoader** (global reusable progress indicator — 3 modes: splash / overlay / top-bar)
- **Sparkle** (decorative twinkling element for hero surfaces)

---

## Component Specs

### Button — Primary
```
bg:        #B8336A (Berry Crush)
text:      White, 14px SemiBold Plus Jakarta Sans
padding:   12px 16px
radius:    8px (verify against reference HTML; may be higher)
shadow:    0 4px 6px rgba(0,0,0,0.1)
disabled:  opacity 50%
```

### Button — Secondary
```
bg:        #534BA8 (Ocean Twilight)
text:      White, 14px SemiBold
radius:    8px
```

### Vibe Ring
```
shape:      circular ring
diameter:   28-32px (small) | 64-80px (hero)
empty:      #E0E0E0
fill:       Wisteria → Berry Crush gradient
animation:  draw counter-clockwise, 600ms ease-out on update
unlock FX:  pulse + haptic at threshold 70
```

### Trust Badge
```
≥90:  "Perfect Mate" — gold tint #FFD700, ✨ icon
80-89: "Trusted"     — Glaucous #7D8CC4, ✓ icon
<80:  "Limited"     — Caviar #121212 on Mint Cream, ⚠ icon
```

### Chat Bubble
```
Sender (right):     bg #B8336A, white text, radius 16/16/0/16
Recipient (left):   bg #E0E0E0, Caviar text, radius 16/16/16/0
Max width:          70% screen width
```

### Vibe Meter Header (above message list, Screens 15 / 16)
```
height:             56-72px sticky band
content:            Vibe ring + numeric "42/100" or "72/100"
unlocked CTA:       "Đặt First Date 🍜" — pill button, Berry Crush bg
```

### Selfie Capture (Screen 20)
```
camera:             front camera only, no library upload
liveness:           on-device detect blink + head turn
overlays:           sticker, text, mood chip, emoji palette
mode chip:          😎 confident · 🥰 excited · 😅 nervous · 🤘 ready
3 actions:          "Xác nhận đi" (primary) · "Báo trễ" · "Nhắc 5'"
```

### AppLoader (Global Reusable Loading Indicator)

**Purpose:** Single primitive used everywhere a loading state must be communicated. Used by Splash, screen-level loading, API call overlays, optimistic state pending, etc.

**3 Modes:**

**Mode 1 — `splash`** (full-screen, branded — Screen 01)
```
size:           horizontal pill bar, width = clamp(160px, 60vw, 280px), height = 4px
position:       bottom area, vi text "Đang nhóm lửa nồi lẩu..." 12px below
track:          rgba(255,255,255,0.25)
fill:           white → wisteria gradient, animated indeterminate flow (left → right loop, 1.4s ease-in-out)
caption:        12px Be Vietnam Pro Regular, white 80%, centered under bar
behavior:       indeterminate (no % unless splash has actual init progress)
```

**Mode 2 — `overlay`** (screen-blocking modal during async)
```
backdrop:       rgba(18,18,18,0.45) full screen, blur 8px (iOS) / dim (Android)
center card:    rounded 16px, bg Mint Cream #F1FFF8, padding 20px, shadow 0 8px 24px rgba(0,0,0,0.2)
content:        AppLoader.splash sized to 200×4px + caption (caller-supplied or default "Đang xử lý...")
dismiss:        non-dismissable by tap (caller controls)
delay-on:       only show after 300ms — avoid flash for fast operations
min-visible:    once shown, stay ≥600ms — avoid blink
```

**Mode 3 — `top-bar`** (thin progress bar pinned under safe-area, doesn't block UI)
```
size:           height 2px, full screen width (under status bar)
track:          transparent
fill:           Berry Crush #B8336A
behavior:
  indeterminate: NProgress-style loop, 1s cycle
  determinate:   bind to 0-100% value (e.g. file upload, OTP timer mirror)
animation:      slides in from top (200ms), fades out (300ms) when reaches 100% or dismissed
```

**API (Riverpod global provider — pseudocode):**
```dart
// Indeterminate (default, when duration unknown — OTP, login, swipe)
final tokenId = ref.read(appLoaderProvider.notifier).show(
  mode: LoaderMode.overlay,
  caption: "Đang gửi OTP...",
);
// ... later
ref.read(appLoaderProvider.notifier).hide(tokenId);

// Determinate (when % known — upload, export, OTP countdown)
final tokenId = ref.read(appLoaderProvider.notifier).show(
  mode: LoaderMode.topBar,
  determinate: true,
);
ref.read(appLoaderProvider.notifier).setProgress(tokenId, 0.6);
ref.read(appLoaderProvider.notifier).hide(tokenId);

// Convenience: wrap a Future
await ref.withLoader(
  mode: LoaderMode.overlay,
  caption: "Đang xác minh khuôn mặt...",
  future: () => api.verifyFace(...),
);

// Convenience for upload with progress
await ref.withLoader(
  mode: LoaderMode.topBar,
  determinate: true,
  future: (onProgress) => api.uploadPhoto(file, onProgress),
);
```

**Concurrent loads (multiple async at once):**
- `show()` returns a `tokenId` — caller MUST `hide(tokenId)` to dismiss its own loader
- Provider keeps a stack of active tokens
- Overlay mode: visible while stack is non-empty; hides only when ALL overlay-mode tokens cleared
- Caption shown: most-recent overlay caption (later push wins display)
- Top-bar mode: stacks multiple determinate progresses into a single bar — shows max progress across all active topBar tokens
- Splash mode: only one allowed at a time (it's app-init scoped)
- Min-visible 600ms applies per token, not per overlay session

**Responsive rules:**
- Width never exceeds 320px on tablet — keeps brand consistent
- On landscape, pill bar shifts center, not stretch
- Caption truncates with ellipsis if longer than container

**Accessibility:**
- `Semantics(label: 'Đang tải', value: 'X phần trăm')` — screen reader announces
- Reduce-motion mode: shrinks animation to opacity-only pulse (no slide)
- Caption is required for `overlay` mode (don't show modal with no context)

**Don't:**
- Don't use spinners (`CircularProgressIndicator`) — brand uses horizontal pill
- Don't show overlay mode for operations <300ms
- Don't put loader in app bar — use top-bar mode instead

---

### Sparkle (decorative twinkle element — Splash + future hero surfaces)

**Visual:**
- SVG assets exported from design (`assets/sparkles/sparkle-4pt.svg`, `sparkle-6pt.svg`) — request from design team
- Renders via `flutter_svg` package (avoid `Image.asset` — SVG keeps crisp at any size)
- White or Wisteria fill (color override prop on widget)
- Size: random 8px / 12px / 16px / 20px (mixed for depth)
- Opacity baseline: 0.4–1.0
- Design DEPENDENCY: must export 2 SVG variants (4-point, 6-point) before FE-006 can ship

**Animation:**
```
twinkle:
  duration:    1500–2500ms (per instance, randomized)
  delay:       0–2000ms staggered offset (per instance)
  loop:        infinite
  keyframes:
    0%:        opacity 0.3, scale 0.6
    50%:       opacity 1.0, scale 1.0
    100%:      opacity 0.3, scale 0.6
  easing:      ease-in-out

drift (optional):
  subtle vertical translate ±4px, 4-6s, ease-in-out, loop
```

**Distribution rules:**
- ≥6 instances on Splash, scattered (avoid overlap with logo/text)
- Each instance has independent timing (no synchronized blink — feels organic)
- Use `RepaintBoundary` per sparkle to keep animation cheap

---

### Splash Screen (Screen 01) — Full Animation Spec

**Layout (top → bottom):**
1. Safe-area top (status bar passthrough)
2. Sparkle field (6–8 instances, scattered in upper 60% of screen)
3. Center logo: white pin/marker with Berry Crush "X" mark + small decorative dot at pin tip
4. Brand wordmark "ĂnMates" (Plus Jakarta Sans Bold, 40px, white)
5. Tagline "MỘT CHẠM · MỘT VA · ĂN MIẾT" (Be Vietnam Pro, 11px, white 85%, letter-spacing 2px, uppercase)
6. Spacer
7. AppLoader.splash + caption "Đang nhóm lửa nồi lẩu..."
8. Safe-area bottom

**Background:**
- Radial gradient: center-top wisteria glow `#C490D1` 25% opacity, fading into Berry Crush `#B8336A` solid

**Animation sequence (timeline):**

```
t=0ms:    All elements opacity 0, logo scale 0.7
t=100ms:  Background gradient fade in (200ms ease-out)
t=200ms:  Sparkles begin twinkling (staggered start, see Sparkle spec)
t=400ms:  Logo pin fade in (300ms ease-out) + scale 0.7→1.0 (450ms spring back)
t=750ms:  Logo "X" mark draw-in stroke (200ms) or fade (if not strokeable)
t=900ms:  Wordmark "ĂnMates" slide up 12px + fade in (350ms ease-out)
t=1100ms: Tagline fade in (300ms)
t=1300ms: AppLoader appears (caption + bar both fade in 200ms)
t=1500ms: AppLoader starts indeterminate animation loop
```

**Idle loop (after t=1500ms while waiting for app init):**
- Sparkles continue twinkling (independent loops)
- Logo: subtle breathing pulse — scale 1.0 → 1.02 → 1.0, 2.4s ease-in-out, infinite
- Loader: indeterminate flow continues

**Exit (when init completes):**
- All elements fade out together (250ms ease-in)
- Navigate to onboarding step 02 (or directly Home if onboarding already complete)

**Reduce-motion mode:**
- Skip entrance scale/slide animations
- Sparkles: opacity-only fade (no scale)
- Logo: no idle breathing pulse
- Loader: still animates (functional feedback required)

**Performance budget:**
- All animations on GPU (transform + opacity only, never on layout properties)
- Each Sparkle wrapped in `RepaintBoundary`
- Background gradient cached as image-painter to avoid re-rasterizing

---

### Onboarding Edu Carousel (Screens 02–04)

**Common framework — shared across all 3 screens:**

**Layout (top → bottom):**
1. Safe-area top
2. Status row: page indicator dots (3 dots) on left · "Bỏ qua" text button on right
3. Hero visual area (~50–55% of screen height) — unique per screen
4. Headline (Plus Jakarta Sans, ~28–32px, white/Caviar depending on bg)
5. Body paragraph (Be Vietnam Pro, 15–16px, secondary opacity)
6. Sticky bottom CTA: "Tiếp tục →" (Screens 02, 03) or "Bắt đầu →" (Screen 04)

**Background:**
- Persists from Splash: same Berry Crush → wisteria glow vibe
- 3–4 background Sparkles (fewer than Splash to avoid hero distraction), continuing twinkle from splash for continuity

**Page indicator (top):**
- 3 horizontal pills, each 8×8px
- Active: 24×8px Berry Crush pill (wider)
- Inactive: 8×8px white 40% opacity
- Transition between pages: pill morphs width 250ms ease-out

**Carousel transition (page → page):**
- Horizontal swipe gesture OR tap "Tiếp tục →"
- Hero visual: slides out left −80px + fade (250ms ease-in) while next screen's hero slides in from right +80px + fade (300ms ease-out, 50ms delay)
- Headline + body: cross-fade only, no slide (avoid motion sickness)
- Background gradient: shifts saturation slightly (warmer → cooler → warmest) — see per-screen notes
- Total transition: ~350ms end-to-end
- During transition, page indicator pill morphs in sync

**"Bỏ qua" button:**
- Tap: scale 0.95 (100ms) → 1.0 (150ms) micro-feedback
- Opens skip confirmation modal: "Bỏ qua phần giới thiệu?" with [Quay lại] [Bỏ qua]

**"Tiếp tục →" / "Bắt đầu →" CTA:**
- Idle: arrow `→` has subtle horizontal nudge — translateX 0 → 4px → 0, 1.6s ease-in-out, infinite
- Press: scale 0.97 (100ms) + arrow shoots right 12px before screen exits (200ms)
- "Bắt đầu →" (Screen 04 only): on press, arrow expands to full-width sweep + screen washes to next route in 400ms

**Reduce-motion mode:**
- Disable: hero slide, arrow nudge, hero idle loops
- Keep: page indicator morph, fade transitions, CTA tap scale feedback

---

#### Screen 02 — "Chọn quán trước" (Place-first)

**Copy:**
- Eyebrow: `01 · Chọn quán trước`
- Headline: `Hôm nay ăn gì? Chạm là ra ngay.`
- Body: `Khám phá theo Genre & Vibe — lẩu sùng sục, cafe khuất hẻm, quán nướng xì xèo… Bookmark vào Wishlist để tính sau.`
- CTA: `Tiếp tục →`

**Hero visual:**
4 Genre category cards arranged in a loose 2×2 grid (or scattered) with each showing emoji + label:
- 🍲 `LẨU`
- ☕ `CAFE CHILL`
- 🥩 `ĐỒ NƯỚNG`
- 🍡 `ĂN VẶT`

**Animation concept:** "Categories pop in like ingredients dropped into a bowl, then user's finger taps one to highlight the choice paradigm."

**Entrance timeline (after carousel arrival):**
```
t=0       page arrives, hero area empty
t=100ms   card 1 (🍲 LẨU) drops in from top −20px + fade + scale 0.85→1.0 (320ms spring)
t=220ms   card 2 (☕ CAFE) drops in (same animation, 120ms stagger)
t=340ms   card 3 (🥩 NƯỚNG) drops in
t=460ms   card 4 (🍡 VẶT) drops in
t=700ms   headline fade in + slide up 8px (250ms)
t=850ms   body fade in (200ms)
t=1000ms  CTA fade in
t=1200ms  ghost "tap" finger SVG appears over card 1, taps (scale pulse 1.0→1.08→1.0, 600ms), ripple emanates
t=1800ms  finger fades out, tapped card stays slightly emphasized (subtle Berry Crush ring 1px, 0.5 opacity)
t=2400ms  → enter idle loop
```

**Idle loop (cards):**
- Each card has independent gentle bob: translateY 0 → −2px → 0, 3.5–4.5s ease-in-out (randomized per card)
- Ghost finger replays tap once every 6s (only if user idle on screen)

**Background gradient nuance:** Slightly warmer (more Berry Crush, less wisteria) — appetizing.

---

#### Screen 03 — "Match cùng quán" (Social proof)

**Copy:**
- Eyebrow: `02 · Match cùng quán`
- Headline: `Ai cũng đang thèm quán này?`
- Body: `15 người quanh đây cũng vừa chọn quán giống bạn. Quẹt phải để gửi lời mời đi ăn cùng — không phải hẹn hò.`
- CTA: `Tiếp tục →`

**Hero visual:**
Stack of 3 Mate cards (MATE 01 / MATE 02 / MATE 03), fanned slightly (rotation −6° / 0° / +6°). Front card shows:
- Avatar circle
- `Vy, 24`
- Tags: 🌶️ `Cay 3`, 💬 `Tám`

Below the stack: a live counter badge — `🔥 15 người đang thèm quán này`

**Animation concept:** "Mates arrive one by one to underscore the social proof, counter ticks up while a swipe gesture demonstrates the L/R mechanic."

**Entrance timeline:**
```
t=0       page arrives, hero empty, counter shows "0"
t=150ms   back card (MATE 03) flies in from bottom-right + rotate −12°→+6° (400ms ease-out)
t=350ms   middle card (MATE 02) flies in from bottom-left + rotate +12°→0° (400ms ease-out)
t=550ms   front card (MATE 01 with Vy details) flies in from bottom + scale 0.8→1.0 + rotate +12°→−6° (450ms spring back)
t=950ms   tags 🌶️ Cay 3 + 💬 Tám pop in (scale 0.6→1.0, 200ms each, 80ms stagger)
t=1200ms  counter starts ticking 0 → 15 (700ms ease-out, easing slows near end; +1 per ~46ms)
t=1250ms  counter 🔥 icon does mini pulse on every odd number
t=1900ms  counter reaches 15, 🔥 emits 3 small Sparkles (twinkle out)
t=2100ms  headline + body + CTA fade in (sequential, 150ms apart)
t=2700ms  ghost swipe-right gesture on front card: translateX 0 → +40px + rotate −6° → +8° (450ms), green ✓ haze appears, card returns
t=3500ms  → enter idle loop
```

**Idle loop:**
- Cards: subtle parallax bob — back card moves +1px, middle 0, front −2px on a 4s loop (depth illusion)
- Ghost swipe replays every 5s if user idle

**Background gradient nuance:** Cooler (more wisteria, less Berry Crush) — communal/people vibe.

---

#### Screen 04 — "Nồi lẩu tự sôi" (Vibe meter unlock)

**Copy:**
- Eyebrow: `03 · Nồi lẩu tự sôi`
- Headline: `Trò chuyện đủ ấm, mới chốt kèo.`
- Body: `Vibe-check qua chat trước. Nồi lẩu sôi >70%, mới mở khóa nút "Đặt lịch hẹn". Không gấp, không gạ.`
- CTA: `Bắt đầu →` (last screen — distinct from Tiếp tục)

**Hero visual:**
Center: large stylized hotpot with circular Vibe ring around it (≈180px diameter).
- Ring fills from 0 → ~72% over the animation
- Inside hotpot: steam particles rise
- Behind the pot: chat bubbles appear one by one (alternating left/right) as Vibe accumulates
- Bottom of pot: lock icon → unlock icon transition at 70% threshold
- Above the pot: small label `ĂN MATES VIBE CHECK` with current % value

**Animation concept:** "Hotpot warms up as chat happens; ring fills; at 70% the lock pops open with a satisfying flash + haptic — the core product mechanic communicated in one motion."

**Entrance timeline:**
```
t=0       page arrives, hotpot scaled 0.85, ring at 0%, lock visible (locked), no chat bubbles, no steam
t=200ms   hotpot fade in + scale to 1.0 (350ms ease-out)
t=500ms   ring tube fade in (track visible, empty fill, 200ms)
t=700ms   first chat bubble pops in from right (bubble scale 0.6→1.0 spring, 250ms), ring fills 0→12% in 400ms
t=1100ms  steam particle #1 begins rising from pot
t=1200ms  second chat bubble from left, ring fills 12→24%
t=1700ms  third bubble (right), ring 24→38%, steam particle #2
t=2200ms  fourth bubble (left), ring 38→52%, steam #3
t=2700ms  fifth bubble (right), ring 52→68%, lock starts shimmering (faint white glow pulse, 600ms)
t=3300ms  sixth bubble (left), ring 68→72% — CROSSES THRESHOLD
t=3300ms  UNLOCK MOMENT (synchronized):
            - Lock icon scale 1.0→1.3→1.0 + flip rotation 0→180° → swaps to unlock icon (450ms total)
            - Ring color pulse: wisteria → Berry Crush burst → settle (300ms)
            - 6 mini Sparkles emanate radially from lock (twinkle out 800ms)
            - Steam particles intensify briefly (more density, 1s)
            - Subtle haptic medium impact (real device only)
            - Percentage text shows "72%" with a green ✓ next to it
t=4100ms  CTA "Bắt đầu →" gets a glow pulse (300ms) signaling "ready to launch"
t=4500ms  → enter idle loop
```

**Idle loop (post-unlock):**
- Steam particles: continuous, 3 active at once, each rising 0 → 60px vertical with curve, fading out, 2.5s lifecycle, ~1s spawn interval
- Ring: subtle breathing pulse at 72% (72 → 73 → 72 alpha shimmer, 2s)
- Hotpot: tiny 0.5px vertical bob (1.2s, very subtle "boiling" feel)
- Chat bubbles: stay in place, no further motion
- CTA "Bắt đầu →": arrow nudge from common framework

**Reduce-motion adaptation:**
- Skip ring fill animation — render directly at 72% with unlock state
- Skip chat bubble spawning sequence — render all bubbles at final positions
- Skip steam — render 1 static decorative wisp
- Keep CTA glow pulse (functional feedback)

**Background gradient nuance:** Warmest of the three — bg shifts to richer Berry Crush, hotpot/warmth metaphor.

---

### Auth Flow — Screens 05, 06, 07

> Shared: form fields use `Input` primitive (focus = 2px Berry Crush border, animate 150ms ease-out). Error state = subtle shake (translateX ±4px, 3 cycles, 200ms total) + red text fade in.

---

#### Screen 05 — Đăng nhập (Phone + Apple ID)

**Copy:**
- Headline: `Va Mates, ăn miết.`
- Body: `Sòng phẳng, an toàn, không sến — nhập số để bắt đầu va Mates.`
- CTA: `Gửi mã xác minh`
- Divider: `HOẶC`
- Apple button: `Tiếp tục với Apple`
- Footnote: `Tiếp tục đồng nghĩa bạn đồng ý Điều khoản & Quy tắc cộng đồng ĂnMates.`

**Concept:** "Welcoming arrival from splash — same brand warmth, now invites action."

**Entrance timeline:**
```
t=0       inherits bg gradient from splash (no re-paint)
t=100ms   logo mark (smaller, top-center) settles in from splash position
t=300ms   headline fade up 8px (300ms)
t=450ms   body fade in (200ms)
t=600ms   phone input slides up 16px + fade (320ms ease-out)
t=750ms   primary CTA fade in
t=900ms   "HOẶC" divider draws horizontally (left → right, 250ms)
t=1100ms  Apple button fade in
t=1300ms  footnote fade in (lowest opacity, 200ms)
```

**Interaction states:**
- Phone input focus: border morph 1px Glaucous → 2px Berry Crush (150ms), label floats up if floating-label style
- Invalid format: shake + red text "Số chưa đúng định dạng" fade in below input
- Valid: green check ✓ scale 0→1 in input trailing slot (200ms spring)
- CTA disabled state: opacity 50%, no shadow
- CTA tap: scale 0.97 + AppLoader.overlay caption "Đang gửi mã..." until API responds → navigate

---

#### Screen 06 — OTP Entry

**Copy:**
- Eyebrow: `BƯỚC 2 / 5`
- Headline: `Nhập mã 6 số`
- Body: `Vừa gửi tới +84 912 345 678. Mã có hiệu lực 90 giây.`
- Resend: `Chưa nhận được? Gửi lại (00:62)`

**Hero visual:** 6 OTP digit slots (4×4 hit area each), spaced evenly, with bottom underline that thickens on focus.

**Concept:** "Each digit pops in with satisfying confirmation; auto-advance feels alive."

**Entrance timeline:**
```
t=0       page transitions from Screen 05 (slide left, 250ms)
t=200ms   6 slots scale in 0.7→1.0 sequentially, 60ms stagger
t=500ms   first slot underline thickens (active focus indicator)
t=600ms   body text fade in
t=750ms   resend countdown fade in
```

**Digit entry interaction (PER DIGIT typed):**
- Digit appears with scale 0→1 spring (180ms)
- Slot underline pulses Berry Crush (200ms fade)
- Cursor auto-advances to next slot — underline focus migrates with 200ms ease
- Micro-haptic light (real device) per digit

**Auto-submit (when 6th digit entered):**
- All 6 slots flash white outline pulse (200ms)
- AppLoader.topBar appears (indeterminate)
- On success: 6 slots turn green ✓ (each cell flip 180°, 80ms stagger from left)
- On failure: shake + red underline + clear digits (300ms shake, then fade out digits)

**Countdown timer (`Gửi lại (00:62)`):**
- Tick every second (no animation per tick — just text update)
- At 00:00 → resend link becomes active (text underline appears, color shifts to Berry Crush)
- Tap resend: button scale 0.95 + AppLoader.topBar + reset countdown to 90s with fade

**SMS auto-fill:**
- When iOS / Android delivers OTP via auto-fill: all 6 slots populate simultaneously with cascade scale (40ms stagger)
- Auto-submits 200ms after fill

---

#### Screen 07 — Face verify (Liveness)

**Copy:**
- Eyebrow: `XÁC MINH KHUÔN MẶT`
- Instruction (dynamic): `Hãy quay đầu chầm chậm sang trái` (changes with liveness step)
- Helper: `Để mặt trong khung — đừng đeo khẩu trang.`
- Footnote: `ĂnMates chỉ dùng selfie để xác minh người thật. Không lưu hình, không bán dữ liệu.` + `Nét tin cậy là nét đẹp nhất.`

**Hero visual:** Circular camera preview (front cam), surrounded by progress ring that tracks liveness completion (0–100%).

**Concept:** "Camera framing feels alive — the ring fills as user completes liveness gestures; clear positive feedback when each step is detected."

**Liveness step sequence (each step = ring fill segment):**
1. "Nhìn thẳng vào camera" → 0% → 25%
2. "Hãy chớp mắt 2 lần" → 25% → 50%
3. "Quay đầu chầm chậm sang trái" → 50% → 75%
4. "Quay đầu chầm chậm sang phải" → 75% → 100%

**Entrance timeline:**
```
t=0       page arrives, camera frame mask scale 0.85, ring at 0%
t=200ms   camera circle fade in + scale to 1.0 (350ms)
t=500ms   ring track fade in
t=650ms   first instruction text fade up 8px
t=800ms   helper text fade in
t=1000ms  → live liveness detection begins (camera active)
```

**Per-step animation (when step detected):**
- Ring segment fills with Wisteria → Berry Crush gradient over 400ms ease-out
- Instruction text fades out (200ms) → next instruction fades in (200ms)
- Subtle micro-haptic on step success
- If detection fails / times out: ring segment flashes amber (200ms), instruction text shakes, "Thử lại" hint appears below

**Completion (100%):**
- Ring color burst: full circumference pulses Berry Crush → white (400ms)
- 8 Sparkles emanate from ring perimeter (twinkle out 900ms)
- Camera preview freezes with shutter flash white overlay (150ms fade)
- "Xác minh thành công ✨" appears (large text scale 0→1 spring, 350ms)
- AppLoader.overlay "Đang xử lý xác minh..." (anti-replay server check)
- On server success: navigate to Screen 08
- On server fail (replay detected): shake + error modal + return to start

---

### Profile Setup — Screens 08, 09a, 10a

#### Screen 08 — Thông tin cá nhân (with auto-derive reveal)

**Copy highlights:**
- Eyebrow: `THÔNG TIN CÁ NHÂN`
- Headline: `Bạn là ai trên bàn ăn?`
- Helper: `Chỉ ĂnMates dùng để ghép Mate hợp vía — không bao giờ public số tử vi của bạn.`
- Sections: Tên, Gọi thân mật, NGÀY/THÁNG/NĂM, Auto-derived (Cung / Mệnh / Thần số), Tính cách bàn ăn slider (Introvert ↔ Ambivert ↔ Extrovert)
- CTA: `Hoàn tất ✨`

**Concept:** "Form feels effortless — when DOB is complete, the magical auto-derive section reveals itself with a sparkle moment (delight beat that justifies privacy ask)."

**Entrance timeline:**
```
t=0       page slides in from right (carousel transition)
t=200ms   headline + helper fade in
t=400ms   name input fade up (250ms)
t=500ms   nickname input fade up
t=600ms   DOB 3-slot inputs fade up together
t=700ms   personality slider track fade in (no thumb yet)
t=800ms   slider thumb scale 0→1 spring (200ms)
t=1000ms  privacy note + CTA appear
```

**DOB completion trigger (when NGÀY + THÁNG + NĂM all valid):**
- 600ms delay (let user feel they "completed" entry)
- Auto-derive section UNVEILS:
  - Section container expands from height 0 → auto (350ms ease-out)
  - "ĂN MATES TỰ NHẬN DIỆN" eyebrow fades in
  - 3 cards (CUNG / MỆNH / THẦN SỐ) scale 0.85→1.0 + fade, stagger 100ms
  - 4 sparkles emit from the divider line (twinkle out, 700ms)
  - Micro-haptic light
- If user changes DOB later: section gracefully updates (cross-fade values, 200ms)

**Personality slider:**
- Drag: thumb scales 1.0→1.2 while dragging, returns 1.0 on release (150ms)
- Label below slider updates live: "Introvert · 22" → "Ambivert · 60" etc.
- Active section (Tám 1-1 / Cân bằng / Bàn 6+) highlights with Berry Crush underline that morphs position 250ms ease-out

**Toggle "Không hiển thị cung/ngũ hành trên public":**
- Standard switch component
- When toggled OFF: auto-derive cards fade to 40% opacity + 🔒 icon appears top-right of section (200ms)

**CTA "Hoàn tất ✨":**
- ✨ sparkle to right of text twinkles continuously (slow, 2s loop)
- Tap: scale 0.97 + AppLoader.overlay → navigate to 09a

---

#### Screen 09a — Gu ẩm thực (Taste picker)

**Copy:**
- Eyebrow: `GU ẨM THỰC`
- Headline: `Bạn ăn kiểu gì?`
- Helper: `Chọn ít nhất 5 thẻ — để ĂnMates ghép bạn với những người ăn cùng vibe.`
- Cuisine tags: 🌶️ Ăn cay cấp 3 / 🌿 Healthy / 🥩 Beef lover / 🍜 Mì các loại / 🦐 Hải sản / 🍰 Hảo ngọt / 🥗 Chay linh hoạt / 🚫 Không hành / 🍻 Bia hơi / ☕ Cà phê đen / 🥟 Dim sum / 🍣 Sushi
- Vibe tags: Tám tới bến / Yên tĩnh thư giãn / Khám phá quán mới / Vỉa hè bụi bặm / Sang chảnh check-in
- Counter: `4 / 5 đã chọn` (live updates)
- CTA: `Tiếp tục →` (disabled until ≥5 cuisine + ≥1 vibe)

**Concept:** "Chip selection feels playful and tactile — each tap has a satisfying pop, and the live counter visualizes progress toward unlock."

**Entrance:**
- Cuisine chips wave in: 4-column grid, each chip cascades scale 0.8→1.0 + fade (60ms stagger, total ~900ms)
- Vibe chips wave in after cuisine completes (300ms after)

**Chip tap interaction:**
- Tap unselected: scale 0.92 → 1.05 → 1.0 spring (250ms), bg fills with chip's category color, white check ✓ scales in (180ms), micro-haptic light
- Tap selected (deselect): scale 0.92 → 1.0, bg fades to neutral, ✓ scales to 0 (180ms)

**Counter `4 / 5 đã chọn`:**
- Number ticks up/down with scale punch (1.0→1.2→1.0, 200ms) on each change
- At threshold met (5+): counter text turns Berry Crush, CTA enables with glow pulse (300ms)
- Below threshold: counter is Glaucous

**CTA enable transition:**
- When ≥5 cuisine + ≥1 vibe selected: button bg morphs from disabled gray → Berry Crush (250ms), shadow appears, arrow `→` starts idle nudge

---

#### Screen 10a — Tải ảnh lên profile

**Copy:**
- Eyebrow: `BƯỚC CUỐI · MÔ TẢ BẢN THÂN`
- Headline: `Show bản thân nào ✨`
- Helper: `Tối đa 3 tấm — chọn những khoảnh khắc kể nhiều về bạn nhất. Mate ăn cùng sẽ thấy đầu tiên.`
- 3 photo slots labeled `MAIN / Ảnh chính` / `Ăn ngon` / `Sở thích`
- Add buttons: `Chụp mới / Thư viện / Instagram`
- Tips list: "Mẹo chọn ảnh ăn miết" (4 bullet tips)
- Counter: `2 / 3 ảnh`
- CTA: `Hoàn tất ✨` + `Bỏ qua`

**Concept:** "Each photo upload feels like adding a polaroid to a board — slot transforms from empty placeholder to actual photo with depth."

**Entrance:**
- 3 photo slots fade up + scale 0.9→1.0 with 80ms stagger
- Add source buttons (Chụp mới / Thư viện / Instagram) fade in after slots
- Tips list fades in last (lowest priority)

**Photo selection flow:**
- Tap "Chụp mới" → camera opens (native), upon return:
  - Photo appears in next available slot with crossfade + scale 0.92→1.0 (300ms)
  - AppLoader.topBar shows upload progress (determinate mode!)
  - Server checks happen in parallel: NSFW score, face detection, OCR
  - On success: green ✓ pulse in corner of slot (200ms)
  - On rejection (NSFW / no face / OCR phone detected): photo flickers red border, then fades out, error toast appears

**Reorder (drag-and-drop) — main photo:**
- Long-press: slot scales to 1.05 + shadow elevates + slight rotation 2° (haptic light)
- Drag: other slots slide aside making room (300ms ease)
- Drop on MAIN slot: photos swap with crossfade (200ms)

**"MAIN" badge:**
- Pinned to top-left corner of slot 1
- Persistent — doesn't animate unless photos reorder

**Counter `2 / 3 ảnh`:**
- Updates with same scale punch as Screen 09a counter

**CTA `Hoàn tất ✨`:**
- Sparkle twinkle on the ✨ (matches Screen 08)
- Tap: AppLoader.overlay → navigate to Home (first content view)

---

### Discovery — Screens 09b, 10b, 11

#### Screen 09b — Khám phá / Home

**Copy:**
- Top: `📍 QUẬN 1, TP.HCM`
- Greeting: `Hôm nay ăn gì, Vy?` (uses user's name)
- Search: `Tìm quán, món, vibe…`
- Genre rail: `BẠN THÈM GENRE GÌ? · Xem tất cả` → Lẩu sùng sục / Nướng xì xèo / Cafe chill / Ăn vặt phố
- Vibe rail: `… HAY MUỐN VIBE NÀO?` → ❄️ Máy lạnh / 🌿 Vỉa hè / 🔇 Khuất hẻm / ✨ Sang chảnh / 🌙 Ngồi khuya
- Hot section: `HOT QUANH BẠN · 18:00 · 5 quán` with restaurant cards
- Bottom nav: Khám phá / Wishlist / Chat / Mình

**Concept:** "Home feels warm and personally addressed — content cascades in like a friend showing options, rails feel scrollable with momentum."

**Entrance (first-time after onboarding):**
```
t=0       page fade in (cross-fade from photo upload)
t=200ms   district pill fade + slide down 4px (250ms)
t=350ms   greeting (with user name) fade up 12px (350ms)
t=550ms   search bar fade in
t=700ms   "BẠN THÈM GENRE GÌ?" eyebrow fade in
t=800ms   genre tiles cascade left → right (90ms stagger, scale 0.85→1.0 each, 250ms)
t=1300ms  vibe rail eyebrow + tiles cascade similarly
t=1900ms  hot section eyebrow + first restaurant card fade up
t=2100ms  remaining restaurant cards fade up sequentially (150ms stagger)
t=2400ms  bottom nav slides up from below safe area (300ms ease-out)
```

**Subsequent visits:** skip entrance cascade, render immediately (snappy feel).

**Rail scroll:**
- Horizontal scroll with momentum + snap to tile center
- First tile peeks from left edge (8px) to indicate scrollability

**Genre / Vibe tile tap:**
- Scale 0.95 + haptic light → navigate to filtered results
- Selected state (filter applied indicator): Berry Crush bg, white text

**Restaurant card tap:**
- Card scales 0.97 (100ms) → navigate to Screen 11 with shared-element transition (hero image expands to fullscreen hero)

**Pull-to-refresh:**
- Custom indicator: Sparkle field (3 sparkles) twinkle in pull zone
- Release with sufficient pull: Sparkles burst outward (300ms) while AppLoader.topBar appears
- On data refresh complete: AppLoader fades out, content cross-fades (200ms)

**Live `15 người đang thèm` counter on cards:**
- Number ticks up if backend updates while user is on screen (no animation per update, just text)
- 🔥 icon pulses gently (1.0→1.05→1.0, 1.5s loop) — subtle attention beacon

**Bottom nav:**
- Tap: icon scale 1.0→1.2→1.0 (180ms spring), label color shifts to Berry Crush, indicator bar morphs to new position (250ms ease-out)

---

#### Screen 10b — Wishlist theo quận

**Copy:**
- Header: `WISHLIST CỦA VY · 34 quán · 3 quận · cập nhật hôm qua`
- 2 sub-tabs: `Quán đã lưu` (default) · `Kèo đã đi qua`
- "Kèo đã đi qua" sub-tab: rail of Best Mates with venues + faces (Khánh / Linh / Trang / Mai / Phúc)
- District filter chips: 📍 Tất cả · 34 / Quận 1 / Quận 3 / Quận 5 / Quận 7 · 5 / Bình Thạnh · 3
- Restaurant cards with 🔥 HOT tag + price ranges

**Concept:** "Personal collection feels organized — district filter morphs instantly, sub-tab switch feels like flipping a page."

**Entrance:**
- Header stats fade in (200ms)
- Sub-tabs fade in
- District filter chips cascade horizontally (60ms stagger)
- Restaurant cards fade up sequentially (100ms stagger, max 5 visible)

**Sub-tab switch (`Quán đã lưu` ↔ `Kèo đã đi qua`):**
- Underline indicator morphs position (250ms ease-out)
- Old content fades out + slides left −20px (200ms)
- New content fades in + slides from right +20px (250ms, 50ms delay)

**District filter chip tap:**
- Selected chip scale 1.0→1.05→1.0 + bg morph to Berry Crush (200ms)
- Previously selected chip fades back to neutral
- Restaurant list re-filters: items leaving fade + scale 0.9 → 0 (200ms), items entering fade up + scale 0.85→1.0 (250ms, staggered)

**Best Mates rail (in "Kèo đã đi qua"):**
- Each Best Mate card shows venue + face avatar
- Card tap: avatar scales 1.0→1.1→1.0 + soft Berry Crush ring pulses outward (300ms) → navigate to chat
- "× ĂN CÙNG" count badge: gentle pulse when count increments after a new shared meal (1 second after page open)

**Pull-to-refresh:** same Sparkle pattern as Home.

---

#### Screen 11 — Chi tiết quán

**Copy:**
- Hero image full-width with overlay: `HERO · TIỆM MÌ RAMEN Q1` / `🍜 Ramen · Lẩu Nhật`
- Name: `Tiệm mì Ramen Q1`
- Stats row: `⭐ 4.6 · 1.2k đánh giá · 80k–250k · 0.4 km`
- Social proof banner: `15 người quanh đây cũng đang thèm quán này · Quẹt để xem Mate cùng vibe →`
- About section: `VỀ QUÁN` + description
- Dish chips: 🍜 Tonkotsu / 🥚 Trứng lòng đào / 🌶️ Spicy miso / 🍻 Sapporo nháp
- Match score: `Hợp gu Vy: 92% · Cay 3 ✓ · Không hành ✓ · Khuất hẻm ✓`
- CTAs: `＋ Wishlist` (secondary) / `Tìm Mate ăn cùng ↗` (primary)

**Concept:** "Restaurant arrives with cinematic hero zoom — social proof banner is the attention beacon that drives swipe intent."

**Entrance (from Home — shared element transition):**
```
t=0       hero image transitions from Home card position to fullscreen (350ms ease-in-out)
t=200ms   name + stats row fade up 12px (300ms, starts during hero expansion)
t=600ms   social proof banner slides up from bottom + scale 0.95→1.0 (350ms spring) — most attention-grabbing motion
t=700ms   🔥 social proof count number ticks 0 → 15 quickly (400ms)
t=900ms   "VỀ QUÁN" section + description fade in
t=1100ms  dish chips cascade horizontally (60ms stagger)
t=1300ms  match score row fades in
t=1300ms  "92%" percentage tick from 0 → 92 (500ms ease-out, scale punch at end)
t=1500ms  CTA bar slides up from bottom (300ms)
```

**Social proof banner idle:**
- "Quẹt để xem Mate cùng vibe →" arrow nudges 0 → 4px → 0 (1.5s loop) — invites action
- Number "15 người" gently pulses (1.0→1.03→1.0, 2.4s loop) — alive
- Background subtle Wisteria → Berry Crush gradient pulse (4s loop, very subtle alpha shift)

**`＋ Wishlist` CTA:**
- Tap: ＋ icon spins 0°→360° (350ms) → swaps to ✓ check icon
- Card subtle white ripple (200ms)
- Toast: "Đã thêm vào Wishlist ✨"

**`Tìm Mate ăn cùng ↗` CTA (primary):**
- Idle: arrow `↗` rotates gently 0° → +5° → 0° (2s loop)
- Tap: AppLoader.overlay → navigate to Screen 12 (Dining swipe)

**Hero image parallax on scroll:**
- Scroll up: hero shrinks slightly + opacity holds, while sticky header (small name + back) fades in at top

---

### Match Flow — Screens 12, 13

#### Screen 12 — Dining swipe

**Copy:**
- Top header: `SWIPE CHO QUÁN · Tiệm mì Ramen Q1`
- Mate card content: `KHÁNH · 26 / ✓ Đã xác minh / 💯 Trust 98 / Khánh, 26 · 0.8 km`
- Status quip: `"Vừa tan làm, đang muốn ramen cay + bia lạnh. Có ai cùng?"`
- Tags: 🌶️ Cay 3 / 💬 Thích tám / 🍻 Bia hơi / 🚶 Đi bộ tới
- Chip: `Cũng vừa thêm quán này · 2 phút trước`

**Hero visual:** Swipe card deck (top card prominent, 2 cards behind peek).

**Concept:** "Cards feel physical and weighted — drag has friction, swipe-out has finality, super-like has lift. Empty state celebrates (no more Mates = either back to explore or come back later)."

**Entrance:**
- Top card slides up from bottom + scale 0.9→1.0 (350ms spring)
- 2 behind cards (deck stack) cross-fade in offset positions (depth illusion)
- Header + restaurant name fade in (200ms)
- Action buttons (👎 / ⭐ / 👍 if present) fade in last

**Drag interaction (top card):**
- Card follows finger with 1:1 translation + rotation proportional to horizontal drag (max ±15° at edge)
- Background reveals colored hint:
  - Drag right: green `✓ ĐI ĂN CÙNG` chip fades in on card top-left (opacity tied to drag distance)
  - Drag left: red `× BỎ QUA` chip fades in on card top-right
  - Drag up (super-like): purple `⭐ ƯU TIÊN` chip with sparkle particles
- Release before threshold: card snaps back to center (250ms spring)
- Release past threshold: card flies off-screen in drag direction (300ms ease-out) + rotates 30°

**Card transition (after swipe):**
- Top card exits → second card scales up 0.95→1.0 + slides forward (200ms)
- Third (back) card scales up similarly
- New card appears at back from below (slides up + fade)

**Super-like (swipe up):**
- Card flies up + scales down 1.0→0.6 (300ms)
- 8 sparkles burst from card position (twinkle out 700ms)
- Haptic medium impact

**Rate-limit hit (>60/min):**
- All buttons grayed out
- Top of screen shows pill banner: "Bạn quẹt nhiệt tình ghê 🔥 chờ 30 giây để cool down"
- Banner slides down from top (250ms) + auto-dismiss after 30s

**Empty state (no more Mates for this restaurant):**
- Last card flies off → empty deck area shows:
  - Hotpot illustration (subtle, large icon, white 80%)
  - Text: "Đã quẹt hết Mate cho quán này rồi 🍜"
  - CTA: "Khám phá quán khác" (secondary button) + "Quay lại sau" (text link)
  - 3 sparkles twinkle in the empty area for ambient life

**Top-of-deck chip `Cũng vừa thêm quán này · 2 phút trước`:**
- Pinned on top of card, time updates live every 30 seconds (no animation per update)

---

#### Screen 13 — Match!

**Copy:**
- Top: `VA TRÚNG MATE`
- Headline: `Có Mate rồi!`
- Body: `Cả hai đều thèm Tiệm mì Ramen Q1 — vào chat làm nóng nồi lẩu nào.`
- Avatars: VY + KHÁNH (face circles, large)
- CTAs: `Nói "Hello" trước đi 👋` (primary) / `Tiếp tục quẹt` (secondary)

**Concept:** "Match is the most CELEBRATORY moment — full-bleed, brand peak, designed to be screenshot-worthy. Should feel earned and joyful, with haptic + sound + sparkles converging."

**Entrance (the big moment):**
```
t=0       bg gradient bursts in (radial from center, 400ms): Berry Crush deep saturation
t=0       deep haptic SUCCESS (real device)
t=100ms   full-bleed Sparkle confetti burst (15+ sparkles from center, scatter outward, mixed sizes, 1.2s lifecycle)
t=200ms   "VA TRÚNG MATE" eyebrow fades in + slight letterspacing punch (250ms)
t=400ms   headline "Có Mate rồi!" types in character by character (60ms per char) — playful
t=900ms   left avatar (VY) flies in from left + scale 0.6→1.0 spring (450ms)
t=1100ms  right avatar (KHÁNH) flies in from right + scale 0.6→1.0 spring (450ms)
t=1500ms  avatars collide softly in center area (subtle ✨ between them, twinkle 300ms)
t=1700ms  body description fades in (300ms)
t=2000ms  primary CTA scales in 0.9→1.0 spring + glow pulse
t=2200ms  secondary CTA fades in
```

**Idle loop:**
- Sparkles continue twinkling at lower density (3-4 active)
- Avatars: subtle breathing pulse (1.0→1.02, 2.4s, offset so they're not synced — feels alive)
- Primary CTA: glow pulse every 3s (signals "tap me")

**Sound:** Brand match jingle (short, ≤800ms, plays once with haptic)

**`Nói "Hello" trước đi 👋` tap:**
- Button scales 0.97 → fills with Berry Crush brighter → screen wipes left to Chat (350ms)
- 👋 emoji wiggles before transition

**`Tiếp tục quẹt` tap:**
- Subtle scale + slide back to Screen 12 (reverse transition)

**Reduce-motion:**
- Skip sparkle burst, character-by-character typing, avatar fly-in
- Render final state immediately with single fade + haptic
- Keep CTA glow pulse

---

### Chat — Screens 14, 15, 16

#### Screen 14 — Chat Inbox (4 groups)

**Copy:**
- Top: `HỘP CHAT · Mates của Vy`
- Section 1: `MATE VỪA MATCH` + hint "Nói 'Hello' trước trong vòng 24h để giữ kèo nha" + list (Khánh / Linh / Duy / Mai with relative times)
- Section 2: `ĐANG TÁM` + list with last messages + venue context (Trang / Phúc / Mai Anh — Phúc shows "đang gõ…")
- Section 3: `BEST MATE` + `≥3 lần ăn cùng` + cards (Hà / Quân / Thảo with venue history)
- Bottom nav

**Concept:** "Inbox is the gathering of relationships — each section has its own visual rhythm, typing indicator pulses with life, time updates feel ambient."

**Entrance:**
- Sections fade in sequentially: Mới match (t=100) → Đang tám (t=300) → Best Mate (t=500)
- Within each section, rows cascade fade up 8px (50ms stagger)
- Bottom nav slides up last

**Row appearance (each chat row):**
- Avatar + name + message preview + timestamp
- Unread badge (if any): scale 0.6→1.0 spring (200ms, slight delay after row appears)

**"Đang gõ..." indicator (Phúc row):**
- 3 dots pulse sequence: dot1 up → dot2 up → dot3 up (1.2s loop)
- Subtle row bg shimmer (Wisteria 5% wash, 2s loop)

**Pull-to-refresh:** Sparkle field same pattern as Home/Wishlist.

**Hello-window urgency (Mới match section):**
- If countdown <2h: countdown text turns amber + small clock 🕐 icon pulses (1.0→1.1→1.0, 1.5s) next to time
- If <30min: text turns red + faster pulse

**Auto-archive notice (Best Mate or older chats):**
- Archived chats appear in a separate "Đã ngưng" section (collapsed by default)
- Tap header to expand: caret rotates 0°→90°, list slides down (300ms)

**Swipe-left on row (block / unmatch action):**
- Row reveals action buttons (Block / Unmatch / Mark unread)
- Buttons slide in from right with bg color expand

**Row tap:**
- Row bg flashes Mint Cream (150ms) → navigate to chat detail (Screen 15 or 16) with slide transition

---

#### Screens 15 / 16 — Chat (Locked vs Unlocked)

**Shared:**
- Header: Mate avatar + name + "Khánh, 26 · 🍜 Tiệm mì Ramen Q1 · đang online"
- Vibe meter band: large Vibe ring + numeric "Nồi 42" or "Nồi 72"
- Message list (sender right / recipient left bubbles)
- Suggestion chips: 🥡 Topping tủ? / 🍻 Có order bia ko? / 🕐 Khung giờ tiện?
- Input row: text field + voice note button + send

**Difference:**
- **Screen 15 (locked, Nồi 42):** Vibe state shows lock + "FIRST DATE · Tâm tình thêm để unlock First Date cùng Mate" + hint "Chat thêm ~10 tin chất lượng nữa"
- **Screen 16 (unlocked, Nồi 72):** Vibe state shows ✨ UNLOCKED + "FIRST DATE · Vibe đã chín — chốt ngày First Date được luôn!" + a "Đề xuất" propose card with date/time + `Chốt First Date — mở rồi!` CTA

**Concept (locked):** "Calm, focused — the Vibe is a quiet progress beacon; chat feels intimate."

**Concept (unlocked):** "Vibe ring is no longer just decoration — it's CELEBRATING. Propose card appears with magnetic pull asking for action."

**Entrance (both):**
- Header fades down 8px (200ms)
- Vibe band slides down from header (250ms)
- Vibe ring fills from 0 → current value (400ms ease-out, scale punch when reaching value)
- Message list pre-rendered (recent first), fades up sequentially (50ms stagger, max 5 visible at entrance)
- Input row + suggestion chips slide up from bottom (300ms)

**Sending a message (user):**
- User types → "Đang gõ" indicator NOT shown on user side (only to recipient)
- Send button tap: button scales 0.9 → message bubble flies from input to right side (250ms ease-out spring)
- Bubble settles in list with subtle fade
- Vibe delta: Vibe ring fills incremental amount (200ms ease-out)
- `Nồi 42` number ticks up live to new value

**Receiving a message:**
- Bubble fades in from left side + slight scale 0.9→1.0 (200ms)
- Vibe ring tick (if scoring boosts Vibe)
- Auto-scroll to bottom if user is already at bottom (otherwise show "↓ Tin mới" pill)

**PII redacted message:**
- Replaced text `[liên hệ bị ẩn]` shown in italic + muted color
- Small ℹ icon next to it; tap → toast "ĂnMates ẩn SĐT/MXH để bảo vệ vibe"

**Voice note (press-hold input button):**
- Button expands to circle with red center + microphone icon
- Surrounding waveform appears + grows with audio
- Slide left to cancel: button + waveform slide along finger, threshold past 80px → cancel icon ❌ + haptic medium → release cancels
- Release at original position: waveform shrinks → voice bubble appears in chat (with play button + duration)

**Suggestion chips:**
- Idle: gentle horizontal scroll suggestion (tiny offset bob ±2px, 3s)
- Tap: chip scales 0.95 → text auto-fills input → user can edit or send

**Vibe unlock moment (transition from 15 → 16, happens IN-PLACE when crossing 70):**
- Triggered by a new message that pushes Vibe from <70 to ≥70
- Vibe ring fills past 70 → at exact moment:
  - Ring pulses (Wisteria → Berry Crush burst, 300ms)
  - Lock icon flips 180° → unlock icon (450ms)
  - 6 sparkles emanate from Vibe ring perimeter
  - Haptic medium impact
  - "FIRST DATE" badge in Vibe band transitions from locked state copy → unlocked state copy (cross-fade)
  - Propose card slides up from below Vibe band (350ms spring) with restaurant + time pre-filled
  - Slight bg gradient warm shift (Berry Crush deeper, 600ms)
- Suggestion chip area updates to show new chip: `🎉 Chốt First Date đi!`

**Propose card (Screen 16):**
- Card sits between Vibe band and message list, sticky
- "ĐỀ XUẤT · Đi luôn tối nay nha? · 19:30 · Tiệm mì Ramen Q1 · còn bàn 2 chỗ"
- CTA `Chốt First Date — mở rồi!` has continuous gentle pulse (1.5s, scale 1.0→1.02)
- Tap: AppLoader.overlay → navigate to Screen 17 (Đặt lịch hẹn)

**Reduce-motion (chat):**
- Skip bubble fly-in animation, just fade in
- Skip Vibe ring fill animation on entrance — render at current value
- Keep unlock moment haptic + ring color burst (functional signal)

---

### Booking & Letter — Screens 17, 18, 19

#### Screen 17 — Đặt lịch hẹn (First Date scheduler)

**Copy:**
- Top: `CHỐT KÈO · Với Khánh tại Ramen Q1`
- Voucher banner: `Tặng voucher 50k vì chốt nhanh · Áp dụng khi cả hai check-in đúng giờ`
- Calendar header: `THÁNG 5 · 2026`
- Days of week + grid
- Status: `ĐÃ CHỌN · SẮP TỚI · ĐÃ QUA`
- Time slot picker `GIỜ` (chips of time slots)
- Footer: `ĂnMates sẽ bật Live Tracking 45 phút trước hẹn để cả hai biết đối phương đang trên đường.`
- CTA: `Chốt T7 · 19:30 →`

**Concept:** "Scheduling feels like a thoughtful commitment — voucher feels rewarding, calendar grid is clean, time slot selection is decisive."

**Entrance:**
- Header + Mate context fade in (200ms)
- Voucher banner slides down from top with subtle gold/wisteria sheen (350ms) + 2 sparkles twinkle on banner
- Calendar grid: each day cell fades in row by row (top to bottom, 40ms stagger per cell)
- Time slot chips: cascade horizontally after calendar settles (60ms stagger)
- Footer + CTA appear last

**Calendar day cell states:**
- ĐÃ QUA (past): Glaucous 50% opacity, no interaction
- SẮP TỚI (available): white bg, Berry Crush text
- ĐÃ CHỌN (selected): Berry Crush bg, white text, subtle scale 1.05 + shadow
- Today: underline accent under date number

**Day tap:**
- Cell scales 0.95→1.05→1.0 (200ms spring) + bg morph to Berry Crush
- Previously selected cell deselects (reverse animation)
- Time slot chips refresh: old chips fade out (150ms), new available chips fade in (200ms)

**Time slot tap:**
- Chip scales + bg fills Berry Crush
- CTA button updates: `Chốt T7 · 19:30 →` text updates in place (cross-fade text, 200ms)
- CTA enables with glow pulse if was disabled

**Voucher banner:**
- Subtle continuous shimmer: gradient sweep left → right across banner (3s loop) — feels rewarding
- 2 sparkles twinkle independently on banner

**Soft-hold countdown (after CTA tap → pending state):**
- Top of screen shows banner: "⏱ Đã giữ chỗ — Khánh có 15:00 để xác nhận"
- Countdown ticks every second
- At <2min: banner turns amber + faster sparkle
- On confirm by partner: banner morphs to green "Khánh đã xác nhận ✓" with celebration (small sparkle burst)
- On expiry: banner turns gray → "Chỗ đã thả · thử slot khác nhé"

**CTA tap:**
- AppLoader.overlay caption "Đang giữ chỗ..."
- On success: navigate to confirmed state (different screen or modal)

---

#### Screen 18 — Lá thư từ Mate (inbound notification)

**Copy:**
- Top eyebrow: `Uiii...ai đó đã mời bạn đi Date này!`
- Headline: `Có người gửi kèo cho Vy nè ✨`
- Body: `Bóc thư xem ai đang muốn rủ bạn ăn cùng · Đừng để Mate đợi lâu nha!`
- Sender card: TỪ Khánh, 26 · ✨ VIBE 78
- CTA: `Bóc thư xem ngay 💌` (primary)
- Footer: `Để sau · Mate sẽ đợi 12 tiếng trước khi hết hạn`

**Concept:** "Letter feels SPECIAL — like receiving a physical postcard. Envelope-style entrance with sealed wax aesthetic. Anticipation builds for the 'bóc thư' moment."

**Entrance:**
```
t=0       page bg fades in (warm Berry Crush gradient)
t=200ms   eyebrow text "Uiii..." fades in with playful wiggle (rotate ±2°, 400ms)
t=500ms   headline fades up 12px
t=700ms   body fades in
t=900ms   envelope visual flies in from top + slight rotation -8°→0° (450ms spring)
t=900ms   envelope settles with gentle bob loop (idle)
t=1100ms  sender card (TỪ Khánh) slides up from below envelope
t=1300ms  CTA "Bóc thư xem ngay 💌" appears with magnetic pulse
t=1500ms  footer expiry note fades in (smallest)
```

**Envelope idle loop:**
- Subtle 3D tilt: rotateY 0° → +5° → 0° → -5° → 0° (4s loop) — like envelope is breathing
- Wax seal (if present): tiny shimmer (sheen across seal, 2.5s)
- 3 sparkles twinkle around envelope perimeter

**CTA `Bóc thư xem ngay 💌`:**
- 💌 emoji bobs gently
- Tap: envelope animates "open" (top flap lifts up 45°, 300ms) → screen wipes to Screen 19 with letter reveal transition

---

#### Screen 19 — Lá thư viết tay (postcard render)

**Copy:**
- Postage stamp: `POST · #042 · 23.05.2026 · ĂN MATES · POSTAGE`
- Side stamp: `★ TP.HCM ★`
- Date/place: `Q.1 · BƯU CỤC ĂN · Sài Gòn, ngày 23 tháng 5,`
- Body: `Gửi Vy thương, Vibe của Vy hợp gu mình lắm — đi quẹo Q.1 ăn ramen cay nha? Mình bao tonkotsu, Vy bao trứng 🥚🌶️`
- Date proposal card: `T7 THG 5 · GIỜ · ĐỊA ĐIỂM · 🍜 Tiệm mì Ramen Q1 · 15 Hàm Nghi, Q.1 · 0.4 km`
- Tags: 🌶 CAY 3 / 🍻 BIA / 💬 TÁM
- Countdown: `⏱ CÒN 1N 4H`
- P.S.: `Mình đợi ở quầy bar, mặc áo đỏ cho Vy nhận ra. Nếu kẹt thì nhắn mình nha 💌`
- Signature: `Khánh · 26 · Trust 98 · 0.8 km`
- CTAs: `I said YES ✨ — gửi hồi âm` (primary) / `Sorry Mate nhé — gấp lá thư lại 🙏` (secondary)
- Footer: `Hồi âm trong 12 tiếng · đồng ý sẽ thêm vào lịch`

**Concept:** "Postcard renders with handwritten warmth — each section reveals as if being read. Most emotional/intimate screen in the app. Choosing to accept feels like writing back."

**Entrance (continuing from envelope open in Screen 18):**
```
t=0       envelope flap fully open, postcard inside slides up + rotates from -8° → 0° (500ms ease-out)
t=400ms   postage stamp + side decoration fade in (200ms)
t=600ms   date/place line fades in
t=750ms   body text reveals line by line (each line fades up 4px, 250ms per line, 200ms stagger)
t=1300ms  proposal card slides in from right with subtle bounce (350ms spring)
t=1450ms  3 tags pop in scale 0→1 (80ms stagger)
t=1600ms  countdown ⏱ fades in + immediately starts ticking
t=1800ms  P.S. line fades in slowly (italic feel, 400ms)
t=2200ms  signature scribbles in (left to right wipe, 600ms) — handwritten feel
t=2900ms  CTAs slide up from bottom (300ms)
```

**Postcard idle:**
- Subtle parchment paper shimmer effect (very subtle, no distraction)
- Countdown ticks every second (no animation per tick)
- At <2h remaining: countdown turns amber + clock 🕐 pulse

**`I said YES ✨` CTA:**
- ✨ continuously twinkles
- Tap: postcard tilts forward 5° + AppLoader.overlay "Đang gửi hồi âm..."
- On success: 6 sparkles burst from postcard + celebration toast "Đã chốt với Khánh ✨" → navigate to Calendar/Schedule

**`Sorry Mate nhé — gấp lá thư lại 🙏` CTA:**
- Tap: confirmation modal "Chắc chắn từ chối kèo?" with [Quay lại] [Gấp lá thư]
- On confirm: postcard physically folds (CSS perspective transform, 600ms) → flies into envelope → envelope closes → fade out → return to inbox

---

### Day-of Flow — Screens 20, 21

#### Screen 20 — Selfie xuất phát

**Copy:**
- Top: `ĂN MATES · NHẮC KÈO`
- Headline: `Lên đường với Khánh nào!`
- Countdown: `CÒN __ ĐẾN KÈO` (or `NGAY BÂY GIỜ`)
- Sub: `Lên con chiến mã 🐎 và phi tới Mate thôi!`
- Helper: `Selfie một phát để Khánh biết bạn đang trên đường.`
- Mood chips: STICKER / Text / Mood (Bruh...Bruh / I'm on my way!) / Giờ / Vị trí / Vibe / Emoji
- Camera controls: Đổi cam · Sticker
- 3 actions: `Xác nhận đã bắt đầu đi 🛵` (primary) / `Báo Mate mình sẽ trễ` / `Nhắc lại sau 5 phút`

**Concept:** "Camera feels alive and playful — overlays are tactile (drag, pinch), mood selection is expressive, the depart action feels committed."

**Entrance:**
- Header + countdown fade in (200ms)
- Camera preview fades in with subtle zoom (1.05 → 1.0, 400ms ease-out) — feels like camera "powering on"
- Overlay tool rail fades in from bottom (slides up 250ms)
- 3 action buttons slide up from below (350ms, stagger 80ms)
- Countdown ticks immediately

**Countdown urgency:**
- Default: Caviar text
- <30 min: turns Berry Crush + small ⏰ icon pulse
- <10 min: turns red + faster pulse + slight text shake (subtle, every 5s)
- 0 / negative (late): turns red + persistent shake + change text to "Khánh đang chờ..."

**Mood chip selection (Bruh / I'm on my way):**
- Tap: chip scales 0.95→1.0 + chosen mood appears as overlay on camera preview (sticker-style, draggable)
- Overlay can be repositioned (drag) and resized (pinch)

**Overlay tools (STICKER / Text / Mood / etc.):**
- Tap: subset of overlays appears in horizontal scroll above tool rail
- Selected overlay drops onto camera preview at default center position
- Each overlay has its own gentle idle bob on the canvas

**Capture (3-action primary `Xác nhận đã bắt đầu đi`):**
- Tap: camera flash (white overlay 100ms) + shutter sound
- Selfie freezes → AppLoader.overlay "Đang kiểm tra liveness..."
- Background server check: anti-replay + embedding match
- On success: green ✓ pulse + transition to Screen 21 (Live Tracking)
- On fail (replay detected / face mismatch): red border + "Selfie chưa hợp lệ · chụp lại nha" toast + return to camera

**`Báo Mate mình sẽ trễ`:**
- Tap: small modal slides up from bottom with 3 chips: 5' / 10' / 15+'
- Select → AppLoader.topBar → Mate receives notification → modal dismisses with confirmation toast

**`Nhắc lại sau 5 phút`:**
- Tap: button scale + AppLoader.topBar → schedule local notification → toast "Sẽ nhắc lại sau 5 phút"
- Max 3 snoozes (after 3rd: button disabled with copy "Hết lượt nhắc · phi tới luôn nha!")

---

#### Screen 21 — Live Tracking (card-style, NOT map)

**Copy:**
- Top: `KHÁNH · ĐANG TỚI · ETA 8 phút`
- Booking summary: `HẸN · HÔM NAY · 19:30 · Tiệm mì Ramen Q1 · 15 Hàm Nghi, Quận 1 · 0.4 km`
- Status: `Live Tracking bật · Cả hai đã đồng ý chia sẻ vị trí`
- Status events:
  - `Khánh đã xuất phát · Đang di chuyển bằng xe máy · ETA 19:28`
  - `Bạn đã có mặt · Check-in tự động qua geofence`
  - `Khánh đang gần tới · Còn 320m — chuẩn bị greeting`
- Trust hint: `+2 Trust điểm khi cả hai check-in đúng giờ`

**Concept:** "Calm assurance — abstract route progression replaces map, status updates feel like a friend giving you real-time radio updates. Anti-creep design."

**Hero visual:** Status pill at top + stylized abstract route progression (NOT real map):
- A horizontal "road" with Mate's avatar dot moving along it from "starting point" to "restaurant" icon
- Progress increments as Mate gets closer
- 320m threshold triggers a final "almost there" pulse

**Entrance:**
```
t=0       page fades in
t=200ms   top status pill slides down 8px + fade (300ms)
t=350ms   ETA number ticks from "??" → current (300ms)
t=500ms   booking summary card fades up
t=700ms   abstract route visualization appears: starting dot + ending restaurant dot fade in, road line draws left → right (450ms)
t=1100ms  Mate avatar dot fades in at current progress position
t=1250ms  status event list fades up sequentially (200ms stagger)
t=1500ms  trust hint footer fades in
```

**Live updates (every 30s from backend):**
- ETA number ticks to new value (scale punch animation)
- Mate avatar dot slides along route to new position (smooth interpolation, 1000ms ease-in-out)
- New status event prepends to list with slide down + fade (300ms)
- Status pill text updates with cross-fade

**Status transitions:**
- `Đang tới` (Berry Crush text) → `Sắp tới` (amber) → `Đã tới` (green ✓ pulse)
- Route dot color matches status

**Proximity moment (Mate within 320m):**
- Avatar dot pulses Berry Crush ring outward (300ms)
- Notification (push + in-app banner): "Khánh đang gần tới — chuẩn bị greeting"
- Banner slides down from top + persists 5s
- Haptic light

**Auto check-in moment (user enters geofence polygon):**
- Restaurant icon at end of route bursts: scale 1.0→1.3→1.0 spring + Berry Crush ring expand (450ms)
- 6 sparkles emanate from restaurant icon
- "✓ Bạn đã check-in" toast slides down (auto-dismiss 3s)
- Trust event ledger update visible: small `+2` floats up from icon (400ms fade up)
- Haptic medium impact

**Running late detection (Mate stationary >5km, >15 min late):**
- Mate avatar dot pulses amber → red
- Status pill turns amber: "Khánh đang trễ ⚠"
- Banner appears with options: [Nhắn cho Khánh] [Hỏi xem có gì xảy ra]

**Both checked in moment:**
- Route shows both avatar dots meeting at restaurant icon
- Larger sparkle burst (10 sparkles)
- "Cả hai đã có mặt — chúc ăn ngon ✨" celebration toast
- Trust hint footer updates: `+2 Trust điểm đã ghi nhận ✓`

**Cancel / Báo trễ / Nhắn Mate buttons:**
- Sticky footer with 3 action buttons (always visible)
- Standard scale-on-tap

**Reduce-motion:**
- Skip avatar dot smooth interpolation — render at current position with snap
- Keep status update fades (functional)

---

### Anonymous Review — Screen 22

**Copy:**
- Top: `SAU BUỔI HẸN · ẨN DANH`
- Headline: `Khánh thế nào nhỉ?`
- Body: `Cả hai sẽ thấy review cùng lúc. Trung thực giúp ĂnMates lọc người tử tế.`
- Mate context: `Khánh, 26 · Tiệm mì Ramen Q1 · 19:30 T7`
- Chips (multi-select): 💬 Dễ tám / ⏰ Đúng giờ / 🎵 Cùng vibe / 🙃 Hơi gượng / 🚀 Sẵn ăn miết / 🍴 Sành ăn
- Section: `VIẾT THÊM CHO KHÁNH (TÙY CHỌN)` + freeform text (≤280 chars)
- Optional venue review section: `NHẬN XÉT QUÁN (TÙY CHỌN · +3 ĐIỂM)` + text + 📷 +Hình / 🎬 +Video
- Footer: `Báo cáo` (link) / `Gửi đánh giá →` (primary CTA)

**Concept:** "Reflective and gentle — review feels constructive, double-blind reveal builds trust. Photo attach has reward feel (+3 Trust). Submitting feels like sealing a private envelope."

**Entrance:**
- Header + Mate context fade in (200ms)
- Chips cascade in 3×2 grid (50ms stagger)
- Freeform text section fades in
- Venue review section fades in last (with subtle gold "+3 ĐIỂM" badge twinkle)

**Chip multi-select:**
- Tap: chip bg fills with category color (positive = green-tinted, cautious 🙃 = amber-tinted)
- Subtle scale 0.95→1.05→1.0 (200ms spring) per tap
- Selected chips group at top, deselected chips at bottom (re-flow with 250ms layout animation)

**Freeform text:**
- Character counter updates live (250/280 → red if over)
- No autofocus (let user choose to write)

**Venue review media (+3 Trust):**
- 📷 +Hình button: subtle gold tint (suggests reward)
- Tap: camera or gallery picker
- Selected media: appears as thumbnail with subtle ✨ sparkle on first add (acknowledging the +3 trust)
- Up to 3 photos + 1 video

**`Báo cáo` link:**
- Tap: opens Screen N3 (Block/Report) modal — feeds into safety pipeline + potential Trust -15

**`Gửi đánh giá →` CTA:**
- Disabled until at least one chip selected
- On tap: AppLoader.overlay "Đang gửi đánh giá..."
- On success:
  - Page transitions to a "submitted" state:
    - Headline changes to "Đã gửi đánh giá ✓"
    - Sub: "Đợi Khánh review xong — review của hai bạn sẽ lộ cùng lúc"
    - If user submitted media: extra success toast `+3 Trust điểm cho review chi tiết ✨` with sparkle burst
    - Countdown to reveal: "Lộ review trong 47:59 (hoặc khi Khánh review xong)"
  - Reveal state will be a separate screen / modal when both submit

**Reveal moment (when both have submitted):**
- Push notification: "Review của Khánh đã sẵn sàng — bóc xem nhé"
- Tap → reveal animation: card flips 180° with sparkle burst → shows both reviews side by side

---

### Profile Dashboard — Screens 23, 24

> **⚠ Phase 1 conflict:** Screen 23 design shows IAP UI (Gold member badge, Plus/Gold/Ultimate tier cards) and Screen 24 shows `Giới hạn 1 phòng chat`. Phase 1 strategy is Ultimate-for-all (no IAP, no gating). FE agent must:
> - Screen 23: replace the entire `GÓI ĂN MATES` section with the Screen N7 "Coming Soon" placeholder card
> - Screen 24: remove the "Giới hạn 1 phòng chat" copy from the threshold display
> - Keep all other elements visual-faithful to design

---

#### Screen 23 — Tab Mình (Profile)

**Copy:**
- Top: `HỒ SƠ CỦA TÔI`
- Profile block: avatar + `Vy, 24 · Designer · Quận 1 · 🇻🇳 · ✓ Verified` (REMOVE: `👑 Gold member` for Phase 1)
- Derived display: `CUNG Song Tử / MỆNH Bạch Lạp Kim / THẦN SỐ Tự do` (if user toggle ON)
- Stats: `Buổi ăn · Wishlist · Best Mates`
- Album: `ALBUM ĂN UỐNG · HERO` (grid of past meal photos)
- Gu ẩm thực tags: 🌶️ Cay 3 / 🥩 Beef / 🦐 Hải sản / 🚫 Không hành / ☕ Cafe đen / 🍣 Sushi
- **Phase 1 swap:** entire `GÓI ĂN MATES` section → use N7 Coming Soon card
- Bottom nav

**Concept:** "Personal page feels owned and curated — stats invite drill-down, album is visual memory, derived horoscope is private brag."

**Entrance:**
- Profile block fades in + avatar scale 0.85→1.0 spring (300ms)
- Verified badge ✓ scale-in (200ms after)
- Stats row fades in with numbers ticking from 0 to current value (500ms ease-out)
- Album grid: thumbnails cascade fade in (top-left → bottom-right, 60ms stagger)
- Derived horoscope cards fade in
- Taste chips cascade
- Coming Soon card (N7) fades in last

**Stats card tap (Buổi ăn / Wishlist / Best Mates):**
- Card scales 0.97 + bg tint flash (Mint Cream) → navigate to relevant detail screen
- E.g., Buổi ăn → list of past completed bookings; Wishlist → Screen 10b

**Album photo tap:**
- Shared-element transition: photo expands to fullscreen viewer (350ms ease-in-out)
- Swipe through other album photos

**Coming Soon card (N7) — see Screen N7 spec below**

---

#### Screen 24 — Trust dashboard

**Copy:**
- Top: `TRUST SCORE · Hồ sơ uy tín`
- Score: large `__ / 100 ĐIỂM` + badge `✨ PERFECT MATE · Top 8%` (if ≥90)
- Threshold display: `NGƯỠNG UY TÍN · BẠN`
  - Perfect: `ưu tiên matching`
  - Trusted: (no special perk text in Phase 1 — show only labels)
  - **Phase 1 swap:** REMOVE the `Giới hạn 1 phòng chat` copy under <80 — replace with `Khuyến khích cải thiện qua hành vi tích cực`
- Recent activity ledger:
  - `Check-in đúng giờ · Ramen Q1 · hôm qua · +2`
  - `Review chi tiết kèm hình · +3`
  - `Khánh đánh giá 5★ · lịch sự · +1`
  - `Trễ 18′ · tắc đường (miễn 1 phần) · -2`
- Bottom nav

**Concept:** "Trust dashboard is a quiet badge of pride — score has gravitas, ledger feels transparent (here's exactly what affected your score)."

**Entrance:**
```
t=0       page fades in
t=200ms   "TRUST SCORE" title fades
t=400ms   score number ticks from 0 → current (800ms ease-out) — feels weighty
t=700ms   if ≥90: PERFECT MATE badge scales in + 4 sparkles burst around it (twinkle 1.2s)
t=1000ms  threshold display fades in (3 ranges visible, current range highlighted with Berry Crush border)
t=1300ms  recent activity ledger entries cascade fade in (top to bottom, 100ms stagger)
t=1300ms  each ledger delta value (`+2`, `+3`, `-2`) ticks in (100ms after row appears)
```

**Score circle / display:**
- Outer ring shows score percentage visually (similar to Vibe ring)
- Score number is large (~64px), Plus Jakarta Sans Bold
- Color logic:
  - ≥90: Gold #FFD700 tinted text
  - 80-89: Wisteria
  - <80: Caviar with subtle amber accent

**Score change moment (real-time, when user has new trust event):**
- Score number ticks to new value with scale punch (250ms)
- Score ring fills/recedes to new percentage (400ms ease-out)
- New ledger entry slides in at top of activity list (300ms ease-out)
- Delta number (`+2` green or `-3` red) floats up + fades (400ms)
- If gained: 2 small sparkles twinkle near score
- If lost: subtle screen shake (very minor) + amber pulse on ring

**Threshold display:**
- 3 horizontal segments (Perfect / Trusted / Limited)
- Current range highlighted with thicker border + Berry Crush text
- Tap on segment: shows tooltip with criteria

**Ledger entry tap:**
- Row expands inline (300ms) showing more detail (event timestamp, related booking link)
- Tap again to collapse

**Auto-recovery moment (when +2 per 30-day clean fires):**
- Push notification "Bạn vừa nhận +2 trust điểm vì giữ vibe tốt 30 ngày liền ✨"
- On opening dashboard: sparkle entrance animation on score, ledger shows new entry

---

### Supplementary Screens — N1 through N7 (designs PENDING from design team)

> These 7 screens lack reference designs (per handoff §A "Màn cần thiết kế bổ sung"). Spec below uses standard patterns; refine when designs deliver.

#### Screen N1 — Profile edit

**Pattern:** Standard form screen with reorderable photo grid + editable fields.

**Animations:**
- Entry: slide up from bottom (modal-style, 350ms)
- Photo drag-reorder: long-press → photo lifts (scale 1.05 + shadow elevate + haptic light) → drag to new position → other photos shift (300ms ease)
- Tag chip add/remove: same scale-pop as Screen 09a
- Save button: AppLoader.overlay → success toast → dismiss modal
- Cancel: confirmation modal if unsaved changes

---

#### Screen N2 — Settings

**Pattern:** Standard list of toggles + grouped sections.

**Animations:**
- Entry: slide in from right (navigation, 300ms)
- Toggle switch: standard scale + color morph (180ms)
- Section row tap (e.g., "Notifications" → subscreen): row bg flash + slide-in subscreen
- Logout button: confirmation modal with destructive-style button (red bg)

---

#### Screen N3 — Block / Report

**Pattern:** Modal with category list + evidence upload + 2-step confirm.

**Animations:**
- Entry: modal slides up from bottom + backdrop fade in (300ms)
- Category selection: row tap → checkmark scales in + row bg highlights (200ms)
- Evidence upload: thumbnails appear with AppLoader.topBar showing per-file upload progress (determinate mode)
- Submit: 2-step confirm modal "Chắc chắn báo cáo?" → AppLoader.overlay → success toast "Đã gửi báo cáo cho T&S · cảm ơn bạn"
- Block 2-step: similar pattern with destructive-style buttons

---

#### Screen N4 — Cancel booking (with Trust penalty preview)

**Pattern:** Modal showing penalty preview prominently before confirm.

**Animations:**
- Entry: slide up modal
- Penalty preview displays prominently: e.g., "Huỷ bây giờ: Trust −5 điểm" with red tint + subtle pulse
- Reason input (optional)
- Confirm button: red destructive bg, requires longer tap (long-press 600ms?) or 2-step "Tôi hiểu, huỷ kèo" to prevent accidental cancel
- On confirm: AppLoader.overlay → success modal "Đã huỷ kèo · Mate đã được thông báo"

---

#### Screen N5 — Delete account + export

**Pattern:** Multi-step confirmation flow with export option.

**Animations:**
- Step 1: warning screen with consequences listed (no special animation, gravitas via typography)
- Step 2: export option toggle ON by default → AppLoader.overlay "Đang chuẩn bị xuất dữ liệu..."
- Step 3: final confirm with 14-day window note + download link for export zip
- Confirm button: red destructive + requires typing username or "XÁC NHẬN XOÁ" to enable
- On confirm: subtle fade-out to login screen with toast "Tài khoản đã ngưng · sẽ xoá hoàn toàn sau 14 ngày"

---

#### Screen N6 — Letter composer

**Pattern:** Multi-section composer with preview.

**Animations:**
- Entry: slide up modal
- Receiver picker: search + select with chip-pop selection (Screen 09a pattern)
- Restaurant picker: list with same pattern
- Date picker: calendar grid (Screen 17 pattern, reduced)
- Mood chip selection: multi-select with scale-pop
- Freeform text: live character count
- P.S. line: smaller field with italic placeholder
- Preview button: opens Screen 19-style postcard preview as bottom sheet (350ms ease-out) — user can see how it'll look
- Send button: AppLoader.overlay + envelope-fly-away animation (postcard scales down + slides up off screen, 600ms) → success toast "Đã gửi lá thư ✨"

---

#### Screen N7 — Coming Soon · Gói ĂnMates (placeholder)

**Pattern:** Single card with email opt-in modal.

**Layout in Tab Mình:**
```
GÓI ĂN MATES
✨ Đang mở toàn bộ tính năng miễn phí trong giai đoạn ra mắt.
   Các gói VIP sẽ xuất hiện trong những bản cập nhật sắp tới.

[Đăng ký nhận tin khi gói ra mắt]
```

**Animations:**
- Card fades in with subtle Wisteria → Berry Crush gradient bg (250ms)
- ✨ sparkle twinkle continuously on the eyebrow
- CTA button has gentle pulse (3s interval)
- Tap CTA: email input modal slides up from bottom (300ms)
  - Email field + submit button
  - Submit: AppLoader.overlay → success toast "Đã đăng ký · bạn sẽ là người đầu tiên biết khi gói ra mắt 🎉" → modal dismisses
  - On error: shake + inline error message

---

> ℹ Note: Full Screen 21 (Live Tracking) animation spec is in `### Day-of Flow — Screens 20, 21` above. Earlier short summary has been folded into that section.

---

## Animation Timing

| Moment | Duration | Easing |
|---|---|---|
| Page transition | 300ms | ease-in-out |
| Modal/overlay fade | 250ms | ease-out |
| Button press feedback | 100ms | linear |
| Toast | 3000ms (visible) | — |
| Vibe ring update | 600ms | ease-out |
| Match celebration | 1500ms full sequence | spring |
| Letter open | 900ms (envelope flip + content rise) | spring |

---

## Accessibility (Phase 1 minimum)

- Dynamic type support (respect OS font size)
- Screen-reader label on every interactive element
- Contrast ratio ≥ WCAG AA (4.5:1)
- Don't rely on color alone (always pair with icon + text)
- Min body 14px

---

## Naming Conventions (per handoff §A.3)

| Layer | Convention | Example |
|---|---|---|
| Screen component | `Screen<NN><Name>` | `Screen11RestaurantDetail` |
| Route path | `/<feature>/<sub>` | `/restaurant/:id`, `/match/:id/chat` |
| Asset folder | `assets/screens/<NN>/` | `assets/screens/11/hero-ramen.jpg` |
| Snapshot test | `__snapshots__/<NN>_<state>.png` | `__snapshots__/11_default.png` |

`<NN>` always zero-padded 2-digit matching screen index in design-reference-index.md.

---

This design system is locked. Deviations require Brand system update + architect approval. All screens trace back to `plan/lastest/design/<file>.html` references.


---

## Hệ v2 — Explore direction (2026-09-02)

> **Source of truth:** project Claude Design `fa249917-433c-4553-b1ae-8909eed150ed`
> ("Mobile app design planning") → file **`AnMates.dc.html`**, screen `home`
> (Canvas frame B1 "Explore · hero 3D collage"). Bản copy local: `plan/design/AnMates.dc.html`.
> **`Canvas.dc.html` chỉ là bảng index** — pin frame qua `<dc-import pin-screen="…">`, không chứa UI.

Code: `anmates_flutter/lib/theme/app_theme_v2.dart` (`AppColorsV2` / `AppGradientsV2` /
`AppShadowsV2` / `AppTextV2`). **Không import lẫn với `app_theme.dart` v1.**

### Color Tokens v2

| Name | Hex | Usage |
|---|---|---|
| **Wisteria** | `#8B5CF6` | Token nhấn chính — CTA phụ, active state, số liệu |
| Wisteria Tint | `#F1EBFE` | Nền chip Trust, nền icon thông báo |
| Violet Glow | `#A855F7` | Lobe trên của nền aurora |
| **Blue** | `#3B82F0` | Nửa còn lại của gradient CTA |
| Blue Deep | `#1F5BE0` | Lobe dưới của nền aurora |
| Cyan | `#28D3F5` | Lobe trái-trên của nền aurora |
| Caviar Ink | `#121212` | Chữ chính, card đen Local Mates *(giữ nguyên từ v1)* |
| Canvas | `#F6F4FF` | Nền màn |
| **Alert Red** | `#FF3B30` | **Chỉ dùng cho khẩn cấp** — chấm chưa đọc, tag "1H" |

Bed pastel xoay vòng sau art: tile `#F2EEFF` `#EAF4FF` `#FFF3E8` `#EFF8F1`;
card thêm `#FDF0F4`.

**Khác v1 thế nào:** v1 nhấn bằng Berry `#B8336A` + Ocean `#534BA8` trên nền Mint `#F1FFF8`.
v2 bỏ hẳn Berry/Ocean/Mint, chuyển sang Wisteria + gradient xanh trên nền aurora 4 lobe.
Wisteria ở v1 là `#C490D1` (nhạt, chỉ để fill vibe meter) — **v2 đổi giá trị thành `#8B5CF6`**
và nâng lên làm token nhấn chính. Đây là điểm dễ nhầm nhất giữa hai hệ.

### Typography v2

Một font duy nhất: **Be Vietnam Pro** (400/500/600/700/800), phân vai bằng weight + size.
Không còn tách Plus Jakarta Sans cho display như v1.

| Role | Size | Weight | Letter-spacing |
|---|---|---|---|
| Section header | 19 | 800 | −0.025em |
| Hero number | 62 | 800 | −0.05em, gradient blue→wisteria qua `ShaderMask` |
| CTA | 16 | 700 | — |
| Card title | 13 | 800 | −0.015em |
| Tile title | 12.5 | 700 | — |
| Meta / caption | 10.5 | 500 | — |
| Nav label | 9 | 700 | — |

### Nền aurora

4 radial lobe ellipse + grain tile 120×120 (`assets/food/v2_grain.png`).
Flow B–D chạy nhạt hơn 30% (`washOpacity 0.56` / `grainOpacity 0.18`) để card + glass đọc được.
Xem `lib/widgets/v2/aurora_background.dart`.

### Gotcha khi code v2

- **Drop shadow cho art cutout phải theo alpha, không dùng `BoxShadow`.** `BoxShadow` đổ bóng
  theo hình chữ nhật của widget → hiện slab xám sau mỗi PNG trong suốt. Dùng `_DropShadowImage`
  trong `food_art.dart` (bản sao ảnh tô màu qua `ColorFilter.mode(..., srcATop)` + `ImageFiltered`).
- **`DesignSync.get_file` cắt binary ở 256 KiB.** `hotpot.png` + `bbq.png` của design vượt ngưỡng
  → hỏng. 4 render còn lại (burger/ramen/coffee/beer) + grain lấy được nguyên vẹn, đã lưu
  `assets/food/v2_*.png`. Hai món thiếu tạm dùng `lau.png`/`nuong.png` (có nền vẽ, không phải
  cutout) → `FoodArtRef(cutout: false)` để clip bo góc thay vì thả bóng.
- Flutter **không có SVG path parser** built-in → 4 glyph nav vẽ tay bằng Canvas
  (`glass_nav_bar.dart`), không port thẳng `NAV_PATHS`.


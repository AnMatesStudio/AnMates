import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';

/// Seed content for the v2 design, transcribed from the Claude Design project
/// "Mobile app design planning" (`AnMates.dc.html`). Swap for API models later —
/// every screen reads through these tables, nothing hardcodes strings inline.

/// A string carrying both languages, mirroring the design's `{vi:…, en:…}` pairs.
/// Call it with the current language flag: `title(en)`.
class T {
  const T(this.vi, this.en);

  final String vi;
  final String en;

  String call(bool en_) => en_ ? en : vi;
}

/// ── Food art ────────────────────────────────────────────────────────────────
/// The design's six transparent 3D renders, shipped in `assets/v2/`.
class A {
  static const hotpot = 'assets/v2/hotpot.png';
  static const bbq = 'assets/v2/bbq.png';
  static const burger = 'assets/v2/burger.png';
  static const ramen = 'assets/v2/ramen.png';
  static const coffee = 'assets/v2/coffee.png';
  static const beer = 'assets/v2/beer.png';

  static const grain = 'assets/v2/grain.png';
  static const avatar = 'assets/v2/avatar-minh.jpg';
}

/// `assets/grain.png` is authored at 260px and tiled at 120 logical px.
const double kGrainSourceSize = 260;
const double kGrainTileSize = 120;

/// Fallback area chips for the filter sheet before the catalogue has loaded.
/// Once venues arrive, `V2State.areaNames` replaces this with the districts
/// actually present in the DB.
const List<String> kAreaNames = [
  'Quận 1', 'Quận 3', 'Bình Thạnh', 'Phú Nhuận', 'Quận 7', 'Thảo Điền',
];

const List<T> kCategories = [
  T('Lẩu', 'Hotpot'), T('Nướng', 'BBQ'), T('Mì phở', 'Noodles'),
  T('Hải sản', 'Seafood'), T('Cà phê', 'Coffee'), T('Bia hơi', 'Beer'),
  T('Tráng miệng', 'Dessert'),
];

/// ── Venues ──────────────────────────────────────────────────────────────────

class SummaryLine {
  const SummaryLine(this.key, this.value, {this.color});

  final T key;
  final T value;
  final Color? color;
}

class Place {
  const Place({
    required this.img,
    required this.name,
    required this.dist,
    required this.wanting,
    required this.group,
    required this.meta,
    required this.reviews,
    required this.lines,
    this.photoUrl,
  });

  final String img;
  final String name;
  final String dist;
  final int wanting;
  final T group;
  final T meta;
  final T reviews;
  final List<SummaryLine> lines;

  /// A real stored photo (see `ApiClient.venuePhotoUrl`), when the venue has
  /// one — null falls back to the [img] 3D render. Never a dead external URL:
  /// the API only ever returns how many photos it actually holds bytes for.
  final String? photoUrl;
}

class Venue {
  const Venue({
    required this.img, required this.name, required this.area,
    required this.dist, required this.price, required this.rating, required this.open,
    this.photoUrl,
  });

  final String img;
  final String name;

  /// Human district label, e.g. `Quận 1` — resolved from `restaurants.district`
  /// by `districtLabel()` in v2_venue_mapper.dart.
  final String area;

  /// `2,4 km` — empty when the listing was fetched without a location.
  final String dist;
  final String price;
  final String rating;

  /// Real demand signal from the API's `want_count`; 0 when nobody has wished
  /// for this venue's food yet.
  final int open;

  /// A real stored photo, when the venue has one — null falls back to [img].
  final String? photoUrl;

  String get tileMeta => dist.isEmpty ? price : '$dist · $price';
  String get cardWhere => dist.isEmpty ? area : '$area · $dist';
}

/// ── Mates ───────────────────────────────────────────────────────────────────
/// Built from `GET /api/v1/matches` (a real wishlist-overlap ranking) by
/// `mateFromCandidate()` in v2_mate_mapper.dart. No sample roster: an empty
/// list means the account genuinely has no candidates yet.

class Mate {
  const Mate({
    required this.userId, required this.name, required this.img,
    required this.overlapFoods, required this.tags, required this.match,
    this.age,
  });

  final String userId;
  final String name;

  /// Real age in years from the candidate's birth_date — null when unset,
  /// never guessed.
  final int? age;
  final String img;

  /// Foods/categories both users are interested in, straight from the API's
  /// `overlap_foods` — this replaces the design's invented "dining intent"
  /// sentence with something actually true.
  final List<String> overlapFoods;

  /// The candidate's own food/vibe tags (real onboarding data).
  final List<String> tags;

  /// Real taste-overlap percentage (API's `score`), not a fabricated rating.
  final int match;
}

/// ── Onboarding ──────────────────────────────────────────────────────────────

class Budget {
  const Budget(this.name, this.desc, this.img);

  final T name;
  final T desc;
  final String img;
}

const List<Budget> kBudgets = [
  Budget(T('Hệ ấm bụng', 'Comfort tier'), T('dưới 50k, ăn no là vui', 'under 50k, full is happy'), A.ramen),
  Budget(T('Hệ đi đều', 'Steady tier'), T('50–150k, quán quen mỗi tuần', '50–150k, a weekly regular'), A.coffee),
  Budget(T('Hệ đại tiệc', 'Big-feast tier'), T('150–350k, lẩu nướng cuối tuần', '150–350k, weekend hotpot and BBQ'), A.hotpot),
  Budget(T('Hệ chơi lớn', 'All-in tier'), T('trên 350k, quán hot phải thử', 'over 350k, must-try hot spots'), A.beer),
];

class Taste {
  const Taste(this.name, this.emoji);

  final T name;
  final String emoji;
}

const List<Taste> kTastes = [
  Taste(T('Lẩu', 'Hotpot'), '🍲'), Taste(T('Nướng', 'BBQ'), '🍢'),
  Taste(T('Mì trộn', 'Dry noodles'), '🍜'), Taste(T('Hải sản', 'Seafood'), '🦐'),
  Taste(T('Cơm tấm', 'Cơm tấm'), '🍚'), Taste(T('Bún đậu', 'Bún đậu'), '🥢'),
  Taste(T('Chay', 'Vegetarian'), '🥗'), Taste(T('Đồ cay', 'Spicy'), '🌶️'),
  Taste(T('Cà phê', 'Coffee'), '☕'), Taste(T('Bia hơi', 'Draft beer'), '🍺'),
  Taste(T('Trà sữa', 'Bubble tea'), '🧋'), Taste(T('Gà rán', 'Fried chicken'), '🍗'),
  Taste(T('Sushi', 'Sushi'), '🍣'), Taste(T('Dimsum', 'Dim sum'), '🥟'),
  Taste(T('Pizza', 'Pizza'), '🍕'), Taste(T('Ốc', 'Snails'), '🐚'),
  Taste(T('Bò bít tết', 'Steak'), '🥩'), Taste(T('Tráng miệng', 'Dessert'), '🍰'),
  Taste(T('Phở', 'Phở'), '🍲'), Taste(T('Bánh mì', 'Bánh mì'), '🥖'),
];

/// Rows 2 and 4 start further in so the chip grid never lines up into columns.
///
/// The design nudges them *left* (`margin-left:-46px/-62px`), which pulls the
/// first chip half off the screen edge — unreadable and untappable. Offsetting
/// the same rows to the right instead keeps the staggered look and keeps every
/// chip whole.
const List<double> kTasteRowShifts = [0, 46, 0, 62];

/// Height of the canvas frame every v2 metric was drawn against (402 × 874).
/// Screens divide by it to scale their fixed sizes down on shorter phones.
const double kDesignFrameHeight = 874;

/// Orbit ring geometry for onboarding A2, in the design's 354×452 box.
const double kOrbitCx = 177;
const double kOrbitCy = 226;
const double kOrbitRxMax = 132;

const List<({double r, double alpha})> kOrbits = [
  (r: 92, alpha: 0.34), (r: 136, alpha: 0.26), (r: 182, alpha: 0.18),
];

const List<({String e, double a, double r, double s})> kOrbitIcons = [
  (e: '🍲', a: 8, r: 92, s: 62), (e: '🍢', a: 128, r: 92, s: 56), (e: '☕', a: 246, r: 92, s: 52),
  (e: '🍜', a: 46, r: 138, s: 66), (e: '🦐', a: 104, r: 140, s: 54), (e: '🍺', a: 172, r: 138, s: 60),
  (e: '🌶️', a: 218, r: 140, s: 50), (e: '🥟', a: 300, r: 138, s: 58), (e: '🍗', a: 340, r: 140, s: 52),
  (e: '🍣', a: 22, r: 186, s: 48), (e: '🧋', a: 76, r: 188, s: 54), (e: '🥩', a: 148, r: 186, s: 46),
  (e: '🍰', a: 200, r: 188, s: 50), (e: '🥖', a: 268, r: 186, s: 44), (e: '🍕', a: 322, r: 188, s: 48),
];

const List<({double a, double r, double s, double o})> kOrbitDots = [
  (a: 62, r: 92, s: 7, o: 1), (a: 196, r: 92, s: 5, o: 0.8), (a: 286, r: 92, s: 6, o: 1),
  (a: 12, r: 138, s: 5, o: 0.85), (a: 250, r: 138, s: 7, o: 1),
  (a: 118, r: 186, s: 5, o: 0.75), (a: 234, r: 186, s: 6, o: 1),
];

const List<({double a, double r, double s, double alpha})> kSparkles = [
  (a: 34, r: 112, s: 11, alpha: 0.9), (a: 158, r: 116, s: 9, alpha: 0.75),
  (a: 210, r: 164, s: 13, alpha: 0.85), (a: 292, r: 118, s: 10, alpha: 0.8),
  (a: 352, r: 166, s: 12, alpha: 0.7),
];

/// ── Filters ─────────────────────────────────────────────────────────────────

const List<T> kVibeTags = [
  T('Ồn vui', 'Lively'), T('Yên tĩnh', 'Quiet'), T('Ăn nhanh về', 'Eat and run'),
  T('Ngồi lâu', 'Long sit'), T('Săn deal', 'Deal hunter'),
];

const List<String> kPrices = ['<50k', '50–150k', '150–350k', '>350k'];

/// ── Rate ────────────────────────────────────────────────────────────────────

const List<T> kStarLabels = [
  T('Không ổn — cần gắn tag để giải thích', 'Not okay — please tag what went wrong'),
  T('Hơi khó chịu', 'A bit uncomfortable'),
  T('Bình thường, không đổi điểm', 'Fine, nothing changes'),
  T('Bữa ăn vui, ăn lại được', 'Good meal, would eat again'),
  T('Mate xịn — đúng giờ, chia bill sòng phẳng', 'Great mate — on time, split fairly'),
];

const List<T> kRateTags = [
  T('Đúng giờ', 'On time'), T('Chia bill sòng phẳng', 'Split fairly'),
  T('Dễ nói chuyện', 'Easy to talk to'), T('Gợi ý quán hay', 'Good venue picks'),
  T('Tới muộn', 'Arrived late'), T('Cư xử không ổn', 'Behaved badly'),
];

/// ── Plans ───────────────────────────────────────────────────────────────────

class Tier {
  const Tier({
    required this.name, required this.price, required this.perks,
    required this.bg, required this.fg, required this.body,
    required this.pillBg, required this.pillFg, required this.elevated, this.cta,
  });

  final String name;
  final String price;
  final T perks;
  final Color bg;
  final Color fg;
  final Color body;
  final Color pillBg;
  final Color pillFg;
  final bool elevated;
  final T? cta;
}

final List<Tier> kTiers = [
  Tier(
    name: 'Free', price: '0đ', bg: Colors.white, fg: AppColorsV2.ink,
    body: AppColorsV2.inkA(0.55), pillBg: AppColorsV2.inkA(0.07), pillFg: AppColorsV2.inkA(0.55),
    elevated: false,
    perks: const T('5 phòng chat · Text only', '5 chat rooms · text only'),
  ),
  Tier(
    name: 'Plus', price: '29.000đ', bg: Colors.white, fg: AppColorsV2.ink,
    body: AppColorsV2.inkA(0.55), pillBg: AppColorsV2.wisteriaTint, pillFg: AppColorsV2.wisteria,
    elevated: false,
    perks: const T('10 phòng chat · Ảnh View-Once · Match 3 người/quán',
        '10 chat rooms · view-once photos · match 3 per venue'),
  ),
  Tier(
    name: 'Gold', price: '59.000đ', bg: AppColorsV2.wisteria, fg: Colors.white,
    body: AppColorsV2.whiteA(0.9), pillBg: AppColorsV2.alert, pillFg: Colors.white,
    elevated: true,
    perks: const T('Chat không giới hạn · Voice chat + album cũ',
        'Unlimited chats · voice chat + past albums'),
    cta: const T('Dùng thử 7 ngày', 'Try 7 days free'),
  ),
  Tier(
    name: 'Ultimate', price: '99.000đ', bg: AppColorsV2.ink, fg: Colors.white,
    body: AppColorsV2.whiteA(0.7), pillBg: const Color(0x388B5CF6), pillFg: const Color(0xFFA78BFA),
    elevated: false,
    perks: const T('Lọc bể match tinh anh · Không xếp hàng Peak Hour',
        'Elite match pool filter · no peak-hour queue'),
  ),
];

/// ── Profile ─────────────────────────────────────────────────────────────────

const List<({String img, double left, double top, double size, double rot})> kMeStickers = [
  (img: A.bbq, left: 38, top: 128, size: 68, rot: -11),
  (img: A.ramen, left: 272, top: 118, size: 74, rot: 9),
  (img: A.coffee, left: 26, top: 178, size: 58, rot: 7),
  (img: A.beer, left: 292, top: 174, size: 60, rot: -8),
];

/// No seeded history — a real user's own typed searches would go here if
/// this were persisted; until then, empty is the honest state.
const List<String> kRecentSearches = [];

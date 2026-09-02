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
  });

  final String img;
  final String name;
  final String dist;
  final int wanting;
  final T group;
  final T meta;
  final T reviews;
  final List<SummaryLine> lines;
}

const List<Place> kPlaces = [
  Place(
    img: A.hotpot, name: 'Lẩu Bò Sáu Râu', dist: '1,2 km', wanting: 5,
    group: T('4 người', '4 people'),
    meta: T('Quận 1 · lẩu · 180–260k/người', 'District 1 · hotpot · 180–260k pp'),
    reviews: T('tổng hợp từ 412 review', 'distilled from 412 reviews'),
    lines: [
      SummaryLine(T('Món vedette', 'Signature'), T('Lẩu bò gân sụn, bánh mì chiên tỏi', 'Beef tendon hotpot, garlic toast')),
      SummaryLine(T('Vibe quán', 'Vibe'), T('Ồn vui, quán vỉa hè, hợp nhóm 4', 'Loud and cheerful, street-side, best for 4')),
      SummaryLine(T('Khoảng giá', 'Price'), T('180–260k/người', '180–260k per person')),
      SummaryLine(T('Điểm trừ', 'Cons'), T('Đợi bàn ~20 phút sau 19:00', '~20 min wait after 19:00'), color: AppColorsV2.alert),
      SummaryLine(T('Chia bill', 'Split'), T('Dễ chia đều, nồi tính chung', 'Easy even split, pot billed to the table')),
    ],
  ),
  Place(
    img: A.bbq, name: 'Nướng Mỡ Chài Cô Ba', dist: '800 m', wanting: 3,
    group: T('3–4 người', '3–4 people'),
    meta: T('Quận 3 · nướng · 150–220k/người', 'District 3 · BBQ · 150–220k pp'),
    reviews: T('tổng hợp từ 268 review', 'distilled from 268 reviews'),
    lines: [
      SummaryLine(T('Món vedette', 'Signature'), T('Mỡ chài nướng, ba rọi sốt cay', 'Caul-fat pork, spicy pork belly')),
      SummaryLine(T('Vibe quán', 'Vibe'), T('Nhạc lớn, đông sinh viên, hợp gom kèo', 'Loud music, student crowd, made for group deals')),
      SummaryLine(T('Khoảng giá', 'Price'), T('150–220k/người', '150–220k per person')),
      SummaryLine(T('Điểm trừ', 'Cons'), T('Khói nhiều, về là phải giặt áo', 'Very smoky — wash your shirt after'), color: AppColorsV2.alert),
      SummaryLine(T('Chia bill', 'Split'), T('Tính theo vỉ, dễ bóc tách từng món', 'Billed per tray, easy to itemise')),
    ],
  ),
  Place(
    img: A.ramen, name: 'Mì Trộn Bà Tám', dist: '2,4 km', wanting: 2,
    group: T('2 người', '2 people'),
    meta: T('Bình Thạnh · mì · 45–70k/người', 'Binh Thanh · noodles · 45–70k pp'),
    reviews: T('tổng hợp từ 903 review', 'distilled from 903 reviews'),
    lines: [
      SummaryLine(T('Món vedette', 'Signature'), T('Mì trộn tóp mỡ, trứng lòng đào', 'Dry noodles with pork crackling, soft egg')),
      SummaryLine(T('Vibe quán', 'Vibe'), T('Nhỏ, nhanh, hợp ăn một mình rồi về', 'Small and fast, fine to eat solo')),
      SummaryLine(T('Khoảng giá', 'Price'), T('45–70k/người', '45–70k per person')),
      SummaryLine(T('Điểm trừ', 'Cons'), T('Chỗ ngồi chật, không máy lạnh', 'Cramped seating, no aircon'), color: AppColorsV2.alert),
      SummaryLine(T('Chia bill', 'Split'), T('Mỗi người một tô, chia đều là xong', 'One bowl each — even split works')),
    ],
  ),
  Place(
    img: A.burger, name: 'Bò Nướng Tảng Bảy', dist: '1,6 km', wanting: 4,
    group: T('4 người', '4 people'),
    meta: T('Quận 1 · bò nướng · 200–300k/người', 'District 1 · grilled beef · 200–300k pp'),
    reviews: T('tổng hợp từ 176 review', 'distilled from 176 reviews'),
    lines: [
      SummaryLine(T('Món vedette', 'Signature'), T('Tảng bò nướng tiêu xanh, khoai lăn bơ', 'Green-pepper beef slab, buttered potatoes')),
      SummaryLine(T('Vibe quán', 'Vibe'), T('Máy lạnh, bàn rộng, nói chuyện được', 'Aircon, wide tables, easy to talk')),
      SummaryLine(T('Khoảng giá', 'Price'), T('200–300k/người', '200–300k per person')),
      SummaryLine(T('Điểm trừ', 'Cons'), T('Phải đặt bàn trước cuối tuần', 'Weekends need a booking'), color: AppColorsV2.alert),
      SummaryLine(T('Chia bill', 'Split'), T('Tảng tính chung, nước tính riêng', 'Slab shared, drinks itemised')),
    ],
  ),
  Place(
    img: A.coffee, name: 'Cà Phê Muối Cô Hạnh', dist: '900 m', wanting: 2,
    group: T('2 người', '2 people'),
    meta: T('Phú Nhuận · cà phê · 35–60k/người', 'Phu Nhuan · coffee · 35–60k pp'),
    reviews: T('tổng hợp từ 521 review', 'distilled from 521 reviews'),
    lines: [
      SummaryLine(T('Món vedette', 'Signature'), T('Cà phê muối, bánh flan nhà làm', 'Salt coffee, house flan')),
      SummaryLine(T('Vibe quán', 'Vibe'), T('Ghế nhựa vỉa hè, ngồi lâu không ai nhắc', 'Plastic chairs, nobody rushes you')),
      SummaryLine(T('Khoảng giá', 'Price'), T('35–60k/người', '35–60k per person')),
      SummaryLine(T('Điểm trừ', 'Cons'), T('Hết bánh flan sau 20:00', 'Flan sells out after 20:00'), color: AppColorsV2.alert),
      SummaryLine(T('Chia bill', 'Split'), T('Mỗi người một ly, chia đều', 'One cup each, even split')),
    ],
  ),
  Place(
    img: A.beer, name: 'Bia Hơi Ngã Sáu', dist: '3,1 km', wanting: 6,
    group: T('5–6 người', '5–6 people'),
    meta: T('Quận 7 · bia hơi · 120–180k/người', 'District 7 · draft beer · 120–180k pp'),
    reviews: T('tổng hợp từ 340 review', 'distilled from 340 reviews'),
    lines: [
      SummaryLine(T('Món vedette', 'Signature'), T('Bia hơi tươi, nem chua nướng', 'Fresh draft, grilled fermented pork')),
      SummaryLine(T('Vibe quán', 'Vibe'), T('Rất ồn, bàn dài, hợp nhóm 6', 'Very loud, long tables, best for 6')),
      SummaryLine(T('Khoảng giá', 'Price'), T('120–180k/người', '120–180k per person')),
      SummaryLine(T('Điểm trừ', 'Cons'), T('Không phù hợp nếu bạn không uống', 'Not for non-drinkers'), color: AppColorsV2.alert),
      SummaryLine(T('Chia bill', 'Split'), T('Đếm ly riêng, đồ ăn chia đều', 'Glasses counted, food split evenly')),
    ],
  ),
];

class Venue {
  const Venue({
    required this.img, required this.name, required this.district,
    required this.dist, required this.price, required this.rating, required this.open,
  });

  final String img;
  final String name;
  final int district;
  final String dist;
  final String price;
  final String rating;
  final int open;

  String get area => kAreaNames[district];
  String get tileMeta => '$dist · $price';
  String get cardWhere => '$area · $dist';
}

const List<Venue> kVenues = [
  Venue(img: A.hotpot, name: 'Lẩu Bò Sáu Râu', district: 0, dist: '1,2 km', price: '180–260k', rating: '4.8', open: 5),
  Venue(img: A.bbq, name: 'Nướng Mỡ Chài Cô Ba', district: 1, dist: '800 m', price: '150–220k', rating: '4.6', open: 3),
  Venue(img: A.ramen, name: 'Mì Trộn Bà Tám', district: 2, dist: '2,4 km', price: '45–70k', rating: '4.9', open: 2),
  Venue(img: A.burger, name: 'Bò Nướng Tảng Bảy', district: 0, dist: '1,6 km', price: '200–300k', rating: '4.5', open: 4),
  Venue(img: A.coffee, name: 'Cà Phê Muối Cô Hạnh', district: 3, dist: '900 m', price: '35–60k', rating: '4.7', open: 2),
  Venue(img: A.beer, name: 'Bia Hơi Ngã Sáu', district: 4, dist: '3,1 km', price: '120–180k', rating: '4.4', open: 6),
];

/// ── Mates ───────────────────────────────────────────────────────────────────

class Mate {
  const Mate({
    required this.name, required this.age, required this.img, required this.trust,
    required this.urgency, required this.urgent, required this.meta,
    required this.intent, required this.tags, required this.match,
  });

  final String name;
  final int age;
  final String img;
  final int trust;
  final T urgency;
  final bool urgent;
  final T meta;
  final T intent;
  final List<T> tags;
  final int match;
}

const List<Mate> kMates = [
  Mate(
    name: 'Hạnh', age: 26, img: A.hotpot, trust: 97, urgent: true,
    urgency: T('Cần ăn trong 1H', 'Eating within 1H'),
    meta: T('Quận 1 · hệ đại tiệc 150–350k', 'District 1 · big-feast tier 150–350k'),
    intent: T('Muốn ăn lẩu bò tối nay, chia đều 4 người', 'Wants beef hotpot tonight, even split across 4'),
    tags: [T('Ăn cay được', 'Handles spice'), T('Không rượu bia', 'No alcohol'), T('Về trước 22h', 'Home before 10pm')],
    match: 92,
  ),
  Mate(
    name: 'Duy', age: 29, img: A.bbq, trust: 91, urgent: false,
    urgency: T('Rảnh cuối tuần', 'Free at the weekend'),
    meta: T('Quận 3 · hệ ấm bụng 50–150k', 'District 3 · comfort tier 50–150k'),
    intent: T('Gom 4 người ăn nướng, săn deal combo', 'Gathering 4 for BBQ, hunting a combo deal'),
    tags: [T('Hay đi nướng', 'BBQ regular'), T('Thích quán ồn', 'Likes loud rooms'), T('Đi bằng xe máy', 'Comes by motorbike')],
    match: 84,
  ),
  Mate(
    name: 'Thu', age: 24, img: A.ramen, trust: 88, urgent: false,
    urgency: T('Ăn trưa mai', 'Lunch tomorrow'),
    meta: T('Bình Thạnh · hệ ấm bụng <50k', 'Binh Thanh · under-50k tier'),
    intent: T('Tìm bạn ăn mì trộn trưa, ăn nhanh 40 phút', 'Wants a noodle lunch mate, 40 minutes flat'),
    tags: [T('Ăn nhanh', 'Eats fast'), T('Không cay', 'No spice'), T('Hay review quán', 'Writes reviews')],
    match: 79,
  ),
];

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

/// ── Chat ────────────────────────────────────────────────────────────────────

const List<T> kPrompts = [
  T('Món nào bạn ăn một lần rồi thề không bao giờ ăn lại?', 'What did you eat once and swear off forever?'),
  T('Bún đậu mắm tôm: nghiện hay tránh xa?', 'Fermented shrimp paste: obsession or hard no?'),
  T('Quán ruột của bạn ở đâu, và món gọi mặc định là gì?', 'Your regular spot — and your default order?'),
];

const List<T> kReplies = [
  T('Sầu riêng nướng. Một lần là đủ cho cả đời.', 'Grilled durian. Once was enough for a lifetime.'),
  T('Mình nghiện, tuần ba lần luôn.', 'Obsessed — three times a week.'),
  T('Quán ốc gần nhà, luôn gọi ốc hút với bia lạnh.', 'The ốc place near mine, always ốc hút and a cold beer.'),
  T('Nghe hợp gu ghê, tối nay đi luôn không?', 'Sounds like a match — shall we go tonight?'),
  T('Mình đặt bàn 4 người nha, 19:30 ok chứ?', 'I will book for four — 19:30 work for you?'),
];

const List<T> kMine = [
  T('Mình chọn nồi lẩu bò, gân sụn nhiều nhé.', 'I vote the beef hotpot — extra tendon.'),
  T('Ok luôn, mình cũng hệ đại tiệc.', 'Works for me, same spending tier.'),
  T('Mình đi bằng xe máy, tới sớm 10 phút.', 'Coming by bike, I will be ten minutes early.'),
];

/// ── Bill ────────────────────────────────────────────────────────────────────

const List<({T name, T who, String amount})> kBill = [
  (name: T('Lẩu bò gân sụn (nồi lớn)', 'Beef tendon hotpot (large)'), who: T('chia chung 4 người', 'shared by 4'), amount: '420.000đ'),
  (name: T('Bánh mì chiên tỏi ×4', 'Garlic toast ×4'), who: T('chia chung', 'shared'), amount: '80.000đ'),
  (name: T('Rau nhúng thêm', 'Extra greens'), who: T('Hạnh gọi', 'Hạnh ordered'), amount: '45.000đ'),
  (name: T('Bia ×2', 'Beer ×2'), who: T('Duy · Yuna', 'Duy · Yuna'), amount: '60.000đ'),
  (name: T('Trà đá ×4', 'Iced tea ×4'), who: T('chia chung', 'shared'), amount: '20.000đ'),
];

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

/// ── Trust ───────────────────────────────────────────────────────────────────

const List<({String delta, T label, T when, bool up})> kTrustLog = [
  (delta: '+2', label: T('Check-in đúng giờ · Lẩu Bò Sáu Râu', 'On-time check-in · Lẩu Bò Sáu Râu'), when: T('2 ngày trước', '2 days ago'), up: true),
  (delta: '+3', label: T('Được mate rate 5 sao ẩn', 'Hidden 5-star rating from a mate'), when: T('2 ngày trước', '2 days ago'), up: true),
  (delta: '+2', label: T('Đóng góp review quán', 'Contributed a venue review'), when: T('1 tuần trước', '1 week ago'), up: true),
  (delta: '-2', label: T('Kẹt xe nhưng đang di chuyển', 'Traffic delay, but en route'), when: T('2 tuần trước', '2 weeks ago'), up: false),
  (delta: '-5', label: T('Hủy sát giờ · Nướng Cô Ba', 'Late cancellation · Nướng Cô Ba'), when: T('3 tuần trước', '3 weeks ago'), up: false),
];

/// ── Local Mates ─────────────────────────────────────────────────────────────

const List<({String img, String name, T badge, T meta, T spot})> kLocals = [
  (img: A.ramen, name: 'Ngọc Anh', badge: T('Local 8 năm', '8-yr local'),
   meta: T('Hải Châu · Trust 98 · dẫn 24 chuyến ăn', 'Hai Chau · Trust 98 · 24 food walks'),
   spot: T('Mì Quảng bà Vị lúc 6h sáng, trước khi hết sườn', 'Mì Quảng bà Vị at 6am, before the ribs run out')),
  (img: A.bbq, name: 'Tùng', badge: T('Local sinh ra ở đây', 'Born here'),
   meta: T('An Thượng · Trust 94 · nói được tiếng Anh', 'An Thuong · Trust 94 · speaks English'),
   spot: T('Ốc hút vỉa hè đường Nguyễn Chí Thanh, không menu tiếng Anh', 'Street-side ốc hút on Nguyễn Chí Thanh — no English menu')),
  (img: A.coffee, name: 'Mai', badge: T('Local 5 năm', '5-yr local'),
   meta: T('Sơn Trà · Trust 92 · hệ ấm bụng <50k', 'Son Tra · Trust 92 · under-50k tier'),
   spot: T('Cà phê muối quán nhà, ngồi ghế nhựa nhìn ra biển', 'Salt coffee at a house-front stall, plastic chairs facing the sea')),
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
    perks: const T('5 phòng chat · Text only · Bị Gating khi dưới 85đ', '5 chat rooms · text only · Gating applies below 85'),
  ),
  Tier(
    name: 'Plus', price: '29.000đ', bg: Colors.white, fg: AppColorsV2.ink,
    body: AppColorsV2.inkA(0.55), pillBg: AppColorsV2.wisteriaTint, pillFg: AppColorsV2.wisteria,
    elevated: false,
    perks: const T('10 phòng chat · Trust Booster +10đ · Ảnh View-Once · Match 3 người/quán · Miễn nhiễm Gating',
        '10 chat rooms · Trust Booster +10 · view-once photos · match 3 per venue · Gating immunity'),
  ),
  Tier(
    name: 'Gold', price: '59.000đ', bg: AppColorsV2.wisteria, fg: Colors.white,
    body: AppColorsV2.whiteA(0.9), pillBg: AppColorsV2.alert, pillFg: Colors.white,
    elevated: true,
    perks: const T('Chat không giới hạn · Ân xá điểm về 90đ · Voice chat + album cũ · Vibe-Check nhanh 1.5x',
        'Unlimited chats · amnesty back to 90 · voice chat + past albums · 1.5× faster Vibe Check'),
    cta: const T('Dùng thử 7 ngày', 'Try 7 days free'),
  ),
  Tier(
    name: 'Ultimate', price: '99.000đ', bg: AppColorsV2.ink, fg: Colors.white,
    body: AppColorsV2.whiteA(0.7), pillBg: const Color(0x388B5CF6), pillFg: const Color(0xFFA78BFA),
    elevated: false,
    perks: const T('Đóng băng Trust 100đ tuyệt đối · Lọc bể match tinh anh · Không xếp hàng Peak Hour',
        'Trust frozen at 100 · elite match pool filter · no peak-hour queue'),
  ),
];

/// ── Profile ─────────────────────────────────────────────────────────────────

const List<({String img, String name, String stars, T when, T short})> kVisited = [
  (img: A.hotpot, name: 'Lẩu Bò Sáu Râu', stars: '5.0', when: T('2 ngày', '2 days'), short: T('Lẩu bò', 'Hotpot')),
  (img: A.bbq, name: 'Nướng Mỡ Chài Cô Ba', stars: '4.0', when: T('3 tuần', '3 weeks'), short: T('Nướng', 'BBQ')),
  (img: A.ramen, name: 'Mì Trộn Bà Tám', stars: '5.0', when: T('1 tháng', '1 month'), short: T('Mì trộn', 'Noodles')),
  (img: A.coffee, name: 'Cà Phê Muối Cô Hạnh', stars: '4.5', when: T('1 tháng', '1 month'), short: T('Cà phê', 'Coffee')),
];

const List<({String img, String name, String stars, T meta, T text, List<T> tags, T helpful})> kMyReviews = [
  (img: A.hotpot, name: 'Lẩu Bò Sáu Râu', stars: '5.0',
   meta: T('Quận 1 · đi cùng Hạnh, Duy, Thu', 'District 1 · with Hạnh, Duy, Thu'),
   text: T('Gân sụn mềm đúng ý, nước lẩu đậm mà không mặn. Đi 4 người gọi một nồi lớn là vừa. Nhớ đặt bàn trước 19:00, tụi mình đợi đúng 20 phút.',
       'Tendon done right, broth deep without being salty. One large pot suits four. Book before 19:00 — we waited exactly twenty minutes.'),
   tags: [T('Đáng đợi', 'Worth the wait'), T('Hợp nhóm 4', 'Best for 4')],
   helpful: T('18 người thấy hữu ích', '18 found this helpful')),
  (img: A.ramen, name: 'Mì Trộn Bà Tám', stars: '5.0',
   meta: T('Bình Thạnh · đi cùng Thu', 'Binh Thanh · with Thu'),
   text: T('Tóp mỡ giòn, trứng lòng đào chuẩn. 45k mà ăn no. Chỗ ngồi chật nên ăn nhanh rồi nhường bàn.',
       'Crisp pork crackling, perfect soft egg. Filling at 45k. Cramped, so eat and free the table.'),
   tags: [T('Giá tốt', 'Great value'), T('Ăn nhanh', 'Quick bite')],
   helpful: T('31 người thấy hữu ích', '31 found this helpful')),
  (img: A.bbq, name: 'Nướng Mỡ Chài Cô Ba', stars: '4.0',
   meta: T('Quận 3 · đi cùng Duy', 'District 3 · with Duy'),
   text: T('Món ngon, nhạc to quá nên khó nói chuyện. Khói bám áo thật, đừng mặc đồ đẹp.',
       'Food is good, music too loud to talk over. The smoke does cling — leave the nice shirt at home.'),
   tags: [T('Ồn', 'Loud'), T('Nhiều khói', 'Smoky')],
   helpful: T('9 người thấy hữu ích', '9 found this helpful')),
];

const List<({String img, double left, double top, double size, double rot})> kMeStickers = [
  (img: A.bbq, left: 38, top: 128, size: 68, rot: -11),
  (img: A.ramen, left: 272, top: 118, size: 74, rot: 9),
  (img: A.coffee, left: 26, top: 178, size: 58, rot: 7),
  (img: A.beer, left: 292, top: 174, size: 60, rot: -8),
];

/// ── Notifications ───────────────────────────────────────────────────────────

enum NotifKind { table, vibe, bill, trust }

class NotifV2 {
  const NotifV2({
    required this.emoji, required this.kind, required this.iconBg,
    required this.title, required this.body, required this.when, this.cta, this.go,
  });

  final String emoji;
  final NotifKind kind;
  final Color iconBg;
  final T title;
  final T body;
  final T when;
  final T? cta;
  final String? go;
}

const List<NotifV2> kNotifs = [
  NotifV2(emoji: '🔥', kind: NotifKind.table, iconBg: Color(0xFFFFEDEA), go: 'swipe',
    title: T('Hạnh muốn ăn lẩu trong 1H', 'Hạnh wants hotpot within 1H'),
    body: T('Lẩu Bò Sáu Râu · còn 2 chỗ trong kèo 4 người.', 'Lẩu Bò Sáu Râu · 2 seats left in a table of 4.'),
    when: T('4 phút', '4m'), cta: T('Vào kèo', 'Join table')),
  NotifV2(emoji: '💜', kind: NotifKind.vibe, iconBg: AppColorsV2.wisteriaTint, go: 'chat',
    title: T('Vibe Check đạt 79%', 'Vibe Check hit 79%'),
    body: T('Nút hẹn với Hạnh đã mở khoá. Chốt giờ đi ăn thôi.', 'The scheduling button with Hạnh is unlocked.'),
    when: T('12 phút', '12m'), cta: T('Chốt kèo', 'Confirm')),
  NotifV2(emoji: '🧾', kind: NotifKind.bill, iconBg: Color(0xFFEAF2FE), go: 'bill',
    title: T('Duy đã gửi bill Nướng Cô Ba', 'Duy shared the Nướng Cô Ba bill'),
    body: T('Phần bạn 183.750đ · OCR bóc tách 6/6 món.', 'Your share 183,750đ · OCR parsed 6 of 6 items.'),
    when: T('1 giờ', '1h'), cta: T('Xem bill', 'Open bill')),
  NotifV2(emoji: '✅', kind: NotifKind.trust, iconBg: Color(0xFFEFF8F1), go: 'trust',
    title: T('Trust Score +2', 'Trust Score +2'),
    body: T('Check-in đúng giờ tại Lẩu Bò Sáu Râu đã được xác thực chéo.', 'Your on-time check-in was cross-verified.'),
    when: T('2 ngày', '2d')),
  NotifV2(emoji: '⭐', kind: NotifKind.trust, iconBg: Color(0xFFFFF7E8), go: 'rate',
    title: T('Thu đã rate bữa ăn', 'Thu rated the meal'),
    body: T('Rate của bạn sẽ hiện khi cả hai bên gửi xong.', 'Your rating shows once both of you submit.'),
    when: T('3 ngày', '3d'), cta: T('Rate lại', 'Rate back')),
  NotifV2(emoji: '📍', kind: NotifKind.table, iconBg: Color(0xFFF4F1FD), go: 'local',
    title: T('Ngọc Anh nhận dẫn bạn đi ăn', 'Ngọc Anh will show you around'),
    body: T('Local Mates · Đà Nẵng · Mì Quảng bà Vị lúc 6h sáng.', 'Local Mates · Đà Nẵng · Mì Quảng bà Vị at 6am.'),
    when: T('5 ngày', '5d')),
];

const List<String> kRecentSearches = ['Lẩu bò', 'Quận 3', 'Nướng', 'Cà phê muối'];

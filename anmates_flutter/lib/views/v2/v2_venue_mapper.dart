import '../../services/venue_catalog_service.dart';
import '../../theme/app_theme_v2.dart';
import 'v2_data.dart';

/// Maps a DB row (`GET /api/v1/venues`) onto the two view models the v2 design
/// renders: [Venue] for the feed tiles/cards and [Place] for the detail sheet.
///
/// Everything here is derived from real columns. Fields the design invented and
/// the schema has no answer for (the "AI culinary summary" prose, review
/// counts, group size) are rendered as an honest blank rather than filled with
/// plausible-looking text — see [placeFromCatalog].

/// Vietnamese district labels for the short codes stored in `restaurants.district`.
const Map<String, String> kDistrictNames = {
  'Q1': 'Quận 1',
  'Q2': 'Thủ Đức', // nhập vào Thủ Đức từ 2021
  'Q3': 'Quận 3',
  'Q4': 'Quận 4',
  'Q5': 'Quận 5',
  'Q6': 'Quận 6',
  'Q7': 'Quận 7',
  'Q8': 'Quận 8',
  'Q9': 'Thủ Đức', // nhập vào Thủ Đức từ 2021
  'Q10': 'Quận 10',
  'Q11': 'Quận 11',
  'Q12': 'Quận 12',
  'BT': 'Bình Thạnh',
  'PN': 'Phú Nhuận',
  'GV': 'Gò Vấp',
  'TB': 'Tân Bình',
  'TP': 'Tân Phú',
  'TD': 'Thủ Đức',
  'BTh': 'Bình Thạnh',
};

String districtLabel(String? code) {
  // Không có quận thì nói là không rõ, đừng đoán thành TP.HCM: dữ liệu có
  // quán ở Hà Nội, Bình Dương, Đà Lạt và từng bị dán nhãn sai vì dòng này.
  if (code == null || code.trim().isEmpty) return 'Chưa rõ';
  final c = code.trim();
  return kDistrictNames[c] ?? c;
}

/// `45000` → `45`, in thousands. Whole thousands only — every price the table
/// holds is. The `k` suffix is added by [priceLabel], which carries it once for
/// the whole band (`180–260k`, not `180k–260k`).
String _k(int vnd) {
  final k = vnd / 1000;
  return k == k.roundToDouble() ? '${k.round()}' : k.toStringAsFixed(1);
}

/// `180–260k`, `từ 69k`, or an em dash when the row carries no price at all.
String priceLabel(int? min, int? max, {bool en = false}) {
  if (min == null && max == null) return '—';
  if (min != null && max != null) return '${_k(min)}–${_k(max)}k';
  if (min != null) return en ? 'from ${_k(min)}k' : 'từ ${_k(min)}k';
  return en ? 'up to ${_k(max!)}k' : 'đến ${_k(max!)}k';
}

/// `800 m` / `2,4 km`, matching the design's Vietnamese decimal comma. Empty
/// when the request carried no location, so callers can omit the segment.
String distanceLabel(int? metres) {
  if (metres == null) return '';
  if (metres < 1000) return '$metres m';
  return '${(metres / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// The six 3D renders in `assets/v2/` are the only art the app ships, so a
/// venue's cuisine tags pick the closest one. `restaurants.photos` is not used:
/// the seeded rows carry none and the pipeline rows point at a dead host.
String artForCuisine(List<String> tags) {
  final t = tags.map((e) => e.toLowerCase()).toSet();
  bool any(List<String> keys) => keys.any(t.contains);

  if (any(['lau', 'nam', 'de'])) return A.hotpot;
  if (any(['bbq', 'nuong', 'korean'])) return A.bbq;
  if (any(['pho', 'bun', 'bun_bo', 'bun_cha', 'bun_dau', 'mi', 'ramen', 'japanese', 'sushi'])) {
    return A.ramen;
  }
  if (any(['cafe', 'trang_mieng'])) return A.coffee;
  if (any(['oc', 'seafood', 'bia', 'beer', 'bar'])) return A.beer;
  return A.burger;
}

/// Tags as the design renders them: `banh_mi` → `bánh mì` is not something the
/// DB knows, so the raw tag is shown with underscores turned into spaces.
String cuisineLabel(List<String> tags) =>
    tags.isEmpty ? 'ẩm thực' : tags.take(2).map((t) => t.replaceAll('_', ' ')).join(' · ');

Venue venueFromCatalog(CatalogVenue v) => Venue(
      img: artForCuisine(v.cuisineTags),
      name: v.name,
      area: districtLabel(v.district),
      dist: distanceLabel(v.distanceM),
      price: priceLabel(v.priceMin, v.priceMax),
      rating: v.rating == null ? '—' : v.rating!.toStringAsFixed(1),
      open: v.wantCount,
      photoUrl: v.photoUrls.isEmpty ? null : v.photoUrls.first,
    );

/// Builds the detail-sheet model. The summary lines are the DB's own columns,
/// labelled — not a generated "culinary summary". A column the row does not
/// have simply does not produce a line.
Place placeFromCatalog(CatalogVenue v) {
  final area = districtLabel(v.district);
  final dist = distanceLabel(v.distanceM);
  final price = priceLabel(v.priceMin, v.priceMax);
  final priceEn = priceLabel(v.priceMin, v.priceMax, en: true);

  final lines = <SummaryLine>[
    SummaryLine(
      const T('Món chính', 'Cuisine'),
      T(cuisineLabel(v.cuisineTags), cuisineLabel(v.cuisineTags)),
    ),
    if (v.address != null)
      SummaryLine(const T('Địa chỉ', 'Address'), T(v.address!, v.address!)),
    SummaryLine(const T('Khu vực', 'Area'), T(area, area)),
    SummaryLine(
      const T('Khoảng giá', 'Price'),
      T(price == '—' ? 'chưa có giá' : '$price/người',
        priceEn == '—' ? 'no price on file' : '$priceEn per person'),
      color: (v.priceMin == null && v.priceMax == null) ? AppColorsV2.alert : null,
    ),
    if (v.rating != null)
      SummaryLine(
        const T('Đánh giá', 'Rating'),
        T('${v.rating!.toStringAsFixed(1)}/5', '${v.rating!.toStringAsFixed(1)}/5'),
      ),
  ];

  return Place(
    img: artForCuisine(v.cuisineTags),
    name: v.name,
    dist: dist,
    wanting: v.wantCount,
    group: const T('—', '—'),
    meta: T(
      [area, cuisineLabel(v.cuisineTags), if (price != '—') '$price/người'].join(' · '),
      [area, cuisineLabel(v.cuisineTags), if (priceEn != '—') '$priceEn pp'].join(' · '),
    ),
    reviews: v.rating == null
        ? const T('chưa có đánh giá', 'no ratings yet')
        : T('điểm ${v.rating!.toStringAsFixed(1)} trong dữ liệu AnMates',
            'rated ${v.rating!.toStringAsFixed(1)} in the AnMates catalogue'),
    lines: lines,
    photoUrl: v.photoUrls.isEmpty ? null : v.photoUrls.first,
  );
}

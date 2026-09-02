import 'package:flutter/foundation.dart';

import 'v2_data.dart';

/// Which screen the phone is showing. Mirrors the design's `state.screen`.
enum V2Screen { onb, home, filters, detail, swipe, chat, bill, rate, me, trust, pay, local }

enum SplitMode { item, equal }

/// Everything the v2 prototype remembers, ported 1:1 from the design's
/// `Component.state` plus the derived values its `renderVals()` computes.
///
/// Keeping the derivations here rather than in the widgets means the rules that
/// drive the design — the Vibe threshold, Trust gating, the star→points table —
/// live in one readable place.
class V2State extends ChangeNotifier {
  V2Screen _screen = V2Screen.onb;
  bool _en = false;
  int _step = 0;

  int _budget = 2;
  Set<int> _tastes = {0, 3};

  int _placeIdx = 0;
  int _mateIdx = 0;

  int _vibe = 22;
  int _msgCount = 2;
  bool _celebrated = false;
  bool _celebrate = false;
  final bool _express = false;

  SplitMode _split = SplitMode.item;
  int _trust = 96;

  Set<int> _areas = {0};
  Set<int> _vibeTags = {1};
  int _price = 2;
  bool _trustOnly = false;

  int _stars = 5;
  Set<int> _rateTags = {0};
  bool _rated = false;

  final int _district = 0;
  final int _dCat = 0;

  bool _notifsOpen = false;
  bool _searchOpen = false;

  // ── Reads ─────────────────────────────────────────────────────────────────

  V2Screen get screen => _screen;
  bool get en => _en;
  int get step => _step;
  int get budget => _budget;
  Set<int> get tastes => _tastes;
  int get placeIdx => _placeIdx;
  int get vibe => _vibe;
  int get msgCount => _msgCount;
  bool get celebrate => _celebrate;
  SplitMode get split => _split;
  int get trust => _trust;
  Set<int> get areas => _areas;
  Set<int> get vibeTags => _vibeTags;
  int get price => _price;
  bool get trustOnly => _trustOnly;
  int get stars => _stars;
  Set<int> get rateTags => _rateTags;
  bool get rated => _rated;
  bool get notifsOpen => _notifsOpen;
  bool get searchOpen => _searchOpen;

  Place get place => kPlaces[_placeIdx];
  Mate get mate => kMates[_mateIdx];

  String t(String vi, String enText) => _en ? enText : vi;
  String tr(T pair) => pair(_en);

  /// Below 85 the account is gated: swipe and chat caps, and venue demand hidden.
  bool get gated => _trust < 85;

  /// Express Vibe-Check unlocks the scheduling button far earlier.
  int get threshold => _express ? 45 : 70;
  bool get unlocked => _vibe >= threshold;

  /// The design hides the bottom nav on the screens that own their full height.
  bool get showNav => const {
        V2Screen.home, V2Screen.swipe, V2Screen.chat, V2Screen.bill,
        V2Screen.me, V2Screen.local, V2Screen.rate, V2Screen.trust,
      }.contains(_screen);

  /// Flows B–D run the aurora 30% softer so cards and glass read cleanly.
  bool get softBackground => const {
        V2Screen.home, V2Screen.detail, V2Screen.filters, V2Screen.swipe,
        V2Screen.chat, V2Screen.bill, V2Screen.rate, V2Screen.local,
      }.contains(_screen);

  double get washOpacity => softBackground ? 0.56 : 0.8;
  double get grainOpacity => softBackground ? 0.18 : 0.24;

  String get sectionTitle => _en
      ? 'Top ${kCategories[_dCat](true).toLowerCase()} near you'
      : 'Quán ${kCategories[_dCat](false).toLowerCase()} gần bạn';

  String get locationLabel =>
      '${kAreaNames[_district]}${_en ? ' · within 3 km' : ' · trong 3 km'}';

  String get cravingCount => gated ? '—' : '14';
  String get openTables =>
      gated ? '—' : kPlaces.fold(0, (a, p) => a + p.wanting).toString();
  String get wantingLabel => gated ? '—' : '${place.wanting}';

  String get trustTier => gated
      ? t('Đang bị gating — dưới mốc 85đ', 'Gated — below the 85 threshold')
      : t('Mate đáng tin · không bị gating', 'Reliable mate · Gating-free');

  String get flakeLabel => gated
      ? t('Về lại 96đ (ân xá Plus)', 'Restore to 96 (Plus amnesty)')
      : t('Thử bùng hẹn có xác nhận (−10)', 'Simulate a confirmed no-show (−10)');

  String get meMeta => _en
      ? 'District 1 · big-feast tier 150–350k · ${gated ? 'Free, gated' : 'Free plan'}'
      : 'Quận 1 · hệ đại tiệc 150–350k · ${gated ? 'gói Free, đang bị gating' : 'gói Free'}';

  /// Chat transcript, alternating their reply and yours, exactly as the design
  /// generates it from the message count.
  List<({String text, bool mine})> get messages => [
        for (var i = 0; i < _msgCount; i++)
          i.isOdd
              ? (text: tr(kMine[((i - 1) ~/ 2) % kMine.length]), mine: true)
              : (text: tr(kReplies[(i ~/ 2) % kReplies.length]), mine: false),
      ];

  String get prompt => tr(kPrompts[(_msgCount ~/ 4) % kPrompts.length]);

  String get chatSub =>
      '${place.name} · ${_express ? 'Express Vibe-Check' : t('Vibe Check chuẩn', 'standard Vibe Check')}';

  String get lockedCta => _en
      ? 'Unlocks at $threshold% vibe · ${(threshold - _vibe).clamp(0, 100)}% to go'
      : 'Mở khoá ở $threshold% vibe · còn ${(threshold - _vibe).clamp(0, 100)}%';

  String get confirmCta => t('Đã mở khoá · chốt kèo 19:30 tối nay',
      'Table unlocked · confirm 19:30 tonight');

  String get celebrateBody => t(
      'Sticker trái tim sôi đã ghim vào phòng chat. Giờ bạn có thể hẹn giờ và chia bill.',
      'The bubbling heart sticker is pinned to your chat. You can schedule the meal and split the bill now.');

  String get billSub => '${place.name} · 19:30 · 4 mates';
  String get ocrLine => t('Bóc tách được 6/6 món. Độ tin cậy 94%.',
      'Parsed 6 of 6 items. Confidence 94%.');
  String get yourShare => _split == SplitMode.equal ? '156.250đ' : '183.750đ';

  List<({String name, String who, String amount})> get billItems =>
      _split == SplitMode.equal
          ? [
              for (final n in ['Yuna', 'Hạnh', 'Duy', 'Thu'])
                (name: n, who: t('chia đều', 'even split'), amount: '156.250đ'),
            ]
          : [
              for (final b in kBill)
                (name: tr(b.name), who: tr(b.who), amount: b.amount),
            ];

  String get ratePlaceLine =>
      '${place.name} · 19:30 · ${t('check-in đúng giờ', 'checked in on time')}';
  String get starLabel => tr(kStarLabels[_stars - 1]);

  /// 4–5 stars lifts the mate, 3 is neutral, 1–2 costs points — and a low score
  /// only counts when tagged, which is why the copy below insists on evidence.
  String get ratePoints {
    final n = _stars >= 4 ? 3 : (_stars == 3 ? 0 : -4);
    return n > 0 ? '+$n' : '$n';
  }

  String get rateEffect => _stars >= 4
      ? t('Trust Score của Hạnh tăng khi bạn ấy rate lại. Điểm +2 check-in đúng giờ của bạn đã được cộng.',
          "Hạnh's Trust Score rises once she rates you back. Your own +2 for the on-time check-in is already banked.")
      : _stars == 3
          ? t('Rate trung tính không đổi điểm. Tag vẫn giúp ghép match sau này.',
              'A neutral rating moves nothing. Tags still help future matching.')
          : t('Rate thấp phải có tag làm bằng chứng. Một báo cáo đơn lẻ không tự trừ điểm.',
              'A low rating needs a tag as evidence. One report alone never drops a score.');

  String get rateCta => _rated
      ? t('Đã gửi · chờ Hạnh rate lại', 'Rating sent · waiting on Hạnh')
      : t('Gửi rate riêng tư', 'Send rating privately');

  String get priceLabel => kPrices[_price];
  double get pricePct => (_price + 1) / 4;
  String get filterCta => _en
      ? 'Show ${_trustOnly ? 9 : 14} matching mates'
      : 'Xem ${_trustOnly ? 9 : 14} mates phù hợp';

  // ── Writes ────────────────────────────────────────────────────────────────

  void go(V2Screen s) {
    _screen = s;
    _celebrate = false;
    _notifsOpen = false;
    _searchOpen = false;
    notifyListeners();
  }

  void setLang(bool english) {
    _en = english;
    notifyListeners();
  }

  void nextStep() {
    _step++;
    notifyListeners();
  }

  void backStep() {
    _step = (_step - 1).clamp(0, 4);
    notifyListeners();
  }

  void pickBudget(int i) {
    _budget = i;
    notifyListeners();
  }

  void toggleTaste(int i) {
    _tastes = _toggled(_tastes, i);
    notifyListeners();
  }

  void openPlace(int i) {
    _placeIdx = i.clamp(0, kPlaces.length - 1);
    _screen = V2Screen.detail;
    notifyListeners();
  }

  void skipMate() {
    _mateIdx = (_mateIdx + 1) % kMates.length;
    notifyListeners();
  }

  void inviteMate() {
    _screen = V2Screen.chat;
    _vibe = 22;
    _msgCount = 2;
    _celebrated = false;
    _celebrate = false;
    notifyListeners();
  }

  /// Every message boils the gauge up; crossing the threshold the first time
  /// fires the celebration sheet exactly once.
  void sendMessage() {
    final inc = _express ? 14 : 9;
    _vibe = (_vibe + inc).clamp(0, 100);
    _msgCount += 2;
    final unlockedNow = _vibe >= threshold && !_celebrated;
    _celebrate = unlockedNow;
    _celebrated = _celebrated || unlockedNow;
    notifyListeners();
  }

  void dismissCelebrate() {
    _celebrate = false;
    notifyListeners();
  }

  void setSplit(SplitMode m) {
    _split = m;
    notifyListeners();
  }

  void toggleArea(int i) {
    _areas = _toggled(_areas, i);
    notifyListeners();
  }

  void toggleVibeTag(int i) {
    _vibeTags = _toggled(_vibeTags, i);
    notifyListeners();
  }

  void cyclePrice() {
    _price = (_price + 1) % 4;
    notifyListeners();
  }

  void toggleTrustOnly() {
    _trustOnly = !_trustOnly;
    notifyListeners();
  }

  void resetFilters() {
    _areas = {0};
    _vibeTags = {1};
    _price = 2;
    _trustOnly = false;
    notifyListeners();
  }

  void pickStars(int n) {
    _stars = n;
    notifyListeners();
  }

  void toggleRateTag(int i) {
    _rateTags = _toggled(_rateTags, i);
    notifyListeners();
  }

  void submitRate() {
    _rated = true;
    notifyListeners();
  }

  void simulateFlake() {
    _trust = gated ? 96 : 84;
    notifyListeners();
  }

  void setNotifsOpen(bool v) {
    _notifsOpen = v;
    notifyListeners();
  }

  void setSearchOpen(bool v) {
    _searchOpen = v;
    notifyListeners();
  }

  static Set<int> _toggled(Set<int> set, int i) =>
      set.contains(i) ? ({...set}..remove(i)) : {...set, i};
}

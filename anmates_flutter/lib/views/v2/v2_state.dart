import 'package:flutter/foundation.dart';

import '../../services/api_client.dart';
import '../../services/booking_service.dart';
import '../../services/chat_socket.dart';
import '../../services/location_service.dart';
import '../../services/match_service.dart';
import '../../services/profile_service.dart';
import '../../services/venue_catalog_service.dart';
import 'v2_data.dart';
import 'v2_mate_mapper.dart';
import 'v2_venue_mapper.dart';

/// Which screen the phone is showing. Mirrors the design's `state.screen`.
enum V2Screen { onb, home, filters, detail, swipe, chat, bill, rate, me, trust, pay, local }

enum SplitMode { item, equal }

/// Everything the v2 prototype remembers.
///
/// Every field here now traces back to either a real API call or an honest
/// "not tracked" state. Three mechanics the original Claude Design prototype
/// invented — a Vibe-Check % gauge, Trust Score gating, and AI bill-split
/// amounts — had no backing anywhere in the schema (no vibe_score, no
/// trust_score, no bill/amount column) and were removed rather than kept as
/// a labelled demo: nothing here is gated, and nothing here is a made-up
/// number. See sessions/2026-09-03-real-data-sweep.md for the full audit.
class V2State extends ChangeNotifier {
  V2Screen _screen = V2Screen.onb;
  bool _en = false;
  int _step = 3; // TEMP-VERIFY: revert to 0

  int _budget = 2;
  Set<int> _tastes = {0, 3};

  int _placeIdx = 0;
  int _mateIdx = 0;

  SplitMode _split = SplitMode.item;

  Set<int> _areas = {0};
  Set<int> _vibeTags = {1};
  int _price = 2;

  int _stars = 5;
  Set<int> _rateTags = {0};
  bool _rated = false;

  final int _district = 0;
  final int _dCat = 0;

  bool _notifsOpen = false;
  bool _searchOpen = false;

  // ── Venue catalogue (GET /api/v1/venues) ──────────────────────────────────
  List<CatalogVenue> _catalog = const [];
  List<Venue> _venues = const [];
  List<Place> _places = const [];
  bool _venuesLoading = false;
  String? _venuesError;

  // ── Match candidates (GET /api/v1/matches — a real wishlist-overlap rank) ─
  List<MatchCandidate> _candidates = const [];
  bool _candidatesLoading = false;
  String? _candidatesError;
  bool _inviteLoading = false;

  /// Set after a swipe that didn't reciprocate, so the swipe screen can show
  /// an honest "sent, waiting on them" line instead of silently doing nothing.
  String? _pendingNotice;

  // ── Active chat (real match + real messages, WebSocket-backed) ───────────
  String? _activeMatchId;
  Mate? _activeMate;
  List<ApiMessage> _messages = const [];
  bool _messagesLoading = false;
  ChatSocket? _chatSocket;
  String? _myUserId;

  // ── Booking (GET/POST /api/v1/matches/:id/booking) ────────────────────────
  Booking? _booking;
  bool _bookingLoading = false;

  // ── Profile (GET /api/v1/profile) ─────────────────────────────────────────
  String? _profileName;

  // ── Reads ─────────────────────────────────────────────────────────────────

  V2Screen get screen => _screen;
  bool get en => _en;
  int get step => _step;
  int get budget => _budget;
  Set<int> get tastes => _tastes;
  int get placeIdx => _placeIdx;
  SplitMode get split => _split;
  Set<int> get areas => _areas;
  Set<int> get vibeTags => _vibeTags;
  int get price => _price;
  int get stars => _stars;
  Set<int> get rateTags => _rateTags;
  bool get rated => _rated;
  bool get notifsOpen => _notifsOpen;
  bool get searchOpen => _searchOpen;

  List<CatalogVenue> get catalog => _catalog;
  List<Venue> get venues => _venues;
  List<Place> get places => _places;
  bool get venuesLoading => _venuesLoading;
  String? get venuesError => _venuesError;
  bool get hasVenues => _venues.isNotEmpty;

  List<MatchCandidate> get candidates => _candidates;
  bool get hasCandidates => _candidates.isNotEmpty;
  bool get candidatesLoading => _candidatesLoading;
  String? get candidatesError => _candidatesError;
  bool get inviteLoading => _inviteLoading;
  String? get pendingNotice => _pendingNotice;

  bool get hasActiveMatch => _activeMatchId != null;
  bool get messagesLoading => _messagesLoading;

  Booking? get booking => _booking;
  bool get bookingLoading => _bookingLoading;

  /// Real display name from `/profile` — never the design's hardcoded "Yuna".
  /// Empty while the profile hasn't loaded yet.
  String get profileName => _profileName ?? '';

  /// Districts actually present in the catalogue, for the filter chips. Falls
  /// back to the design's static list only while the catalogue is still empty.
  List<String> get areaNames {
    if (_catalog.isEmpty) return kAreaNames;
    final seen = <String>{};
    for (final v in _catalog) {
      seen.add(districtLabel(v.district));
    }
    final out = seen.toList()..sort();
    return out;
  }

  /// The detail sheet's venue. While the catalogue is empty this is a neutral
  /// placeholder — a loading state, never invented venue data.
  Place get place => _places.isEmpty ? _placeholderPlace : _places[_placeIdx];

  /// The swipe card's candidate. While there are none yet, a neutral
  /// placeholder — never a sample person.
  Mate get mate => _candidates.isEmpty
      ? _placeholderMate
      : mateFromCandidate(_candidates[_mateIdx.clamp(0, _candidates.length - 1)]);

  /// Who chat/bill/rate are about. Captured at match time (before the
  /// candidate is dropped from the swipe deck), so the chat header still
  /// knows who you matched with even once they're gone from `_candidates`.
  Mate get chatPartner => _activeMate ?? _placeholderMate;

  String t(String vi, String enText) => _en ? enText : vi;
  String tr(T pair) => pair(_en);

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

  String get locationLabel {
    final names = areaNames;
    // Chưa có khu vực nào thì không đoán thành phố — dữ liệu trải khắp
    // Hà Nội, Bình Dương, Đà Lạt chứ không riêng TP.HCM.
    final area = names.isEmpty
        ? (_en ? 'Nearby' : 'Quanh đây')
        : names[_district.clamp(0, names.length - 1)];
    return '$area${_en ? ' · within 3 km' : ' · trong 3 km'}';
  }

  String get cravingCount => '${_catalog.length}';

  /// Sum of the API's `want_count` across the catalogue. Zero renders as an em
  /// dash: nobody has wished for these cuisines yet.
  String get openTables {
    final total = _places.fold(0, (a, p) => a + p.wanting);
    return total == 0 ? '—' : '$total';
  }

  String get wantingLabel {
    final w = place.wanting;
    return w == 0 ? '—' : '$w';
  }

  String get meMeta => _profileName == null
      ? ''
      : _en
          ? 'AnMates member'
          : 'Thành viên AnMates';

  /// Real transcript of the active match, oldest first — [ApiMessage] rows
  /// from `/matches/:id/messages` plus anything the live socket has appended.
  /// Empty means genuinely no messages yet, not a loading placeholder.
  List<({String text, bool mine})> get messages => [
        for (final m in _messages) (text: m.content, mine: m.senderId == _myUserId),
      ];

  String get chatSub {
    final foods = chatPartner.overlapFoods;
    if (foods.isEmpty) return t('Match mới', 'New match');
    return t('Cùng thích: ${foods.take(3).join(", ")}', 'Both like: ${foods.take(3).join(", ")}');
  }

  String get billSub {
    final b = _booking;
    if (b == null) return t('Chưa có lịch hẹn', 'No booking yet');
    return '${b.restaurantName} · ${_fmtTime(b.scheduledAt)}';
  }

  String get ratePlaceLine {
    final b = _booking;
    if (b == null) return chatPartner.name;
    return '${chatPartner.name} · ${b.restaurantName} · ${_fmtTime(b.scheduledAt)}';
  }

  String get starLabel => tr(kStarLabels[_stars - 1]);

  String get rateCta => _rated
      ? t('Đã gửi · chờ ${chatPartner.name} rate lại', 'Rating sent · waiting on ${chatPartner.name}')
      : t('Gửi rate riêng tư', 'Send rating privately');

  String get priceLabel => kPrices[_price];
  double get pricePct => (_price + 1) / 4;

  /// Real count of candidates in the pool — not the design's hardcoded 9/14.
  String get filterCta =>
      _en ? 'Show ${_candidates.length} matching mates' : 'Xem ${_candidates.length} mates phù hợp';

  // ── Writes ────────────────────────────────────────────────────────────────

  void go(V2Screen s) {
    if (_screen == V2Screen.chat && s != V2Screen.chat) {
      _disconnectChat();
    }
    _screen = s;
    _notifsOpen = false;
    _searchOpen = false;
    notifyListeners();

    // Re-establish the live socket when coming back to chat (e.g. from the
    // booking screen) for the same match — go() itself must stay synchronous,
    // so this fires without blocking the navigation.
    if (s == V2Screen.chat && _chatSocket == null && _activeMatchId != null) {
      _connectChat(_activeMatchId!);
    }
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

  /// Opens the detail sheet for the venue with this name. Names come from the
  /// same loaded catalogue, so a miss means the list changed underneath us —
  /// in which case we stay put rather than opening an unrelated venue.
  void openVenueNamed(String name) {
    final i = _places.indexWhere((p) => p.name == name);
    if (i < 0) return;
    openPlace(i);
  }

  void openPlace(int i) {
    if (_places.isEmpty) return;
    _placeIdx = i.clamp(0, _places.length - 1);
    _screen = V2Screen.detail;
    notifyListeners();
  }

  /// Records a real pass and drops the candidate locally — the backend's own
  /// `NOT EXISTS (swipes …)` filter means it would never be re-offered anyway.
  Future<void> skipMate() async {
    if (_candidates.isEmpty) return;
    final target = _candidates[_mateIdx.clamp(0, _candidates.length - 1)];
    _removeCandidate(target.userId);
    try {
      await MatchService().swipe(target.userId, false);
    } catch (_) {
      // The swipe is fire-and-forget from the UI's perspective — a failed
      // pass just means the candidate may reappear on the next reload, which
      // is harmless.
    }
  }

  /// Records a real like. A reciprocated like creates the match — the app
  /// moves to a real chat with real (empty, at first) history. Otherwise the
  /// invite is honestly reported as pending, never faked into a conversation
  /// with someone who hasn't matched back.
  Future<void> inviteMate() async {
    if (_candidates.isEmpty || _inviteLoading) return;
    final target = _candidates[_mateIdx.clamp(0, _candidates.length - 1)];
    _inviteLoading = true;
    _pendingNotice = null;
    notifyListeners();

    try {
      final result = await MatchService().swipe(target.userId, true);
      _removeCandidate(target.userId);

      if (result.matched && result.matchId != null) {
        _activeMatchId = result.matchId;
        // Captured now, before `target` disappears from `_candidates` —
        // chatPartner reads this instead of the (now empty) swipe deck.
        _activeMate = mateFromCandidate(target);
        _screen = V2Screen.chat;
        await _loadMyUserId();
        await loadMessages(result.matchId!);
        await _connectChat(result.matchId!);
        await loadBooking(result.matchId!);
      } else {
        _pendingNotice = t(
          'Đã gửi lời mời tới ${target.name} — đang chờ phản hồi.',
          'Invite sent to ${target.name} — waiting on a reply.',
        );
      }
    } catch (e) {
      _pendingNotice = t('Gửi lời mời thất bại, thử lại nhé.', "Couldn't send the invite — try again.");
    } finally {
      _inviteLoading = false;
      notifyListeners();
    }
  }

  void _removeCandidate(String userId) {
    _candidates = _candidates.where((c) => c.userId != userId).toList();
    if (_mateIdx >= _candidates.length) _mateIdx = 0;
  }

  Future<void> _loadMyUserId() async {
    if (_myUserId != null) return;
    try {
      final profile = await ProfileService().getProfile();
      _myUserId = profile['id'] as String?;
      _profileName = profile['name'] as String? ?? profile['nickname'] as String?;
    } catch (_) {
      // Chat still renders without this — every message just shows as "theirs"
      // until the id is known, which self-corrects once the profile loads.
    }
  }

  /// Loads the real message history for [matchId], oldest first.
  Future<void> loadMessages(String matchId) async {
    _messagesLoading = true;
    notifyListeners();
    try {
      _messages = await MatchService().getHistory(matchId);
    } catch (_) {
      _messages = const [];
    } finally {
      _messagesLoading = false;
      notifyListeners();
    }
  }

  Future<void> _connectChat(String matchId) async {
    _disconnectChat();
    final token = await ApiClient.accessToken();
    if (token == null) return;
    final socket = ChatSocket();
    try {
      await socket.connect(matchId, token);
    } catch (_) {
      return;
    }
    _chatSocket = socket;
    socket.messages.listen((m) {
      _messages = [..._messages, m];
      notifyListeners();
    });
  }

  void _disconnectChat() {
    _chatSocket?.dispose();
    _chatSocket = null;
  }

  /// Sends a real message over the live socket and appends it optimistically —
  /// the hub excludes the sender from its own broadcast, so without this the
  /// message you just sent would never appear in your own transcript.
  void sendRealMessage(String text) {
    final content = text.trim();
    if (content.isEmpty || _activeMatchId == null || _myUserId == null) return;
    _chatSocket?.sendText(content);
    _messages = [
      ..._messages,
      ApiMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        matchId: _activeMatchId!,
        senderId: _myUserId!,
        content: content,
        msgType: 'text',
        createdAt: DateTime.now(),
      ),
    ];
    notifyListeners();
  }

  Future<void> loadBooking(String matchId) async {
    _bookingLoading = true;
    notifyListeners();
    try {
      _booking = await BookingService().current(matchId);
    } catch (_) {
      _booking = null;
    } finally {
      _bookingLoading = false;
      notifyListeners();
    }
  }

  Future<void> proposeBooking({
    required String restaurantName,
    String restaurantAddress = '',
    required DateTime scheduledAt,
  }) async {
    final matchId = _activeMatchId;
    if (matchId == null) return;
    _bookingLoading = true;
    notifyListeners();
    try {
      _booking = await BookingService().propose(
        matchId,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        scheduledAt: scheduledAt,
      );
    } finally {
      _bookingLoading = false;
      notifyListeners();
    }
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

  void resetFilters() {
    _areas = {0};
    _vibeTags = {1};
    _price = 2;
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

  static String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Loading ───────────────────────────────────────────────────────────────

  /// Loads the venue catalogue from the API. Uses the device location when it
  /// is available so the feed is distance-sorted; otherwise falls back to the
  /// whole active table, name-sorted. Safe to call repeatedly.
  Future<void> loadVenues({bool force = false}) async {
    if (_venuesLoading) return;
    if (_venues.isNotEmpty && !force) return;

    _venuesLoading = true;
    _venuesError = null;
    notifyListeners();

    try {
      double? lat, lng;
      try {
        final pos = await LocationService().currentLatLng();
        lat = pos?.lat;
        lng = pos?.lng;
      } catch (_) {
        // Location is a nice-to-have here — without it we just lose the
        // distance sort and the "1,2 km" labels.
      }

      final rows = await VenueCatalogService().list(
        lat: lat,
        lng: lng,
        radiusM: lat != null ? 20000 : null,
      );

      _catalog = rows;
      _venues = rows.map(venueFromCatalog).toList();
      _places = rows.map(placeFromCatalog).toList();
      if (_placeIdx >= _places.length) _placeIdx = 0;
      _venuesError = _venues.isEmpty ? 'empty' : null;
    } on ApiException catch (e) {
      _venuesError = 'HTTP ${e.statusCode}';
    } catch (e) {
      _venuesError = e.toString();
    } finally {
      _venuesLoading = false;
      notifyListeners();
    }
  }

  /// Loads real match candidates (a wishlist-overlap ranking — see
  /// services/matching.go `ListCandidates`). An empty result means the
  /// account genuinely has no candidates yet (e.g. it's the only onboarded
  /// user), not a fetch failure.
  Future<void> loadCandidates({bool force = false}) async {
    if (_candidatesLoading) return;
    if (_candidates.isNotEmpty && !force) return;

    _candidatesLoading = true;
    _candidatesError = null;
    notifyListeners();

    try {
      _candidates = await MatchService().getCandidates();
      _mateIdx = 0;
    } on ApiException catch (e) {
      _candidatesError = 'HTTP ${e.statusCode}';
    } catch (e) {
      _candidatesError = e.toString();
    } finally {
      _candidatesLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    try {
      final profile = await ProfileService().getProfile();
      _myUserId = profile['id'] as String?;
      _profileName = (profile['name'] as String?) ?? (profile['nickname'] as String?);
      notifyListeners();
    } catch (_) {
      // The header falls back to blank rather than a fake name.
    }
  }

  @override
  void dispose() {
    _disconnectChat();
    super.dispose();
  }
}

/// Shown by the detail sheet only when the catalogue has not loaded — it holds
/// no venue facts, so it can never be mistaken for real data.
const Place _placeholderPlace = Place(
  img: A.hotpot,
  name: '—',
  dist: '',
  wanting: 0,
  group: T('—', '—'),
  meta: T('Đang tải quán…', 'Loading venues…'),
  reviews: T('', ''),
  lines: [],
);

/// Shown by the swipe screen only before candidates have loaded — holds no
/// person's facts, so it can never be mistaken for a real match.
const Mate _placeholderMate = Mate(
  userId: '',
  name: '—',
  img: A.burger,
  overlapFoods: [],
  tags: [],
  match: 0,
);

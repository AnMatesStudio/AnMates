import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/ai_venue_card.dart';
import '../../services/api_client.dart';
import '../../services/chat_socket.dart';
import '../../services/concierge_service.dart';
import '../../services/location_service.dart';
import '../../services/match_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_venue_card.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

// ─── Message model ────────────────────────────────────────────────────────────

/// A rendered chat item. [type] mirrors the backend `msg_type`
/// ('text' | 'image' | 'system' | 'ai_venue_card').
class _ChatItem {
  final bool isMe;
  final String type;
  final String content;
  const _ChatItem(this.isMe, this.type, this.content);
}

// ─── ChatDetailView ───────────────────────────────────────────────────────────

class ChatDetailView extends StatefulWidget {
  final String mateName;
  final int vibePercent;

  /// When non-null the view runs in **live mode**: it loads history, opens the
  /// chat WebSocket, and renders real messages (incl. the AI `ai_venue_card`).
  /// When null it runs in the original demo mode with sample content.
  final String? matchId;
  final String? currentUserId;

  const ChatDetailView({
    super.key,
    this.mateName = 'Khánh',
    this.vibePercent = 42,
    this.matchId,
    this.currentUserId,
  });

  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView> {
  late int _vibePercent;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final _socket = ChatSocket();
  final _concierge = ConciergeService();
  StreamSubscription? _msgSub;
  bool _live = false;
  bool _loading = false;

  List<_ChatItem> _items = [];

  // Demo content (used only when matchId is null).
  static const _demoMessages = [
    _ChatItem(false, 'text', 'Hey Vy! Cùng team thèm ramen quận 1 nè 🍜'),
    _ChatItem(true, 'text', 'Haha, mình đặt nó vào wishlist 2 tuần rồi mà chưa rủ được ai'),
    _ChatItem(false, 'text', 'Quán bé tí mà ngon ác. Vy thường gọi tonkotsu hay miso?'),
    _ChatItem(true, 'text', 'Spicy miso, level 3 luôn nha 🌶️🌶️🌶️'),
    _ChatItem(false, 'text', 'Wow same! Mình còn order thêm chả cá quết 👀'),
  ];

  // Sample card matching the backend `ai_venue_card` JSON contract
  // (docs/specs/ai-concierge-chat-spec §6). Shown in demo mode only.
  static final AiVenueCardContent _sampleAiCard = AiVenueCardContent.fromJson({
    'intro': '2 đứa hợp gu rồi nè! Đây là 3 chỗ ngon, vừa túi tiền, nằm giữa 2 đứa:',
    'midpoint': {'lat': 10.778, 'lng': 106.695},
    'picks': [
      {
        'restaurant_id': 'a', 'name': 'Bún Bò Giáo Toàn', 'rating': 4.6,
        'price_min': 50000, 'price_max': 90000, 'lat': 10.7882, 'lng': 106.679,
        'distance_m': 480, 'reason': 'Yên tĩnh, hợp first date',
      },
      {
        'restaurant_id': 'b', 'name': "Pizza 4P's Lê Thánh Tôn", 'rating': 4.7,
        'price_min': 200000, 'price_max': 420000, 'lat': 10.779, 'lng': 106.7035,
        'distance_m': 900, 'reason': 'Không gian ấm, dễ trò chuyện',
      },
      {
        'restaurant_id': 'c', 'name': 'Cộng Cà Phê', 'rating': 4.3,
        'price_min': 45000, 'price_max': 90000, 'lat': 10.7757, 'lng': 106.7007,
        'distance_m': 650, 'reason': 'Cà phê chill, nhẹ nhàng',
      },
    ],
  });

  @override
  void initState() {
    super.initState();
    _vibePercent = widget.vibePercent;
    // Push last-known coarse location so the AI Concierge can compute the
    // meetup midpoint. Best-effort, fire-and-forget.
    LocationService().pushCurrentLocation();

    if (widget.matchId != null) {
      _live = true;
      _initLive();
    } else {
      _items = List.from(_demoMessages);
    }
  }

  Future<void> _initLive() async {
    setState(() => _loading = true);
    final matchId = widget.matchId!;
    try {
      final history = await MatchService().getHistory(matchId);
      _items = history.map(_toItem).toList();

      // Vibe bar from real Nồi Lẩu progress.
      try {
        final p = await ApiClient().get('/api/v1/matches/$matchId/progress');
        final pts = (p['points'] as num?)?.toInt();
        if (pts != null) _vibePercent = pts.clamp(0, 100);
      } catch (_) {}

      final token = await ApiClient.accessToken();
      if (token != null) {
        await _socket.connect(matchId, token);
        _msgSub = _socket.messages.listen(_onIncoming);
      }
    } catch (_) {
      // Stay graceful — show whatever history loaded.
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollToBottom();
  }

  _ChatItem _toItem(ApiMessage m) =>
      _ChatItem(m.senderId == widget.currentUserId, m.msgType, m.content);

  // Inbound = other user's messages + AI cards (the hub excludes our own sends).
  void _onIncoming(ApiMessage m) {
    if (!mounted) return;
    setState(() => _items.add(_toItem(m)));
    _scrollToBottom();
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _socket.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _unlocked => _vibePercent >= 70;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    text = text.trim();
    if (text.isEmpty) return;
    if (_live) _socket.sendText(text);
    setState(() {
      _items.add(_ChatItem(true, 'text', text));
      _textCtrl.clear();
    });
    _scrollToBottom();
  }

  void _sendQuickReply(String text) => _sendMessage(text);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            VibeProgressBar(percent: _vibePercent, unlocked: _unlocked),
            Expanded(child: _buildMessageList()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.ink,
            onPressed: () => Navigator.maybePop(context),
          ),
          AnmAvatar(size: 36, hue: 1),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.mateName,
                  style: AppTextStyles.display(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _live ? 'đang online' : '🍜 Tiệm mì Ramen Q1 · đang online',
                  style: AppTextStyles.body(size: 11, color: AppColors.ink50),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz_rounded, size: 22),
            color: AppColors.ink,
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  Widget _buildMessageList() {
    return ListView(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        _buildSystemPill(),
        const SizedBox(height: 12),
        if (_loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
        ..._items.map(_buildItem),
        const SizedBox(height: 12),
        _buildQuickReplies(),
        // Demo-only extras (live mode shows only real messages/cards).
        if (!_live && _unlocked) ...[
          const SizedBox(height: 12),
          AiVenueCard(
            content: _sampleAiCard,
            onSuggest: (pick) => _sendMessage('Mình muốn đi ${pick.name} nè! 😍'),
          ),
          const SizedBox(height: 12),
          _buildBookingSuggestion(),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildItem(_ChatItem item) {
    if (item.type == 'ai_venue_card') {
      final card = AiVenueCardContent.tryParse(item.content);
      if (card != null) {
        final matchId = widget.matchId;
        return AiVenueCard(
          content: card,
          mateName: widget.mateName,
          // Anchor chips only in live mode (need a real match id to re-query).
          onReanchor: matchId == null
              ? null
              : (anchor) => _concierge.suggest(matchId, anchor),
          onSuggest: (pick) => _sendMessage('Mình muốn đi ${pick.name} nè! 😍'),
        );
      }
      // Fall back to a plain bubble if the payload can't be parsed.
    }
    return _buildBubble(item);
  }

  Widget _buildSystemPill() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.ocean.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Phòng chat ẩn SĐT — vibe đủ chín, First Date sẽ mở ✨',
          style: AppTextStyles.body(size: 11, color: AppColors.ocean),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBubble(_ChatItem msg) {
    final isMe = msg.isMe;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[AnmAvatar(size: 28, hue: 1), const SizedBox(width: 8)],
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.berry : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: AppColors.ink10),
              ),
              child: Text(
                msg.content,
                style: AppTextStyles.body(
                  size: 14,
                  color: isMe ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    const chips = [
      ('🥡 Topping tủ?', AppColors.berry),
      ('🍻 Có order bia ko?', AppColors.ocean),
      ('🕐 Khung giờ tiện?', AppColors.wisteria),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: chips
          .map(
            (c) => GestureDetector(
              onTap: () => _sendQuickReply(c.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: c.$2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.$2.withValues(alpha: 0.35)),
                ),
                child: Text(
                  c.$1,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: c.$2,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildBookingSuggestion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.berryDeep, AppColors.berry],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.berry.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Sparkle(size: 28, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đề xuất First Date',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: Colors.white70,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Đi luôn tối nay nha? 19:30 · Tiệm mì Ramen Q1 · còn bàn 2 chỗ',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Chốt →',
              style: AppTextStyles.body(
                size: 13,
                weight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Composer ───────────────────────────────────────────────────────────────

  Widget _buildComposer() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink10)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBookingCTABar(),
          _buildInputRow(),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildBookingCTABar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _unlocked ? AppColors.berry : AppColors.ink10,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _unlocked
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Sparkle(size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Chốt First Date — mở rồi! →',
                  style: AppTextStyles.display(
                    size: 15,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'First Date — mở khi vibe ≥ 70',
                  style: AppTextStyles.display(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.ink70,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Chat thêm ~10 tin chất lượng nữa',
                  style: AppTextStyles.body(size: 11, color: AppColors.ink50),
                ),
              ],
            ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Row(
        children: [
          // + button
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, size: 20, color: AppColors.ink),
          ),
          const SizedBox(width: 8),
          // Text input
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.ink10),
              ),
              child: TextField(
                controller: _textCtrl,
                style: AppTextStyles.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'Nhắn cho ${widget.mateName}…',
                  hintStyle: AppTextStyles.body(
                    size: 14,
                    color: AppColors.ink50,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Camera button (berry→wisteria gradient with badge)
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.berry, AppColors.wisteria],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.berryDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '1',
                      style: AppTextStyles.mono(
                        size: 8,
                        weight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Mic button
          GestureDetector(
            onTap: () {},
            child: const SizedBox(
              width: 38,
              height: 38,
              child: Icon(
                Icons.mic_none_rounded,
                size: 22,
                color: AppColors.ink70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

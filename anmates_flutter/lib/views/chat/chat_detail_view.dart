import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

// ─── Message model ────────────────────────────────────────────────────────────

enum _Sender { me, them }

class _Message {
  final _Sender sender;
  final String text;
  const _Message(this.sender, this.text);
}

// ─── ChatDetailView ───────────────────────────────────────────────────────────

class ChatDetailView extends StatefulWidget {
  final String mateName;
  final int vibePercent;

  const ChatDetailView({
    super.key,
    this.mateName = 'Khánh',
    this.vibePercent = 42,
  });

  @override
  State<ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<ChatDetailView> {
  late int _vibePercent;
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  static final _initialMessages = [
    const _Message(_Sender.them, 'Hey Vy! Cùng team thèm ramen quận 1 nè 🍜'),
    const _Message(
      _Sender.me,
      'Haha, mình đặt nó vào wishlist 2 tuần rồi mà chưa rủ được ai',
    ),
    const _Message(
      _Sender.them,
      'Quán bé tí mà ngon ác. Vy thường gọi tonkotsu hay miso?',
    ),
    const _Message(_Sender.me, 'Spicy miso, level 3 luôn nha 🌶️🌶️🌶️'),
    const _Message(
      _Sender.them,
      'Wow same! Mình còn order thêm chả cá quết 👀',
    ),
  ];

  late List<_Message> _messages;

  @override
  void initState() {
    super.initState();
    _vibePercent = widget.vibePercent;
    _messages = List.from(_initialMessages);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  bool get _unlocked => _vibePercent >= 70;

  void _sendMessage(String text) {
    if (text.isEmpty) return;
    setState(() {
      _messages.add(_Message(_Sender.me, text));
      _textCtrl.clear();
    });
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
                  '${widget.mateName}, 26',
                  style: AppTextStyles.display(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '🍜 Tiệm mì Ramen Q1 · đang online',
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
        ..._messages.map(_buildBubble),
        const SizedBox(height: 12),
        _buildQuickReplies(),
        if (_unlocked) ...[
          const SizedBox(height: 12),
          _buildBookingSuggestion(),
        ],
        const SizedBox(height: 12),
      ],
    );
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

  Widget _buildBubble(_Message msg) {
    final isMe = msg.sender == _Sender.me;
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
                msg.text,
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

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';
import 'chat_detail_view.dart';

// ─── Data models (local mock) ─────────────────────────────────────────────────

class _NewMatch {
  final String name;
  final int age;
  final String time;
  final int hue;
  const _NewMatch(this.name, this.age, this.time, this.hue);
}

class _ActiveChat {
  final String name;
  final int hue;
  final bool online;
  final int vibe;
  final String restaurant;
  final String lastMsg;
  final bool typing;
  final int unread;
  const _ActiveChat({
    required this.name,
    required this.hue,
    required this.online,
    required this.vibe,
    required this.restaurant,
    required this.lastMsg,
    this.typing = false,
    this.unread = 0,
  });
}

class _BestMate {
  final String name;
  final int hue;
  final int count;
  final String lastDish;
  const _BestMate(this.name, this.hue, this.count, this.lastDish);
}

// ─── ChatListView ─────────────────────────────────────────────────────────────

class ChatListView extends StatefulWidget {
  const ChatListView({super.key});

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  static const _newMatches = [
    _NewMatch('Khánh', 26, 'vừa xong', 1),
    _NewMatch('Linh', 24, '5 phút', 2),
    _NewMatch('Duy', 28, '1 giờ', 4),
    _NewMatch('Mai', 25, '3 giờ', 3),
  ];

  static const _activeChats = [
    _ActiveChat(
      name: 'Khánh',
      hue: 1,
      online: true,
      vibe: 72,
      restaurant: 'Tiệm mì Ramen Q1',
      lastMsg: 'Wow same! Mình còn order thêm...',
      unread: 2,
    ),
    _ActiveChat(
      name: 'Trang',
      hue: 2,
      online: false,
      vibe: 48,
      restaurant: 'Bún bò Huế Cô Ba',
      lastMsg: 'Ừ, hôm nào rảnh mình thử nhé',
    ),
    _ActiveChat(
      name: 'Phúc',
      hue: 4,
      online: true,
      vibe: 65,
      restaurant: 'Pizza 4P\'s D1',
      lastMsg: 'đang nhắn tin...',
      typing: true,
    ),
    _ActiveChat(
      name: 'Mai Anh',
      hue: 3,
      online: false,
      vibe: 30,
      restaurant: 'Cơm tấm Thuận Kiều',
      lastMsg: 'Ok nha, để mình xem lịch',
    ),
  ];

  static const _bestMates = [
    _BestMate('Hà', 5, 7, 'Bún bò Huế'),
    _BestMate('Quân', 0, 5, 'Cơm tấm sườn'),
    _BestMate('Thảo', 2, 4, 'Bánh mì Hòa Mã'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  _buildNewMatchSection(),
                  const SizedBox(height: 8),
                  _buildActiveChatSection(),
                  const SizedBox(height: 8),
                  _buildBestMateSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('HỘP CHAT'),
              const SizedBox(height: 3),
              Text(
                'Mates của Vy',
                style: AppTextStyles.display(
                  size: 24,
                  weight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.6,
                ),
              ),
            ],
          ),
          const Spacer(),
          _IconBtn(icon: Icons.search_rounded, onTap: () {}),
          const SizedBox(width: 8),
          _IconBtn(icon: Icons.settings_outlined, onTap: () {}),
        ],
      ),
    );
  }

  // ── Section 1: Mate vừa match ──────────────────────────────────────────────

  Widget _buildNewMatchSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow('MATE VỪA MATCH', color: AppColors.berry),
              const SizedBox(width: 8),
              _CountBadge(count: _newMatches.length, color: AppColors.berry),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Nói \'Hello\' trước trong vòng 24h để giữ kèo nha',
            style: AppTextStyles.body(size: 12, color: AppColors.ink50),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _newMatches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _NewMatchCard(match: _newMatches[i]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 2: Đang tám ────────────────────────────────────────────────────

  Widget _buildActiveChatSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow('ĐANG TÁM', color: AppColors.ocean),
              const SizedBox(width: 8),
              _CountBadge(count: _activeChats.length, color: AppColors.ocean),
            ],
          ),
          const SizedBox(height: 10),
          ..._activeChats.map(
            (chat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ActiveChatCard(
                chat: chat,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatDetailView(
                      mateName: chat.name,
                      vibePercent: chat.vibe,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section 3: Best Mate ───────────────────────────────────────────────────

  Widget _buildBestMateSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Eyebrow('BEST MATE', color: AppColors.wisteriaDeep),
              const SizedBox(width: 8),
              _CountBadge(
                count: _bestMates.length,
                color: AppColors.wisteriaDeep,
              ),
              const SizedBox(width: 6),
              Text(
                '≥3 lần ăn cùng',
                style: AppTextStyles.body(size: 11, color: AppColors.ink50),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.ink10),
            ),
            child: Column(
              children: List.generate(_bestMates.length, (i) {
                final mate = _bestMates[i];
                final isLast = i == _bestMates.length - 1;
                return Column(
                  children: [
                    _BestMateRow(mate: mate),
                    if (!isLast)
                      Divider(
                        height: 1,
                        color: AppColors.ink10,
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New Match Card ───────────────────────────────────────────────────────────

class _NewMatchCard extends StatelessWidget {
  final _NewMatch match;
  const _NewMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink10),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink10,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(17),
                ),
                child: PhotoSlot(width: 96, height: 100, radius: 0),
              ),
              Positioned(
                bottom: -10,
                right: 8,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: AppColors.berry,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '♥',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${match.name}, ${match.age}',
              style: AppTextStyles.display(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.ink,
                letterSpacing: -0.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            match.time,
            style: AppTextStyles.mono(
              size: 10,
              color: AppColors.ink50,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Active Chat Card ─────────────────────────────────────────────────────────

class _ActiveChatCard extends StatelessWidget {
  final _ActiveChat chat;
  final VoidCallback onTap;
  const _ActiveChatCard({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final vibeColor = chat.vibe >= 70 ? AppColors.berry : AppColors.wisteria;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink10),
        ),
        child: Row(
          children: [
            // Avatar with vibe ring
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(58, 58),
                    painter: _VibeRingPainter(
                      progress: chat.vibe / 100,
                      color: vibeColor,
                    ),
                  ),
                  Positioned(
                    top: 5,
                    left: 5,
                    right: 5,
                    bottom: 5,
                    child: AnmAvatar(size: 48, hue: chat.hue),
                  ),
                  if (chat.online)
                    Positioned(
                      right: 3,
                      bottom: 3,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        chat.name,
                        style: AppTextStyles.display(
                          size: 14,
                          weight: FontWeight.w700,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: vibeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'vibe ${chat.vibe}',
                          style: AppTextStyles.mono(
                            size: 9,
                            weight: FontWeight.w700,
                            color: vibeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        chat.online ? 'online' : 'offline',
                        style: AppTextStyles.mono(
                          size: 9,
                          color: chat.online
                              ? const Color(0xFF27AE60)
                              : AppColors.ink30,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chat.restaurant,
                    style: AppTextStyles.body(
                      size: 11,
                      color: AppColors.wisteria,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: chat.typing
                              ? AppTextStyles.body(
                                  size: 12,
                                  color: AppColors.ocean,
                                ).copyWith(fontStyle: FontStyle.italic)
                              : chat.unread > 0
                              ? AppTextStyles.body(
                                  size: 12,
                                  weight: FontWeight.w700,
                                  color: AppColors.ink,
                                )
                              : AppTextStyles.body(
                                  size: 12,
                                  color: AppColors.ink50,
                                ),
                        ),
                      ),
                      if (chat.unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: AppColors.berry,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${chat.unread}',
                              style: AppTextStyles.mono(
                                size: 10,
                                weight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Best Mate Row ────────────────────────────────────────────────────────────

class _BestMateRow extends StatelessWidget {
  final _BestMate mate;
  const _BestMateRow({required this.mate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnmAvatar(size: 44, hue: mate.hue, ringColor: AppColors.wisteria),
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.wisteriaDeep,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '${mate.count}',
                      style: AppTextStyles.mono(
                        size: 9,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      mate.name,
                      style: AppTextStyles.display(
                        size: 14,
                        weight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnmChip(
                      label: '${mate.count}× ĂN CÙNG',
                      active: true,
                      color: AppColors.wisteria,
                      sm: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  mate.lastDish,
                  style: AppTextStyles.body(size: 12, color: AppColors.ink50),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.wisteria.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.wisteria.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                'Rủ đi',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: AppColors.wisteriaDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.ink10,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: AppColors.ink),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: AppTextStyles.mono(
          size: 10,
          weight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Vibe Ring Painter ────────────────────────────────────────────────────────

class _VibeRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _VibeRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    final trackPaint = Paint()
      ..color = AppColors.ink10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, trackPaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(_VibeRingPainter old) =>
      old.progress != progress || old.color != color;
}

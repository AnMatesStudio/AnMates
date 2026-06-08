import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/match_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';
import '../chat/chat_detail_view.dart';
import 'match_view.dart';

class SwipeView extends StatefulWidget {
  const SwipeView({super.key});

  @override
  State<SwipeView> createState() => _SwipeViewState();
}

class _SwipeViewState extends State<SwipeView>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Real data.
  List<MatchCandidate>? _candidates;
  int _index = 0;
  bool _loading = true;
  String? _error;
  String? _currentUserId;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = await AuthService().currentUserId();
      final cands = await MatchService().getCandidates();
      if (!mounted) return;
      setState(() {
        _currentUserId = uid;
        _candidates = cands;
        _index = 0;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được danh sách mate. Thử lại nhé.';
        _loading = false;
      });
    }
  }

  MatchCandidate? get _current {
    final c = _candidates;
    if (c == null || _index >= c.length) return null;
    return c[_index];
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (_accepting) return;
    setState(() {
      _isDragging = true;
      _dragOffset += Offset(details.delta.dx, details.delta.dy * 0.3);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_accepting) return;
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragOffset.dx > 120 || velocity > 400) {
      _decide(true);
    } else if (_dragOffset.dx < -120 || velocity < -400) {
      _decide(false);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  /// Animate the front card off-screen, then (if liked) accept the match and
  /// open the match screen, then advance to the next candidate.
  void _decide(bool liked) {
    if (_accepting) return;
    final cand = _current;
    if (cand == null) return;
    setState(() => _dragOffset = Offset(liked ? 600 : -600, 0));
    Future.delayed(const Duration(milliseconds: 320), () async {
      if (!mounted) return;
      if (liked) {
        await _like(cand);
      } else {
        _pass(cand);
      }
      if (!mounted) return;
      setState(() {
        _index++;
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    });
  }

  // Pass: record the decision so the candidate doesn't resurface. Fire-and-forget
  // — the deck advances locally regardless of the network result.
  void _pass(MatchCandidate cand) {
    MatchService().swipe(cand.userId, false).then((_) {}, onError: (_) {});
  }

  // Like: a match is created only when the other user has already liked back
  // (mutual-like gate). Otherwise we just record the like and move on.
  Future<void> _like(MatchCandidate cand) async {
    setState(() => _accepting = true);
    try {
      final res = await MatchService().swipe(cand.userId, true);
      if (!mounted) return;
      if (res.matched) {
        final shared = cand.overlapFoods.isNotEmpty
            ? cand.overlapFoods.take(2).join(', ')
            : 'nhiều món hợp gu';
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchView(
              mateName: cand.name,
              restaurantName: shared,
              onChat: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailView(
                    mateName: cand.name,
                    vibePercent: cand.vibeScore,
                    matchId: res.matchId,
                    currentUserId: _currentUserId,
                  ),
                ),
              ),
              onContinue: () => Navigator.pop(context),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thích ${cand.name} 💜 — chờ họ thích lại nha'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Có lỗi, thử lại nha')));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  // Rewind: undo the last swipe (server-side) and step the deck back one card.
  Future<void> _rewind() async {
    if (_accepting || _index == 0) return;
    setState(() => _accepting = true);
    try {
      await MatchService().undoSwipe();
    } catch (_) {
      // best-effort — still let the user step back locally
    }
    if (!mounted) return;
    setState(() {
      _index--;
      _accepting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.mint, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.berry),
      );
    }
    if (_error != null) {
      return _buildMessage(
        emoji: '😕',
        title: _error!,
        actionLabel: 'Thử lại',
        onAction: _load,
      );
    }
    if (_current == null) {
      return _buildMessage(
        emoji: '🍽️',
        title: 'Hết mate hợp gu rồi!',
        subtitle: 'Quay lại sau hoặc thêm gu ẩm thực để tìm thêm bạn ăn.',
        actionLabel: 'Tải lại',
        onAction: _load,
      );
    }
    return Column(
      children: [
        Expanded(child: _buildCardStack()),
        _buildActionButtons(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMessage({
    required String emoji,
    required String title,
    String? subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.display(
                size: 20,
                weight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.5,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(
                  size: 14,
                  color: AppColors.ink70,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            AnmCTA(label: actionLabel, onTap: onAction, fullWidth: false),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          if (Navigator.canPop(context))
            GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: _circleIcon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 40),
          Expanded(
            child: Column(
              children: [
                Text(
                  'QUẸT BẠN ĂN MATE',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.ink50,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hợp gu thì quẹt phải nha',
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          GestureDetector(onTap: _load, child: _circleIcon(Icons.refresh)),
        ],
      ),
    );
  }

  Widget _circleIcon(IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 18, color: AppColors.ink),
    );
  }

  Widget _buildCardStack() {
    final rotation = _dragOffset.dx / 1200;
    final hasNext = _candidates != null && _index + 1 < _candidates!.length;
    final hasNext2 = _candidates != null && _index + 2 < _candidates!.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back card 2
          if (hasNext2)
            Transform(
              transform: Matrix4.identity()
                ..translateByDouble(0.0, 16.0, 0.0, 1.0)
                ..rotateZ(3 * math.pi / 180),
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: 0.5,
                child: _buildCard(isInteractive: false),
              ),
            ),
          // Back card 1
          if (hasNext)
            Transform(
              transform: Matrix4.identity()
                ..translateByDouble(0.0, 8.0, 0.0, 1.0)
                ..rotateZ(1.5 * math.pi / 180),
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: 0.75,
                child: _buildCard(isInteractive: false),
              ),
            ),
          // Front card (interactive)
          GestureDetector(
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transform: Matrix4.identity()
                ..translateByDouble(_dragOffset.dx, _dragOffset.dy, 0.0, 1.0)
                ..rotateZ(rotation),
              alignment: Alignment.center,
              child: _buildCard(isInteractive: true, cand: _current),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required bool isInteractive, MatchCandidate? cand}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isInteractive
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                _cardPhoto(cand),
                if (isInteractive) ...[
                  if (_dragOffset.dx > 30)
                    Positioned(
                      top: 24,
                      left: 24,
                      child: _stampLabel('THÈM', AppColors.berry, -0.4),
                    ),
                  if (_dragOffset.dx < -30)
                    Positioned(
                      top: 24,
                      right: 24,
                      child: _stampLabel('PASS', AppColors.glaucous, 0.4),
                    ),
                  if (cand != null)
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _badge('💯 Hợp gu ${cand.vibeScore}%'),
                          const SizedBox(width: 6),
                          _badge('🍜 ${cand.overlapCount} món chung'),
                        ],
                      ),
                    ),
                ],
              ],
            ),
            if (isInteractive && cand != null) _buildCardContent(cand),
          ],
        ),
      ),
    );
  }

  Widget _cardPhoto(MatchCandidate? cand) {
    final url = cand?.avatarUrl;
    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        width: double.infinity,
        height: 320,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            PhotoSlot(width: double.infinity, height: 320, radius: 0),
      );
    }
    return PhotoSlot(width: double.infinity, height: 320, radius: 0);
  }

  Widget _stampLabel(String text, Color color, double angle) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          text,
          style: AppTextStyles.mono(
            size: 16,
            weight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: AppTextStyles.body(size: 11, color: Colors.white),
      ),
    );
  }

  Widget _buildCardContent(MatchCandidate cand) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cand.name,
            style: AppTextStyles.display(
              size: 22,
              weight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cand.overlapFoods.isNotEmpty
                ? 'Cùng mê: ${cand.overlapFoods.join(' · ')}'
                : 'Hai bạn có gu ăn uống khá hợp đó!',
            style: AppTextStyles.body(
              size: 13,
              color: AppColors.ink70,
              height: 1.5,
            ),
          ),
          if (cand.overlapFoods.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in cand.overlapFoods.take(4))
                  AnmChip(
                    label: f,
                    active: true,
                    color: AppColors.berry,
                    sm: true,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rewind button (undo last swipe)
          GestureDetector(
            onTap: (_accepting || _index == 0) ? null : _rewind,
            child: Opacity(
              opacity: _index == 0 ? 0.4 : 1.0,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.glaucous,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glaucous.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.replay, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Pass button
          GestureDetector(
            onTap: _accepting ? null : () => _decide(false),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '✕',
                  style: TextStyle(fontSize: 20, color: AppColors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          // Like button with pulse
          GestureDetector(
            onTap: _accepting ? null : () => _decide(true),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _accepting ? 1.0 : _pulseAnimation.value,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.berry,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.berry.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _accepting
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.favorite,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

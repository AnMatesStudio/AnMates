import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

class DiscoverView extends StatefulWidget {
  const DiscoverView({super.key});

  @override
  State<DiscoverView> createState() => _DiscoverViewState();
}

class _DiscoverViewState extends State<DiscoverView> {
  final Set<String> _activeVibes = {'❄️ Máy lạnh'};

  // Hardcoded for now — will become a Bloc-driven List<Place> in Phase 4c
  // (DiscoverBloc + repository). Once that lands, this becomes:
  //   final places = context.watch<DiscoverBloc>().state.places;
  static final List<_RestaurantData> _hotNearby = [
    _RestaurantData(
      name: 'Tiệm mì Ramen Q1',
      tag: '🍜 Mì · Lẩu',
      dist: '0.4km',
      peopleCraving: 15,
      hot: false,
    ),
    _RestaurantData(
      name: 'Bò tơ nướng đá tảng',
      tag: '🥩 Nướng · Bia',
      dist: '1.2km',
      peopleCraving: 8,
      hot: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      // CustomScrollView + slivers replaces SingleChildScrollView + Column.
      // Why: slivers participate directly in the scroll viewport, so each
      // section's layout is computed lazily as it scrolls into view. This
      // eliminates the "compute every child's intrinsic height up front"
      // cost of SingleChildScrollView + Column.
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _TopBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          const SliverToBoxAdapter(child: _SearchBar()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          const SliverToBoxAdapter(child: _GenreSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: _VibeSection(
              activeVibes: _activeVibes,
              onToggle: (vibe) {
                setState(() {
                  if (_activeVibes.contains(vibe)) {
                    _activeVibes.remove(vibe);
                  } else {
                    _activeVibes.add(vibe);
                  }
                });
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          // "Hot Nearby" heading
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Eyebrow('HOT QUANH BẠN · 18:00'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Restaurant rows — SliverList.builder so future Bloc-driven list
          // pagination plugs in without refactoring the scroll architecture.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList.separated(
              itemCount: _hotNearby.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final place = _hotNearby[index];
                return _RestaurantRow(
                  name: place.name,
                  tag: place.tag,
                  dist: place.dist,
                  peopleCraving: place.peopleCraving,
                  hot: place.hot,
                );
              },
            ),
          ),
          // Bottom safe-area for the tab bar overlap.
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// Plain data holder for the hardcoded list. Replaced by Place entity in Phase 4c.
class _RestaurantData {
  final String name;
  final String tag;
  final String dist;
  final int peopleCraving;
  final bool hot;

  const _RestaurantData({
    required this.name,
    required this.tag,
    required this.dist,
    required this.peopleCraving,
    required this.hot,
  });
}

// ─── Section widgets (extracted from build() for clarity + const-ness) ──────

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const LogoMark(size: 32, float: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📍 QUẬN 1, TP.HCM',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w600,
                    color: AppColors.ink50,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hôm nay ăn gì, Vy?',
                  style: AppTextStyles.body(
                    size: 15,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const TrustRing(score: 96, size: 42),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Text('🔍', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tìm quán, món, vibe…',
                style: AppTextStyles.body(size: 14, color: AppColors.ink50),
              ),
            ),
            const Text('🎙️', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

class _GenreSection extends StatelessWidget {
  const _GenreSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Eyebrow('BẠN THÈM GENRE GÌ?'),
              const Spacer(),
              Text(
                'Xem tất cả',
                style: AppTextStyles.body(
                  size: 12,
                  weight: FontWeight.w600,
                  color: AppColors.berry,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _HorizontalDraggableGenreList(
          items: [
            (
              'Lẩu sùng sục',
              '🍲',
              const LinearGradient(
                colors: [AppColors.berry, AppColors.berryDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            (
              'Nướng xì xèo',
              '🥩',
              const LinearGradient(
                colors: [AppColors.wisteria, AppColors.wisteriaDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            (
              'Cafe chill',
              '☕',
              const LinearGradient(
                colors: [AppColors.ocean, AppColors.oceanDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            (
              'Ăn vặt phố',
              '🍢',
              LinearGradient(
                colors: [
                  AppColors.glaucous,
                  AppColors.glaucous.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _VibeSection extends StatelessWidget {
  final Set<String> activeVibes;
  final void Function(String vibe) onToggle;

  const _VibeSection({required this.activeVibes, required this.onToggle});

  static const _vibes = [
    '❄️ Máy lạnh',
    '🌿 Vỉa hè',
    '🔇 Khuất hẻm',
    '✨ Sang chảnh',
    '🌙 Ngồi khuya',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Eyebrow('… HAY MUỐN VIBE NÀO?'),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _vibes.map((v) {
              final active = activeVibes.contains(v);
              return AnmChip(
                label: v,
                active: active,
                color: AppColors.ocean,
                onTap: () => onToggle(v),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─── Genre carousel (unchanged from previous implementation) ────────────────

class _HorizontalDraggableGenreList extends StatefulWidget {
  final List<(String label, String emoji, LinearGradient gradient)> items;

  const _HorizontalDraggableGenreList({required this.items});

  @override
  State<_HorizontalDraggableGenreList> createState() =>
      _HorizontalDraggableGenreListState();
}

class _HorizontalDraggableGenreListState
    extends State<_HorizontalDraggableGenreList> {
  late final ScrollController _scrollCtrl;
  bool _isDragging = false;
  double _dragStart = 0;
  double _scrollStart = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMouseDown(PointerDownEvent event) {
    setState(() => _isDragging = true);
    _dragStart = event.position.dx;
    _scrollStart = _scrollCtrl.offset;
  }

  void _onMouseMove(PointerMoveEvent event) {
    if (!_isDragging) return;
    final delta = event.position.dx - _dragStart;
    _scrollCtrl.jumpTo(_scrollStart - delta);
  }

  void _onMouseUp(PointerUpEvent event) {
    setState(() => _isDragging = false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onMouseDown,
      onPointerMove: _onMouseMove,
      onPointerUp: _onMouseUp,
      child: MouseRegion(
        cursor: _isDragging
            ? SystemMouseCursors.grabbing
            : SystemMouseCursors.grab,
        child: SizedBox(
          height: 90,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ...widget.items.indexed.map((indexed) {
                    final (i, (label, emoji, gradient)) = indexed;
                    return Row(
                      children: [
                        if (i > 0) const SizedBox(width: 10),
                        _GenreCard(
                          label: label,
                          emoji: emoji,
                          gradient: gradient,
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GenreCard extends StatefulWidget {
  final String label;
  final String emoji;
  final LinearGradient gradient;

  const _GenreCard({
    required this.label,
    required this.emoji,
    required this.gradient,
  });

  @override
  State<_GenreCard> createState() => _GenreCardState();
}

class _GenreCardState extends State<_GenreCard>
    with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _emojiCtrl;
  late final Animation<double> _emojiFloat;

  @override
  void initState() {
    super.initState();
    final durationMs = 1800 + (widget.emoji.hashCode.abs() % 500);
    _emojiCtrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );
    _emojiFloat = Tween<double>(
      begin: 0.0,
      end: -7.0,
    ).animate(CurvedAnimation(parent: _emojiCtrl, curve: Curves.easeInOut));
    final delayMs = (widget.label.length * 160) % 700;
    Future.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) _emojiCtrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedScale(
        scale: _hovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 140,
          height: 90,
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.colors.first.withValues(
                  alpha: _hovered ? 0.48 : 0.30,
                ),
                blurRadius: _hovered ? 20 : 10,
                offset: Offset(0, _hovered ? 8 : 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 10,
                top: 10,
                child: AnimatedBuilder(
                  animation: _emojiFloat,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _hovered ? -7 : _emojiFloat.value),
                    child: child,
                  ),
                  child: Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Text(
                  widget.label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestaurantRow extends StatefulWidget {
  final String name;
  final String tag;
  final String dist;
  final int peopleCraving;
  final bool hot;

  const _RestaurantRow({
    required this.name,
    required this.tag,
    required this.dist,
    required this.peopleCraving,
    required this.hot,
  });

  @override
  State<_RestaurantRow> createState() => _RestaurantRowState();
}

class _RestaurantRowState extends State<_RestaurantRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(12),
        transform: Matrix4.translationValues(0, _hovered ? -3 : 0, 0),
        decoration: BoxDecoration(
          color: _hovered ? const Color(0xFFF8FFFB) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: _hovered ? 0.09 : 0.05),
              blurRadius: _hovered ? 20 : 12,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const PhotoSlot(width: 68, height: 68, radius: 14, label: '📸'),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.name,
                          style: AppTextStyles.body(
                            size: 14,
                            weight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.hot)
                        const Text('🔥', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${widget.tag} · ${widget.dist}',
                    style: AppTextStyles.body(size: 12, color: AppColors.ink50),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.berry.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Sparkle(size: 9, color: AppColors.berry),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.peopleCraving} người đang thèm',
                          style: AppTextStyles.mono(
                            size: 9,
                            weight: FontWeight.w700,
                            color: AppColors.berry,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink10, width: 1),
              ),
              child: const Center(
                child: Text(
                  '→',
                  style: TextStyle(fontSize: 16, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

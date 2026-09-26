import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_mate_mapper.dart';
import '../v2_state.dart';

/// **C2 · Quẹt gửi lời mời** — a deck of real candidates from the
/// wishlist-overlap ranking (`GET /api/v1/matches`), after the 2026-09-26
/// mockup: drag right to invite, left to pass, or use the buttons. Each card
/// shows only what the API knows — age, the foods you both like, the
/// candidate's own tags, the taste-overlap % — never an invented intent,
/// distance or district. With no real candidate for this viewer the deck is
/// [kSampleMates], labelled as samples and swiped without touching the API.
class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
      child: _Deck(s: s),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('Gửi lời mời', 'Send an invite'),
                style: AppTextV2.section().copyWith(fontSize: 25, letterSpacing: -0.75),
              ),
              const SizedBox(height: 3),
              Text(
                s.t('Quẹt theo gu ăn, không theo ngoại hình', 'Swipe on taste, not looks'),
                style: AppTextV2.meta(color: AppColorsV2.inkA(0.55))
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (s.isSampleDeck) ...[
              _Pill(
                text: s.t('Dữ liệu mẫu', 'Sample data'),
                color: AppColorsV2.wisteriaTint,
                ink: const Color(0xFF6D28D9),
              ),
              const SizedBox(height: 6),
            ],
            if (s.deckTotal > 0)
              _Pill(
                text: '${s.deckPosition} / ${s.deckTotal}',
                color: Colors.white,
                ink: AppColorsV2.ink,
                shadow: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.ink, this.shadow = false});
  final String text;
  final Color color;
  final Color ink;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: shadow ? AppShadowsV2.pill : null,
      ),
      child: Text(
        text,
        style: AppTextV2.name(color: ink, size: 12)
            .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColorsV2.wisteriaTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(text, style: AppTextV2.name(color: const Color(0xFF6D28D9), size: 12)),
    );
  }
}

/// The card stack and its buttons. Owns the drag: the top card follows the
/// finger, and past [_threshold] (or on a fling) flies off and becomes an
/// invite (right) or a pass (left).
class _Deck extends StatefulWidget {
  const _Deck({required this.s});
  final V2State s;

  @override
  State<_Deck> createState() => _DeckState();
}

class _DeckState extends State<_Deck> with SingleTickerProviderStateMixin {
  static const _threshold = 100.0;

  late final AnimationController _anim;
  double _dx = 0;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 240))
      ..addListener(() => setState(() => _dx = _from + (_to - _from) * Curves.easeOut.transform(_anim.value)));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  bool get _busy => _anim.isAnimating || widget.s.inviteLoading;

  void _animateTo(double target, [VoidCallback? then]) {
    _from = _dx;
    _to = target;
    _anim.forward(from: 0).then((_) => then?.call());
  }

  void _fly(int dir) {
    if (_busy || !widget.s.hasCandidates) return;
    final width = context.size?.width ?? 400;
    _animateTo(dir * (width + 160), () {
      if (!mounted) return;
      dir > 0 ? widget.s.inviteMate() : widget.s.skipMate();
      setState(() => _dx = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    final head = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(s: s),
        if (s.isSampleDeck) ...[
          const SizedBox(height: 10),
          _Banner(
            text: s.sampleBecauseSignedOut
                ? s.t('Đăng nhập để gặp mates hợp gu thật. Đây là hồ sơ mẫu để bạn thử.',
                    'Sign in to meet real matching mates. These are sample profiles to try.')
                : s.t('Chưa có mates hợp gu với bạn. Đây là hồ sơ mẫu để bạn thử quẹt.',
                    'No matching mates yet. These are sample profiles to try swiping.'),
          ),
        ],
        if (s.pendingNotice case final notice?) ...[
          const SizedBox(height: 10),
          _Banner(text: notice),
        ],
        const SizedBox(height: 14),
      ],
    );

    final Widget body;
    var dealing = false;
    if (s.candidatesError != null) {
      body = _Empty(
        title: s.t('Không tải được danh sách mates', "Couldn't load candidates"),
        body: s.t('Kiểm tra kết nối rồi thử lại.', 'Check your connection and try again.'),
        action: s.t('Thử lại', 'Retry'),
        onAction: () => s.loadCandidates(force: true),
      );
    } else if (s.deckFinished) {
      body = _Empty(
        art: A.coffee,
        title: s.isSampleDeck
            ? s.t('Bạn đã xem hết ${s.deckTotal} hồ sơ mẫu', "You've seen all ${s.deckTotal} sample profiles")
            : s.t('Bạn đã xem hết mates hợp gu lúc này', "You've seen every matching mate for now"),
        body: s.t('Thêm món vào wishlist để gặp thêm người hợp gu.',
            'Add foods to your wishlist to meet more matching mates.'),
        action: s.isSampleDeck ? s.t('Xem lại từ đầu', 'Start over') : s.t('Tải lại', 'Reload'),
        onAction: s.isSampleDeck ? s.restartSampleDeck : () => s.loadCandidates(force: true),
        undo: s.canUndo ? s.undoSwipe : null,
      );
    } else if (!s.hasCandidates) {
      body = const CircularProgressIndicator(strokeWidth: 2.2, color: AppColorsV2.wisteria);
    } else {
      dealing = true;
      body = ConstrainedBox(
        // What a card needs to show everything; with less room (a phone held
        // sideways, large text) the card keeps this height and scrolls.
        constraints: BoxConstraints(minHeight: 350 + V2Layout.textGrowth(context, 90)),
        child: _Stack(
          deck: s.deck,
          dx: _dx,
          sample: s.isSampleDeck,
          s: s,
          onDrag: (d) {
            if (!_busy) setState(() => _dx += d);
          },
          onRelease: (velocity) {
            if (_busy) return;
            if (_dx > _threshold || velocity > 900) {
              _fly(1);
            } else if (_dx < -_threshold || velocity < -900) {
              _fly(-1);
            } else {
              _animateTo(0);
            }
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(slivers: [
            SliverToBoxAdapter(child: head),
            SliverFillRemaining(
              hasScrollBody: false,
              child: dealing ? body : Center(child: body),
            ),
          ]),
        ),
        if (dealing) ...[
          const SizedBox(height: 12),
          _actions(s),
        ],
      ],
    );
  }

  Widget _actions(V2State s) {
    return Row(children: [
      _Round(
        key: const Key('swipe-undo'),
        size: 48,
        label: s.t('Hoàn tác', 'Undo'),
        icon: Icons.replay_rounded,
        onTap: s.canUndo ? s.undoSwipe : null,
      ),
      const SizedBox(width: 12),
      _Round(
        size: 60,
        label: s.t('Bỏ qua', 'Pass'),
        icon: Icons.close_rounded,
        onTap: () => _fly(-1),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: () => _fly(1),
          child: Container(
            height: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: AppGradientsV2.cta,
              borderRadius: BorderRadius.circular(999),
              boxShadow: AppShadowsV2.ctaGlow(opacity: 0.4),
            ),
            child: s.inviteLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        s.t('Gửi lời mời đi ăn', 'Send dining invite'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextV2.cta().copyWith(fontSize: 15),
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    ]);
  }
}

/// The top card plus up to two peeking behind it.
class _Stack extends StatelessWidget {
  const _Stack({
    required this.deck,
    required this.dx,
    required this.sample,
    required this.s,
    required this.onDrag,
    required this.onRelease,
  });

  final List<Mate> deck;
  final double dx;
  final bool sample;
  final V2State s;
  final ValueChanged<double> onDrag;
  final ValueChanged<double> onRelease;

  @override
  Widget build(BuildContext context) {
    final behind = deck.skip(1).take(2).toList();
    return Padding(
      // Room below for the cards peeking out behind the top one.
      padding: const EdgeInsets.only(bottom: 18),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var k = behind.length - 1; k >= 0; k--)
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, 9.0 * (k + 1)),
                child: Transform.scale(
                  scale: 1 - 0.045 * (k + 1),
                  alignment: Alignment.bottomCenter,
                  child: _CardBack(mate: behind[k]),
                ),
              ),
            ),
          Positioned.fill(
            child: GestureDetector(
              key: const Key('swipe-top-card'),
              onHorizontalDragUpdate: (d) => onDrag(d.delta.dx),
              onHorizontalDragEnd: (d) => onRelease(d.primaryVelocity ?? 0),
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: Transform.rotate(
                  angle: dx / 900,
                  child: _Card(mate: deck.first, sample: sample, s: s, dx: dx),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card waiting behind the top one: only its edge shows, so it carries no
/// text (scaled down, text would drop below the 11pt floor).
class _CardBack extends StatelessWidget {
  const _CardBack({required this.mate});
  final Mate mate;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10366E).withValues(alpha: 0.1),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        Expanded(child: ColoredBox(color: _bedFor(mate), child: const SizedBox.expand())),
        const SizedBox(height: 150),
      ]),
    );
  }
}

Color _bedFor(Mate mate) =>
    AppColorsV2.tileBeds[mate.userId.hashCode.abs() % AppColorsV2.tileBeds.length];

class _Card extends StatelessWidget {
  const _Card({required this.mate, required this.sample, required this.s, required this.dx});
  final Mate mate;
  final bool sample;
  final V2State s;
  final double dx;

  @override
  Widget build(BuildContext context) {
    final bed = _bedFor(mate);
    final invite = (dx / 100).clamp(0.0, 1.0);
    final pass = (-dx / 100).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10366E).withValues(alpha: 0.2),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ColoredBox(
                    color: bed,
                    child: FoodArt(asset: mate.img, fillFraction: 0.62, shadowOpacity: 0.16, shadowBlur: 14),
                  ),
                ),
                Positioned(
                  top: 14, right: 14,
                  child: _Pill(
                    text: s.en ? '${mate.match}% match' : '${mate.match}% hợp gu',
                    color: Colors.white.withValues(alpha: 0.94),
                    ink: const Color(0xFF6D28D9),
                  ),
                ),
                if (sample)
                  Positioned(
                    top: 14, left: 14,
                    child: _Pill(
                      text: s.t('Dữ liệu mẫu', 'Sample data'),
                      color: AppColorsV2.ink.withValues(alpha: 0.74),
                      ink: Colors.white,
                    ),
                  ),
                ...[
                  Positioned(
                    top: 56, left: 18,
                    child: _Stamp(text: s.t('MỜI ĂN', 'INVITE'), color: AppColorsV2.wisteria, angle: -0.2, opacity: invite),
                  ),
                  Positioned(
                    top: 56, right: 18,
                    child: _Stamp(text: s.t('BỎ QUA', 'PASS'), color: AppColorsV2.ink, angle: 0.2, opacity: pass),
                  ),
                ],
                Positioned(
                  left: 18, bottom: -28,
                  child: MateAvatar(name: mate.name, userId: mate.userId, url: mate.avatarUrl, size: 62),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 36, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        mate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextV2.section().copyWith(fontSize: 22, letterSpacing: -0.6),
                      ),
                    ),
                    if (mate.age != null) ...[
                      const SizedBox(width: 8),
                      Text('${mate.age}', style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 17)),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(s.t('CÙNG THÍCH', 'BOTH LIKE'), style: AppTextV2.eyebrow()),
                const SizedBox(height: 6),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  if (mate.overlapFoods.isEmpty)
                    _FoodChip(label: s.t('Chưa rõ món chung', 'No shared food yet')),
                  for (final f in mate.overlapFoods.take(4))
                    _FoodChip(label: tasteLabel(f), art: tasteArt(f)),
                ]),
                if (mate.tags.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final t in mate.tags.take(3))
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AppColorsV2.inkA(0.12), width: 1.5),
                        ),
                        child: Text(
                          tasteLabel(t),
                          style: AppTextV2.name(color: AppColorsV2.inkA(0.66), size: 12)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodChip extends StatelessWidget {
  const _FoodChip({required this.label, this.art});
  final String label;
  final String? art;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(art == null ? 11 : 5, 4, 11, 4),
      decoration: BoxDecoration(
        color: AppColorsV2.wisteriaTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (art case final a?) ...[
          SizedBox.square(dimension: 22, child: FoodArt(asset: a, shadowOpacity: 0)),
          const SizedBox(width: 5),
        ],
        Text(label, style: AppTextV2.name(color: const Color(0xFF5B21B6), size: 12.5)),
      ]),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({required this.text, required this.color, required this.angle, required this.opacity});
  final String text;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 3),
            ),
            child: Text(
              text,
              style: AppTextV2.section(color: color).copyWith(fontSize: 20, letterSpacing: 1),
            ),
          ),
        ),
      ),
    );
  }
}

class _Round extends StatelessWidget {
  const _Round({super.key, required this.size, required this.label, required this.icon, required this.onTap});
  final double size;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadowsV2.pill,
            ),
            child: Icon(icon, size: size * 0.42, color: AppColorsV2.inkA(size > 50 ? 0.85 : 0.55)),
          ),
        ),
      ),
    );
  }
}

/// What the deck area shows with no card: an error, or every card swiped.
class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.art,
    this.undo,
  });

  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;
  final String? art;
  final VoidCallback? undo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadowsV2.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (art case final a?) ...[
            SizedBox(width: 120, height: 96, child: FoodArt(asset: a, shadowOpacity: 0.12)),
            const SizedBox(height: 10),
          ],
          Text(title, textAlign: TextAlign.center, style: AppTextV2.section().copyWith(fontSize: 19)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppTextV2.body(color: AppColorsV2.inkA(0.6), size: 13)),
          const SizedBox(height: 14),
          V2Cta(label: action, height: 50, fontSize: 15, onTap: onAction),
          if (undo != null)
            V2TapTarget(
              onTap: undo,
              child: Text(
                context.read<V2State>().t('Hoàn tác lượt vừa rồi', 'Undo the last swipe'),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

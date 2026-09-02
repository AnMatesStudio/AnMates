import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **E1 · Profile** — sticker hero, the spots you've been to as a fanned deck,
/// and reviews you can only write after a verified check-in.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 268,
            child: Stack(clipBehavior: Clip.none, children: [
              for (final st in kMeStickers)
                Positioned(
                  left: st.left, top: st.top, width: st.size, height: st.size,
                  child: Transform.rotate(
                    angle: st.rot * 0.017453,
                    child: FoodArt(asset: st.img, shadowOpacity: 0.26, shadowBlur: 14),
                  ),
                ),
              Positioned(
                top: 104, left: 16, right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    V2BackButton(size: 40, onTap: () => s.go(V2Screen.home)),
                    GestureDetector(
                      onTap: () => s.go(V2Screen.pay),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: AppShadowsV2.pill,
                        ),
                        child: Text(s.t('Nâng cấp', 'Upgrade'),
                            style: AppTextV2.name(
                                color: AppColorsV2.wisteria, size: 11.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -96),
            child: Container(
              padding: const EdgeInsets.only(bottom: 26),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0xE0FFFFFF), Colors.white],
                  stops: [0, 0.14, 0.22],
                ),
              ),
              child: Column(children: [
                const SizedBox(height: 56),
                Container(
                  width: 116, height: 116, padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A285A).withValues(alpha: 0.26),
                        blurRadius: 34,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(backgroundImage: AssetImage(A.avatar)),
                ),
                const SizedBox(height: 12),
                Text('Yuna',
                    style: AppTextV2.section().copyWith(fontSize: 26, letterSpacing: -0.78)),
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(s.meMeta, textAlign: TextAlign.center,
                      style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12)),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 7, runSpacing: 7, alignment: WrapAlignment.center,
                  children: [
                    for (final t in [
                      s.t('Hệ đại tiệc', 'Big-feast tier'),
                      s.t('Ăn cay được', 'Handles spice'),
                      s.t('Về trước 22h', 'Home by 10pm'),
                    ])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F1FD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(t,
                            style: AppTextV2.name(
                                    color: AppColorsV2.wisteria, size: 11.5)
                                .copyWith(fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    Expanded(child: _MiniStat(value: '24', label: s.t('bữa đã ăn', 'meals'))),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(value: '17', label: 'mates')),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(value: '12', label: 'review')),
                  ]),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _TrustRow(s: s),
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(s.t("Quán bạn đã đi", "Spots you've been to"),
                        style: AppTextV2.section()
                            .copyWith(fontSize: 18, letterSpacing: -0.36)),
                  ),
                ),
                const SizedBox(height: 14),
                _VisitedDeck(s: s),
                const SizedBox(height: 2),
                Text(s.t('Chạm vào thẻ để mở lại quán', 'Tap a card to reopen the spot'),
                    style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                        .copyWith(fontSize: 11)),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('Review của bạn', 'Your reviews'),
                          style: AppTextV2.section()
                              .copyWith(fontSize: 18, letterSpacing: -0.36)),
                      const SizedBox(height: 3),
                      Text(
                        s.t('Chỉ viết được sau khi check-in đã xác thực',
                            'Only written after a verified check-in'),
                        style: AppTextV2.meta().copyWith(fontSize: 11.5),
                      ),
                      const SizedBox(height: 12),
                      for (final r in kMyReviews) ...[
                        _ReviewCard(s: s, review: r),
                        const SizedBox(height: 11),
                      ],
                      const SizedBox(height: 5),
                      _UpgradeCard(s: s),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColorsV2.inkA(0.07)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextV2.stat().copyWith(fontSize: 19)),
          const SizedBox(height: 3),
          Text(label, style: AppTextV2.meta().copyWith(
            fontSize: 10, fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.trust),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColorsV2.inkA(0.07)),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Row(children: [
          SizedBox(
            width: 56, height: 56,
            child: CustomPaint(
              painter: TrustRingPainter(pct: s.trust / 100),
              child: Center(
                child: Container(
                  width: 44, height: 44, alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle,
                  ),
                  child: Text('${s.trust}',
                      style: AppTextV2.section().copyWith(fontSize: 16, letterSpacing: 0)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trust Score', style: AppTextV2.name(size: 13.5)),
                const SizedBox(height: 3),
                Text(s.trustTier,
                    style: AppTextV2.body(size: 11.5).copyWith(height: 1.4)),
              ],
            ),
          ),
          Text('›', style: AppTextV2.name(color: AppColorsV2.wisteria, size: 19)),
        ]),
      ),
    );
  }
}

/// `conic-gradient(#8B5CF6 <pct>, …)` — the Trust dial.
class TrustRingPainter extends CustomPainter {
  const TrustRingPainter({required this.pct, this.trackColor = const Color(0xFFEFEAFB)});

  final double pct;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawArc(rect, 0, 6.2832, true, Paint()..color = trackColor);
    canvas.drawArc(
      rect, -1.5708, 6.2832 * pct.clamp(0.0, 1.0), true,
      Paint()..color = AppColorsV2.wisteria,
    );
  }

  @override
  bool shouldRepaint(TrustRingPainter old) => old.pct != pct;
}

/// The fanned deck of visited spots — cards overlap by 44px and each sits at its
/// own angle, so the stack reads as a hand of photos.
class _VisitedDeck extends StatelessWidget {
  const _VisitedDeck({required this.s});
  final V2State s;

  static const _rots = [-7.0, -2.5, 3.0, 8.0];
  static const _lifts = [6.0, 0.0, 3.0, 11.0];

  @override
  Widget build(BuildContext context) {
    // Cards are 118 wide and overlap by 44, so each one steps 74px along.
    const step = 74.0;
    const width = 118 + step * 3;

    return SizedBox(
      height: 176,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: SizedBox(
          width: width,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var i = 0; i < kVisited.length; i++)
                Positioned(
                  left: i * step,
                  top: _lifts[i],
                  child: Transform.rotate(
                    angle: _rots[i] * 0.017453,
                    child: GestureDetector(
                      onTap: () => s.openPlace(i),
                      child: _VisitedCard(s: s, i: i),
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

class _VisitedCard extends StatelessWidget {
  const _VisitedCard({required this.s, required this.i});
  final V2State s;
  final int i;

  @override
  Widget build(BuildContext context) {
    final v = kVisited[i];
    return Container(
      width: 118, height: 150,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFE8F1FE), Color(0xFFF7FAFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A285A).withValues(alpha: 0.22),
            blurRadius: 26,
            offset: const Offset(-6, 12),
          ),
        ],
      ),
      child: Stack(children: [
        Positioned(
          left: 4, top: 36, width: 68, height: 64,
          child: FoodArt(asset: v.img, shadowOpacity: 0.18, shadowBlur: 13),
        ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0x0008142C), Color(0xCC08142C)],
                stops: [0.46, 0.9],
              ),
            ),
          ),
        ),
        Positioned(
          top: 9, left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColorsV2.whiteA(0.92),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(s.tr(v.when), style: AppTextV2.name(size: 8.5)),
          ),
        ),
        Positioned(
          left: 8, bottom: 9,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColorsV2.whiteA(0.94),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('★ ${v.stars}',
                    style: AppTextV2.section(color: AppColorsV2.wisteria)
                        .copyWith(fontSize: 9.5, letterSpacing: 0)),
              ),
              const SizedBox(height: 3),
              Text(s.tr(v.short),
                  style: AppTextV2.name(color: AppColorsV2.whiteA(0.78), size: 9)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.s, required this.review});

  final V2State s;
  final ({String img, String name, String stars, T meta, T text, List<T> tags, T helpful}) review;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColorsV2.inkA(0.07)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadowsV2.pill,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFFE8F1FE), Color(0xFFF7FAFF)],
                ),
              ),
              child: FoodArt(
                asset: review.img, fillFraction: 0.78,
                shadowOpacity: 0.1, shadowBlur: 8,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(review.name, style: AppTextV2.name(size: 13.5)),
                  const SizedBox(height: 2),
                  Text(s.tr(review.meta),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextV2.meta()),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F1FD),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('★ ${review.stars}',
                  style: AppTextV2.section(color: AppColorsV2.wisteria)
                      .copyWith(fontSize: 10.5, letterSpacing: 0)),
            ),
          ]),
          const SizedBox(height: 11),
          Text(s.tr(review.text),
              style: AppTextV2.body(color: AppColorsV2.inkA(0.68), size: 12.5)
                  .copyWith(height: 1.6)),
          const SizedBox(height: 11),
          Row(children: [
            Expanded(
              child: Wrap(spacing: 7, runSpacing: 7, children: [
                for (final tg in review.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F7FD),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(s.tr(tg),
                        style: AppTextV2.meta(color: AppColorsV2.inkA(0.55))
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
              ]),
            ),
            const SizedBox(width: 8),
            Text(s.tr(review.helpful),
                style: AppTextV2.meta(color: AppColorsV2.inkA(0.38))),
          ]),
        ],
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.pay),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColorsV2.ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('Nâng cấp Ăn Mates', 'Upgrade AnMates'),
                    style: AppTextV2.name(color: Colors.white, size: 15)),
                const SizedBox(height: 5),
                Text(
                  s.t('Miễn nhiễm Gating, Trust Booster, voice chat, bể match tinh anh.',
                      'Gating immunity, Trust Booster, voice chat, elite match pool.'),
                  style: AppTextV2.body(color: AppColorsV2.whiteA(0.68), size: 11.5)
                      .copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text('›', style: AppTextV2.name(color: AppColorsV2.wisteria, size: 20)),
        ]),
      ),
    );
  }
}

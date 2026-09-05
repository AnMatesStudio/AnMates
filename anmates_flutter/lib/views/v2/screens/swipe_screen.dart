import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C2 · Quẹt gửi lời mời** — real candidates from a wishlist-overlap ranking
/// (`GET /api/v1/matches`). The design's card also carried a Trust Score pill,
/// an "urgency" badge ("Cần ăn trong 1H"), and a free-text "dining intent"
/// sentence — none of it backed by the schema, so none of it survived. What's
/// shown instead is exactly what the API knows: the candidate's real tags and
/// the foods you both share.
class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  s.t('Gửi lời mời', 'Send an invite'),
                  style: AppTextV2.section()
                      .copyWith(fontSize: 25, letterSpacing: -0.75),
                ),
              ),
              Flexible(
                child: Text(
                  s.t('Quẹt theo ý định ăn', 'Swipe on intent, not looks'),
                  textAlign: TextAlign.end,
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.5))
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (s.pendingNotice case final notice?) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColorsV2.wisteriaTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(notice,
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12)),
            ),
          ],
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 24),
                  child: Center(child: _Body(s: s)),
                ),
              ),
            ),
          ),
          if (s.hasCandidates) ...[
            Row(children: [
              GestureDetector(
                onTap: s.skipMate,
                child: Container(
                  width: 60, height: 60, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10366E).withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Text('✕',
                      style: AppTextV2.body(color: AppColorsV2.inkA(0.4), size: 21)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: s.inviteLoading ? null : s.inviteMate,
                  child: Container(
                    height: 60, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppGradientsV2.cta,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: AppShadowsV2.ctaGlow(opacity: 0.4),
                    ),
                    child: s.inviteLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Text(
                            s.t('Gửi lời mời đi ăn', 'Send dining invite'),
                            style: AppTextV2.cta().copyWith(fontSize: 15),
                          ),
                  ),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    if (s.candidatesLoading) {
      return const CircularProgressIndicator(strokeWidth: 2.2, color: AppColorsV2.wisteria);
    }
    if (!s.hasCandidates) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.candidatesError != null
                  ? s.t('Không tải được danh sách mates', "Couldn't load candidates")
                  : s.t('Chưa có ai hợp gu để gợi ý lúc này',
                      'No matching candidates right now'),
              textAlign: TextAlign.center,
              style: AppTextV2.name(size: 14),
            ),
            const SizedBox(height: 8),
            Text(
              s.t('Thêm món vào wishlist để tìm được người hợp gu hơn.',
                  'Add more foods to your wishlist to find better matches.'),
              textAlign: TextAlign.center,
              style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => s.loadCandidates(force: true),
              child: Text(s.t('Thử lại', 'Retry'),
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12)),
            ),
          ],
        ),
      );
    }
    return _MateCard(s: s);
  }
}

class _MateCard extends StatelessWidget {
  const _MateCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final mate = s.mate;
    return Container(
      key: ValueKey(mate.userId),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10366E).withValues(alpha: 0.24),
            blurRadius: 46,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Portrait(s: s),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mate.age == null ? mate.name : '${mate.name}, ${mate.age}',
                  style: AppTextV2.section()
                      .copyWith(fontSize: 21, letterSpacing: -0.525),
                ),
                if (mate.tags.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(spacing: 7, runSpacing: 7, children: [
                    for (final tag in mate.tags.take(5))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF2FE),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          tag.replaceAll('_', ' '),
                          style: AppTextV2.name(
                            color: const Color(0xFF1A56DB), size: 11.5,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                  ]),
                ],
                const SizedBox(height: 12),
                _Overlap(s: s),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: mate.match / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEDF1F7),
                        valueColor: const AlwaysStoppedAnimation(
                            AppColorsV2.wisteria),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    s.en ? '${mate.match}% taste match' : '${mate.match}% hợp gu',
                    style: AppTextV2.name(
                        color: AppColorsV2.wisteria, size: 11.5),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final mate = s.mate;
    return SizedBox(
      height: 172,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFE7F0FF), Color(0xFFF7FAFF)],
          ),
        ),
        child: FoodArt(
          asset: mate.img, fillFraction: 0.62,
          shadowOpacity: 0.16, shadowBlur: 14,
        ),
      ),
    );
  }
}

/// Real overlap facts from the API — replaces the design's invented "dining
/// intent" sentence ("Muốn ăn lẩu bò tối nay, chia đều 4 người").
class _Overlap extends StatelessWidget {
  const _Overlap({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final foods = s.mate.overlapFoods;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('CÙNG THÍCH', 'BOTH LIKE'),
            style: AppTextV2.eyebrow().copyWith(fontSize: 10),
          ),
          const SizedBox(height: 5),
          Text(
            foods.isEmpty
                ? s.t('Chưa rõ điểm chung', 'No shared foods on file yet')
                : foods.map((f) => f.replaceAll('_', ' ')).join(', '),
            style: AppTextV2.name(size: 14).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

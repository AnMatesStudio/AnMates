import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **B2 · Chi tiết quán** — the AI culinary summary, five lines, cons in red.
class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final place = s.place;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 300,
            child: Stack(children: [
              Positioned(
                left: 0, right: 0, bottom: 34, height: 230,
                child: FloatingArt(
                  period: const Duration(milliseconds: 6000),
                  child: FoodArt(
                    asset: place.img, fillFraction: 0.76,
                    shadowOpacity: 0.26, shadowBlur: 26,
                  ),
                ),
              ),
              Positioned(
                top: 104, left: 18,
                child: V2BackButton(size: 40, onTap: () => s.go(V2Screen.home)),
              ),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -96),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              child: Column(children: [
                const SizedBox(height: 104),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColorsV2.inkA(0.06)),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A285A).withValues(alpha: 0.08),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        place.name,
                        style: AppTextV2.section()
                            .copyWith(fontSize: 25, height: 1.14, letterSpacing: -0.75),
                      ),
                      const SizedBox(height: 6),
                      Text(s.tr(place.meta),
                          style: AppTextV2.body(color: AppColorsV2.inkA(0.48), size: 12.5)),
                      const SizedBox(height: 16),
                      _AiSummary(s: s),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _Stat(
                          value: s.wantingLabel,
                          color: AppColorsV2.wisteria,
                          label: s.t('người muốn đi tối nay', 'want to go tonight'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _Stat(
                          value: s.tr(place.group),
                          color: AppColorsV2.ink,
                          label: s.t('nhóm tối ưu để chia món', 'ideal group to split this'),
                        )),
                      ]),
                      const SizedBox(height: 16),
                      V2Cta(
                        label: s.t('Tìm mates đi quán này', 'Find mates for this spot'),
                        radius: 20,
                        onTap: () => s.go(V2Screen.swipe),
                      ),
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

class _AiSummary extends StatelessWidget {
  const _AiSummary({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColorsV2.wisteria,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'AI CULINARY SUMMARY',
                style: AppTextV2.name(color: Colors.white, size: 9.5)
                    .copyWith(letterSpacing: 0.76),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.tr(s.place.reviews),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                      .copyWith(fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 12),
          for (final l in s.place.lines) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 82,
                  child: Text(s.tr(l.key),
                      style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.tr(l.value),
                    style: AppTextV2.body(color: l.color ?? AppColorsV2.ink, size: 13)
                        .copyWith(fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ],
            ),
            if (l != s.place.lines.last) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.color, required this.label});

  final String value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextV2.stat(color: color).copyWith(fontSize: 21)),
          const SizedBox(height: 3),
          Text(label, style: AppTextV2.meta().copyWith(
            fontWeight: FontWeight.w600, height: 1.35,
          )),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **D4 · Chốt bữa ăn** — both sides rate privately; nothing shows until both
/// submit, and only the Trust Score moves.
class RateScreen extends StatelessWidget {
  const RateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('Chốt bữa ăn', 'Close out the meal'),
              style: AppTextV2.section()
                  .copyWith(fontSize: 25, height: 1.15, letterSpacing: -0.75)),
          const SizedBox(height: 6),
          Text(
            s.t('Hai bên rate riêng. Không ai thấy điểm của ai cho tới khi cả hai xong, và chỉ Trust Score thay đổi.',
                'Both of you rate privately. Neither rating is shown until both are in, and only the Trust Score moves.'),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5)
                .copyWith(height: 1.5),
          ),
          const SizedBox(height: 16),
          V2Sheet(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [Color(0xFFE7F0FF), Color(0xFFF7FAFF)],
                      ),
                    ),
                    child: FoodArt(
                      asset: s.mate.img, fillFraction: 0.8,
                      shadowOpacity: 0.12, shadowBlur: 10,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.mate.name,
                            style: AppTextV2.section()
                                .copyWith(fontSize: 17, letterSpacing: -0.34)),
                        const SizedBox(height: 2),
                        Text(s.ratePlaceLine,
                            maxLines: 2,
                            style: AppTextV2.meta(color: AppColorsV2.inkA(0.48))
                                .copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                V2Eyebrow(s.t('BỮA ĂN THẾ NÀO?', 'HOW WAS IT?')),
                const SizedBox(height: 10),
                Row(children: [
                  for (var n = 1; n <= 5; n++) ...[
                    Expanded(
                      child: GestureDetector(
                        onTap: () => s.pickStars(n),
                        child: Container(
                          height: 48, alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: n <= s.stars ? AppColorsV2.wisteria : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: n <= s.stars
                                  ? AppColorsV2.wisteria
                                  : AppColorsV2.inkA(0.1),
                              width: 1.5,
                            ),
                          ),
                          child: Text('★',
                              style: AppTextV2.name(
                                color: n <= s.stars ? Colors.white : AppColorsV2.inkA(0.2),
                                size: 17,
                              )),
                        ),
                      ),
                    ),
                    if (n != 5) const SizedBox(width: 8),
                  ],
                ]),
                const SizedBox(height: 10),
                Text(s.starLabel,
                    style: AppTextV2.name(color: AppColorsV2.wisteria, size: 12)
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                V2Eyebrow(s.t('GẮN TAG CHO BỮA ĂN', 'TAG WHAT HAPPENED')),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (var i = 0; i < kRateTags.length; i++)
                    V2Chip(
                      label: s.tr(kRateTags[i]),
                      selected: s.rateTags.contains(i),
                      onTap: () => s.toggleRateTag(i),
                    ),
                ]),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F3FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColorsV2.wisteria,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(s.ratePoints,
                          style: AppTextV2.section(color: Colors.white)
                              .copyWith(fontSize: 13, letterSpacing: 0)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.rateEffect,
                          style: AppTextV2.name(size: 12)
                              .copyWith(fontWeight: FontWeight.w600, height: 1.45)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                V2Cta(
                  label: s.rateCta,
                  height: 54, radius: 20, fontSize: 15.5,
                  onTap: s.submitRate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _EatAgainCard(s: s),
        ],
      ),
    );
  }
}

class _EatAgainCard extends StatelessWidget {
  const _EatAgainCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColorsV2.inkA(0.06)),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadowsV2.pill,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('Ăn tiếp với mate này?', 'Eat again with this mate?'),
              style: AppTextV2.name(size: 12.5)),
          const SizedBox(height: 6),
          Text(
            s.t('Chọn có thì lần sau cặp này bỏ qua Vibe Check — nút hẹn mở ngay từ tin nhắn đầu.',
                'Say yes and the pair skips Vibe Check next time — the scheduling button is open from the first message.'),
            style: AppTextV2.body(size: 11.5).copyWith(height: 1.5),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: V2Cta(
                label: s.t('Có, thêm vào bàn quen', 'Yes, add to my table'),
                height: 44, radius: 15, fontSize: 13,
                onTap: () => s.go(V2Screen.swipe),
              ),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: () => s.go(V2Screen.home),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FD),
                  border: Border.all(color: AppColorsV2.inkA(0.07)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(s.t('Bỏ qua', 'Skip'),
                    style: AppTextV2.name(color: AppColorsV2.inkA(0.6), size: 13)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

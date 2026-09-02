import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **E3 · Gói** — Free → Ultimate, Gold carried in Wisteria as the hero tier.
class PayScreen extends StatelessWidget {
  const PayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 104, 18, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: V2BackButton(onTap: () => s.go(V2Screen.me)),
          ),
          const SizedBox(height: 14),
          Text(s.t('Chọn gói ăn của bạn', 'Pick your eating plan'),
              style: AppTextV2.section()
                  .copyWith(fontSize: 26, height: 1.15, letterSpacing: -0.78)),
          const SizedBox(height: 6),
          Text(s.t('Hủy bất cứ lúc nào. Không phí ẩn.', 'Cancel anytime. No hidden fees.'),
              style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5)),
          const SizedBox(height: 18),
          for (final tier in kTiers) ...[
            _TierCard(s: s, tier: tier),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.s, required this.tier});

  final V2State s;
  final Tier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tier.bg,
        borderRadius: BorderRadius.circular(26),
        boxShadow: tier.elevated
            ? [
                BoxShadow(
                  color: AppColorsV2.wisteria.withValues(alpha: 0.42),
                  blurRadius: 38,
                  offset: const Offset(0, 18),
                ),
              ]
            : (tier.bg == Colors.white
                ? [
                    BoxShadow(
                      color: const Color(0xFF10366E).withValues(alpha: 0.14),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(
              child: Text(tier.name,
                  style: AppTextV2.section(color: tier.fg)
                      .copyWith(fontSize: 17, letterSpacing: 0)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tier.pillBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(tier.price,
                  style: AppTextV2.name(color: tier.pillFg, size: 11)),
            ),
          ]),
          const SizedBox(height: 9),
          Text(s.tr(tier.perks),
              style: AppTextV2.body(color: tier.body, size: 12).copyWith(height: 1.6)),
          if (tier.cta case final cta?) ...[
            const SizedBox(height: 12),
            Container(
              height: 48, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(s.tr(cta),
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 14.5)),
            ),
          ],
        ],
      ),
    );
  }
}

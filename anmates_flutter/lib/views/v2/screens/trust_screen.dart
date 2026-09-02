import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';
import 'me_screen.dart' show TrustRingPainter;

/// **E2 · Trust Score** — the dial, the gating warning below 85, and the history
/// that only moves when the mate you ate with confirms.
class TrustScreen extends StatelessWidget {
  const TrustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: V2BackButton(onTap: () => s.go(V2Screen.me)),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 122, height: 122,
              child: CustomPaint(
                painter: TrustRingPainter(
                  pct: s.trust / 100,
                  trackColor: AppColorsV2.whiteA(0.32),
                ),
                child: Center(
                  child: Container(
                    width: 98, height: 98,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${s.trust}',
                            style: AppTextV2.section()
                                .copyWith(fontSize: 31, letterSpacing: -0.93)),
                        Text('TRUST SCORE',
                            style: AppTextV2.eyebrow(color: AppColorsV2.inkA(0.45))
                                .copyWith(fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(s.trustTier, textAlign: TextAlign.center,
              style: AppTextV2.name(color: AppColorsV2.inkA(0.55), size: 13)),
          const SizedBox(height: 13),
          Center(
            child: GestureDetector(
              onTap: s.simulateFlake,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColorsV2.inkA(0.07)),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: AppShadowsV2.pill,
                ),
                child: Text(s.flakeLabel,
                    style: AppTextV2.name(color: AppColorsV2.inkA(0.6), size: 11)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
          if (s.gated) ...[
            const SizedBox(height: 18),
            _GatingWarning(s: s),
          ],
          const SizedBox(height: 18),
          V2Sheet(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(s.t('Lịch sử uy tín', 'Trust history'),
                          style: AppTextV2.name(size: 14.5)),
                    ),
                    Text(s.t('Check-in + xác thực chéo', 'Check-in + cross-verification'),
                        style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                for (final l in kTrustLog)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F4F9))),
                    ),
                    child: Row(children: [
                      SizedBox(
                        width: 40,
                        child: Text(l.delta,
                            style: AppTextV2.section(
                              color: l.up ? AppColorsV2.wisteria : AppColorsV2.alert,
                            ).copyWith(fontSize: 14, letterSpacing: 0)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s.tr(l.label),
                            style: AppTextV2.name(size: 12.5)
                                .copyWith(fontWeight: FontWeight.w600, height: 1.35)),
                      ),
                      const SizedBox(width: 8),
                      Text(s.tr(l.when),
                          style: AppTextV2.meta(color: AppColorsV2.inkA(0.4))),
                    ]),
                  ),
                const SizedBox(height: 12),
                Text(
                  s.t('Không đặt cọc, không theo dõi GPS ngầm. Điểm chỉ đổi khi mate đi cùng xác nhận.',
                      'No deposits, no silent GPS tracking. Points only move when the mate you ate with confirms.'),
                  style: AppTextV2.body(size: 11.5).copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GatingWarning extends StatelessWidget {
  const _GatingWarning({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F0),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28, height: 28, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColorsV2.alert,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('!',
                style: AppTextV2.section(color: Colors.white)
                    .copyWith(fontSize: 14, letterSpacing: 0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('Đang bị Gating (dưới 85đ)', 'Gating active (below 85)'),
                    style: AppTextV2.name(size: 12.5)),
                const SizedBox(height: 4),
                Text(
                  s.t('Tối đa 3 phòng chat · 3 lượt quẹt/ngày · ẩn số người muốn đi quán. Gói Plus trở lên miễn nhiễm.',
                      'Max 3 chat rooms · 3 swipes a day · the count of people wanting a spot is hidden. Plus and above are immune.'),
                  style: AppTextV2.body(size: 11.5).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

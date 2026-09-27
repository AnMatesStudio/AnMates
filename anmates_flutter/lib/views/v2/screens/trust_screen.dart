import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **E2 · Trust Score** — the real score, computed server-side (GET /profile/trust)
/// from confirmed meals, ratings received and distinct no-show / harassment
/// reporters. The number in the circle is `s.trust.score` (starts at 80, capped
/// to 0–100); the sheet below it shows how the points add up, per category.
class TrustScreen extends StatelessWidget {
  const TrustScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: V2BackButton(onTap: () => s.go(V2Screen.me)),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 122 * V2Layout.unit(context), height: 122 * V2Layout.unit(context),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColorsV2.inkA(0.08)),
              ),
              child: Text(s.trust?.score.toString() ?? '—',
                  key: const Key('trust-score'),
                  style: AppTextV2.section().copyWith(fontSize: 31, letterSpacing: -0.93)),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            s.t('Trust Score', 'Trust Score'),
            textAlign: TextAlign.center,
            style: AppTextV2.name(color: AppColorsV2.inkA(0.55), size: 13),
          ),
          const SizedBox(height: 18),
          V2Sheet(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.t('Điểm được tính thế nào', 'How the score works'),
                    style: AppTextV2.name(size: 14.5)),
                const SizedBox(height: 10),
                Text(
                  s.t('Bắt đầu từ 80 điểm, giới hạn 0–100.', 'Starts at 80, capped to 0–100.'),
                  style: AppTextV2.body(size: 12.5).copyWith(height: 1.55),
                ),
                if (s.trust != null)
                  ...[
                    const SizedBox(height: 14),
                    _trustRow(context, s,
                        s.t('Bữa ăn đã xác nhận', 'Confirmed meals'),
                        '${s.trust!.meals} × +4', positive: true),
                    const SizedBox(height: 8),
                    _trustRow(context, s,
                        s.t('Đánh giá ≥ 4★ nhận được', '4★+ ratings received'),
                        '${s.trust!.goodRatings} × +2', positive: true),
                    const SizedBox(height: 8),
                    _trustRow(context, s,
                        s.t('Người báo bùng hẹn', 'No-show reporters'),
                        '${s.trust!.noShowReports} × −20', positive: false),
                    const SizedBox(height: 8),
                    _trustRow(context, s,
                        s.t('Người báo quấy rối / giả mạo', 'Harassment / fake reporters'),
                        '${s.trust!.otherReports} × −10', positive: false),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trustRow(BuildContext context, V2State s, String label, String points,
      {required bool positive}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTextV2.name(size: 13)),
        Text(
          points,
          style: AppTextV2.name(
              size: 13,
              color: positive ? AppColorsV2.wisteria : AppColorsV2.alert),
        ),
      ],
    );
  }
}

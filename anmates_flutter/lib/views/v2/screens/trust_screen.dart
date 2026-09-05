import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **E2 · Trust Score** — the design's dial, gating warning, and point-history
/// log all assumed a `trust_score` on the user. The schema has no such column
/// anywhere, and no event log to source a history from, so none of it was
/// real: the number moved on a client-side simulation
/// (`simulateFlake()`), not on anything that happened. This is an honest
/// placeholder until a real trust system exists — no fake dial, no fake log,
/// nothing gated on it.
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
            child: Container(
              width: 122, height: 122,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColorsV2.inkA(0.08)),
              ),
              child: Text('—',
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
                Text(s.t('Chưa được theo dõi', 'Not tracked yet'),
                    style: AppTextV2.name(size: 14.5)),
                const SizedBox(height: 10),
                Text(
                  s.t('Tính năng Trust Score đang được xây dựng. Chưa có lịch sử điểm nào — số này sẽ hiện khi hệ thống chấm điểm thật đi vào hoạt động.',
                      "Trust Score is still being built. There's no point history yet — this will populate once real scoring is live."),
                  style: AppTextV2.body(size: 12.5).copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

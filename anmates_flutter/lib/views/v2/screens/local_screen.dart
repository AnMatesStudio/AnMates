import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C3 · Local Mates** — travel mode, locals who eat here every week.
///
/// The design shipped this with three sample locals (name, "Trust 98", a
/// signature spot). None of it maps to anything in the schema — there is no
/// "local guide" role, no per-user trust score, no travel-mode detection — so
/// rather than keep inventing people, this is an honest placeholder until a
/// real local-guide feature exists.
class LocalScreen extends StatelessWidget {
  const LocalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Local Mates',
              style: AppTextV2.section()
                  .copyWith(fontSize: 25, height: 1.15, letterSpacing: -0.75)),
          const SizedBox(height: 6),
          Text(
            s.t('Người bản địa dẫn đi ăn đúng chỗ — không bẫy du lịch.',
                'Locals who take you to the real thing — no tourist traps.'),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  s.t('Tính năng đang được phát triển — chưa có local mate nào.',
                      'This feature is still being built — no local mates yet.'),
                  textAlign: TextAlign.center,
                  style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

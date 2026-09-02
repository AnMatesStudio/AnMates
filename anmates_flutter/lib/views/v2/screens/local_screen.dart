import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C3 · Local Mates** — travel mode, locals who eat here every week.
class LocalScreen extends StatelessWidget {
  const LocalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Local Mates · Đà Nẵng',
              style: AppTextV2.section()
                  .copyWith(fontSize: 25, height: 1.15, letterSpacing: -0.75)),
          const SizedBox(height: 6),
          Text(
            s.t('Đang bật chế độ du lịch. Đây là người bản địa ăn ở đây mỗi tuần — không bẫy du lịch.',
                'Travel mode is on. These locals eat here every week — no tourist traps.'),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
          ),
          const SizedBox(height: 16),
          for (final p in kLocals) ...[
            GestureDetector(
              onTap: () => s.go(V2Screen.chat),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10366E).withValues(alpha: 0.18),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
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
                          asset: p.img, fillFraction: 0.8,
                          shadowOpacity: 0.12, shadowBlur: 10,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                style: AppTextV2.section()
                                    .copyWith(fontSize: 16, letterSpacing: -0.32)),
                            const SizedBox(height: 2),
                            Text(s.tr(p.meta),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: AppTextV2.meta(color: AppColorsV2.inkA(0.48))
                                    .copyWith(fontSize: 11.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColorsV2.wisteriaTint,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(s.tr(p.badge),
                            style: AppTextV2.name(
                                color: AppColorsV2.wisteria, size: 10.5)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.t('SẼ DẪN BẠN ĐI', 'WILL TAKE YOU TO'),
                              style: AppTextV2.eyebrow().copyWith(fontSize: 9.5)),
                          const SizedBox(height: 4),
                          Text(s.tr(p.spot),
                              style: AppTextV2.name(size: 13).copyWith(height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

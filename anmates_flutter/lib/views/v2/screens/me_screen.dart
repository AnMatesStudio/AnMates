import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **E1 · Profile** — the design paired this with a fanned deck of "spots
/// you've been to" and reviews "only written after a verified check-in".
/// Neither has any backing: there's no visited-venue tracking and no
/// user-authored review table anywhere in the schema, so both sections are
/// now an honest placeholder instead of four invented restaurant visits and
/// three invented five-paragraph reviews.
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
                Text(s.profileName.isEmpty ? '—' : s.profileName,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    s.t('Chưa có lịch sử ghé quán — tính năng đang phát triển.',
                        "No visit history yet — this feature is still being built."),
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.48), size: 12.5),
                  ),
                ),
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
                      Text(
                        s.t('Bạn chưa viết review nào.', "You haven't written any reviews yet."),
                        style: AppTextV2.body(color: AppColorsV2.inkA(0.48), size: 12.5),
                      ),
                      const SizedBox(height: 16),
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
          Container(
            width: 56, height: 56, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FD),
              shape: BoxShape.circle,
              border: Border.all(color: AppColorsV2.inkA(0.08)),
            ),
            child: Text('—', style: AppTextV2.section().copyWith(fontSize: 16, letterSpacing: 0)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trust Score', style: AppTextV2.name(size: 13.5)),
                const SizedBox(height: 3),
                Text(s.t('Chưa được theo dõi', 'Not tracked yet'),
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

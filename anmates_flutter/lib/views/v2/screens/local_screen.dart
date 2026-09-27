import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/extras_service.dart';
import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C3 · Local Mates** — people within 5 km with at least one confirmed
/// meal (GET /locals). Each card shows their distance, district and meal
/// count, with a one-tap invite.
class LocalScreen extends StatelessWidget {
  const LocalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
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
          Expanded(child: _body(s)),
        ],
      ),
    );
  }

  Widget _body(V2State s) {
    if (s.localsLoading) {
      return const Center(
        child: CircularProgressIndicator(
            strokeWidth: 2.2, color: AppColorsV2.wisteria),
      );
    }
    if (!s.signedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            s.t('Đăng nhập để xem local mates quanh bạn.',
                'Sign in to see local mates near you.'),
            textAlign: TextAlign.center,
            style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 13),
          ),
        ),
      );
    }
    if (s.locals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            s.t('Chưa có local mate nào trong bán kính 5 km — bật vị trí và thử lại sau.',
                'No local mates within 5 km yet — turn on location and check back later.'),
            textAlign: TextAlign.center,
            style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 13),
          ),
        ),
      );
    }
    return ListView.separated(
      key: const Key('local-list'),
      padding: const EdgeInsets.only(top: 16),
      itemCount: s.locals.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) => _LocalCard(s: s, mate: s.locals[i]),
    );
  }
}

/// One local mate row: avatar, name, distance/meal meta and an invite pill.
class _LocalCard extends StatelessWidget {
  const _LocalCard({required this.s, required this.mate});

  final V2State s;
  final LocalMate mate;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottom = navClearance(context);
    return V2Sheet(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          MateAvatar(
              name: mate.name, userId: mate.userId, url: mate.avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mate.name, style: AppTextV2.name(size: 14.5)),
                const SizedBox(height: 2),
                Text(
                  '${mate.district ?? ''} · ${mate.distanceKm.toStringAsFixed(1)} km · '
                      '${s.t('${mate.meals} bữa', '${mate.meals} meals')}',
                  style: AppTextV2.meta(),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          V2TapTarget(
            onTap: () async {
              final ok = await s.inviteLocal(mate.userId);
              showV2Toast(
                messenger,
                ok
                    ? s.t('Đã gửi lời mời tới ${mate.name}',
                        'Invite sent to ${mate.name}')
                    : s.t('Không gửi được lời mời', 'Could not send the invite'),
                bottom: bottom,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColorsV2.wisteria,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                s.t('Mời đi ăn', 'Invite'),
                style: AppTextV2.name(color: Colors.white, size: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

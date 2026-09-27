import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_kit.dart';
import '../../views/v2/v2_state.dart';

/// Liquid-glass notification sheet (canvas frame B1.2). Sits inset from every
/// edge — `left:10 right:10 top:88 bottom:86` — so the aurora shows around it.
///
/// Notifications now come from GET /notifications (rows written by DB
/// triggers), polled into [V2State] — the sheet just renders them.
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key, required this.onClose, required this.en});

  final VoidCallback onClose;
  final bool en;

  static String _notifTime(DateTime dt, V2State s) {
    final m = DateTime.now().difference(dt).inMinutes;
    if (m < 1) return s.t('vừa xong', 'just now');
    if (m < 60) return s.t('$m phút trước', '${m}m ago');
    final h = m ~/ 60;
    if (h < 24) return s.t('$h giờ trước', '${h}h ago');
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: const Color(0xFF181430).withValues(alpha: 0.28)),
        ),
        Positioned(
          left: 10,
          right: 10,
          // 26pt under the status bar, as in the design frame (62 + 26 = 88).
          top: MediaQuery.paddingOf(context).top + 26,
          // Just above the glass nav (navClearance is 96 + inset; the design used 86).
          bottom: navClearance(context) - 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(color: AppColorsV2.whiteA(0.8)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColorsV2.whiteA(0.82), AppColorsV2.whiteA(0.72)],
                  ),
                ),
                child: Column(
                  children: [
                    V2TapTarget(
                      onTap: onClose,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11, bottom: 3),
                        child: Center(
                          child: Container(
                            width: 38,
                            height: 5,
                            decoration: BoxDecoration(
                              color: AppColorsV2.inkA(0.16),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 9, 20, 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          en ? 'Notifications' : 'Thông báo',
                          style: AppTextV2.section().copyWith(fontSize: 24, letterSpacing: -0.72),
                        ),
                      ),
                    ),
                    Expanded(
                      child: s.notifications.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 30),
                                child: Text(
                                  en ? "You're all caught up — no notifications yet." : 'Chưa có thông báo nào.',
                                  textAlign: TextAlign.center,
                                  style: AppTextV2.name(color: AppColorsV2.inkA(0.48), size: 13),
                                ),
                              ),
                            )
                          : ListView.separated(
                              key: const Key('notif-list'),
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              itemCount: s.notifications.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final n = s.notifications[i];
                                final label = switch (n.kind) {
                                  'match' => '💞',
                                  'message' => '💬',
                                  'booking_proposed' => '📅',
                                  'booking_confirmed' => '✅',
                                  'booking_cancelled' => '❌',
                                  'rating' => '⭐',
                                  _ => '🔔',
                                };
                                return V2TapTarget(
                                  onTap: () => s.openNotification(n),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: n.read ? Colors.white : AppColorsV2.wisteriaTint,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(label, style: const TextStyle(fontSize: 20)),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(s.notifText(n), style: AppTextV2.name(size: 13.5)),
                                              Text(
                                                _notifTime(n.createdAt, s),
                                                style: AppTextV2.meta(),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

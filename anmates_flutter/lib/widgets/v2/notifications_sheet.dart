import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';

/// Liquid-glass notification sheet (canvas frame B1.2). Sits inset from every
/// edge — `left:10 right:10 top:88 bottom:86` — so the aurora shows around it.
///
/// The design shipped six sample notifications (a table invite, a "Vibe Check
/// hit 79%", a bill share, two Trust Score events, a Local Mates offer) — none
/// of them backed by anything: there is no notifications table, no push
/// pipeline, and three of the six referenced mechanics (Vibe Check %, Trust
/// Score, bill split) that don't exist in the schema either. This is an
/// honest empty state until a real notifications system exists.
class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key, required this.onClose, required this.en});

  final VoidCallback onClose;
  final bool en;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: Container(color: const Color(0xFF181430).withValues(alpha: 0.28)),
        ),
        Positioned(
          left: 10,
          right: 10,
          top: 88,
          bottom: 86,
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
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.opaque,
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
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: Text(
                            en ? "You're all caught up — no notifications yet." : 'Chưa có thông báo nào.',
                            textAlign: TextAlign.center,
                            style: AppTextV2.name(color: AppColorsV2.inkA(0.48), size: 13),
                          ),
                        ),
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

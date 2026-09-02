import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme_v2.dart';
import '../../views/v2/v2_data.dart';

/// Liquid-glass notification sheet (canvas frame B1.2). Sits inset from every
/// edge — `left:10 right:10 top:88 bottom:86` — so the aurora shows around it.
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key, required this.onClose, required this.en});

  final VoidCallback onClose;
  final bool en;

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  static const _tabs = <(T, NotifKind?)>[
    (T('Tất cả', 'All'), null),
    (T('Kèo', 'Tables'), NotifKind.table),
    (T('Vibe Check', 'Vibe Check'), NotifKind.vibe),
    (T('Bill', 'Bill'), NotifKind.bill),
    (T('Trust', 'Trust'), NotifKind.trust),
  ];

  int _tab = 0;
  final Set<int> _read = <int>{};

  @override
  Widget build(BuildContext context) {
    final filter = _tabs[_tab].$2;
    final rows = <(int, NotifV2)>[
      for (var i = 0; i < kNotifs.length; i++)
        if (filter == null || kNotifs[i].kind == filter) (i, kNotifs[i]),
    ];
    final unreadCount = kNotifs.length - _read.length;

    return Stack(
      children: [
        GestureDetector(
          onTap: widget.onClose,
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
                      onTap: widget.onClose,
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
                    _header(unreadCount),
                    _tabStrip(),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 2, 14, 20),
                        itemCount: rows.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          if (index == rows.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                widget.en
                                    ? 'Older than 7 days is cleared automatically'
                                    : 'Thông báo quá 7 ngày sẽ tự xoá',
                                textAlign: TextAlign.center,
                                style: AppTextV2.meta(color: AppColorsV2.inkA(0.36))
                                    .copyWith(fontSize: 11),
                              ),
                            );
                          }
                          final (i, n) = rows[index];
                          return _NotifCard(
                            notif: n,
                            en: widget.en,
                            unread: !_read.contains(i),
                            onTap: () => setState(() => _read.add(i)),
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

  Widget _header(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 9, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.en ? 'Notifications' : 'Thông báo',
                  style: AppTextV2.section().copyWith(fontSize: 24, letterSpacing: -0.72),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.en
                      ? '$unreadCount unread · District 1'
                      : '$unreadCount chưa đọc · ${kAreaNames.first}',
                  style: AppTextV2.meta().copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              for (var i = 0; i < kNotifs.length; i++) {
                _read.add(i);
              }
            }),
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColorsV2.whiteA(0.86),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColorsV2.whiteA(0.9)),
              ),
              child: Text(
                widget.en ? 'Mark all read' : 'Đọc hết',
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabStrip() {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, i) {
          final on = i == _tab;
          return GestureDetector(
            onTap: () => setState(() => _tab = i),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColorsV2.ink : AppColorsV2.whiteA(0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? AppColorsV2.ink : AppColorsV2.whiteA(0.9)),
              ),
              child: Text(
                _tabs[i].$1(widget.en),
                style: AppTextV2.name(
                  color: on ? Colors.white : AppColorsV2.inkA(0.55),
                  size: 11.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.notif,
    required this.unread,
    required this.onTap,
    required this.en,
  });

  final NotifV2 notif;
  final bool en;
  final bool unread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColorsV2.whiteA(unread ? 0.92 : 0.58),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColorsV2.whiteA(unread ? 0.96 : 0.72)),
          boxShadow: unread
              ? [
                  BoxShadow(
                    color: const Color(0xFF10143C).withValues(alpha: 0.09),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: notif.iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(notif.emoji, style: const TextStyle(fontSize: 19, height: 1)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title(en),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextV2.name(size: 13.5).copyWith(letterSpacing: -0.135),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        notif.when(en),
                        style: AppTextV2.meta(color: AppColorsV2.inkA(0.38)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(notif.body(en), style: AppTextV2.body()),
                  if (notif.cta case final cta?) ...[
                    const SizedBox(height: 7),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppGradientsV2.cta,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: AppShadowsV2.ctaGlow(opacity: 0.32),
                      ),
                      child: Text(cta(en), style: AppTextV2.cta().copyWith(fontSize: 11.5)),
                    ),
                  ],
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 5, left: 8),
                decoration: const BoxDecoration(
                  color: AppColorsV2.wisteria,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

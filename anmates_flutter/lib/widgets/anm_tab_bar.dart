import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnmTabBar extends StatelessWidget {
  final int activeIndex;
  final ValueChanged<int>? onTap;

  const AnmTabBar({super.key, this.activeIndex = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore,
        label: 'Khám phá',
      ),
      (
        icon: Icons.favorite_border,
        activeIcon: Icons.favorite,
        label: 'Wishlist',
      ),
      (
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
        label: 'Chat',
      ),
      (icon: Icons.person_outline, activeIcon: Icons.person, label: 'Mình'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.ink10, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              return _TabItem(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
                active: i == activeIndex,
                onTap: () => onTap?.call(i),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatefulWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  State<_TabItem> createState() => _TabItemState();
}

class _TabItemState extends State<_TabItem> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? AppColors.berry
        : _hovered
        ? AppColors.berry.withValues(alpha: 0.55)
        : AppColors.ink50;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _pressed
              ? 0.88
              : _hovered
              ? 1.10
              : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    widget.active ? widget.activeIcon : widget.icon,
                    key: ValueKey(widget.active),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 160),
                  style: AppTextStyles.body(
                    size: 11,
                    weight: widget.active ? FontWeight.w700 : FontWeight.w500,
                    color: color,
                  ),
                  child: Text(widget.label),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

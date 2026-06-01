import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnmChip extends StatefulWidget {
  final String label;
  final bool active;
  final Color? color;
  final bool dark;
  final bool sm;
  final VoidCallback? onTap;

  const AnmChip({
    super.key,
    required this.label,
    this.active = false,
    this.color,
    this.dark = false,
    this.sm = false,
    this.onTap,
  });

  @override
  State<AnmChip> createState() => _AnmChipState();
}

class _AnmChipState extends State<AnmChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.color ?? AppColors.ink;
    final padding = widget.sm
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: widget.label,
      selected: widget.active,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: AnimatedScale(
          scale: _hovered ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: GestureDetector(
            onTap: widget.onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: padding,
              decoration: BoxDecoration(
                color: widget.active
                    ? activeColor
                    : _hovered
                    ? (widget.dark
                          ? Colors.white.withValues(alpha: 0.18)
                          : activeColor.withValues(alpha: 0.08))
                    : (widget.dark ? Colors.white12 : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: widget.active
                      ? Colors.transparent
                      : _hovered
                      ? (widget.dark
                            ? Colors.white38
                            : activeColor.withValues(alpha: 0.35))
                      : (widget.dark ? Colors.white24 : AppColors.ink10),
                  width: 1,
                ),
              ),
              child: Text(
                widget.label,
                style: AppTextStyles.chip(
                  active: widget.active,
                  color: widget.dark ? Colors.white : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

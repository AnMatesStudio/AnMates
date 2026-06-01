import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AnmCTA extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;
  final bool fullWidth;
  final double? height;

  const AnmCTA({
    super.key,
    required this.label,
    this.onTap,
    this.background = AppColors.berry,
    this.foreground = Colors.white,
    this.fullWidth = true,
    this.height,
  });

  @override
  State<AnmCTA> createState() => _AnmCTAState();
}

class _AnmCTAState extends State<AnmCTA> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isBerry = widget.background == AppColors.berry;
    return Semantics(
      button: true,
      enabled: widget.onTap != null,
      label: widget.label,
      excludeSemantics: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        child: AnimatedScale(
          scale: (_hovered && widget.onTap != null) ? 1.025 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: widget.fullWidth ? double.infinity : null,
            height: widget.height ?? 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              boxShadow: isBerry
                  ? [
                      BoxShadow(
                        color: AppColors.berry.withValues(
                          alpha: (_hovered && widget.onTap != null)
                              ? 0.50
                              : 0.35,
                        ),
                        blurRadius: (_hovered && widget.onTap != null)
                            ? 36
                            : 24,
                        offset: (_hovered && widget.onTap != null)
                            ? const Offset(0, 12)
                            : const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: ElevatedButton(
              onPressed: widget.onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.background,
                foregroundColor: widget.foreground,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 0,
                ),
                elevation: 0,
                shadowColor: Colors.transparent,
              ).copyWith(overlayColor: WidgetStateProperty.all(Colors.white12)),
              child: Text(
                widget.label,
                style: AppTextStyles.cta(color: widget.foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

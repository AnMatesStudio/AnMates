import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Reusable error state with optional retry action.
///
/// Use whenever a BLoC emits an error state (e.g., `DiscoverFailure`,
/// `ChatLoadFailure`). Keep the messaging short and friendly — link to
/// support flows from the surrounding screen if needed.
class AnmErrorView extends StatelessWidget {
  /// One-sentence error message. Defaults to a generic Vietnamese fallback.
  final String message;

  /// Optional retry callback. When null, no retry button is rendered.
  final VoidCallback? onRetry;

  /// Optional icon override. Defaults to a friendly cloud-off icon.
  final IconData icon;

  /// Padding around the content.
  final EdgeInsets padding;

  const AnmErrorView({
    this.message = 'Có lỗi xảy ra. Vui lòng thử lại.',
    this.onRetry,
    this.icon = Icons.cloud_off_outlined,
    this.padding = const EdgeInsets.all(32),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: AppColors.ink50),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.body(
              size: 14,
              color: AppColors.ink70,
              height: 1.5,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử lại'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.berry,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

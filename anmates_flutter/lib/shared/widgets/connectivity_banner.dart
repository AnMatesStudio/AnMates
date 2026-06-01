import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/connectivity_service.dart';
import '../../theme/app_theme.dart';

/// Compact offline indicator that slides in from the top when the device
/// loses connectivity and slides out when it returns.
///
/// Wrap your top-level scaffold body in this widget; it stacks itself
/// above the child without consuming layout space when online.
///
/// ```dart
/// ConnectivityBanner(child: MainTabView())
/// ```
///
/// Honours [MediaQuery.disableAnimations] for reduce-motion users.
class ConnectivityBanner extends StatefulWidget {
  /// The screen content. The banner is drawn above this when offline.
  final Widget child;

  /// Override the connectivity service for tests.
  final ConnectivityService? service;

  const ConnectivityBanner({required this.child, this.service, super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  late final ConnectivityService _service;
  StreamSubscription<bool>? _sub;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ConnectivityService();
    _checkInitial();
    _sub = _service.connectivityStream.listen(_onChanged);
  }

  Future<void> _checkInitial() async {
    final online = await _service.isOnline;
    if (mounted) setState(() => _isOnline = online);
  }

  void _onChanged(bool online) {
    if (mounted) setState(() => _isOnline = online);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: AnimatedSlide(
              offset: _isOnline ? const Offset(0, -1) : Offset.zero,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: _isOnline ? 0.0 : 1.0,
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                child: const _OfflineBar(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfflineBar extends StatelessWidget {
  const _OfflineBar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Mất kết nối mạng',
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.berry,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.berry.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Mất kết nối — đang dùng dữ liệu đã lưu',
                style: AppTextStyles.body(
                  size: 13,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

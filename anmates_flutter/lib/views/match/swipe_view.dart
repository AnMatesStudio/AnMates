import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';

class SwipeView extends StatefulWidget {
  final String restaurantName;

  const SwipeView({super.key, this.restaurantName = 'Tiệm mì Ramen Q1'});

  @override
  State<SwipeView> createState() => _SwipeViewState();
}

class _SwipeViewState extends State<SwipeView>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += Offset(details.delta.dx, details.delta.dy * 0.3);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    if (_dragOffset.dx > 120 || velocity > 400) {
      _animateOut(true);
    } else if (_dragOffset.dx < -120 || velocity < -400) {
      _animateOut(false);
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _isDragging = false;
      });
    }
  }

  void _animateOut(bool liked) {
    setState(() {
      _dragOffset = Offset(liked ? 600 : -600, 0);
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _isDragging = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.mint, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              Expanded(child: _buildCardStack()),
              _buildActionButtons(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back,
                size: 18,
                color: AppColors.ink,
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'SWIPE CHO QUÁN',
                  style: AppTextStyles.mono(
                    size: 10,
                    weight: FontWeight.w700,
                    color: AppColors.ink50,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.restaurantName,
                  style: AppTextStyles.body(
                    size: 13,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.settings_outlined,
              size: 18,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack() {
    final rotation = _dragOffset.dx / 1200;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back card 2
          Transform(
            transform: Matrix4.identity()
              ..translateByDouble(0.0, 16.0, 0.0, 1.0)
              ..rotateZ(3 * math.pi / 180),
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: 0.5,
              child: _buildCard(isInteractive: false),
            ),
          ),
          // Back card 1
          Transform(
            transform: Matrix4.identity()
              ..translateByDouble(0.0, 8.0, 0.0, 1.0)
              ..rotateZ(1.5 * math.pi / 180),
            alignment: Alignment.bottomCenter,
            child: Opacity(
              opacity: 0.75,
              child: _buildCard(isInteractive: false),
            ),
          ),
          // Front card (interactive)
          GestureDetector(
            onPanUpdate: _handleDragUpdate,
            onPanEnd: _handleDragEnd,
            child: AnimatedContainer(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 300),
              transform: Matrix4.identity()
                ..translateByDouble(_dragOffset.dx, _dragOffset.dy, 0.0, 1.0)
                ..rotateZ(rotation),
              alignment: Alignment.center,
              child: _buildCard(isInteractive: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required bool isInteractive}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isInteractive
            ? [
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                PhotoSlot(
                  width: double.infinity,
                  height: 320,
                  radius: 0,
                  label: 'PHOTO',
                ),
                if (isInteractive) ...[
                  // Like/Nope overlay indicators
                  if (_dragOffset.dx > 30)
                    Positioned(
                      top: 24,
                      left: 24,
                      child: Transform.rotate(
                        angle: -0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.berry,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            'THÈM',
                            style: AppTextStyles.mono(
                              size: 16,
                              weight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_dragOffset.dx < -30)
                    Positioned(
                      top: 24,
                      right: 24,
                      child: Transform.rotate(
                        angle: 0.4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.glaucous,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Text(
                            'PASS',
                            style: AppTextStyles.mono(
                              size: 16,
                              weight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // Verified + trust chips
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '✓',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Đã xác minh',
                                style: AppTextStyles.body(
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '💯 Trust 98',
                            style: AppTextStyles.body(
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (isInteractive) _buildCardContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Khánh, 26',
                style: AppTextStyles.display(
                  size: 22,
                  weight: FontWeight.w800,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.ink10),
                ),
                child: Text(
                  '0.8 km',
                  style: AppTextStyles.mono(
                    size: 10,
                    color: AppColors.ink70,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"Vừa tan làm, đang muốn ramen cay + bia lạnh. Có ai cùng?"',
            style: AppTextStyles.body(
              size: 13,
              color: AppColors.ink70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AnmChip(
                label: '🌶️ Cay 3',
                active: true,
                color: AppColors.berry,
                sm: true,
              ),
              AnmChip(label: '💬 Thích tám', sm: true),
              AnmChip(label: '🍻 Bia hơi', sm: true),
              AnmChip(label: '🚶 Đi bộ tới', sm: true),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.ink10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🍜', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                Text(
                  'Cũng vừa thêm quán này · 2 phút trước',
                  style: AppTextStyles.body(
                    size: 11,
                    weight: FontWeight.w500,
                    color: AppColors.ink70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Pass button
          GestureDetector(
            onTap: () => _animateOut(false),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.ink, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  '✕',
                  style: TextStyle(fontSize: 20, color: AppColors.ink),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Rewind button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.glaucous,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.glaucous.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.replay, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          // Like button with pulse
          GestureDetector(
            onTap: () => _animateOut(true),
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.berry,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.berry.withValues(alpha: 0.45),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          // Sparkle / Super Like button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.wisteria,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.wisteria.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text('✨', style: const TextStyle(fontSize: 20)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

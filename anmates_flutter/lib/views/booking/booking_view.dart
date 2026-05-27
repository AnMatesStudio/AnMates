import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

// ─── BookingView ──────────────────────────────────────────────────────────────

class BookingView extends StatefulWidget {
  final String mateName;
  final String restaurantName;

  const BookingView({
    super.key,
    this.mateName = 'Khánh',
    this.restaurantName = 'Ramen Q1',
  });

  @override
  State<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<BookingView> {
  // May 2026 starts on Friday → 0-indexed weekday: Mon=0 … Sun=6
  // Friday = index 4
  int _selectedDay = 24; // Sat 24 May
  int _selectedTimeIndex = 2; // 19:30

  static const _times = ['18:30', '19:00', '19:30', '20:00', '20:30'];
  static const int _today = 23; // 23 May 2026 (today per system context)
  static const int _month = 5;
  static const int _year = 2026;

  // May 2026: 31 days, starts Friday (weekday 5 in Dart, Mon=1..Sun=7)
  // We display Mon-Sun headers, so offset: Friday = col index 4 (0-based Mon)
  static const int _startOffset = 4;
  static const int _daysInMonth = 31;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  _buildVoucherBanner(),
                  const SizedBox(height: 14),
                  _buildCalendarCard(),
                  const SizedBox(height: 14),
                  _buildTimeSection(),
                  const SizedBox(height: 14),
                  _buildTrustCard(),
                  const SizedBox(height: 20),
                  _buildCTAButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            color: AppColors.ink,
            onPressed: () => Navigator.maybePop(context),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow('CHỐT KÈO'),
              const SizedBox(height: 2),
              Text(
                'Với ${widget.mateName} tại ${widget.restaurantName}',
                style: AppTextStyles.display(
                  size: 16,
                  weight: FontWeight.w700,
                  color: AppColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Voucher banner ─────────────────────────────────────────────────────────

  Widget _buildVoucherBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.wisteria, AppColors.berry],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.5,
          // Dashed effect simulated via strokeAlign + decoration
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🎟️', style: TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tặng voucher 50k vì chốt nhanh',
                  style: AppTextStyles.display(
                    size: 14,
                    weight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Áp dụng khi cả hai check-in đúng giờ',
                  style: AppTextStyles.body(
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Calendar card ──────────────────────────────────────────────────────────

  Widget _buildCalendarCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink10),
      ),
      child: Column(
        children: [
          _buildCalendarHeader(),
          const SizedBox(height: 14),
          _buildDayHeaders(),
          const SizedBox(height: 8),
          _buildCalendarGrid(),
          const SizedBox(height: 14),
          _buildCalendarLegend(),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      children: [
        Eyebrow('THÁNG $_month · $_year'),
        const Spacer(),
        _CalNavBtn(icon: Icons.chevron_left, onTap: () {}),
        const SizedBox(width: 4),
        _CalNavBtn(icon: Icons.chevron_right, onTap: () {}),
      ],
    );
  }

  Widget _buildDayHeaders() {
    const headers = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    return Row(
      children: headers.map((h) {
        final isSun = h == 'CN';
        return Expanded(
          child: Center(
            child: Text(
              h,
              style: AppTextStyles.mono(
                size: 10,
                weight: FontWeight.w700,
                color: isSun ? AppColors.berry : AppColors.ink50,
                letterSpacing: 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCalendarGrid() {
    // Total cells = offset + 31 days, rounded up to full rows of 7
    final totalCells = _startOffset + _daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final day = cellIndex - _startOffset + 1;

              if (day < 1 || day > _daysInMonth) {
                return const Expanded(child: SizedBox(height: 36));
              }

              final isPast = day < _today;
              final isToday = day == _today;
              final isSelected = day == _selectedDay;
              final isSunday = col == 6;

              return Expanded(
                child: GestureDetector(
                  onTap: isPast
                      ? null
                      : () => setState(() => _selectedDay = day),
                  child: Container(
                    height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.berry
                          : isPast
                          ? AppColors.ink10
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.berry, width: 1.5)
                          : isSelected
                          ? null
                          : Border.all(color: AppColors.ink10),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.berry.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: isPast
                            ? AppTextStyles.body(
                                size: 13,
                                color: AppColors.ink30,
                              ).copyWith(decoration: TextDecoration.lineThrough)
                            : AppTextStyles.display(
                                size: 13,
                                weight: isToday || isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : isToday
                                    ? AppColors.berry
                                    : isSunday
                                    ? AppColors.berry
                                    : AppColors.ink,
                                letterSpacing: 0,
                              ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildCalendarLegend() {
    const items = [
      ('■', AppColors.berry, 'ĐÃ CHỌN'),
      ('□', AppColors.glaucous, 'SẮP TỚI'),
      ('▩', AppColors.ink30, 'ĐÃ QUA'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(item.$1, style: TextStyle(color: item.$2, fontSize: 11)),
              const SizedBox(width: 4),
              Text(
                item.$3,
                style: AppTextStyles.mono(
                  size: 9,
                  color: AppColors.ink50,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Time section ───────────────────────────────────────────────────────────

  Widget _buildTimeSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow('GIỜ'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_times.length, (i) {
              final active = i == _selectedTimeIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedTimeIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: active ? AppColors.berry : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: active ? AppColors.berry : AppColors.ink10,
                      width: active ? 0 : 1,
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.berry.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    _times[i],
                    style: AppTextStyles.mono(
                      size: 13,
                      weight: FontWeight.w700,
                      color: active ? Colors.white : AppColors.ink70,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ── Trust card ─────────────────────────────────────────────────────────────

  Widget _buildTrustCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ocean.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ocean.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.ocean.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Sparkle(size: 18, color: AppColors.ocean),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'ĂnMates sẽ bật Live Tracking 45 phút trước hẹn — để bạn an tâm và giúp nhau đến đúng giờ.',
              style: AppTextStyles.body(size: 13, color: AppColors.oceanDeep),
            ),
          ),
        ],
      ),
    );
  }

  // ── CTA button ─────────────────────────────────────────────────────────────

  Widget _buildCTAButton() {
    final day = _selectedDay;
    final time = _times[_selectedTimeIndex];
    // Day of week: May 1 2026 = Friday, so day+3 mod 7 gives Mon=0
    // day 24 = Friday + 23 = 23 days later from May 1 = Saturday (T7)
    const dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    // May 1 = Friday = index 4. day 1 → 4, day 24 → (4+23) % 7 = 27 % 7 = 6 = CN
    // Actually May 24 2026: let's compute properly
    // May 1 2026 = Friday (weekday 5 in Dart where Mon=1, Fri=5)
    final dayOfWeek = (4 + (day - 1)) % 7; // Mon=0 offset
    final label = dayNames[dayOfWeek];

    return AnmCTA(
      label: 'Chốt $label · $time →',
      onTap: () {},
      background: AppColors.berry,
      fullWidth: true,
    );
  }
}

// ─── Calendar nav button ──────────────────────────────────────────────────────

class _CalNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CalNavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.ink10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: AppColors.ink),
      ),
    );
  }
}

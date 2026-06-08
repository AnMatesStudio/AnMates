import 'package:flutter/material.dart';
import '../../services/booking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

// ─── BookingView ──────────────────────────────────────────────────────────────
//
// First Date scheduling. With a [matchId] it talks to the backend: loads any
// existing booking, lets one member propose a venue+time, and the other confirm
// (or either cancel). Without a matchId it stays a visual demo (CTA pops).

class BookingView extends StatefulWidget {
  final String? matchId;
  final String? currentUserId;
  final String mateName;
  final String restaurantName;
  final String restaurantAddress;
  final double? lat;
  final double? lng;

  const BookingView({
    super.key,
    this.matchId,
    this.currentUserId,
    this.mateName = 'Mate',
    this.restaurantName = '',
    this.restaurantAddress = '',
    this.lat,
    this.lng,
  });

  @override
  State<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends State<BookingView> {
  static const _times = ['18:30', '19:00', '19:30', '20:00', '20:30'];
  static const _dayNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  // Calendar is anchored to the real current month (was hardcoded May 2026).
  late final int _year, _month, _today, _daysInMonth;
  late final int _startOffset; // weekday of the 1st, Mon=0 … Sun=6
  late int _selectedDay;
  int _selectedTimeIndex = 2;

  Booking? _existing;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
    _today = now.day;
    _daysInMonth = DateUtils.getDaysInMonth(_year, _month);
    _startOffset = DateTime(_year, _month, 1).weekday - 1;
    _selectedDay = _today;
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final mid = widget.matchId;
    if (mid == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final bk = await BookingService().current(mid);
      if (mounted) setState(() { _existing = bk; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime get _selectedDateTime {
    final parts = _times[_selectedTimeIndex].split(':');
    return DateTime(_year, _month, _selectedDay, int.parse(parts[0]), int.parse(parts[1]));
  }

  String get _venueName =>
      widget.restaurantName.trim().isEmpty ? 'Quán đã chọn' : widget.restaurantName.trim();

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final mid = widget.matchId;
    if (mid == null) { Navigator.maybePop(context); return; }
    setState(() => _submitting = true);
    try {
      final bk = await BookingService().propose(
        mid,
        restaurantName: _venueName,
        restaurantAddress: widget.restaurantAddress,
        lat: widget.lat,
        lng: widget.lng,
        scheduledAt: _selectedDateTime,
      );
      if (!mounted) return;
      setState(() { _existing = bk; _submitting = false; });
      _toast('Đã đề xuất First Date! Chờ ${widget.mateName} xác nhận 💌');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Không đề xuất được: $e');
    }
  }

  Future<void> _confirm() async {
    final mid = widget.matchId;
    if (mid == null) return;
    setState(() => _submitting = true);
    try {
      final bk = await BookingService().confirm(mid);
      if (!mounted) return;
      setState(() { _existing = bk; _submitting = false; });
      _toast('Đã chốt First Date! Hẹn gặp nha 🎉');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Không xác nhận được: $e');
    }
  }

  Future<void> _cancel() async {
    final mid = widget.matchId;
    if (mid == null) return;
    setState(() => _submitting = true);
    try {
      await BookingService().cancel(mid);
      if (!mounted) return;
      setState(() { _existing = null; _submitting = false; });
      _toast('Đã huỷ đề xuất.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('Không huỷ được: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mint,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                      children: [
                        if (_existing != null && _existing!.isActive) ...[
                          _buildExistingBanner(),
                          const SizedBox(height: 14),
                        ],
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

  // ── Existing-booking banner (propose/confirm/cancel state) ──────────────────

  Widget _buildExistingBanner() {
    final b = _existing!;
    final confirmed = b.status == 'confirmed';
    final mine = widget.currentUserId != null && b.proposedBy == widget.currentUserId;
    final when = '${_dayNames[b.scheduledAt.weekday - 1]} ${b.scheduledAt.day}/${b.scheduledAt.month} · '
        '${b.scheduledAt.hour.toString().padLeft(2, '0')}:${b.scheduledAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: confirmed ? AppColors.berry.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: confirmed ? AppColors.berry : AppColors.ink10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(confirmed ? 'ĐÃ CHỐT ✓' : 'ĐÃ ĐỀ XUẤT'),
          const SizedBox(height: 6),
          Text('${b.restaurantName} · $when',
              style: AppTextStyles.display(size: 15, weight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!confirmed && !mine)
                Expanded(
                  child: AnmCTA(
                    label: 'Xác nhận →',
                    onTap: _submitting ? () {} : _confirm,
                    background: AppColors.berry,
                    fullWidth: true,
                  ),
                ),
              if (!confirmed && mine)
                Expanded(
                  child: Text('Chờ ${widget.mateName} xác nhận…',
                      style: AppTextStyles.body(size: 13, color: AppColors.ink50)),
                ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _submitting ? null : _cancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.ink10,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('Huỷ',
                      style: AppTextStyles.body(size: 13, weight: FontWeight.w700, color: AppColors.ink70)),
                ),
              ),
            ],
          ),
        ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow('CHỐT KÈO'),
                const SizedBox(height: 2),
                Text(
                  'Với ${widget.mateName}${_venueName.isEmpty ? '' : ' tại $_venueName'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.display(
                    size: 16,
                    weight: FontWeight.w700,
                    color: AppColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
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
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
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
            child: const Center(child: Text('🎟️', style: TextStyle(fontSize: 22))),
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
                  style: AppTextStyles.body(size: 12, color: Colors.white.withValues(alpha: 0.85)),
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
                  onTap: isPast ? null : () => setState(() => _selectedDay = day),
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
                            ? AppTextStyles.body(size: 13, color: AppColors.ink30)
                                .copyWith(decoration: TextDecoration.lineThrough)
                            : AppTextStyles.display(
                                size: 13,
                                weight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
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
                style: AppTextStyles.mono(size: 9, color: AppColors.ink50, letterSpacing: 1),
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
            child: const Center(child: Sparkle(size: 18, color: AppColors.ocean)),
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
    final time = _times[_selectedTimeIndex];
    final label = _dayNames[DateTime(_year, _month, _selectedDay).weekday - 1];
    return AnmCTA(
      label: _submitting
          ? 'Đang gửi…'
          : (_existing != null && _existing!.isActive
              ? 'Đề xuất lại $label · $time →'
              : 'Chốt $label · $time →'),
      onTap: _submitting ? () {} : _submit,
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

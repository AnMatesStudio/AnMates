import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/booking_service.dart';
import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **D3 · Meal booking.** The design called this "AI Smart Split" — a
/// receipt-OCR + per-item split + VietQR settlement flow. None of it is real:
/// there is no OCR pipeline, no bill/amount column anywhere in the schema, and
/// no payment integration. What IS real is the First Date booking API
/// (`GET/POST /matches/:id/booking`, fully built in booking_service.dart but
/// never wired into the v2 UI) — so this screen now shows that instead: the
/// actual proposed venue and time, or an honest "not scheduled yet" state.
class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final booking = s.booking;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            V2BackButton(onTap: () => s.go(V2Screen.chat)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(s.t('Lịch hẹn', 'Booking'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextV2.section()
                      .copyWith(fontSize: 25, letterSpacing: -0.75)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
            s.t('Không OCR, không chia bill tự động, không ký quỹ trong app — tính năng đó chưa tồn tại.',
                "No receipt scanning, no auto-split, no in-app escrow — that feature doesn't exist yet."),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
          ),
          const SizedBox(height: 16),
          if (s.bookingLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColorsV2.wisteria))
          else if (booking == null)
            _NoBookingCard(s: s)
          else ...[
            _BookingCard(s: s, booking: booking),
            const SizedBox(height: 16),
            _RulesCard(s: s),
            if (booking.status == 'confirmed') ...[
              const SizedBox(height: 16),
              _MealStatusCard(s: s),
            ],
            if (booking.status == 'confirmed' || booking.status == 'completed') ...[
              const SizedBox(height: 16),
              V2Cta(
                key: const Key('bill-rate-cta'),
                label: s.t('Đánh giá bữa ăn', 'Rate the meal'),
                height: 50, radius: 18, fontSize: 15,
                onTap: () => s.go(V2Screen.rate),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _NoBookingCard extends StatelessWidget {
  const _NoBookingCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return V2Sheet(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('Chưa có lịch hẹn nào', 'No booking proposed yet'),
              style: AppTextV2.name(size: 14.5)),
          const SizedBox(height: 8),
          Text(
            s.t('Đề xuất quán và giờ hẹn trong khung chat để chốt bữa ăn với ${s.chatPartner.name}.',
                'Propose a venue and time in chat to lock in a meal with ${s.chatPartner.name}.'),
            style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  const _RulesCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final bullets = [
      s.t('Hai bạn được nhắc 24 giờ và 2 giờ trước giờ hẹn.',
          'You both get reminders 24 h and 2 h before the meal.'),
      s.t('Đang tới hay sẽ trễ? Báo mate bằng một chạm ở trên.',
          'On the way or running late? Tell your mate with one tap above.'),
      s.t('Bị báo "không đến" bị trừ 20 điểm Trust Score; 3 người khác nhau báo cáo trong 30 ngày thì tài khoản tạm khoá.',
          'A no-show report costs 20 Trust Score points; reports from 3 different people within 30 days suspend the account.'),
    ];
    return V2Sheet(
      key: const Key('bill-rules'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('Luật chơi chống bùng hẹn', 'No-show rules'),
              style: AppTextV2.name(size: 14.5)),
          const SizedBox(height: 8),
          for (final line in bullets)
            Text('• $line', style: AppTextV2.body(size: 13).copyWith(height: 1.45)),
        ],
      ),
    );
  }
}

class _MealStatusCard extends StatelessWidget {
  const _MealStatusCard({required this.s});
  final V2State s;

  static const _codes = ['on_my_way', 'running_late_10', 'running_late_20', 'arrived'];

  @override
  Widget build(BuildContext context) {
    return V2Sheet(
      key: const Key('bill-meal-status'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.t('Hôm nay thế nào?', 'How is it going?'),
              style: AppTextV2.name(size: 14.5)),
          if (s.partnerMealStatus != null) ...[
            const SizedBox(height: 8),
            Text('${s.chatPartner.name}: ${s.mealStatusLabel(s.partnerMealStatus!)}',
                key: const Key('bill-partner-status'),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13.5)),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final code in _codes)
                V2TapTarget(
                  key: Key('meal-status-$code'),
                  onTap: s.mealStatusBusy ? null : () => _pick(code, context),
                  child: _pill(context, code),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String code) {
    final selected = s.myMealStatus == code;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AppColorsV2.wisteria : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: selected
            ? null
            : Border.all(color: AppColorsV2.inkA(0.25), width: 1),
      ),
      child: Text(
        s.mealStatusLabel(code),
        style: AppTextV2.name(
          color: selected ? Colors.white : AppColorsV2.ink,
          size: 13,
        ),
      ),
    );
  }

  Future<void> _pick(String code, BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottom = navClearance(context);
    final ok = await s.setMealStatus(code);
    showV2Toast(
      messenger,
      ok
          ? s.t('Đã báo cho ${s.chatPartner.name}', 'Told ${s.chatPartner.name}')
          : s.t('Chỉ báo được trong khoảng 3 giờ trước tới 2 giờ sau giờ hẹn.',
              'You can only send this from 3 h before to 2 h after the meal.'),
      bottom: bottom,
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.s, required this.booking});
  final V2State s;
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final statusLabel = switch (booking.status) {
      'confirmed' => s.t('Đã xác nhận', 'Confirmed'),
      'cancelled' => s.t('Đã huỷ', 'Cancelled'),
      'completed' => s.t('Đã hoàn tất', 'Completed'),
      _ => s.t('Đang chờ xác nhận', 'Awaiting confirmation'),
    };

    return V2Sheet(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: AppColorsV2.wisteriaTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(statusLabel.toUpperCase(),
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11)
                    .copyWith(letterSpacing: 0.76)),
          ),
          const SizedBox(height: 12),
          Text(booking.restaurantName, style: AppTextV2.name(size: 16)),
          if (booking.restaurantAddress.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(booking.restaurantAddress,
                style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5)),
          ],
          const SizedBox(height: 10),
          Text(
            '${booking.scheduledAt.day}/${booking.scheduledAt.month} · '
            '${booking.scheduledAt.hour.toString().padLeft(2, '0')}:'
            '${booking.scheduledAt.minute.toString().padLeft(2, '0')}',
            style: AppTextV2.name(size: 13.5),
          ),
        ],
      ),
    );
  }
}

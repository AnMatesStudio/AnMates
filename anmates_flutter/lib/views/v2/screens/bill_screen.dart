import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/booking_service.dart';
import '../../../theme/app_theme_v2.dart';
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
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
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
          else
            _BookingCard(s: s, booking: booking),
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
                style: AppTextV2.name(color: AppColorsV2.wisteria, size: 9.5)
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

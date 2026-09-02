import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **D3 · AI Smart Split** — OCR the receipt, split by item or evenly, settle
/// over VietQR. No escrow: the app never holds anyone's money.
class BillScreen extends StatelessWidget {
  const BillScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            V2BackButton(onTap: () => s.go(V2Screen.chat)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('AI Smart Split',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextV2.section()
                      .copyWith(fontSize: 25, letterSpacing: -0.75)),
            ),
          ]),
          const SizedBox(height: 8),
          Text(s.billSub,
              style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5)),
          const SizedBox(height: 16),
          V2Sheet(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _OcrRow(s: s),
                const SizedBox(height: 15),
                _SplitTabs(s: s),
                const SizedBox(height: 15),
                for (final it in s.billItems)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Color(0xFFF0F4F9))),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(it.name,
                                style: AppTextV2.name(size: 13.5)
                                    .copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(it.who,
                                style: AppTextV2.meta().copyWith(fontSize: 11)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(it.amount, style: AppTextV2.name(size: 13)),
                    ]),
                  ),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(
                    child: Text(s.t('Bạn phải trả', 'You owe'),
                        style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 12.5)
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  Text(s.yourShare,
                      style: AppTextV2.section().copyWith(fontSize: 25, letterSpacing: -0.5)),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _VietQrCard(s: s),
          const SizedBox(height: 12),
          _TrustNudge(s: s),
        ],
      ),
    );
  }
}

class _OcrRow extends StatelessWidget {
  const _OcrRow({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 94, height: 122,
          padding: const EdgeInsets.all(8),
          alignment: Alignment.bottomLeft,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Color(0xFFEEF3FA), Color(0xFFE1E9F4)],
            ),
          ),
          child: Text(
            s.t('ảnh hóa đơn đã scan', 'scanned receipt photo'),
            style: const TextStyle(
              fontSize: 7.5, height: 1.35, color: Color(0xFF7A8AA0),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColorsV2.wisteriaTint,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(s.t('OCR HOÀN TẤT', 'OCR COMPLETE'),
                    style: AppTextV2.name(color: AppColorsV2.wisteria, size: 9.5)
                        .copyWith(letterSpacing: 0.76)),
              ),
              const SizedBox(height: 8),
              Text(s.ocrLine,
                  style: AppTextV2.name(size: 12.5)
                      .copyWith(fontWeight: FontWeight.w600, height: 1.45)),
              const SizedBox(height: 8),
              Text(
                s.t('Hóa đơn mờ hoặc viết tay? Nhập thủ công',
                    'Blurry or handwritten? Enter manually'),
                style: AppTextV2.name(color: const Color(0xFF1A56DB), size: 11.5)
                    .copyWith(height: 1.4, decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SplitTabs extends StatelessWidget {
  const _SplitTabs({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool active, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                label,
                style: AppTextV2.name(
                  color: active ? AppColorsV2.wisteria : AppColorsV2.inkA(0.45),
                  size: 12.5,
                ),
              ),
            ),
          ),
        );

    final equal = s.split == SplitMode.equal;
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FD),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(children: [
        tab(s.t('Theo món', 'By item'), !equal, () => s.setSplit(SplitMode.item)),
        const SizedBox(width: 6),
        tab(s.t('Chia đều', 'Divided equally'), equal, () => s.setSplit(SplitMode.equal)),
      ]),
    );
  }
}

class _VietQrCard extends StatelessWidget {
  const _VietQrCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A56DB),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A56DB).withValues(alpha: 0.32),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 88, height: 88,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            s.t('VietQR mã động', 'VietQR dynamic code'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 7.5, height: 1.4, color: Color(0xFF7A8AA0),
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.t('Chuyển sòng phẳng', 'Settle straight up'),
                  style: AppTextV2.name(color: Colors.white, size: 15)),
              const SizedBox(height: 6),
              Text(
                s.t('Quét là xong. Không ký quỹ, không giữ tiền trong app.',
                    "Scan and it's done. No escrow, no money parked in the app."),
                style: AppTextV2.body(color: AppColorsV2.whiteA(0.86), size: 11.5)
                    .copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _TrustNudge extends StatelessWidget {
  const _TrustNudge({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.rate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppGradientsV2.cta,
          borderRadius: BorderRadius.circular(22),
          boxShadow: AppShadowsV2.ctaGlow(opacity: 0.28),
        ),
        child: Row(children: [
          Container(
            width: 34, height: 34, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColorsV2.wisteria,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('+2',
                style: AppTextV2.section(color: Colors.white)
                    .copyWith(fontSize: 13, letterSpacing: 0)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              s.t('Check-in đúng giờ — Trust Score +2. Rate mate để chốt bữa ăn.',
                  'Checked in on time — Trust Score +2. Rate your mate to close the meal.'),
              style: AppTextV2.name(color: Colors.white, size: 12)
                  .copyWith(fontWeight: FontWeight.w600, height: 1.45),
            ),
          ),
          const SizedBox(width: 8),
          Text('›', style: AppTextV2.name(color: Colors.white, size: 18)),
        ]),
      ),
    );
  }
}

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **D1 / D2 · Vibe Check → Vibe Match.** The gauge boils up with every message;
/// crossing the threshold unlocks the scheduling button and fires the celebration
/// sheet once.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return Stack(children: [
      Column(children: [
        _Header(s: s),
        Expanded(child: _Transcript(s: s)),
        _Composer(s: s),
      ]),
      if (s.celebrate) _CelebrateSheet(s: s),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 96, 14, 10),
          decoration: BoxDecoration(
            color: AppColorsV2.whiteA(0.55),
            border: Border(bottom: BorderSide(color: AppColorsV2.inkA(0.06))),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: () => s.go(V2Screen.swipe),
              child: SizedBox(
                width: 34, height: 34,
                child: Center(
                  child: Text('‹',
                      style: AppTextV2.name(color: AppColorsV2.wisteria, size: 20)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 40, height: 40,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppShadowsV2.pill,
                  ),
                  child: FoodArt(
                    asset: s.mate.img, fillFraction: 0.74, shadowOpacity: 0,
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 11, height: 11,
                    decoration: BoxDecoration(
                      color: const Color(0xFF34C759),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.mate.name, style: AppTextV2.name(size: 15)),
                  Text(s.chatSub,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextV2.meta().copyWith(fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _VibeGauge(s: s),
          ]),
        ),
      ),
    );
  }
}

/// The boiling gauge — a wisteria fill with a diagonal shimmer sliding across it.
class _VibeGauge extends StatefulWidget {
  const _VibeGauge({required this.s});
  final V2State s;

  @override
  State<_VibeGauge> createState() => _VibeGaugeState();
}

class _VibeGaugeState extends State<_VibeGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('VIBE',
              style: AppTextV2.meta(color: AppColorsV2.inkA(0.45))
                  .copyWith(fontSize: 9.5, fontWeight: FontWeight.w600, letterSpacing: 0.57)),
          const SizedBox(width: 5),
          Text('${s.vibe}%',
              style: AppTextV2.section(color: AppColorsV2.wisteria)
                  .copyWith(fontSize: 12.5, letterSpacing: 0)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            width: 72, height: 5,
            child: Stack(children: [
              const Positioned.fill(child: ColoredBox(color: Color(0xFFEFEAFB))),
              AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                widthFactor: (s.vibe / 100).clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) => CustomPaint(
                    painter: _BoilPainter(phase: _c.value),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _BoilPainter extends CustomPainter {
  _BoilPainter({required this.phase});
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()..shader = const LinearGradient(
        colors: [AppColorsV2.wisteria, Color(0xFFA78BFA)],
      ).createShader(rect),
    );

    // `@keyframes amBoil` — repeating diagonal stripes drifting sideways.
    canvas.save();
    canvas.clipRect(rect);
    final stripe = Paint()..color = Colors.white.withValues(alpha: 0.5);
    const gap = 10.0;
    final offset = phase * gap;
    for (double x = -size.height - gap + offset; x < size.width + gap; x += gap) {
      canvas.drawParallelogram(x, size, stripe);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoilPainter old) => old.phase != phase;
}

extension on Canvas {
  /// One 3px-wide slanted stripe of the boiling shimmer.
  void drawParallelogram(double x, Size size, Paint paint) {
    drawPath(
      Path()
        ..moveTo(x, size.height)
        ..lineTo(x + size.height, 0)
        ..lineTo(x + size.height + 3, 0)
        ..lineTo(x + 3, size.height)
        ..close(),
      paint,
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: [
        Center(
          child: Text(s.t('Hôm nay 18:42', 'Today 18:42'),
              style: AppTextV2.meta(color: AppColorsV2.inkA(0.38)).copyWith(fontSize: 10.5)),
        ),
        const SizedBox(height: 10),
        _IceBreaker(s: s),
        const SizedBox(height: 6),
        for (final m in s.messages) ...[
          Align(
            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.74,
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  gradient: m.mine ? AppGradientsV2.cta : null,
                  color: m.mine ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(m.mine ? 18 : 5),
                    bottomRight: Radius.circular(m.mine ? 5 : 18),
                  ),
                ),
                child: Text(
                  m.text,
                  style: AppTextV2.body(
                    color: m.mine ? Colors.white : AppColorsV2.ink,
                    size: 13.5,
                  ).copyWith(height: 1.4),
                ),
              ),
            ),
          ),
        ],
        if (s.unlocked) const Center(child: _VibeMatchBadge()),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(s.t('Đã xem', 'Seen'),
              style: AppTextV2.meta(color: AppColorsV2.inkA(0.36)).copyWith(fontSize: 10)),
        ),
      ],
    );
  }
}

class _IceBreaker extends StatelessWidget {
  const _IceBreaker({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.86),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColorsV2.wisteria.withValues(alpha: 0.18)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Text(s.t('PHÁ BĂNG', 'ICE-BREAKER'),
                style: AppTextV2.eyebrow(color: AppColorsV2.wisteria)
                    .copyWith(fontSize: 9.5)),
            const SizedBox(height: 6),
            Text(s.prompt, textAlign: TextAlign.center,
                style: AppTextV2.name(size: 12.5)
                    .copyWith(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: s.sendMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColorsV2.wisteriaTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(s.t('Trả lời · +vibe', 'Answer · +vibe'),
                    style: AppTextV2.name(color: AppColorsV2.wisteria, size: 11)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _VibeMatchBadge extends StatelessWidget {
  const _VibeMatchBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColorsV2.wisteria.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: AppColorsV2.wisteria.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColorsV2.wisteria, shape: BoxShape.circle,
          ),
          child: Transform.rotate(
            angle: 0.785,
            child: Container(
              width: 10, height: 10,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5), topRight: Radius.circular(5),
                  bottomLeft: Radius.circular(5), bottomRight: Radius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('VIBE MATCH',
            style: AppTextV2.section(color: AppColorsV2.wisteria)
                .copyWith(fontSize: 11, letterSpacing: 0.44)),
      ]),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, navClearance(context) - 12),
      child: Column(children: [
        if (s.unlocked)
          GestureDetector(
            onTap: () => s.go(V2Screen.rate),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              decoration: BoxDecoration(
                gradient: AppGradientsV2.cta,
                borderRadius: BorderRadius.circular(999),
                boxShadow: AppShadowsV2.ctaGlow(opacity: 0.3),
              ),
              child: Row(children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColorsV2.whiteA(0.35),
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.confirmCta,
                      style: AppTextV2.name(color: Colors.white, size: 12.5)),
                ),
                Container(
                  width: 30, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColorsV2.whiteA(0.22), shape: BoxShape.circle,
                  ),
                  child: Text('›',
                      style: AppTextV2.name(color: Colors.white, size: 15)),
                ),
              ]),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColorsV2.whiteA(0.7),
              border: Border.all(color: AppColorsV2.inkA(0.06)),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: AppColorsV2.inkA(0.45)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(s.lockedCta,
                    style: AppTextV2.name(color: AppColorsV2.inkA(0.55), size: 11.5)
                        .copyWith(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          GestureDetector(
            onTap: () => s.go(V2Screen.bill),
            child: SizedBox(
              width: 38, height: 38,
              child: Icon(Icons.receipt_long_rounded,
                  size: 21, color: AppColorsV2.wisteria),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColorsV2.inkA(0.07)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(s.t('Nhắn tin…', 'Message…'),
                  style: AppTextV2.body(color: AppColorsV2.inkA(0.4), size: 13)),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: s.sendMessage,
            child: Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                color: AppColorsV2.wisteria, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _CelebrateSheet extends StatelessWidget {
  const _CelebrateSheet({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColorsV2.ink.withValues(alpha: 0.52),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 104, height: 104, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColorsV2.wisteria,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColorsV2.wisteria.withValues(alpha: 0.45),
                        blurRadius: 34,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: 0.785,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20), topRight: Radius.circular(20),
                          bottomLeft: Radius.circular(20), bottomRight: Radius.circular(5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(s.t('Đã mở khóa Vibe Match', 'Vibe Match unlocked'),
                    textAlign: TextAlign.center,
                    style: AppTextV2.section().copyWith(fontSize: 22, height: 1.2)),
                const SizedBox(height: 10),
                Text(s.celebrateBody, textAlign: TextAlign.center,
                    style: AppTextV2.body(size: 12.5).copyWith(height: 1.55)),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: () => s.go(V2Screen.rate),
                    child: Container(
                      height: 52, alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColorsV2.wisteria,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(s.confirmCta,
                          textAlign: TextAlign.center,
                          style: AppTextV2.cta().copyWith(fontSize: 15)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: s.dismissCelebrate,
                  child: Text(s.t('Nhắn tiếp đã', 'Keep chatting'),
                      style: AppTextV2.name(color: AppColorsV2.inkA(0.45), size: 12)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

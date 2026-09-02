import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **C2 · Quẹt gửi lời mời** — the card swipes on dining intent, not looks.
class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    // The action row is pinned outside the scroll view so it always clears the
    // glass nav; only the card scrolls, and it centres when there is room.
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 104, 18, navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  s.t('Gửi lời mời', 'Send an invite'),
                  style: AppTextV2.section()
                      .copyWith(fontSize: 25, letterSpacing: -0.75),
                ),
              ),
              Flexible(
                child: Text(
                  s.t('Quẹt theo ý định ăn', 'Swipe on intent, not looks'),
                  textAlign: TextAlign.end,
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.5))
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: c.maxHeight - 24),
                  child: Center(child: _MateCard(s: s)),
                ),
              ),
            ),
          ),
          Row(children: [
            GestureDetector(
              onTap: s.skipMate,
              child: Container(
                width: 60, height: 60, alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10366E).withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Text('✕',
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.4), size: 21)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: GestureDetector(
                onTap: s.inviteMate,
                child: Container(
                  height: 60, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradientsV2.cta,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppShadowsV2.ctaGlow(opacity: 0.4),
                  ),
                  child: Text(
                    s.t('Gửi lời mời đi ăn', 'Send dining invite'),
                    style: AppTextV2.cta().copyWith(fontSize: 15),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _MateCard extends StatelessWidget {
  const _MateCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final mate = s.mate;
    return Container(
      key: ValueKey(mate.name),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10366E).withValues(alpha: 0.24),
            blurRadius: 46,
            offset: const Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Portrait(s: s),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${mate.name}, ${mate.age}',
                    style: AppTextV2.section()
                        .copyWith(fontSize: 21, letterSpacing: -0.525)),
                const SizedBox(height: 3),
                Text(s.tr(mate.meta),
                    style: AppTextV2.body(
                        color: AppColorsV2.inkA(0.48), size: 12)),
                const SizedBox(height: 12),
                _Intent(s: s),
                const SizedBox(height: 12),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  for (final tag in mate.tags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FE),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        s.tr(tag),
                        style: AppTextV2.name(
                          color: const Color(0xFF1A56DB), size: 11.5,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: mate.match / 100,
                        minHeight: 6,
                        backgroundColor: const Color(0xFFEDF1F7),
                        valueColor: const AlwaysStoppedAnimation(
                            AppColorsV2.wisteria),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    s.en ? '${mate.match}% taste match' : '${mate.match}% hợp gu',
                    style: AppTextV2.name(
                        color: AppColorsV2.wisteria, size: 11.5),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final mate = s.mate;
    return SizedBox(
      height: 172,
      child: Stack(children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFFE7F0FF), Color(0xFFF7FAFF)],
              ),
            ),
            child: FoodArt(
              asset: mate.img, fillFraction: 0.62,
              shadowOpacity: 0.16, shadowBlur: 14,
            ),
          ),
        ),
        Positioned(
          top: 11, left: 11,
          child: _Pill(
            label: s.tr(mate.urgency),
            bg: mate.urgent ? AppColorsV2.alert : AppColorsV2.wisteria,
            fg: Colors.white,
          ),
        ),
        Positioned(
          top: 11, right: 11,
          child: _Pill(
            label: 'Trust ${mate.trust}',
            bg: Colors.white,
            fg: AppColorsV2.ink,
          ),
        ),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: AppTextV2.name(color: fg, size: 10.5)),
    );
  }
}

class _Intent extends StatelessWidget {
  const _Intent({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.t('Ý ĐỊNH ĐI ĂN', 'DINING INTENT'),
            style: AppTextV2.eyebrow().copyWith(fontSize: 10),
          ),
          const SizedBox(height: 5),
          Text(
            s.tr(s.mate.intent),
            style: AppTextV2.name(size: 14).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

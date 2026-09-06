import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../widgets/v2/aurora_background.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **Flow A · Onboarding** — five steps, from the welcome arch to the taste grid.
///
/// Each step paints its own background: A0 reuses the full-bleed aurora of the
/// welcome screen, A1–A4 sit on white with a masked aurora blob floating inside.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    return switch (s.step) {
      0 => _Welcome(s: s),
      1 => _Hero(s: s),
      2 => _SocialProof(s: s),
      3 => _BudgetStep(s: s),
      _ => _TasteStep(s: s),
    };
  }
}

/// The masked aurora blob A1–A4 share: inset from the edges and faded out at the
/// rim so it reads as a glow rather than a rectangle.
class _BlobBackground extends StatelessWidget {
  const _BlobBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Colors.white)),
      Positioned(
        top: 56, left: 14, right: 14, bottom: 96,
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => RadialGradient(
            center: const Alignment(0, -0.06),
            radius: 0.76,
            colors: [
              Colors.black,
              Colors.black,
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0),
            ],
            stops: const [0, 0.52, 0.76, 1],
          ).createShader(rect),
          child: const AuroraBlob(),
        ),
      ),
    ]);
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 60),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 30, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppGradientsV2.cta,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text('AM',
                      style: AppTextV2.section(color: Colors.white)
                          .copyWith(fontSize: 11, letterSpacing: -0.22)),
                ),
                const SizedBox(width: 9),
                Text('Ăn Mates',
                    style: AppTextV2.name(size: 17).copyWith(letterSpacing: -0.34)),
              ]),
              const SizedBox(height: 22),
              _GradientHeadline(
                gradientPart: s.t('Chào bạn.', 'Welcome.'),
                restPart: s.t('\nBàn ăn nào cũng\ncòn chỗ cho bạn.',
                    "\nThere's always a seat\nsaved for you."),
              ),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 250),
                child: Text(
                  s.t('Không hẹn hò. Chỉ có món ngon và những người hợp gu.',
                      'No dating. Just good food and mates who match your taste.'),
                  textAlign: TextAlign.center,
                  style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5)
                      .copyWith(height: 1.6),
                ),
              ),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: s.nextStep,
                child: Container(
                  height: 54,
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A285A).withValues(alpha: 0.16),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(s.t('CÙNG ĂN THÔI', "LET'S EAT TOGETHER"),
                        style: AppTextV2.name(color: const Color(0xFF5B6BF5), size: 12)
                            .copyWith(letterSpacing: 1.2)),
                    const SizedBox(width: 11),
                    Text('→',
                        style: AppTextV2.name(color: AppColorsV2.wisteria, size: 15)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A headline whose first clause is painted with the CTA gradient.
class _GradientHeadline extends StatelessWidget {
  const _GradientHeadline({required this.gradientPart, required this.restPart});

  final String gradientPart;
  final String restPart;

  @override
  Widget build(BuildContext context) {
    final style = AppTextV2.section()
        .copyWith(fontSize: 33, height: 1.14, letterSpacing: -1.32);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: [
        TextSpan(
          text: gradientPart,
          style: style.copyWith(
            foreground: Paint()
              ..shader = const LinearGradient(
                begin: Alignment(-1, -0.6), end: Alignment(1, 0.6),
                colors: [AppColorsV2.blue, AppColorsV2.wisteria],
              ).createShader(const Rect.fromLTWH(0, 0, 260, 44)),
          ),
        ),
        TextSpan(text: restPart, style: style),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const _BlobBackground(),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 26),
        child: Column(children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(children: [
                  const SizedBox(
                    width: 238, height: 238,
                    child: FloatingArt(
                      period: Duration(milliseconds: 5500),
                      travel: 12,
                      child: FoodArt(asset: A.hotpot, shadowOpacity: 0.24, shadowBlur: 28),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _GradientHeadline(
                    gradientPart: '',
                    restPart: s.t('Đi ăn một mình\n', 'Eating alone was\n'),
                  ),
                  _GradientHeadline(
                    gradientPart: s.t('là chuyện của hôm qua', 'so last year'),
                    restPart: '',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.t('Tìm bạn ăn hợp gu, chia bill sòng phẳng, khám phá quán chuẩn vị bằng AI. Không hẹn hò, chỉ ăn.',
                        'Find mates who match your taste, split the bill fairly, discover the real local spots with AI. No dating — just eating.'),
                    textAlign: TextAlign.center,
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.55), size: 13.5)
                        .copyWith(height: 1.6),
                  ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 22),
          V2Cta(
            label: s.t('Bắt đầu gom kèo', 'Start gathering mates'),
            height: 58, fontSize: 16.5,
            onTap: s.nextStep,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => s.go(V2Screen.home),
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                  text: '${s.t('Đã có tài khoản?', 'Already a member?')} ',
                  style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12.5),
                ),
                TextSpan(
                  text: s.t('Đăng nhập', 'Log in'),
                  style: AppTextV2.name(color: const Color(0xFF5B6BF5), size: 12.5)
                      .copyWith(decoration: TextDecoration.underline),
                ),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _SocialProof extends StatelessWidget {
  const _SocialProof({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const _BlobBackground(),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.t('TỐI NAY Ở SÀI GÒN', 'TONIGHT IN SAIGON'),
                style: AppTextV2.eyebrow(color: AppColorsV2.inkA(0.5))
                    .copyWith(fontSize: 11, letterSpacing: 1.54)),
            // The orbit is a fixed 354×452 composition, so it has to be scaled
            // as a whole — on a short screen it would otherwise spill over the
            // headline below it.
            const Expanded(
              child: Center(
                child: FittedBox(fit: BoxFit.contain, child: _OrbitField()),
              ),
            ),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(children: [
                TextSpan(
                  text: '14 mates ',
                  style: AppTextV2.section().copyWith(
                    fontSize: 29, height: 1.16, letterSpacing: -0.87,
                    foreground: Paint()
                      ..shader = const LinearGradient(
                        begin: Alignment(-1, -0.6), end: Alignment(1, 0.6),
                        colors: [AppColorsV2.blue, AppColorsV2.wisteria],
                      ).createShader(const Rect.fromLTWH(0, 0, 140, 36)),
                  ),
                ),
                TextSpan(
                  text: s.t('quanh bạn cũng đang tìm người ăn cùng',
                      'near you are looking for someone to eat with'),
                  style: AppTextV2.section()
                      .copyWith(fontSize: 29, height: 1.16, letterSpacing: -0.87),
                ),
              ]),
            ),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 20, height: 6,
                decoration: BoxDecoration(
                  color: AppColorsV2.wisteria,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              for (var i = 0; i < 2; i++) ...[
                const SizedBox(width: 7),
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: AppColorsV2.inkA(0.16),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            V2Cta(
              label: s.t('Xem ai đang gom kèo', "See who's gathering a table"),
              onTap: s.nextStep,
            ),
            const SizedBox(height: 12),
            Text(
              s.t('Đi ăn vui hơn khi có bạn hợp gu 🤝',
                  'Eating out is better with mates who match your taste 🤝'),
              textAlign: TextAlign.center,
              style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                  .copyWith(fontSize: 11.5, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// Three orbit rings of floating food emoji around the AM mark, laid out from the
/// design's polar coordinates and squashed horizontally so nothing leaves the frame.
class _OrbitField extends StatelessWidget {
  const _OrbitField();

  static Offset _pos(double a, double r) {
    final rad = (a - 90) * math.pi / 180;
    return Offset(
      kOrbitCx + math.cos(rad) * math.min(r, kOrbitRxMax),
      kOrbitCy + math.sin(rad) * r,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 354, height: 452,
      child: Stack(clipBehavior: Clip.none, children: [
        for (final o in kOrbits)
          Positioned(
            left: kOrbitCx - math.min(o.r, kOrbitRxMax),
            top: kOrbitCy - o.r,
            width: math.min(o.r, kOrbitRxMax) * 2,
            height: o.r * 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColorsV2.whiteA(o.alpha)),
              ),
            ),
          ),
        for (final d in kOrbitDots)
          Positioned(
            left: _pos(d.a, d.r).dx - d.s / 2,
            top: _pos(d.a, d.r).dy - d.s / 2,
            child: Container(
              width: d.s, height: d.s,
              decoration: BoxDecoration(
                color: AppColorsV2.whiteA(d.o),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppColorsV2.whiteA(0.6), blurRadius: 8),
                ],
              ),
            ),
          ),
        for (final k in kSparkles)
          Positioned(
            left: _pos(k.a, k.r).dx,
            top: _pos(k.a, k.r).dy,
            child: Text('✦',
                style: TextStyle(
                  fontSize: k.s, height: 1,
                  color: AppColorsV2.whiteA(k.alpha),
                )),
          ),
        Positioned(
          left: kOrbitCx - 59, top: kOrbitCy - 59,
          child: Container(
            width: 118, height: 118, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(34),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A285A).withValues(alpha: 0.22),
                  blurRadius: 40,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Text('AM',
                style: AppTextV2.section().copyWith(
                  fontSize: 40, letterSpacing: -1.6,
                  foreground: Paint()
                    ..shader = const LinearGradient(
                      begin: Alignment(-1, -0.6), end: Alignment(1, 0.6),
                      colors: [AppColorsV2.blue, AppColorsV2.wisteria],
                    ).createShader(const Rect.fromLTWH(0, 0, 80, 44)),
                )),
          ),
        ),
        for (var i = 0; i < kOrbitIcons.length; i++)
          () {
            final b = kOrbitIcons[i];
            final p = _pos(b.a, b.r);
            final left = math.max(8.0, math.min(346 - b.s, p.x - b.s / 2));
            return Positioned(
              left: left, top: p.y - b.s / 2,
              child: FloatingArt(
                period: Duration(milliseconds: (5400 + (i % 4) * 600)),
                delay: Duration(milliseconds: (i % 5) * 350),
                child: Container(
                  width: b.s, height: b.s, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A285A).withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Text(b.e,
                      style: TextStyle(fontSize: b.s * 0.46, height: 1)),
                ),
              ),
            );
          }(),
      ]),
    );
  }
}

extension on Offset {
  double get x => dx;
  double get y => dy;
}

class _BudgetStep extends StatelessWidget {
  const _BudgetStep({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const _BlobBackground(),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 100, 24, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: V2BackButton(size: 44, radius: 16, onTap: s.backStep),
            ),
            const SizedBox(height: 22),
            Text(s.t('BƯỚC 2 / 3', 'STEP 2 / 3'),
                style: AppTextV2.eyebrow(color: const Color(0xFF5B6BF5))
                    .copyWith(fontSize: 11, letterSpacing: 1.76)),
            const SizedBox(height: 8),
            Text(s.t('Bạn thuộc hệ nào?', 'Which spending tribe are you?'),
                style: AppTextV2.section()
                    .copyWith(fontSize: 32, height: 1.12, letterSpacing: -1.12)),
            const SizedBox(height: 8),
            Text(
              s.t('Để tụi mình ghép bàn với người chi tiêu cùng tầm, khỏi ai phải gượng khi chia bill.',
                  'So we seat you with people spending in the same range — nobody gets awkward when the bill lands.'),
              style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 13.5)
                  .copyWith(height: 1.55),
            ),
            const SizedBox(height: 22),
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  for (var i = 0; i < kBudgets.length; i++) ...[
                    _BudgetCard(s: s, i: i),
                    if (i != kBudgets.length - 1) const SizedBox(height: 11),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 22),
            V2Cta(
              label: s.t('Tiếp tục', 'Continue'),
              height: 58, radius: 20, fontSize: 16.5,
              onTap: s.nextStep,
            ),
          ],
        ),
      ),
    ]);
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.s, required this.i});
  final V2State s;
  final int i;

  @override
  Widget build(BuildContext context) {
    final b = kBudgets[i];
    final on = s.budget == i;
    return GestureDetector(
      onTap: () => s.pickBudget(i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: on ? AppColorsV2.wisteria : Colors.transparent, width: 2,
          ),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Row(children: [
          SizedBox(
            width: 46, height: 46,
            child: FoodArt(asset: b.img, shadowOpacity: 0.12, shadowBlur: 9),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.tr(b.name), style: AppTextV2.name(size: 15)),
                const SizedBox(height: 2),
                Text(s.tr(b.desc),
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 22, height: 22, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? AppColorsV2.wisteria : const Color(0xFFEDF1F7),
              shape: BoxShape.circle,
            ),
            child: on
                ? Text('✓', style: AppTextV2.name(color: Colors.white, size: 11))
                : null,
          ),
        ]),
      ),
    );
  }
}

class _TasteStep extends StatelessWidget {
  const _TasteStep({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      const _BlobBackground(),
      Padding(
        padding: const EdgeInsets.only(top: 100, bottom: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: V2BackButton(size: 44, radius: 16, onTap: s.backStep),
                  ),
                  const SizedBox(height: 22),
                  Text(s.t('BƯỚC 3 / 3', 'STEP 3 / 3'),
                      style: AppTextV2.eyebrow(color: const Color(0xFF5B6BF5))
                          .copyWith(fontSize: 11, letterSpacing: 1.76)),
                  const SizedBox(height: 8),
                  Text(s.t('Gu món của bạn?', "What's your taste?"),
                      style: AppTextV2.section()
                          .copyWith(fontSize: 32, height: 1.12, letterSpacing: -1.12)),
                  const SizedBox(height: 8),
                  Text(
                    s.t('Chọn ít nhất 3 món. AI sẽ dùng để ghép mates và gợi quán.',
                        'Pick at least three. The AI uses them to match mates and suggest spots.'),
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 13.5)
                        .copyWith(height: 1.55),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            // Scrolls the chip grid on short screens (e.g. iPhone SE) instead of
            // letting it push the CTA below the fold — CTA stays pinned below.
            Expanded(
              child: SingleChildScrollView(
                child: Column(children: [
                  for (var r = 0; r < 4; r++) ...[
                    _TasteRow(s: s, row: r),
                    if (r != 3) const SizedBox(height: 11),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColorsV2.whiteA(0.72),
                        border: Border.all(color: AppColorsV2.whiteA(0.9)),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Row(children: [
                        Text('${s.tastes.length}',
                            style: AppTextV2.stat(color: const Color(0xFF5B6BF5))),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            s.t('món đã chọn — đủ 3 là bắt đầu ghép được',
                                'tastes picked — three is enough to start matching'),
                            style: AppTextV2.body(size: 12.5).copyWith(height: 1.4),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(children: [
                V2Cta(
                  label: s.t('Vào Ăn Mates', 'Enter AnMates'),
                  height: 58, radius: 20, fontSize: 16.5,
                  onTap: () => s.go(V2Screen.home),
                ),
                const SizedBox(height: 12),
                Text(
                  s.t('Không thu thập GPS ngầm. Không ký quỹ.',
                      'No silent GPS tracking. No deposits held.'),
                  textAlign: TextAlign.center,
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.42))
                      .copyWith(fontSize: 11.5, fontWeight: FontWeight.w500),
                ),
              ]),
            ),
          ],
        ),
      ),
    ]);
  }
}

/// One staggered row of taste chips. Rows 2 and 4 start further left so the grid
/// never lines up into columns.
class _TasteRow extends StatelessWidget {
  const _TasteRow({required this.s, required this.row});
  final V2State s;
  final int row;

  @override
  Widget build(BuildContext context) {
    final items = kTastes.sublist(row * 5, row * 5 + 5);
    return SizedBox(
      height: 54,
      // Fades both edges so a row that overflows the viewport reads as
      // "swipe for more" rather than a clipped/broken layout.
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent, Colors.black, Colors.black, Colors.transparent,
          ],
          stops: [0, 0.03, 0.94, 1],
        ).createShader(rect),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: 24 + kTasteRowShifts[row], right: 24),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 11),
          itemBuilder: (context, j) {
            final index = row * 5 + j;
            final on = s.tastes.contains(index);
            return GestureDetector(
              onTap: () => s.toggleTaste(index),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  color: on ? null : Colors.white,
                  gradient: on ? AppGradientsV2.cta : null,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: on
                          ? const Color(0xFF5A50F0).withValues(alpha: 0.42)
                          : const Color(0xFF0A285A).withValues(alpha: 0.14),
                      blurRadius: on ? 10 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(items[j].emoji, style: const TextStyle(fontSize: 19, height: 1)),
                  const SizedBox(width: 10),
                  Text(
                    s.tr(items[j].name),
                    style: AppTextV2.name(
                      color: on ? Colors.white : AppColorsV2.ink, size: 15,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}

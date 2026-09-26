import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/app_theme_v2.dart';
import '../../theme/v2_layout.dart';
import '../../widgets/v2/aurora_background.dart';
import '../../widgets/v2/design_frame.dart';
import '../../widgets/v2/glass_nav_bar.dart';
import '../../widgets/v2/notifications_sheet.dart';
import '../../widgets/v2/radius_sheet.dart';
import '../../widgets/v2/search_overlay.dart';
import 'screens/all_venues_screen.dart';
import 'screens/bill_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/detail_screen.dart';
import 'screens/filters_screen.dart';
import 'screens/home_screen.dart';
import 'screens/local_screen.dart';
import 'screens/me_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pay_screen.dart';
import 'screens/rate_screen.dart';
import 'screens/swipe_screen.dart';
import 'screens/trust_screen.dart';
import 'v2_state.dart';

/// The phone shell every v2 screen sits inside: the aurora wash, the language
/// toggle pinned top-right, the current screen, the glass nav, and the
/// overlays that float above everything (search, notifications, feed radius).
///
/// Port of the Claude Design project *Mobile app design planning* — all 19
/// canvas frames across its five flows.
class V2App extends StatelessWidget {
  const V2App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Kick the catalogue fetch as the shell mounts, so the feed has real
      // venues by the time onboarding hands over to Explore.
      create: (_) => V2State()
        ..loadVenues()
        ..loadCandidates()
        ..loadProfile(),
      child: const V2AppBody(),
    );
  }
}

/// The shell itself, split out so tests can mount it against a seeded state.
class V2AppBody extends StatelessWidget {
  const V2AppBody({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppColorsV2.canvas,
      // Everything — screens, glass nav, overlays — lays out in the canvas's
      // 402 × 874 frame and scales down together on shorter phones, so the nav
      // keeps its proportions against the content it floats over.
      body: DesignFrame(
        child: Stack(
          children: [
            Positioned.fill(
              child: AuroraBackground(
                washOpacity: s.washOpacity,
                grainOpacity: s.grainOpacity,
              ),
            ),

            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                child: KeyedSubtree(
                  key: ValueKey('${s.screen}-${s.step}'),
                  child: _screenFor(s.screen),
                ),
              ),
            ),

            // The keyboard owns the bottom of the screen while it is up. Read the
            // raw view: Scaffold consumes the inset before it reaches the body.
            if (s.showNav && View.of(context).viewInsets.bottom == 0)
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: SafeArea(
                  top: false,
                  child: GlassNavBar(
                    en: s.en,
                    current: _tabFor(s.screen),
                    onSelect: (tab) => s.go(switch (tab) {
                      NavTab.discover => V2Screen.home,
                      NavTab.swipe => V2Screen.swipe,
                      NavTab.tables => V2Screen.chat,
                      NavTab.me => V2Screen.me,
                    }),
                  ),
                ),
              ),

            Positioned(top: topInset + 8, right: 16, child: _LangToggle(s: s)),

            if (s.searchOpen)
              Positioned.fill(
                child: SearchOverlay(
                  en: s.en,
                  onClose: () => s.setSearchOpen(false),
                  venues: s.venues,
                  onOpenVenue: (v) => s.openVenueNamed(v.name),
                ),
              ),

            if (s.notifsOpen)
              Positioned.fill(
                child: NotificationsSheet(
                  en: s.en,
                  onClose: () => s.setNotifsOpen(false),
                ),
              ),

            if (s.radiusSheetOpen)
              Positioned.fill(
                child: RadiusSheet(
                  en: s.en,
                  radiusKm: s.radiusKm,
                  minKm: kRadiusMinKm,
                  maxKm: kRadiusMaxKm,
                  stepKm: kRadiusStepKm,
                  locationOff: s.locationUnavailable,
                  onClose: () => s.setRadiusSheetOpen(false),
                  onApply: (km) {
                    s.setRadiusSheetOpen(false);
                    s.setRadiusKm(km);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  static Widget _screenFor(V2Screen screen) => switch (screen) {
        V2Screen.onb => const OnboardingScreen(),
        V2Screen.home => const HomeScreen(),
        V2Screen.filters => const FiltersScreen(),
        V2Screen.detail => const DetailScreen(),
        V2Screen.swipe => const SwipeScreen(),
        V2Screen.chat => const ChatScreen(),
        V2Screen.bill => const BillScreen(),
        V2Screen.rate => const RateScreen(),
        V2Screen.me => const MeScreen(),
        V2Screen.trust => const TrustScreen(),
        V2Screen.pay => const PayScreen(),
        V2Screen.local => const LocalScreen(),
        V2Screen.allVenues => const AllVenuesScreen(),
      };

  /// The design keeps a tab lit for the screens that live under it — Trust under
  /// Me, and Split bill / Close the meal under Messages.
  static NavTab _tabFor(V2Screen screen) => switch (screen) {
        V2Screen.swipe => NavTab.swipe,
        V2Screen.chat || V2Screen.bill || V2Screen.rate => NavTab.tables,
        V2Screen.me || V2Screen.trust => NavTab.me,
        _ => NavTab.discover,
      };
}

class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    // Each chip is drawn ~30pt tall but hit-tests over a full 48pt square; the
    // white pill is painted behind the pair rather than wrapped around them so
    // the larger hit areas don't make it visibly taller.
    Widget chip(String label, bool active, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: V2Layout.minTap, minHeight: V2Layout.minTap,
            ),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: active ? AppColorsV2.wisteria : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: AppTextV2.name(
                    color: active ? Colors.white : AppColorsV2.inkA(0.5),
                    size: 11,
                  ),
                ),
              ),
            ),
          ),
        );

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          top: 9, bottom: 9,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColorsV2.whiteA(0.92),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10366E).withValues(alpha: 0.16),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            chip('VI', !s.en, () => s.setLang(false)),
            chip('EN', s.en, () => s.setLang(true)),
          ]),
        ),
      ],
    );
  }
}

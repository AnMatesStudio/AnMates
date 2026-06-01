import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// TODO: Import BLoCs and screens when Phase 2 (Auth) is implemented
// For now, this is a placeholder structure showing the intended route hierarchy

/// Main app router configuration
/// Route structure:
/// / (root) → auth-guard → /splash → /auth/* or /app/*
final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // TODO: Implement these routes in Phase 2+
    // GoRoute(
    //   path: '/',
    //   builder: (context, state) => const SplashScreen(),
    // ),
    // GoRoute(
    //   path: '/auth/phone',
    //   builder: (context, state) => PhoneInputView(
    //     onAuthenticated: () => context.go('/app/discover'),
    //   ),
    // ),
    // GoRoute(
    //   path: '/auth/otp',
    //   builder: (context, state) => const OtpView(),
    // ),
    // ShellRoute(
    //   builder: (context, state, child) => MainShell(
    //     navigationShell: navigationShell,
    //   ),
    //   routes: [
    //     GoRoute(
    //       path: '/app/discover',
    //       builder: (context, state) => const DiscoverView(),
    //     ),
    //     GoRoute(
    //       path: '/app/match',
    //       builder: (context, state) => const MatchView(),
    //     ),
    //     GoRoute(
    //       path: '/app/chat',
    //       builder: (context, state) => const ChatListView(),
    //     ),
    //     GoRoute(
    //       path: '/app/profile',
    //       builder: (context, state) => const ProfileView(),
    //     ),
    //   ],
    // ),
    // Placeholder route to prevent router errors during Phase 1
    GoRoute(
      path: '/',
      builder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text('Phase 1 Foundation'),
              SizedBox(height: 16),
              Text('Routes will be wired in Phase 2 (Auth)'),
            ],
          ),
        ),
      ),
    ),
  ],
);

/// Auth guard for go_router
/// Uncomment and implement in Phase 2 when AuthCubit is ready
// String? authGuard(BuildContext context, GoRouterState state) {
//   final authState = context.read<AuthCubit>().state;
//   final isAuthenticated = authState is AuthAuthenticated;
//   final isGoingToAuth = state.matchedLocation.startsWith('/auth');
//
//   if (!isAuthenticated && !isGoingToAuth) return '/auth/phone';
//   if (isAuthenticated && isGoingToAuth) return '/app/discover';
//   return null;
// }

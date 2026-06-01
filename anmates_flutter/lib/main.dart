import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/di/injection.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'views/splash/splash_screen.dart';

Future<void> main() async {
  // runZonedGuarded catches any uncaught async error and forwards it to
  // the same handler we wire onto FlutterError.onError below. In a real
  // production build this becomes the bridge to Crashlytics/Sentry.
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Bootstrap the service locator BEFORE runApp so any widget that
      // resolves from getIt at first build (e.g., BlocProvider creating an
      // AuthCubit) has its dependencies available. Without this call the
      // entire lib/features/ stack is dead code at runtime.
      await setupDependencies();

      // Framework-level error funnel. In release we forward to Crashlytics;
      // in debug we keep Flutter's default red-screen so devs see the stack.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        // TODO(observability): FirebaseCrashlytics.instance.recordFlutterError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        // TODO(observability): FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        debugPrint('Uncaught platform error: $error\n$stack');
        return true; // mark handled — keep app alive
      };

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
        ),
      );
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

      runApp(
        ChangeNotifierProvider(
          create: (_) => ThemeNotifier(),
          child: const AnMatesApp(),
        ),
      );
    },
    (error, stack) {
      // TODO(observability): forward to Crashlytics/Sentry
      debugPrint('Uncaught zoned error: $error\n$stack');
    },
  );
}

class AnMatesApp extends StatelessWidget {
  const AnMatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ĂnMates',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
      // The phone-frame wrapper is a *dev* affordance for previewing the
      // mobile layout on a desktop browser. Wrapping production builds
      // would clamp tablet/desktop deployments to a 430x900 viewport.
      builder: kDebugMode ? _webFrameBuilder : null,
    );
  }
}

Widget _webFrameBuilder(BuildContext context, Widget? child) {
  if (!kIsWeb) return child!;
  final mq = MediaQuery.of(context);
  if (mq.size.width <= 600) return child!;

  const frameW = 430.0;
  final frameH = (mq.size.height - 48).clamp(600.0, 900.0);

  return ColoredBox(
    color: const Color(0xFF0C0B18),
    child: Center(
      child: Container(
        width: frameW,
        height: frameH,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(44),
          boxShadow: [
            BoxShadow(
              color: AppColors.berry.withValues(alpha: 0.25),
              blurRadius: 80,
              spreadRadius: -10,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: MediaQuery(
          data: mq.copyWith(
            size: const Size(frameW, 900),
            padding: const EdgeInsets.only(top: 44, bottom: 34),
            viewPadding: const EdgeInsets.only(top: 44, bottom: 34),
            viewInsets: EdgeInsets.zero,
          ),
          child: child!,
        ),
      ),
    ),
  );
}

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme_v2.dart';
import 'views/v2/v2_app.dart';

/// AnMates — single entry point. The v2 design (Claude Design project
/// "Mobile app design planning") is the only UI; the pre-v2 screens, widgets
/// and theme have been removed. Business logic that outlives any one UI —
/// `services/`, `models/`, `utils/` — stays, ready to wire into these screens
/// once they move off seed data.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const AnMatesApp());
}

class AnMatesApp extends StatelessWidget {
  const AnMatesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ăn Mates',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColorsV2.canvas,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColorsV2.wisteria,
          primary: AppColorsV2.wisteria,
        ),
      ),
      home: const V2App(),
      builder: _webFrameBuilder,
    );
  }
}

/// On a desktop browser, crop the app into a phone frame instead of stretching
/// the mobile layout across the whole window, sized to the design's own
/// 402 × 874 artboard. Below 600px wide (a real phone) it renders edge to edge.
Widget _webFrameBuilder(BuildContext context, Widget? child) {
  if (!kIsWeb) return child!;
  final mq = MediaQuery.of(context);
  if (mq.size.width <= 600) return child!;

  const frameW = 402.0;
  final frameH = (mq.size.height - 48).clamp(600.0, 874.0);

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
              color: AppColorsV2.wisteria.withValues(alpha: 0.28),
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
        // Report the frame's real height — a hardcoded 900 here would make the
        // app lay out taller than the box it is actually clamped into.
        child: MediaQuery(
          data: mq.copyWith(
            size: Size(frameW, frameH),
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

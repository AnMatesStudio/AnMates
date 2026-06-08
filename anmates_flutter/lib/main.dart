import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'views/chat/chat_detail_view.dart';
import 'views/splash/splash_screen.dart';

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

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeNotifier(),
      child: const AnMatesApp(),
    ),
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
      home: _resolveHome(),
      builder: _webFrameBuilder,
    );
  }

  // Dev/e2e-only deep-link straight into a live chat for the 2-phone AI Concierge
  // video — open /?dev_match=<id>&dev_phone=<phone>&dev_mate=<name>. Driver:
  // .dev-e2e/e2e_two_users.js. Gated behind the same dev condition as the OTP
  // bypass (kDebugMode or a localhost API), so it is INERT in a production web
  // build (real API domain) — safe to ship. Backend dev-login also enforces
  // DEV_MODE + the secret, so it can't be abused against prod.
  static final bool _devDeepLinkEnabled = kDebugMode ||
      apiBaseUrl.contains('localhost') ||
      apiBaseUrl.contains('127.0.0.1');

  Widget _resolveHome() {
    if (kIsWeb && _devDeepLinkEnabled) {
      final q = Uri.base.queryParameters;
      final matchId = q['dev_match'];
      if (matchId != null && matchId.isNotEmpty) {
        return _DevChatDeepLink(
          matchId: matchId,
          phone: q['dev_phone'] ?? '+84999000001',
          mate: q['dev_mate'] ?? 'Mate',
        );
      }
    }
    return const SplashScreen();
  }
}

// TEMP (dev/e2e only): dev-logs the browser in with the given phone, then opens
// the live ChatDetailView for the match. Paired with _resolveHome above.
class _DevChatDeepLink extends StatefulWidget {
  final String matchId;
  final String phone;
  final String mate;
  const _DevChatDeepLink({
    required this.matchId,
    required this.phone,
    required this.mate,
  });

  @override
  State<_DevChatDeepLink> createState() => _DevChatDeepLinkState();
}

class _DevChatDeepLinkState extends State<_DevChatDeepLink> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _enter());
  }

  Future<void> _enter() async {
    String? uid;
    try {
      final data = await AuthService().devLogin(
        secret: 'dev-local-2026',
        phone: widget.phone,
        name: widget.mate,
      );
      uid = (data['user'] as Map<String, dynamic>?)?['id'] as String?;
    } catch (_) {
      // Stay graceful — open the chat anyway (history still loads if logged in).
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ChatDetailView(
          matchId: widget.matchId,
          currentUserId: uid,
          mateName: widget.mate,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.mint,
    body: Center(child: CircularProgressIndicator()),
  );
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

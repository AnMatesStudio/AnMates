import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';
import 'auth_error_messages.dart';
import 'otp_view.dart';

// Dev bypass — must match backend DEV_BYPASS_SECRET. Override via:
//   flutter run --dart-define=DEV_BYPASS_SECRET=...
const _devBypassSecret = String.fromEnvironment(
  'DEV_BYPASS_SECRET',
  defaultValue: 'dev-local-2026',
);
const _devTestPhone = '+84999000001';
const _devTestName = 'Dev User';

// Must match the <div id="..."> in web/index.html.
const _recaptchaContainerId = 'recaptcha-container';
const _otpRequestTimeout = Duration(seconds: 90);

class PhoneInputView extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const PhoneInputView({super.key, required this.onAuthenticated});

  @override
  State<PhoneInputView> createState() => _PhoneInputViewState();
}

class _PhoneInputViewState extends State<PhoneInputView> {
  final _phoneCtrl = TextEditingController();
  bool _loading = false;

  /// Web-only. Per Firebase docs, the verifier must be re-created on retry —
  /// we hold a reference so we can `clear()` it on dispose to release the
  /// DOM widget.
  RecaptchaVerifier? _recaptchaVerifier;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _clearVerifier();
    super.dispose();
  }

  void _clearVerifier() {
    _recaptchaVerifier?.clear();
    _recaptchaVerifier = null;
  }

  RecaptchaVerifier _buildVerifier() {
    return RecaptchaVerifier(
      auth: FirebaseAuthPlatform.instance,
      container: _recaptchaContainerId,
      size: RecaptchaVerifierSize.normal,
      theme: RecaptchaVerifierTheme.light,
      onError: (FirebaseAuthException e) {
        if (!mounted) return;
        _showError(friendlyPhoneAuthError(e.code));
        setState(() => _loading = false);
      },
      onExpired: () {
        if (!mounted) return;
        _clearVerifier();
        _showError('reCAPTCHA đã hết hạn. Thử lại.');
        setState(() => _loading = false);
      },
    );
  }

  bool get _canSubmit => _phoneCtrl.text.trim().length >= 9;

  String _normalizePhone(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'\s+'), '');
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) return '+84${cleaned.substring(1)}';
    return '+84$cleaned';
  }

  Future<void> _sendOtp() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    final phone = _normalizePhone(_phoneCtrl.text.trim());
    if (kIsWeb) {
      await _sendOtpWeb(phone);
    } else {
      await _sendOtpMobile(phone);
    }
  }

  // ── Web flow ───────────────────────────────────────────────────────────────
  // https://firebase.google.com/docs/auth/flutter/phone-auth#web
  Future<void> _sendOtpWeb(String phone) async {
    _clearVerifier();
    _recaptchaVerifier = _buildVerifier();
    try {
      final result = await FirebaseAuth.instance.signInWithPhoneNumber(
        phone,
        _recaptchaVerifier!,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _goToOtp(phone, confirmationResult: result);
    } on FirebaseAuthException catch (e) {
      _clearVerifier();
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(friendlyPhoneAuthError(e.code));
    } catch (e) {
      _clearVerifier();
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ── Mobile flow ────────────────────────────────────────────────────────────
  // https://firebase.google.com/docs/auth/flutter/phone-auth#mobile
  Future<void> _sendOtpMobile(String phone) async {
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: _otpRequestTimeout,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android instant-verification path: sign in without typing OTP.
        try {
          final uc = await FirebaseAuth.instance.signInWithCredential(
            credential,
          );
          final idToken = await uc.user?.getIdToken();
          if (idToken != null && mounted) {
            _goToOtp(phone, autoIdToken: idToken);
          }
        } catch (_) {
          // Fall through to manual OTP entry.
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _loading = false);
        _showError(friendlyPhoneAuthError(e.code));
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _loading = false);
        _goToOtp(phone, verificationId: verificationId);
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  void _goToOtp(
    String phone, {
    String? verificationId,
    String? autoIdToken,
    ConfirmationResult? confirmationResult,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtpView(
          phone: phone,
          name: '',
          verificationId: verificationId ?? '',
          autoIdToken: autoIdToken,
          confirmationResult: confirmationResult,
          onVerified: widget.onAuthenticated,
        ),
      ),
    );
  }

  Future<void> _devSkipOtp() async {
    if (_loading) return;
    setState(() => _loading = true);
    const name = _devTestName;
    try {
      await AuthService().devLogin(
        secret: _devBypassSecret,
        phone: _devTestPhone,
        name: name,
      );
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Dev bypass: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.berry,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.mint, Colors.white],
            stops: [0.0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListenableBuilder(
                    listenable: _phoneCtrl,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 40),
                          const LogoMark(size: 64, float: true),
                          const SizedBox(height: 24),
                          ScreenTitle(
                            title: 'Va Mates, ăn miết.',
                            subtitle:
                                'Nhập SĐT để đăng ký hoặc đăng nhập — không cần mật khẩu.',
                            align: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          _PhoneField(controller: _phoneCtrl),
                          const SizedBox(height: 20),
                          AnmCTA(
                            label: _loading ? 'Đang gửi mã…' : 'Gửi mã OTP',
                            onTap: (_canSubmit && !_loading) ? _sendOtp : null,
                            background: (_canSubmit && !_loading)
                                ? AppColors.berry
                                : AppColors.ink30,
                          ),
                          if (kDebugMode) ...[
                            const SizedBox(height: 12),
                            _DevModeButton(
                              loading: _loading,
                              onTap: _loading ? null : _devSkipOtp,
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Text(
                  'Tiếp tục đồng nghĩa với việc bạn đồng ý với\nĐiều khoản dịch vụ và Chính sách quyền riêng tư của ĂnMates.',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    color: AppColors.ink50,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Dev-only bypass button (only when kDebugMode) ───────────────────────────
class _DevModeButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _DevModeButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF8A1F);
    return Semantics(
      identifier: 'dev_mode_skip_otp',
      button: true,
      label: 'Dev Mode skip OTP',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('dev_mode_skip_otp'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: orange.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bug_report_outlined,
                  size: 18,
                  color: orange.withValues(alpha: loading ? 0.5 : 1.0),
                ),
                const SizedBox(width: 8),
                Text(
                  loading ? 'Đang đăng nhập dev…' : 'Dev Mode (skip OTP)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: orange.withValues(alpha: loading ? 0.5 : 1.0),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Phone field với prefix 🇻🇳 +84 ────────────────────────────────────────────
class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  const _PhoneField({required this.controller});

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(14));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🇻🇳', style: TextStyle(fontSize: 16, height: 1)),
                  const SizedBox(width: 8),
                  Text(
                    '+84',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink70,
                    ),
                  ),
                ],
              ),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            hintText: '912 345 678',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.ink30,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: radius,
              borderSide: BorderSide(color: AppColors.berry, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

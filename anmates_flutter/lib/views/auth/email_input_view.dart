import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';
import 'email_otp_view.dart';

/// Passwordless email-OTP login — an alternative to phone OTP with no reCAPTCHA.
/// Enter an email → backend mails a 6-digit code → [EmailOtpView] verifies it.
class EmailInputView extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const EmailInputView({super.key, required this.onAuthenticated});

  @override
  State<EmailInputView> createState() => _EmailInputViewState();
}

class _EmailInputViewState extends State<EmailInputView> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _canSubmit => _emailRegex.hasMatch(_emailCtrl.text.trim());

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    final email = _emailCtrl.text.trim().toLowerCase();
    try {
      await AuthService().requestEmailOtp(email);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmailOtpView(
            email: email,
            onVerified: widget.onAuthenticated,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
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
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
                  child: IconButton(
                    onPressed: _loading ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ListenableBuilder(
                    listenable: _emailCtrl,
                    builder: (context, _) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          const LogoMark(size: 64, float: true),
                          const SizedBox(height: 24),
                          ScreenTitle(
                            title: 'Đăng nhập bằng email',
                            subtitle:
                                'Nhập email để nhận mã OTP — không cần mật khẩu, không captcha.',
                            align: TextAlign.center,
                          ),
                          const SizedBox(height: 36),
                          _EmailField(controller: _emailCtrl),
                          const SizedBox(height: 20),
                          AnmCTA(
                            label: _loading ? 'Đang gửi mã…' : 'Gửi mã OTP',
                            onTap: (_canSubmit && !_loading) ? _sendOtp : null,
                            background: (_canSubmit && !_loading)
                                ? AppColors.berry
                                : AppColors.ink30,
                          ),
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

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  const _EmailField({required this.controller});

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
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        enableSuggestions: false,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Icon(Icons.mail_outline, size: 20, color: AppColors.ink70),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          hintText: 'ban@email.com',
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
    );
  }
}

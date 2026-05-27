import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/anm_logo.dart';
import '../../widgets/anm_widgets.dart';

class AuthView extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthView({super.key, required this.onAuthenticated});

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final name = _nameCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return false;
    if (_isRegister && name.isEmpty) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    setState(() => _loading = true);
    try {
      if (_isRegister) {
        await AuthService().register(
          _emailCtrl.text.trim(),
          _passwordCtrl.text,
          _nameCtrl.text.trim(),
        );
      } else {
        await AuthService().login(_emailCtrl.text.trim(), _passwordCtrl.text);
      }
      if (mounted) widget.onAuthenticated();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.berry,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSocialTap(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đăng nhập $provider sắp ra mắt 🚀'),
        backgroundColor: AppColors.ink70,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ListenableBuilder(
              listenable: Listenable.merge([
                _emailCtrl,
                _passwordCtrl,
                _nameCtrl,
              ]),
              builder: (context, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    const LogoMark(size: 64),
                    const SizedBox(height: 24),
                    ScreenTitle(
                      title: _isRegister
                          ? 'Tạo tài khoản'
                          : 'Va Mates, ăn miết.',
                      subtitle: _isRegister
                          ? 'Nhập thông tin để bắt đầu va Mates.'
                          : 'Sòng phẳng, an toàn, không sến — đăng nhập để bắt đầu.',
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: 36),

                    // Name field (register only)
                    if (_isRegister) ...[
                      _InputField(
                        controller: _nameCtrl,
                        hint: 'Tên của bạn',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Email field
                    _InputField(
                      controller: _emailCtrl,
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),

                    // Password field
                    _InputField(
                      controller: _passwordCtrl,
                      hint: 'Mật khẩu',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffixIcon: GestureDetector(
                        onTap: () => setState(() => _obscure = !_obscure),
                        child: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.ink50,
                        ),
                      ),
                    ),
                    if (_isRegister)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tối thiểu 10 ký tự',
                            style: AppTextStyles.body(
                              size: 11,
                              color: AppColors.ink50,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // CTA button
                    AnmCTA(
                      label: _loading
                          ? 'Đang xử lý…'
                          : (_isRegister ? 'Tạo tài khoản' : 'Đăng nhập'),
                      onTap: (_canSubmit && !_loading) ? _submit : null,
                      background: (_canSubmit && !_loading)
                          ? AppColors.berry
                          : AppColors.ink30,
                    ),
                    const SizedBox(height: 16),

                    // Toggle login / register
                    GestureDetector(
                      onTap: () => setState(() {
                        _isRegister = !_isRegister;
                        _emailCtrl.clear();
                        _passwordCtrl.clear();
                        _nameCtrl.clear();
                      }),
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: _isRegister
                                  ? 'Đã có tài khoản? '
                                  : 'Chưa có tài khoản? ',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: AppColors.ink50,
                              ),
                            ),
                            TextSpan(
                              text: _isRegister ? 'Đăng nhập' : 'Đăng ký ngay',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.berry,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.berry,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const _OrDivider(),
                    const SizedBox(height: 20),

                    _SocialButton(
                      label: 'Tiếp tục với Facebook',
                      icon: 'ƒ',
                      iconColor: const Color(0xFF1877F2),
                      backgroundColor: const Color(0xFFE7F0FD),
                      onTap: () => _onSocialTap('Facebook'),
                    ),
                    const SizedBox(height: 10),
                    _SocialButton(
                      label: 'Tiếp tục với Apple',
                      icon: '',
                      useAppleIcon: true,
                      iconColor: AppColors.ink,
                      backgroundColor: const Color(0xFFF2F2F2),
                      onTap: () => _onSocialTap('Apple'),
                    ),
                    const SizedBox(height: 10),
                    _SocialButton(
                      label: 'Tiếp tục với Google',
                      icon: 'G',
                      iconColor: const Color(0xFFEA4335),
                      backgroundColor: const Color(0xFFFCECEB),
                      onTap: () => _onSocialTap('Google'),
                    ),
                    const SizedBox(height: 32),

                    Text(
                      'Tiếp tục đồng nghĩa với việc bạn đồng ý với\nĐiều khoản dịch vụ và Chính sách quyền riêng tư của ĂnMates.',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: AppColors.ink50,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Generic input field ──────────────────────────────────────────────────────
class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboardType;
  final Widget? suffixIcon;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _focused ? AppColors.berry : AppColors.ink10,
            width: _focused ? 1.5 : 1,
          ),
          boxShadow: [
            if (_focused)
              BoxShadow(
                color: AppColors.berry.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              )
            else
              const BoxShadow(
                color: AppColors.ink10,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Icon(widget.icon, size: 20, color: AppColors.ink50),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    color: AppColors.ink30,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  suffixIcon: widget.suffixIcon != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: widget.suffixIcon,
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── OR Divider ───────────────────────────────────────────────────────────────
class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.ink10, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'HOẶC',
            style: AppTextStyles.mono(size: 11, color: AppColors.ink30),
          ),
        ),
        Expanded(child: Divider(color: AppColors.ink10, thickness: 1)),
      ],
    );
  }
}

// ─── Social button ────────────────────────────────────────────────────────────
class _SocialButton extends StatelessWidget {
  final String label;
  final String icon;
  final Color iconColor;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool useAppleIcon;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.onTap,
    this.useAppleIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.ink10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (useAppleIcon)
              Icon(Icons.apple, color: iconColor, size: 22)
            else
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: iconColor,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

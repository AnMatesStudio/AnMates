import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import 'legal_screen.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **Đăng nhập / Đăng ký.** Email + password against `POST /auth/login` and
/// `POST /auth/register` — no OTP. The UI v2 migration dropped the old auth
/// screens, which left every account feature (real deck, messages, booking)
/// unreachable; this is the way back in.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  DateTime? _dob;
  bool _accept = false;
  final _termsTap = TapGestureRecognizer();
  final _privacyTap = TapGestureRecognizer();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  void _submit(V2State s) => s.submitAuth(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        birthDate: _dob,
        acceptTerms: _accept,
      );

  Future<void> _pickDob(V2State s) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 22, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: s.t('Bạn phải từ 18 tuổi', 'You must be 18 or older'),
    );
    if (picked != null && mounted) setState(() => _dob = picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final reg = s.authRegister;
    final pad = V2Layout.hPad(context);
    _termsTap.onTap = () => showLegalSheet(context, s, privacy: false);
    _privacyTap.onTap = () => showLegalSheet(context, s, privacy: true);

    return AutofillGroup(
      child: ListView(
        padding: EdgeInsets.fromLTRB(pad + 4, V2Layout.contentTop(context), pad + 4, 32),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: V2BackButton(onTap: s.authCancel),
          ),
          const SizedBox(height: 28),
          Text(
            reg ? s.t('Tạo tài khoản', 'Create account') : s.t('Đăng nhập', 'Sign in'),
            style: AppTextV2.section().copyWith(fontSize: 30, letterSpacing: -1),
          ),
          const SizedBox(height: 6),
          Text(
            reg
                ? s.t('Để quẹt người thật, nhắn tin và đặt bàn.',
                    'To swipe real people, chat and book tables.')
                : s.t('Chào mừng quay lại Ăn Mates.', 'Welcome back to AnMates.'),
            style: AppTextV2.body(size: 13.5),
          ),
          const SizedBox(height: 24),
          if (reg) ...[
            _Field(
              key: const Key('auth-name'),
              controller: _name,
              label: s.t('Tên', 'Name'),
              hint: s.t('Tên mọi người sẽ thấy', 'What people will see'),
              autofill: const [AutofillHints.name],
              action: TextInputAction.next,
            ),
            const SizedBox(height: 12),
          ],
          _Field(
            key: const Key('auth-email'),
            controller: _email,
            label: 'Email',
            hint: 'ban@email.com',
            keyboard: TextInputType.emailAddress,
            autofill: const [AutofillHints.email],
            action: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          _Field(
            key: const Key('auth-password'),
            controller: _password,
            label: s.t('Mật khẩu', 'Password'),
            hint: reg
                ? s.t('Ít nhất ${V2State.minPasswordLength} ký tự',
                    'At least ${V2State.minPasswordLength} characters')
                : '',
            obscure: !_showPassword,
            autofill: [reg ? AutofillHints.newPassword : AutofillHints.password],
            action: TextInputAction.done,
            onSubmitted: () => _submit(s),
            trailing: IconButton(
              tooltip: _showPassword ? s.t('Ẩn', 'Hide') : s.t('Hiện', 'Show'),
              icon: Icon(
                _showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                size: 20,
                color: AppColorsV2.inkA(0.4),
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          if (reg) ...[
            const SizedBox(height: 12),
            Semantics(
              button: true,
              label: s.t('Ngày sinh', 'Date of birth'),
              child: V2TapTarget(
                key: const Key('auth-dob'),
                onTap: () => _pickDob(s),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.t('Ngày sinh', 'Date of birth'),
                      style: AppTextV2.name(color: AppColorsV2.inkA(0.6), size: 12.5)),
                  const SizedBox(height: 6),
                  Container(
                    height: 52,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColorsV2.inkA(0.08)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _dob == null
                            ? s.t('Chọn ngày sinh', 'Pick your date of birth')
                            : '${_dob!.day.toString().padLeft(2, '0')}/'
                                '${_dob!.month.toString().padLeft(2, '0')}/'
                                '${_dob!.year}',
                        style: AppTextV2.body(
                            color: _dob == null ? AppColorsV2.inkA(0.35) : AppColorsV2.ink,
                            size: 14),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Semantics(
                  container: true,
                  label: s.t('Đồng ý Điều khoản và Chính sách', 'Accept the Terms and Privacy Policy'),
                  child: Checkbox(
                    key: const Key('auth-terms'),
                    value: _accept,
                    activeColor: AppColorsV2.wisteria,
                    onChanged: (v) => setState(() => _accept = v ?? false),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTextV2.body(size: 12.5),
                      children: [
                        TextSpan(text: s.t('Tôi từ 18 tuổi trở lên và đồng ý ', 'I am 18+ and agree to the ')),
                        TextSpan(
                          text: s.t('Điều khoản', 'Terms'),
                          style: AppTextV2.body(color: AppColorsV2.wisteria, size: 12.5).merge(const TextStyle(fontWeight: FontWeight.bold)),
                          recognizer: _termsTap,
                        ),
                        TextSpan(text: s.t(' và ', ' and the ')),
                        TextSpan(
                          text: s.t('Chính sách quyền riêng tư', 'Privacy Policy'),
                          style: AppTextV2.body(color: AppColorsV2.wisteria, size: 12.5).merge(const TextStyle(fontWeight: FontWeight.bold)),
                          recognizer: _privacyTap,
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (s.authError case final err?) ...[
            const SizedBox(height: 12),
            Text(err,
                key: const Key('auth-error'),
                style: AppTextV2.name(color: AppColorsV2.alert, size: 13)),
          ],
          const SizedBox(height: 22),
          Opacity(
            opacity: s.authBusy ? 0.6 : 1,
            child: V2Cta(
              key: const Key('auth-submit'),
              label: s.authBusy
                  ? s.t('Đang xử lý…', 'Working…')
                  : reg
                      ? s.t('Đăng ký', 'Sign up')
                      : s.t('Đăng nhập', 'Sign in'),
              onTap: () => _submit(s),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: V2TapTarget(
              onTap: () => s.setAuthRegister(!reg),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                    text: reg
                        ? s.t('Đã có tài khoản? ', 'Have an account? ')
                        : s.t('Chưa có tài khoản? ', 'New here? '),
                    style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 13),
                  ),
                  TextSpan(
                    text: reg ? s.t('Đăng nhập', 'Sign in') : s.t('Đăng ký', 'Sign up'),
                    style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13),
                  ),
                ])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboard,
    this.obscure = false,
    this.autofill = const [],
    this.action,
    this.onSubmitted,
    this.trailing,
  });
  final TextEditingController controller;
  final String label, hint;
  final TextInputType? keyboard;
  final bool obscure;
  final List<String> autofill;
  final TextInputAction? action;
  final VoidCallback? onSubmitted;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextV2.name(color: AppColorsV2.inkA(0.6), size: 12.5)),
      const SizedBox(height: 6),
      Container(
        height: 52,
        padding: EdgeInsets.only(left: 16, right: trailing == null ? 16 : 4),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColorsV2.inkA(0.08)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              obscureText: obscure,
              autocorrect: false,
              enableSuggestions: !obscure,
              autofillHints: autofill,
              textInputAction: action,
              onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: hint,
                hintStyle: AppTextV2.body(color: AppColorsV2.inkA(0.35), size: 14),
              ),
              style: AppTextV2.body(color: AppColorsV2.ink, size: 14.5),
            ),
          ),
          ?trailing,
        ]),
      ),
    ]);
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, LogicalKeyboardKey;
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/anm_widgets.dart';

const _otpLength = 6;
const _resendTimeout = Duration(seconds: 90);

/// Enters + verifies the 6-digit email OTP minted by the backend. Mirrors the
/// phone [OtpView] UX (boxes + custom keypad + resend timer) but talks to the
/// passwordless `/auth/email/verify-otp` endpoint instead of Firebase.
class EmailOtpView extends StatefulWidget {
  final String email;
  final VoidCallback onVerified;

  const EmailOtpView({
    super.key,
    required this.email,
    required this.onVerified,
  });

  @override
  State<EmailOtpView> createState() => _EmailOtpViewState();
}

class _EmailOtpViewState extends State<EmailOtpView> {
  final List<String> _digits = List.filled(_otpLength, '');
  bool _loading = false;
  int _secondsLeft = _resendTimeout.inSeconds;
  Timer? _timer;
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent || _loading) return KeyEventResult.ignored;
    final char = event.character;
    if (char != null && RegExp(r'^[0-9]$').hasMatch(char)) {
      _onKeyTap(char);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _onKeyTap('⌫');
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendTimeout.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        } else {
          t.cancel();
        }
      });
    });
  }

  void _onKeyTap(String key) {
    if (_loading) return;
    setState(() {
      if (key == '⌫') {
        for (int i = _digits.length - 1; i >= 0; i--) {
          if (_digits[i].isNotEmpty) {
            _digits[i] = '';
            break;
          }
        }
      } else {
        for (int i = 0; i < _digits.length; i++) {
          if (_digits[i].isEmpty) {
            _digits[i] = key;
            break;
          }
        }
      }
    });
    if (_digits.every((d) => d.isNotEmpty)) {
      _submitOtp(_digits.join());
    }
  }

  void _clearDigits() {
    for (int i = 0; i < _digits.length; i++) {
      _digits[i] = '';
    }
  }

  Future<void> _submitOtp(String code) async {
    setState(() => _loading = true);
    try {
      await AuthService().verifyEmailOtp(widget.email, code);
      if (mounted) widget.onVerified();
    } catch (e) {
      _resetOnError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _loading) return;
    setState(() => _loading = true);
    try {
      await AuthService().requestEmailOtp(widget.email);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _clearDigits();
      });
      _startTimer();
      _showInfo('Đã gửi lại mã tới ${widget.email}');
    } catch (e) {
      _resetOnError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _resetOnError(String msg) {
    if (!mounted) return;
    _showError(msg);
    setState(() {
      _loading = false;
      _clearDigits();
    });
  }

  void _showError(String msg) => _snack(msg, AppColors.berry);
  void _showInfo(String msg) => _snack(msg, AppColors.ink);

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int get _activeIndex => _digits.indexWhere((d) => d.isEmpty);

  String get _timerText {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: GestureDetector(
                  onTap: _loading ? null : () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [
                        BoxShadow(
                          color: AppColors.ink10,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 20,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('XÁC THỰC EMAIL'),
                    const SizedBox(height: 10),
                    Text(
                      'Nhập mã 6 số',
                      style: AppTextStyles.display(
                        size: 36,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vừa gửi tới ${widget.email}. Kiểm tra cả hộp thư spam.',
                      style: AppTextStyles.body(
                        size: 15,
                        color: AppColors.ink70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _otpLength,
                    (i) => _OtpBox(
                      digit: _digits[i],
                      isActive: !_loading && i == _activeIndex,
                      isLoading: _loading,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: _secondsLeft == 0 ? _resend : null,
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Chưa nhận được? ',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: AppColors.ink50,
                          ),
                        ),
                        TextSpan(
                          text: _secondsLeft > 0
                              ? 'Gửi lại ($_timerText)'
                              : 'Gửi lại',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _secondsLeft > 0
                                ? AppColors.ink30
                                : AppColors.berry,
                            decoration: _secondsLeft == 0
                                ? TextDecoration.underline
                                : TextDecoration.none,
                            decorationColor: AppColors.berry,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 32),
                    child: CircularProgressIndicator(color: AppColors.berry),
                  ),
                )
              else ...[
                _NumericKeypad(onKeyTap: _onKeyTap),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── OTP Digit Box ────────────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final String digit;
  final bool isActive;
  final bool isLoading;

  const _OtpBox({
    required this.digit,
    required this.isActive,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLoading
              ? AppColors.berry.withValues(alpha: 0.4)
              : isActive
              ? AppColors.berry
              : AppColors.ink10,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.berry.withValues(alpha: 0.22),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                ),
              ]
            : const [
                BoxShadow(
                  color: AppColors.ink10,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Center(
        child: digit.isNotEmpty
            ? Text(
                digit,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              )
            : isActive
            ? Container(
                width: 2,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.berry,
                  borderRadius: BorderRadius.circular(1),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ─── Custom Numeric Keypad ────────────────────────────────────────────────────
class _NumericKeypad extends StatelessWidget {
  final ValueChanged<String> onKeyTap;
  const _NumericKeypad({required this.onKeyTap});

  static const _keys = [
    '1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 10,
        children: _keys
            .map(
              (key) => _KeyButton(
                keyLabel: key,
                onTap: key.isEmpty ? null : () => onKeyTap(key),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KeyButton extends StatefulWidget {
  final String keyLabel;
  final VoidCallback? onTap;
  const _KeyButton({required this.keyLabel, this.onTap});

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (widget.keyLabel.isEmpty) return const SizedBox.shrink();
    final isBackspace = widget.keyLabel == '⌫';
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.berry.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink10,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: isBackspace
              ? const Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: AppColors.ink70,
                )
              : Text(
                  widget.keyLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.ink,
                  ),
                ),
        ),
      ),
    );
  }
}

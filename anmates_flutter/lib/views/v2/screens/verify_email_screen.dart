import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **Email verification** — reached after sign-up (or when the deck is
/// held back on an unverified address). The 6-digit code is confirmed
/// against the server via [V2State.confirmEmailCode]; a passing code takes
/// the user straight to Explore, "Later" lets them browse without it.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        V2Layout.hPad(context), V2Layout.contentTop(context),
        V2Layout.hPad(context), navClearance(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('Xác minh email', 'Verify your email'),
              style: AppTextV2.section().copyWith(fontSize: 25)),
          const SizedBox(height: 8),
          Text(
            s.t(
              'Nhập mã 6 số chúng tôi vừa gửi tới ${s.account?.email ?? 'email của bạn'}. Cần xác minh trước khi quẹt và hẹn ăn.',
              'Enter the 6-digit code we sent to ${s.account?.email ?? 'your email'}. You need to verify before swiping and booking.',
            ),
            style: AppTextV2.body(size: 13.5),
          ),
          const SizedBox(height: 22),
          TextField(
            key: const Key('verify-code'),
            controller: _c,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: AppTextV2.section().copyWith(fontSize: 26, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: s.t('Mã 6 số', '6-digit code'),
              hintStyle: AppTextV2.body(color: AppColorsV2.inkA(0.35), size: 15),
              counterText: '',
            ),
          ),
          if (s.verifyMessage != null) ...[
            const SizedBox(height: 12),
            Text(s.verifyMessage!,
                key: const Key('verify-message'),
                style: AppTextV2.body(size: 13)),
          ],
          const SizedBox(height: 18),
          V2Cta(
            label:
                s.verifyBusy ? s.t('Đang kiểm tra…', 'Checking…') : s.t('Xác minh', 'Verify'),
            onTap: () async {
              if (s.verifyBusy) return;
              final ok = await s.confirmEmailCode(_c.text);
              if (ok && mounted) s.go(V2Screen.home);
            },
          ),
          const SizedBox(height: 4),
          Center(
            child: V2TapTarget(
              onTap: () => s.requestEmailCode(),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  s.t('Gửi lại mã', 'Resend code'),
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13),
                ),
              ),
            ),
          ),
          Center(
            child: V2TapTarget(
              onTap: () => s.go(V2Screen.home),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  s.t('Để sau', 'Later'),
                  style: AppTextV2.body(size: 13),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

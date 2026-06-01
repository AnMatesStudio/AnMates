import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_session.dart';

/// Must match the <div id="..."> in web/index.html.
const _recaptchaContainerId = 'recaptcha-container';
const _otpRequestTimeout = Duration(seconds: 90);

/// Firebase auth datasource — owns the RecaptchaVerifier lifecycle.
///
/// Lifecycle rules:
/// - At most ONE verifier exists at a time (prevents DOM widget leak).
/// - On dispose, clear() is called so the DOM container is released.
/// - Cubit/repo owns this datasource and calls dispose() in close().
class AuthFirebaseDataSource {
  final FirebaseAuth _auth;
  RecaptchaVerifier? _verifier;

  AuthFirebaseDataSource({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  /// Web OTP: build/refresh RecaptchaVerifier, call signInWithPhoneNumber.
  Future<OtpSendResult> sendOtpWeb({required String phone}) async {
    // Always clear any previous verifier before creating a new one —
    // re-using a verifier across multiple calls causes DOM leaks.
    _clearVerifier();
    _verifier = _buildVerifier();
    try {
      final result = await _auth.signInWithPhoneNumber(phone, _verifier!);
      return OtpSendResult(phone: phone, confirmationResult: result);
    } on FirebaseAuthException catch (e) {
      _clearVerifier();
      throw AuthFailure(message: _friendlyMessage(e.code), code: e.code);
    } catch (e) {
      _clearVerifier();
      throw AuthFailure(message: e.toString());
    }
  }

  /// Mobile OTP: verifyPhoneNumber with callbacks converted to Future.
  Future<OtpSendResult> sendOtpMobile({required String phone}) async {
    final completer = Completer<OtpSendResult>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      timeout: _otpRequestTimeout,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android instant-verify path
        if (completer.isCompleted) return;
        try {
          final uc = await _auth.signInWithCredential(credential);
          final idToken = await uc.user?.getIdToken();
          if (idToken != null && !completer.isCompleted) {
            completer.complete(
              OtpSendResult(phone: phone, autoIdToken: idToken),
            );
          }
        } catch (_) {
          // Fall through to codeSent flow.
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(
            AuthFailure(message: _friendlyMessage(e.code), code: e.code),
          );
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            OtpSendResult(phone: phone, verificationId: verificationId),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  /// Convenience entry — picks web vs mobile flow automatically.
  Future<OtpSendResult> sendOtp({required String phone}) {
    return kIsWeb ? sendOtpWeb(phone: phone) : sendOtpMobile(phone: phone);
  }

  /// Verify the user-typed OTP code, returning a Firebase ID token.
  /// The caller exchanges that ID token for an app JWT via the remote datasource.
  Future<String> verifyOtpAndGetIdToken({
    required String otpCode,
    String? verificationId,
    Object? confirmationResult,
  }) async {
    UserCredential credential;
    if (confirmationResult is ConfirmationResult) {
      credential = await confirmationResult.confirm(otpCode);
    } else if (verificationId != null && verificationId.isNotEmpty) {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpCode,
      );
      credential = await _auth.signInWithCredential(cred);
    } else {
      throw const AuthFailure(
        message:
            'Missing verification context (no verificationId or confirmationResult)',
      );
    }
    final idToken = await credential.user?.getIdToken();
    if (idToken == null) {
      throw const AuthFailure(message: 'Firebase did not return an ID token');
    }
    return idToken;
  }

  /// Release the RecaptchaVerifier DOM container.
  /// MUST be called when the auth flow is closed (e.g., AuthCubit.close()).
  void dispose() {
    _clearVerifier();
  }

  // ── Internals ───────────────────────────────────────────────────────────────

  void _clearVerifier() {
    _verifier?.clear();
    _verifier = null;
  }

  RecaptchaVerifier _buildVerifier() {
    return RecaptchaVerifier(
      auth: FirebaseAuthPlatform.instance,
      container: _recaptchaContainerId,
      size: RecaptchaVerifierSize.normal,
      theme: RecaptchaVerifierTheme.light,
    );
  }

  /// Maps Firebase error codes to Vietnamese user-friendly messages.
  String _friendlyMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Số điện thoại không hợp lệ';
      case 'too-many-requests':
        return 'Quá nhiều lượt thử. Vui lòng thử lại sau';
      case 'invalid-verification-code':
        return 'Mã OTP không đúng';
      case 'invalid-verification-id':
        return 'Phiên xác thực đã hết hạn. Gửi lại OTP';
      case 'session-expired':
        return 'Phiên đã hết hạn. Gửi lại OTP';
      case 'network-request-failed':
        return 'Mất kết nối mạng';
      case 'captcha-check-failed':
        return 'Xác thực reCAPTCHA thất bại';
      case 'app-not-authorized':
      case 'INVALID_APP_CREDENTIAL':
        return 'Ứng dụng chưa được cấu hình đúng (liên hệ admin)';
      default:
        return 'Lỗi xác thực: $code';
    }
  }
}

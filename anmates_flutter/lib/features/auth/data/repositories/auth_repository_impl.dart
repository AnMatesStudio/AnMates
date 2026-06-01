import 'package:flutter/foundation.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_firebase_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

const _userIdKey = 'user_id';

class AuthRepositoryImpl implements AuthRepository {
  final AuthFirebaseDataSource _firebase;
  final AuthRemoteDataSource _remote;
  final SecureStorageService _storage;

  AuthRepositoryImpl({
    required AuthFirebaseDataSource firebase,
    required AuthRemoteDataSource remote,
    required SecureStorageService storage,
  }) : _firebase = firebase,
       _remote = remote,
       _storage = storage;

  @override
  Future<Result<OtpSendResult>> sendOtp({required String phone}) async {
    try {
      final result = await _firebase.sendOtp(phone: phone);
      return Result.success(result);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<AuthSession>> verifyOtp({
    required String phone,
    required String otpCode,
    String? verificationId,
    Object? confirmationResult,
    String name = '',
  }) async {
    try {
      // Step 1: Verify OTP with Firebase, get ID token
      final idToken = await _firebase.verifyOtpAndGetIdToken(
        otpCode: otpCode,
        verificationId: verificationId,
        confirmationResult: confirmationResult,
      );
      // Step 2: Exchange ID token for app JWT
      return _exchangeIdToken(idToken: idToken, name: name);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<AuthSession>> verifyWithIdToken({
    required String idToken,
    String name = '',
  }) {
    return _exchangeIdToken(idToken: idToken, name: name);
  }

  Future<Result<AuthSession>> _exchangeIdToken({
    required String idToken,
    required String name,
  }) async {
    try {
      final session = await _remote.phoneVerify(idToken: idToken, name: name);
      await _persist(session);
      return Result.success(session);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<AuthSession>> devLogin({
    required String secret,
    required String phone,
    required String name,
  }) async {
    try {
      final session = await _remote.devLogin(
        secret: secret,
        phone: phone,
        name: name,
      );
      await _persist(session);
      return Result.success(session);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> logout() async {
    try {
      final accessToken = await _storage.accessToken;
      final refreshToken = await _storage.refreshToken;
      if (accessToken != null) {
        await _remote.logout(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      }
      await _storage.clearAll();
      return const Result<void>.success(null);
    } catch (e) {
      // Even if remote call fails, clear local tokens.
      await _storage.clearAll();
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await _storage.accessToken;
    return token != null && token.isNotEmpty;
  }

  @override
  Future<String?> currentUserId() async {
    // user_id stored alongside tokens (FlutterSecureStorage)
    // For consistency we keep it in the same secure store.
    try {
      final value = await _storage.read(_userIdKey);
      return value;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() => _firebase.dispose();

  Future<void> _persist(AuthSession session) async {
    await _storage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    await _storage.write(_userIdKey, session.userId);
    if (kDebugMode) {
      debugPrint('AuthRepository: persisted session for ${session.userId}');
    }
  }
}

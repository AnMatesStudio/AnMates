import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Uploads onboarding photos to Firebase Storage and returns download URLs.
///
/// Storage path: `user_photos/{firebaseUid}/{slot}_{ts}.jpg`
/// The path uses the Firebase Auth UID (NOT the Postgres UUID) so it matches
/// the storage rules: `allow write: if request.auth.uid == uid`.
class StorageService {
  static final StorageService _instance = StorageService._();
  StorageService._();
  factory StorageService() => _instance;

  final _storage = FirebaseStorage.instance;

  /// Uploads [bytes] as a JPEG, returns the public download URL.
  ///
  /// Storage write rules require a Firebase Auth session (`request.auth.uid`).
  /// Phone-OTP login establishes one, but the Email-OTP path (and dev-login)
  /// only mint a backend JWT — no Firebase session — so `currentUser` is null.
  /// In that case we sign in anonymously so the upload still succeeds; the photo
  /// lands under the anonymous uid and its public download URL is saved to the
  /// backend profile, which is all the app needs. Requires the Anonymous
  /// provider enabled in Firebase Console → Authentication → Sign-in method.
  Future<String> uploadPhoto(Uint8List bytes, {required String slot}) async {
    var user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      try {
        final cred = await FirebaseAuth.instance.signInAnonymously();
        user = cred.user;
      } catch (e) {
        throw Exception(
          'Không khởi tạo được phiên tải ảnh (Firebase Anonymous chưa bật?). '
          'Chi tiết: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
    if (user == null) {
      throw Exception('Không tạo được phiên tải ảnh. Thử lại nhé.');
    }

    final uid = user.uid; // Firebase Auth UID — matches storage rules
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref('user_photos/$uid/${slot}_$ts.jpg');

    // putString(base64) works more reliably on Flutter web than putData —
    // avoids a null-check bug in the JS interop layer of firebase_storage.
    final task = await ref.putString(
      base64Encode(bytes),
      format: PutStringFormat.base64,
      metadata: SettableMetadata(contentType: 'image/jpeg'),
    );
    return task.ref.getDownloadURL();
  }
}

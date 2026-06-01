import 'api_client.dart';
import 'auth_service.dart';

/// Talks to the Go backend for the user profile.
///
/// Onboarding now submits once at the end (Screen 10 "Hoàn tất") via
/// [completeOnboarding] — Screens 08/09 only stash data in the client-side
/// draft. [getProfile] backs the discovery/home + profile screens.
class ProfileService {
  static final ProfileService _instance = ProfileService._();
  ProfileService._();
  factory ProfileService() => _instance;

  /// One-shot submit for Screens 08+09+10. Persists everything server-side and
  /// flips onboarding_done. [photos] is the gallery (extra) photos as
  /// `{'url': ..., 'caption': ...}` maps; [avatarUrl] is the required main photo.
  Future<Map<String, dynamic>> completeOnboarding({
    required String name,
    required String nickname,
    DateTime? birthDate,
    int? personalityScore,
    required List<String> foodTags,
    required List<String> vibeTags,
    required String avatarUrl,
    required List<Map<String, dynamic>> photos,
  }) async {
    final body = <String, dynamic>{
      'name': name.trim(),
      'nickname': nickname.trim(),
      'birth_date': ?(birthDate == null ? null : _formatDate(birthDate)),
      'personality_score': ?personalityScore,
      'food_tags': foodTags,
      'vibe_tags': vibeTags,
      'avatar_url': avatarUrl,
      'photos': photos,
    };
    final data = await ApiClient().patch(
      '/api/v1/profile/complete-onboarding',
      body: body,
    );
    final map = (data as Map).cast<String, dynamic>();
    await AuthService().setOnboardingDone(map['onboarding_done'] as bool? ?? true);
    return map;
  }

  /// GET /profile — full user record incl. avatar_url, nickname and photos[].
  Future<Map<String, dynamic>> getProfile() async {
    final data = await ApiClient().get('/api/v1/profile');
    return (data as Map).cast<String, dynamic>();
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$mm-$dd';
  }
}

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
    required List<String> cultureTags,
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
      'culture_tags': cultureTags,
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

  /// PATCH /profile/preferences — food + vibe tags; also marks onboarding done,
  /// which is what puts this account into other people's swipe decks.
  Future<void> updatePreferences(List<String> foodTags, List<String> vibeTags) async {
    await ApiClient().patch('/api/v1/profile/preferences',
        body: {'food_tags': foodTags, 'vibe_tags': vibeTags});
  }

  /// PUT /profile — display name and bio from the Me screen's edit sheet.
  Future<void> updateProfile({required String name, required String bio}) async {
    await ApiClient().put('/api/v1/profile', body: {'name': name, 'bio': bio});
  }

  String _formatDate(DateTime d) {
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$mm-$dd';
  }
}

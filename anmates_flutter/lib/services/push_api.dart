import 'api_client.dart';

/// Push registration endpoints: VAPID public key and web push
/// subscribe/unsubscribe (the Go backend relays via Web Push; see
/// handlers/push.go).
class PushApi {
  static final PushApi _instance = PushApi._();
  PushApi._();
  factory PushApi() => _instance;

  final _api = ApiClient();

  /// GET /api/v1/push/vapid-public-key — the base64url VAPID public key.
  /// Returns null when push is not configured (503) or the call fails.
  Future<String?> vapidKey() async {
    try {
      final data = await _api.get('/api/v1/push/vapid-public-key');
      final key = (data as Map<String, dynamic>)['key'];
      return key is String ? key : null;
    } catch (_) {
      return null;
    }
  }

  /// POST /api/v1/push/subscribe — register [subscriptionJson] (the parsed
  /// PushSubscription) for the signed-in user.
  Future<void> subscribe(Map<String, dynamic> subscriptionJson) async {
    await _api.post('/api/v1/push/subscribe', body: {
      'endpoint': subscriptionJson['endpoint'],
      'keys': subscriptionJson['keys'],
    });
  }

  /// POST /api/v1/push/unsubscribe — drop the user's push subscription.
  Future<void> unsubscribe(String endpoint) async {
    await _api.post('/api/v1/push/unsubscribe', body: {'endpoint': endpoint});
  }
}

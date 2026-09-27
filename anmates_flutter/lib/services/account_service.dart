import 'api_client.dart';

/// The signed-in user's account state: email, verification, suspension,
/// admin flag and terms consent.
class AccountStatus {
  final String? email;
  final bool emailVerified;
  final bool suspended;
  final bool isAdmin;
  final bool termsAccepted;

  AccountStatus({
    this.email,
    required this.emailVerified,
    required this.suspended,
    required this.isAdmin,
    required this.termsAccepted,
  });

  factory AccountStatus.fromJson(Map<String, dynamic> j) => AccountStatus(
    email: j['email'] as String?,
    emailVerified: j['email_verified'] as bool? ?? false,
    suspended: j['suspended'] as bool? ?? false,
    isAdmin: j['is_admin'] as bool? ?? false,
    termsAccepted: j['terms_accepted'] as bool? ?? false,
  );
}

/// One user report in the admin queue: who reported whom, why, and its
/// current status.
class AdminReport {
  final String id;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final String reason;
  final String note;
  final String status;
  final bool reportedSuspended;
  final DateTime createdAt;

  AdminReport({
    required this.id,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    required this.reason,
    required this.note,
    required this.status,
    required this.reportedSuspended,
    required this.createdAt,
  });

  factory AdminReport.fromJson(Map<String, dynamic> j) => AdminReport(
    id: j['id'] as String,
    reporterName: j['reporter_name'] as String? ?? '',
    reportedId: j['reported_id'] as String? ?? '',
    reportedName: j['reported_name'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
    note: j['note'] as String? ?? '',
    status: j['status'] as String? ?? '',
    reportedSuspended: j['reported_suspended'] as bool? ?? false,
    createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
  );
}

/// Account status, email verification, and the admin report queue.
class AccountService {
  static final AccountService _instance = AccountService._();
  AccountService._();
  factory AccountService() => _instance;

  final _api = ApiClient();

  /// GET /api/v1/account/status — the signed-in user's account state.
  Future<AccountStatus> status() async {
    final data = await _api.get('/api/v1/account/status');
    return AccountStatus.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/v1/account/verify-email/request — send the verification code.
  Future<void> requestEmailCode() async {
    await _api.post('/api/v1/account/verify-email/request');
  }

  /// POST /api/v1/account/verify-email — confirm the verification code.
  Future<void> confirmEmailCode(String code) async {
    await _api.post('/api/v1/account/verify-email', body: {'code': code});
  }

  /// GET /api/v1/admin/reports?status=$status — admin report queue.
  Future<List<AdminReport>> adminReports({String status = 'open'}) async {
    final data = await _api.get('/api/v1/admin/reports?status=$status') as List;
    return data
        .map((e) => AdminReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/v1/admin/reports/$id/resolve — resolve a report.
  Future<void> resolveReport(String id, String action) async {
    await _api.post(
      '/api/v1/admin/reports/$id/resolve',
      body: {'action': action},
    );
  }

  /// POST /api/v1/admin/users/$userId/unsuspend — unsuspend a user.
  Future<void> unsuspend(String userId) async {
    await _api.post('/api/v1/admin/users/$userId/unsuspend');
  }
}

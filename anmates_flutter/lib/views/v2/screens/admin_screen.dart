import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/account_service.dart';
import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **Reports to review** — the admin queue behind the "Báo cáo cần xử lý"
/// entry on the Me tab. Non-admins see a one-line placeholder; everyone
/// else gets a card per open report with Dismiss / Suspend actions (the
/// Suspend ask is behind a confirm dialog because it signs the person out
/// for everyone).
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

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
          Align(
            alignment: Alignment.centerLeft,
            child: V2BackButton(onTap: () => s.go(V2Screen.me)),
          ),
          const SizedBox(height: 16),
          Text(s.t('Báo cáo cần xử lý', 'Reports to review'),
              style: AppTextV2.section().copyWith(fontSize: 25)),
          const SizedBox(height: 16),
          if (!s.isAdmin)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(s.t('Chỉ dành cho quản trị viên.', 'Admins only.'),
                    style: AppTextV2.body(size: 14)),
              ),
            )
          else if (s.adminLoading)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: AppColorsV2.wisteria),
              ),
            )
          else if (s.adminReports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(s.t('Không còn báo cáo nào.', 'No open reports.'),
                    style: AppTextV2.body(size: 14)),
              ),
            )
          else
            Column(
              key: const Key('admin-reports'),
              children: [
                for (var i = 0; i < s.adminReports.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _ReportCard(s: s, report: s.adminReports[i]),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.s, required this.report});

  final V2State s;
  final AdminReport report;

  Future<void> _resolve(BuildContext context, V2State s, bool suspend) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottom = navClearance(context);
    if (suspend) {
      final ok = await showV2Confirm(
        context,
        title: s.t('Khoá ${report.reportedName}?', 'Suspend ${report.reportedName}?'),
        body: s.t(
            'Người này sẽ không đăng nhập và không xuất hiện với ai nữa.',
            'They will not be able to sign in or appear to anyone.'),
        cancelLabel: s.t('Huỷ', 'Cancel'),
        confirmLabel: s.t('Khoá', 'Suspend'),
      );
      if (!ok) return;
    }
    final done = await s.resolveReport(report.id, suspend: suspend);
    showV2Toast(
      messenger,
      done ? s.t('Đã xử lý', 'Done') : s.t('Không xử lý được', 'Could not update'),
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return V2Sheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(report.reportedName,
                    style: AppTextV2.name(size: 15)),
              ),
              if (report.reportedSuspended) ...[
                const SizedBox(width: 8),
                Text(s.t('đang khoá', 'suspended'),
                    style: AppTextV2.name(color: AppColorsV2.alert, size: 11)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  s.t('Bị ${report.reporterName} báo: ${report.reason}',
                      'Reported by ${report.reporterName}: ${report.reason}'),
                  style: AppTextV2.meta(),
                ),
              ),
              const SizedBox(width: 8),
              Text('${report.createdAt.day}/${report.createdAt.month}',
                  style: AppTextV2.meta()),
            ],
          ),
          if (report.note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(report.note, style: AppTextV2.body(size: 13)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: V2TapTarget(
                  onTap: () => _resolve(context, s, false),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColorsV2.inkA(0.14)),
                    ),
                    child: Text(s.t('Bỏ qua', 'Dismiss'),
                        style: AppTextV2.name(
                            color: AppColorsV2.ink, size: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: V2TapTarget(
                  onTap: () => _resolve(context, s, true),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColorsV2.alert,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child:
                        Text(s.t('Khoá tài khoản', 'Suspend'),
                            style: AppTextV2.name(
                                color: Colors.white, size: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

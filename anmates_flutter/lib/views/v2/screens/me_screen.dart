import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../../../widgets/v2/edit_profile_sheet.dart';
import '../../../widgets/v2/food_art.dart';
import '../v2_data.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **E1 · Profile** — the "spots you've been to" and "your reviews"
/// sections are backed by real data: confirmed bookings feed the visit
/// list and the ratings the user gave feed the review list, with a
/// placeholder shown when the user has none of either yet.
class MeScreen extends StatelessWidget {
  const MeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    // The header was drawn with its content starting at 104; move all of it by
    // however far the real content top is from that. Stickers also scale by width.
    final dy = V2Layout.contentTop(context) - 104;
    final u = V2Layout.unit(context);

    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: navClearance(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 268 + dy,
            child: Stack(clipBehavior: Clip.none, children: [
              for (final st in kMeStickers)
                Positioned(
                  left: st.left * u, top: st.top + dy, width: st.size * u, height: st.size * u,
                  child: Transform.rotate(
                    angle: st.rot * 0.017453,
                    child: FoodArt(asset: st.img, shadowOpacity: 0.26, shadowBlur: 14),
                  ),
                ),
              Positioned(
                top: 104 + dy, left: 16, right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    V2BackButton(size: 40, onTap: () => s.go(V2Screen.home)),
                    V2TapTarget(
                      onTap: () => s.go(V2Screen.pay),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: AppShadowsV2.pill,
                        ),
                        child: Text(s.t('Nâng cấp', 'Upgrade'),
                            style: AppTextV2.name(
                                color: AppColorsV2.wisteria, size: 11.5)),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Transform.translate(
            offset: const Offset(0, -96),
            child: Container(
              padding: const EdgeInsets.only(bottom: 26),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x00FFFFFF), Color(0xE0FFFFFF), Colors.white],
                  stops: [0, 0.14, 0.22],
                ),
              ),
              child: Column(children: [
                const SizedBox(height: 56),
                Container(
                  width: 116, height: 116, padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0A285A).withValues(alpha: 0.26),
                        blurRadius: 34,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const CircleAvatar(backgroundImage: AssetImage(A.avatar)),
                ),
                const SizedBox(height: 12),
                Text(s.profileName.isEmpty ? '—' : s.profileName,
                    style: AppTextV2.section().copyWith(fontSize: 26, letterSpacing: -0.78)),
                const SizedBox(height: 9),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(s.meMeta, textAlign: TextAlign.center,
                      style: AppTextV2.body(color: AppColorsV2.inkA(0.5), size: 12)),
                ),
                const SizedBox(height: 9),
                if (s.signedIn)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      V2TapTarget(
                        key: const Key('me-edit'),
                        onTap: () => showEditProfileSheet(context, s),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(s.t('Sửa hồ sơ', 'Edit profile'),
                              style: AppTextV2.name(
                                  color: AppColorsV2.wisteria, size: 12.5)),
                        ),
                      ),
                      Text('·', style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 14)),
                      V2TapTarget(
                        onTap: s.signOut,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: Text(s.t('Đăng xuất', 'Sign out'),
                              key: const Key('me-sign-out'),
                              style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 12.5)),
                        ),
                      ),
                    ],
                  )
                else
                  V2TapTarget(
                    onTap: () => s.openAuth(then: V2Screen.me),
                    child: Container(
                      key: const Key('me-sign-in'),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppGradientsV2.cta,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(s.t('Đăng nhập / Đăng ký', 'Sign in / Sign up'),
                          style: AppTextV2.cta().copyWith(fontSize: 13.5)),
                    ),
                  ),
                const SizedBox(height: 9),
                if (s.myPrefLabels.isNotEmpty)
                  Wrap(
                    spacing: 7, runSpacing: 7, alignment: WrapAlignment.center,
                    children: [
                      for (final t in s.myPrefLabels)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F1FD),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(t,
                              style: AppTextV2.name(
                                      color: AppColorsV2.wisteria, size: 11.5)
                                  .copyWith(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(children: [
                    Expanded(child: _MiniStat(
                        value: s.mealsCount?.toString() ?? '–',
                        label: s.t('bữa đã ăn', 'meals'))),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(
                        value: s.matchesCount?.toString() ?? '–', label: 'mates')),
                    const SizedBox(width: 10),
                    Expanded(child: _MiniStat(
                        value: s.history?.reviews.length.toString() ?? '–',
                        label: 'review')),
                  ]),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _TrustRow(s: s),
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(s.t("Quán bạn đã đi", "Spots you've been to"),
                        style: AppTextV2.section()
                            .copyWith(fontSize: 18, letterSpacing: -0.36)),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: s.history == null || s.history!.visits.isEmpty
                      ? Text(
                          s.t('Chưa có bữa nào được xác nhận.', 'No confirmed meals yet.'),
                          style: AppTextV2.body(color: AppColorsV2.inkA(0.48), size: 12.5),
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: Column(
                            key: const Key('me-visits'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final v in s.history!.visits.take(5)) ...[
                                Text(v.restaurantName, style: AppTextV2.name(size: 14)),
                                Text(
                                  '${v.scheduledAt.day}/${v.scheduledAt.month}/${v.scheduledAt.year} · '
                                  '${s.t('với ${v.partnerName}', 'with ${v.partnerName}')}',
                                  style: AppTextV2.meta(),
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.t('Review của bạn', 'Your reviews'),
                          style: AppTextV2.section()
                              .copyWith(fontSize: 18, letterSpacing: -0.36)),
                      const SizedBox(height: 3),
                      Text(
                        s.t('Đánh giá bạn đã gửi sau mỗi bữa ăn',
                            'Ratings you gave after each meal'),
                        style: AppTextV2.meta().copyWith(fontSize: 11.5),
                      ),
                      const SizedBox(height: 12),
                      s.history?.reviews.isEmpty ?? true
                          ? Text(
                              s.t('Bạn chưa viết review nào.', "You haven't written any reviews yet."),
                              style: AppTextV2.body(color: AppColorsV2.inkA(0.48), size: 12.5),
                            )
                          : Column(
                              key: const Key('me-reviews'),
                              children: [
                                for (final r in s.history!.reviews.take(5)) ...[
                                  Text(
                                      '${'★' * r.stars}  ${r.restaurantName}',
                                      style: AppTextV2.name(size: 13.5)),
                                  if (r.note.isNotEmpty)
                                    Text(r.note, style: AppTextV2.body(size: 12.5)),
                                ],
                              ],
                            ),
                      if (s.signedIn && s.blocked.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _BlockedList(s: s),
                      ],
                      const SizedBox(height: 16),
                      _UpgradeCard(s: s),
                      if (s.signedIn) ...[
                        const SizedBox(height: 22),
                        Center(
                          child: V2TapTarget(
                            key: const Key('me-delete-account'),
                            onTap: () => _deleteAccount(context, s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: Text(s.t('Xoá tài khoản', 'Delete account'),
                                  style: AppTextV2.name(
                                      color: AppColorsV2.alert, size: 13)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Xoá tài khoản" — confirm, then delete on the server and toast the result.
Future<void> _deleteAccount(BuildContext context, V2State s) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final bottom = navClearance(context);
  final ok = await showV2Confirm(
    context,
    title: s.t('Xoá tài khoản vĩnh viễn?', 'Delete your account for good?'),
    body: s.t(
        'Hồ sơ, match, tin nhắn và lịch hẹn sẽ bị xoá và không khôi phục được.',
        'Your profile, matches, messages and bookings are deleted and cannot be restored.'),
    cancelLabel: s.t('Huỷ', 'Cancel'),
    confirmLabel: s.t('Xoá', 'Delete'),
  );
  if (!ok) return;
  final done = await s.deleteAccount();
  showV2Toast(
    messenger,
    done
        ? s.t('Đã xoá tài khoản', 'Account deleted')
        : s.t('Không xoá được, thử lại sau', 'Could not delete, try again'),
    bottom: bottom,
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColorsV2.inkA(0.07)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextV2.stat().copyWith(fontSize: 19)),
          const SizedBox(height: 3),
          Text(label, style: AppTextV2.meta().copyWith(
            fontSize: 11, fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  const _TrustRow({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final tr = s.trust;
    return GestureDetector(
      onTap: () => s.go(V2Screen.trust),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColorsV2.inkA(0.07)),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppShadowsV2.pill,
        ),
        child: Row(children: [
          Container(
            width: 56, height: 56, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F7FD),
              shape: BoxShape.circle,
              border: Border.all(color: AppColorsV2.inkA(0.08)),
            ),
            child: Text(s.trust?.score.toString() ?? '—',
                style: AppTextV2.section().copyWith(fontSize: 16, letterSpacing: 0)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Trust Score', style: AppTextV2.name(size: 13.5)),
                const SizedBox(height: 3),
                Text(
                    tr == null
                        ? s.t('Chưa được theo dõi', 'Not tracked yet')
                        : s.t('${tr.meals} bữa · ${tr.noShowReports} báo bùng hẹn',
                            '${tr.meals} meals · ${tr.noShowReports} no-show reports'),
                    style: AppTextV2.body(size: 11.5).copyWith(height: 1.4)),
              ],
            ),
          ),
          Text('›', style: AppTextV2.name(color: AppColorsV2.wisteria, size: 19)),
        ]),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => s.go(V2Screen.pay),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColorsV2.ink,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.t('Nâng cấp Ăn Mates', 'Upgrade AnMates'),
                    style: AppTextV2.name(color: Colors.white, size: 15)),
                const SizedBox(height: 5),
                Text(
                  s.t('Miễn nhiễm Gating, Trust Booster, voice chat, bể match tinh anh.',
                      'Gating immunity, Trust Booster, voice chat, elite match pool.'),
                  style: AppTextV2.body(color: AppColorsV2.whiteA(0.68), size: 11.5)
                      .copyWith(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text('›', style: AppTextV2.name(color: AppColorsV2.wisteria, size: 20)),
        ]),
      ),
    );
  }
}

/// "Đã chặn" — everyone this user blocked, each with an unblock button that
/// asks first. Unblocking does not restore the old match or chat.
class _BlockedList extends StatelessWidget {
  const _BlockedList({required this.s});
  final V2State s;

  Future<void> _unblock(BuildContext context, String userId, String name) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottom = navClearance(context);
    final ok = await showV2Confirm(
      context,
      title: s.t('Bỏ chặn $name?', 'Unblock $name?'),
      body: s.t('Hai bạn có thể thấy lại nhau khi quẹt. Cuộc trò chuyện cũ không quay lại.',
          'You may see each other again when swiping. The old chat does not come back.'),
      cancelLabel: s.t('Huỷ', 'Cancel'),
      confirmLabel: s.t('Bỏ chặn', 'Unblock'),
      destructive: false,
    );
    if (!ok) return;
    final done = await s.unblockUser(userId);
    showV2Toast(
      messenger,
      done ? s.t('Đã bỏ chặn $name', 'Unblocked $name') : s.t('Không bỏ chặn được', 'Could not unblock'),
      bottom: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('me-blocked-list'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.t('Đã chặn', 'Blocked'),
            style: AppTextV2.section().copyWith(fontSize: 18, letterSpacing: -0.36)),
        const SizedBox(height: 8),
        for (final b in s.blocked)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(
                child: Text(b.name.isEmpty ? s.t('(không tên)', '(no name)') : b.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: AppTextV2.name(size: 14)),
              ),
              V2TapTarget(
                onTap: () => _unblock(context, b.userId, b.name),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(s.t('Bỏ chặn', 'Unblock'),
                      style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13.5)),
                ),
              ),
            ]),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/match_service.dart';
import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_chat_format.dart';
import '../v2_kit.dart';
import '../v2_mate_mapper.dart';
import '../v2_state.dart';

/// **Tin nhắn · inbox.** Every match as a Messenger-style row from
/// `GET /conversations`: avatar, name, last line ("Bạn: …" when it was you),
/// time, bold + dot while unread, the partner's tiny avatar once they've read
/// your last message. The demo bots (POST /demo/bots) sit on top as the
/// "active" strip — they are the only partners that are actually always there.
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();
    final pad = V2Layout.hPad(context);

    return RefreshIndicator(
      color: AppColorsV2.wisteria,
      onRefresh: s.loadConversations,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(pad, V2Layout.contentTop(context) + 44, pad, 0),
            sliver: SliverList.list(children: [
              Text(s.t('Tin nhắn', 'Chats'),
                  style: AppTextV2.section().copyWith(fontSize: 26, letterSpacing: -0.8)),
              const SizedBox(height: 12),
              _SearchBox(s: s),
              const SizedBox(height: 14),
            ]),
          ),
          if (s.activeBots.isNotEmpty && s.inboxQuery.isEmpty)
            SliverToBoxAdapter(child: _ActiveStrip(s: s, pad: pad)),
          ..._body(context, s, pad),
          SliverToBoxAdapter(child: SizedBox(height: navClearance(context) + 12)),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, V2State s, double pad) {
    if (!s.conversationsLoaded || (s.conversationsLoading && s.conversations.isEmpty)) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColorsV2.wisteria),
            ),
          ),
        ),
      ];
    }
    if (s.inboxSignedOut) {
      return [
        _Empty(
          title: s.t('Đăng nhập để nhắn tin', 'Sign in to chat'),
          body: s.t('Tin nhắn gắn với tài khoản của bạn.', 'Chats belong to your account.'),
          action: s.t('Đăng nhập', 'Sign in'),
          onAction: () => s.openAuth(then: V2Screen.inbox),
        ),
      ];
    }
    final rows = s.conversations;
    return [
      if (s.conversationsError != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 0, pad, 10),
            child: Text(
              s.t('Không tải được tin nhắn (${s.conversationsError}). Kéo xuống để thử lại.',
                  "Couldn't load chats (${s.conversationsError}). Pull to retry."),
              style: AppTextV2.meta(color: AppColorsV2.alert),
            ),
          ),
        ),
      if (rows.isEmpty && s.inboxQuery.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Center(
              child: Text(s.t('Không tìm thấy "${s.inboxQuery}"', 'No chats match "${s.inboxQuery}"'),
                  style: AppTextV2.meta()),
            ),
          ),
        )
      else if (rows.isEmpty)
        _Empty(
          title: s.t('Chưa có cuộc trò chuyện nào', 'No chats yet'),
          body: s.t('Quẹt để tìm bạn ăn — hoặc nhắn thử với bot demo, nó trả lời ngay.',
              'Swipe to find a food mate — or try the demo bots, they answer right away.'),
          action: s.t('Chat thử với bot demo', 'Try the demo bots'),
          busy: s.botsStarting,
          onAction: s.startBotChats,
          secondary: s.t('Đi quẹt', 'Go swipe'),
          onSecondary: () => s.go(V2Screen.swipe),
        )
      else
        SliverList.builder(
          itemCount: rows.length,
          itemBuilder: (context, i) => _Row(s: s, c: rows[i], pad: pad),
        ),
      if (rows.isNotEmpty && s.activeBots.isEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, 14, pad, 0),
            child: Center(
              child: V2TapTarget(
                onTap: s.startBotChats,
                child: Text(
                  s.t('+ Chat thử với bot demo', '+ Try the demo bots'),
                  style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13),
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColorsV2.inkA(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(children: [
        Icon(Icons.search_rounded, size: 18, color: AppColorsV2.inkA(0.4)),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            key: const Key('inbox-search'),
            onChanged: s.setInboxQuery,
            textAlignVertical: TextAlignVertical.center,
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: s.t('Tìm kiếm', 'Search'),
              hintStyle: AppTextV2.body(color: AppColorsV2.inkA(0.4), size: 13.5),
            ),
            style: AppTextV2.body(color: AppColorsV2.ink, size: 13.5),
          ),
        ),
      ]),
    );
  }
}

/// The partner's avatar with, for a bot, the green "active" dot.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.c, required this.size});
  final ApiMatch c;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.28;
    return SizedBox(
      width: size, height: size,
      child: Stack(clipBehavior: Clip.none, children: [
        MateAvatar(
          name: c.partnerName,
          userId: c.partnerId,
          url: c.partnerAvatarUrl,
          asset: kBotAvatars[c.partnerId],
          size: size,
          ring: 0,
        ),
        if (c.partnerIsBot)
          Positioned(
            right: 0, bottom: 0,
            child: Container(
              width: dot, height: dot,
              decoration: BoxDecoration(
                color: const Color(0xFF31CC46),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
              ),
            ),
          ),
      ]),
    );
  }
}

class _ActiveStrip extends StatelessWidget {
  const _ActiveStrip({required this.s, required this.pad});
  final V2State s;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final bots = s.activeBots;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: pad),
        itemCount: bots.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final c = bots[i];
          return V2TapTarget(
            onTap: () => s.openConversation(c),
            child: SizedBox(
              width: 62,
              child: Column(children: [
                _Avatar(c: c, size: 56),
                const SizedBox(height: 6),
                Text(
                  c.partnerName.replaceFirst('Bot ', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextV2.meta(color: AppColorsV2.inkA(0.6)).copyWith(fontSize: 11.5),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.s, required this.c, required this.pad});
  final V2State s;
  final ApiMatch c;
  final double pad;

  @override
  Widget build(BuildContext context) {
    final unread = c.unreadCount > 0;
    final mine = c.lastSenderId != null && c.lastSenderId == s.myUserId;
    final last = c.lastMessage;
    final preview = last == null
        ? s.t('Các bạn đã hợp gu — vẫy chào đi 👋', "You matched — say hi 👋")
        : c.lastSenderId == '00000000-0000-0000-0000-0000000000a1'
            ? s.t('✨ Trợ lý gợi ý quán cho hai bạn', '✨ The assistant suggested spots')
            : mine
                ? s.t('Bạn: $last', 'You: $last')
                : last;
    final seen = mine && c.partnerReadAt != null && c.lastMessageAt != null &&
        !c.lastMessageAt!.isAfter(c.partnerReadAt!);

    return InkWell(
      key: Key('inbox-row-${c.id}'),
      onTap: () => s.openConversation(c),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: pad, vertical: 8),
        child: Row(children: [
          _Avatar(c: c, size: 56),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    c.partnerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextV2.name(size: 15).copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (c.partnerIsBot) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColorsV2.wisteriaTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('BOT',
                        style: AppTextV2.eyebrow(color: const Color(0xFF6D28D9))
                            .copyWith(fontSize: 9.5, letterSpacing: 0.6)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Flexible(
                  child: Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextV2.body(
                      color: unread ? AppColorsV2.ink : AppColorsV2.inkA(0.5),
                      size: 13,
                    ).copyWith(
                      height: 1.3,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                Text(' · ${inboxTime(c.activityAt, en: s.en)}',
                    style: AppTextV2.body(
                      color: unread ? AppColorsV2.ink : AppColorsV2.inkA(0.5),
                      size: 13,
                    ).copyWith(height: 1.3)),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          if (unread)
            Container(
              key: Key('inbox-unread-${c.id}'),
              width: 12, height: 12,
              decoration: const BoxDecoration(color: AppColorsV2.wisteria, shape: BoxShape.circle),
            )
          else if (seen)
            MateAvatar(
              key: Key('inbox-seen-${c.id}'),
              name: c.partnerName,
              userId: c.partnerId,
              url: c.partnerAvatarUrl,
              asset: kBotAvatars[c.partnerId],
              size: 16,
              ring: 0,
            ),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
    this.busy = false,
    this.secondary,
    this.onSecondary,
  });
  final String title, body, action;
  final VoidCallback onAction;
  final bool busy;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 0),
        child: Column(children: [
          Container(
            width: 76, height: 76,
            decoration: const BoxDecoration(color: AppColorsV2.wisteriaTint, shape: BoxShape.circle),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 34, color: AppColorsV2.wisteria),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppTextV2.cardTitle().copyWith(fontSize: 17)),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: AppTextV2.body(size: 13)),
          const SizedBox(height: 20),
          V2TapTarget(
            onTap: busy ? null : onAction,
            child: Container(
              key: const Key('inbox-primary-action'),
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: AppGradientsV2.cta,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (busy) ...[
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(action,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextV2.cta().copyWith(fontSize: 14.5)),
                ),
              ]),
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 6),
            V2TapTarget(
              onTap: onSecondary,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(secondary!, style: AppTextV2.name(color: AppColorsV2.wisteria, size: 13)),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

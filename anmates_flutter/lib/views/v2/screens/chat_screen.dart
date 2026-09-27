import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/safety_service.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_chat_format.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **D1 · Chat.** Real message history (`GET /matches/:id/messages`) plus a
/// live WebSocket connection for new ones (`ChatSocket` in
/// services/chat_socket.dart — fully built already, just never wired into the
/// v2 UI until now).
///
/// Messenger-style: bubbles from one sender stack into a group, a time
/// separator after a quiet gap, the partner's avatar beside their last bubble,
/// "…" while they type and "Đã gửi" / their avatar under your newest message
/// once they've read it (read receipts: POST /matches/:id/read + socket).
///
/// The design's version boiled a "Vibe %" gauge with every message and popped
/// a celebration sheet at 70% to "unlock" scheduling. No `vibe_score` exists
/// anywhere in the schema — it was a client-side counter with no real signal
/// behind it — so it's gone, along with the gate: scheduling a table is always
/// reachable now, the same way messaging always was.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send(V2State s) {
    if (_controller.text.trim().isEmpty) return;
    s.sendRealMessage(_controller.text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<V2State>();

    return Column(children: [
      _Header(s: s),
      if (s.isSampleChat) _SampleNote(s: s),
      Expanded(child: _Transcript(s: s)),
      _Composer(s: s, controller: _controller, onSend: () => _send(s)),
    ]);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.fromLTRB(14, V2Layout.contentTop(context), 14, 10),
          decoration: BoxDecoration(
            color: AppColorsV2.whiteA(0.55),
            border: Border(bottom: BorderSide(color: AppColorsV2.inkA(0.06))),
          ),
          child: Row(children: [
            V2TapTarget(
              onTap: s.chatBack,
              child: SizedBox(
                width: 34, height: 34,
                child: Center(
                  child: Text('‹',
                      style: AppTextV2.name(color: AppColorsV2.wisteria, size: 20)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 40, height: 40,
              child: Stack(clipBehavior: Clip.none, children: [
                MateAvatar(
                  name: s.chatPartner.name,
                  userId: s.chatPartner.userId,
                  url: s.chatPartner.avatarUrl,
                  asset: s.chatPartner.avatarAsset,
                  size: 40,
                  ring: 2,
                ),
                if (s.isBotChat)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      key: const Key('chat-online-dot'),
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: const Color(0xFF34C759),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.chatPartner.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextV2.name(size: 15)),
                  Text(s.chatSub,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextV2.meta().copyWith(fontSize: 11)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: V2TapTarget(
                onTap: () => showQuickEmojiPicker(context, s),
                child: Tooltip(
                  message: s.t('Đổi biểu tượng cảm xúc', 'Change emoji'),
                  child: Text(s.quickEmoji,
                      key: const Key('chat-emoji-header'),
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
            ),
            if (s.hasActiveMatch) _SafetyMenu(s: s),
          ]),
        ),
      ),
    );
  }
}

/// A sample profile is not a person: say so where the messages would go.
class _SampleNote extends StatelessWidget {
  const _SampleNote({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColorsV2.wisteriaTint,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          s.t('Hồ sơ mẫu: tin nhắn chỉ nằm trên máy bạn, không được gửi đi và không ai trả lời.',
              'Sample profile: messages stay on your device — nothing is sent and nobody replies.'),
          style: AppTextV2.name(color: const Color(0xFF6D28D9), size: 12),
        ),
      ),
    );
  }
}

class _Transcript extends StatelessWidget {
  const _Transcript({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    if (s.messagesLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColorsV2.wisteria),
      );
    }

    final lines = s.transcript;
    if (lines.isEmpty && !s.partnerTyping) {
      // Scrolls rather than overflows on a short landscape screen.
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            MateAvatar(
              name: s.chatPartner.name,
              userId: s.chatPartner.userId,
              url: s.chatPartner.avatarUrl,
              asset: s.chatPartner.avatarAsset,
              size: 72,
              ring: 3,
            ),
            const SizedBox(height: 12),
            Text(s.chatPartner.name, style: AppTextV2.name(size: 16)),
            const SizedBox(height: 6),
            Text(
              s.t('Match mới — gửi tin nhắn đầu tiên đi!',
                  'New match — send the first message!'),
              textAlign: TextAlign.center,
              style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 13),
            ),
          ]),
        ),
      );
    }

    final lastMine = s.lastMineIndex;
    // Built newest-first into a reversed list, so it opens at the bottom and
    // stays pinned there as messages arrive — the way a messenger does.
    final items = <Widget>[
      if (s.partnerTyping) _TypingBubble(s: s),
      for (var i = lines.length - 1; i >= 0; i--) ...[
        if (i == lastMine && !s.isSampleChat) _Status(s: s),
        if (lines[i].kind == 'quick_emoji')
          _EmojiChangeLine(s: s, line: lines[i])
        else
        _Bubble(
          s: s,
          line: lines[i],
          // Rounded less where it touches a neighbour from the same sender.
          joinsAbove: i > 0 && _sameGroup(lines[i - 1], lines[i]),
          joinsBelow: i < lines.length - 1 && _sameGroup(lines[i], lines[i + 1]),
        ),
        if (i == 0 || lines[i].at.difference(lines[i - 1].at) >= kSeparatorGap)
          _Separator(text: separatorTime(lines[i].at, en: s.en)),
      ],
    ];

    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      children: items,
    );
  }

  static bool _sameGroup(ChatLine a, ChatLine b) =>
      a.mine == b.mine &&
      a.kind != 'quick_emoji' &&
      b.kind != 'quick_emoji' &&
      b.at.difference(a.at) < kGroupGap;
}

/// "Bạn đã đổi biểu tượng cảm xúc thành 🍜", centred like a separator.
class _EmojiChangeLine extends StatelessWidget {
  const _EmojiChangeLine({required this.s, required this.line});
  final V2State s;
  final ChatLine line;

  @override
  Widget build(BuildContext context) {
    final who = line.mine ? s.t('Bạn', 'You') : s.chatPartner.name;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          s.t('$who đã đổi biểu tượng cảm xúc thành ${line.text}',
              '$who changed the emoji to ${line.text}'),
          textAlign: TextAlign.center,
          style: AppTextV2.meta(color: AppColorsV2.inkA(0.5)).copyWith(fontSize: 12),
        ),
      ),
    );
  }
}

/// The quick-emoji picker: one tap changes it for both people in the chat.
Future<void> showQuickEmojiPicker(BuildContext context, V2State s) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      child: Padding(
        key: const Key('emoji-picker'),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(s.t('Biểu tượng cảm xúc nhanh', 'Quick reaction'),
              style: AppTextV2.name(size: 15)),
          const SizedBox(height: 4),
          Text(s.t('Cả hai bạn đều thấy biểu tượng này.', 'You both see this emoji.'),
              style: AppTextV2.meta()),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final e in kQuickEmojiChoices)
                V2TapTarget(
                  onTap: () {
                    Navigator.of(sheet).pop();
                    s.setQuickEmoji(e);
                  },
                  child: Container(
                    key: Key('emoji-$e'),
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == s.quickEmoji ? AppColorsV2.wisteriaTint : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                ),
            ],
          ),
        ]),
      ),
    ),
  );
}

class _Separator extends StatelessWidget {
  const _Separator({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(text,
            style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 11.5)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.s,
    required this.line,
    required this.joinsAbove,
    required this.joinsBelow,
  });
  final V2State s;
  final ChatLine line;
  final bool joinsAbove, joinsBelow;

  @override
  Widget build(BuildContext context) {
    final mine = line.mine;
    const big = Radius.circular(18);
    const small = Radius.circular(5);
    final radius = BorderRadius.only(
      topLeft: !mine && joinsAbove ? small : big,
      bottomLeft: !mine && joinsBelow ? small : big,
      topRight: mine && joinsAbove ? small : big,
      bottomRight: mine && joinsBelow ? small : big,
    );
    final concierge = line.kind == 'ai_venue_card' || line.kind == 'system';

    final Widget body = line.kind == 'image'
        ? ClipRRect(
            borderRadius: radius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220, maxHeight: 280),
              child: Image.network(
                line.text,
                key: const Key('chat-image'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 160,
                  height: 120,
                  color: AppColorsV2.inkA(0.06),
                  alignment: Alignment.center,
                  child: Icon(Icons.broken_image_outlined, color: AppColorsV2.inkA(0.4)),
                ),
              ),
            ),
          )
        : isBigEmoji(line.text)
        ? Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(line.text, style: const TextStyle(fontSize: 38, height: 1.15)),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              gradient: mine ? AppGradientsV2.cta : null,
              color: mine ? null : (concierge ? AppColorsV2.wisteriaTint : Colors.white),
              borderRadius: radius,
            ),
            child: Text(
              concierge ? '✨ ${line.text}' : line.text,
              style: AppTextV2.body(
                color: mine ? Colors.white : AppColorsV2.ink,
                size: 14,
              ).copyWith(height: 1.38),
            ),
          );

    return Padding(
      padding: EdgeInsets.only(top: joinsAbove ? 2 : 8),
      child: Row(
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine) ...[
            // The partner's face sits beside the last bubble of their group.
            SizedBox(
              width: 28,
              child: joinsBelow
                  ? null
                  : MateAvatar(
                      name: s.chatPartner.name,
                      userId: s.chatPartner.userId,
                      url: s.chatPartner.avatarUrl,
                      asset: s.chatPartner.avatarAsset,
                      size: 28,
                      ring: 0,
                    ),
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
            child: Tooltip(
              message: separatorTime(line.at, en: s.en),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

/// Under your newest message: "Đã gửi", or the partner's tiny avatar + "Đã xem".
class _Status extends StatelessWidget {
  const _Status({required this.s});
  final V2State s;

  @override
  Widget build(BuildContext context) {
    final seen = s.lastMineSeen;
    return Padding(
      padding: const EdgeInsets.only(top: 3, right: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (seen) ...[
          MateAvatar(
            name: s.chatPartner.name,
            userId: s.chatPartner.userId,
            url: s.chatPartner.avatarUrl,
            asset: s.chatPartner.avatarAsset,
            size: 14,
            ring: 0,
          ),
          const SizedBox(width: 4),
        ],
        Text(
          seen ? s.t('Đã xem', 'Seen') : s.t('Đã gửi', 'Sent'),
          key: Key(seen ? 'chat-status-seen' : 'chat-status-sent'),
          style: AppTextV2.meta(color: AppColorsV2.inkA(0.42)).copyWith(fontSize: 11),
        ),
      ]),
    );
  }
}

/// The partner's "…" bubble, three dots pulsing in turn.
class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.s});
  final V2State s;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      key: const Key('chat-typing'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        MateAvatar(
          name: s.chatPartner.name,
          userId: s.chatPartner.userId,
          url: s.chatPartner.avatarUrl,
          asset: s.chatPartner.avatarAsset,
          size: 28,
          ring: 0,
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Opacity(
                  opacity: 0.3 + 0.7 * _pulse((_c.value - i * 0.18) % 1.0),
                  child: Container(
                    width: 7, height: 7,
                    decoration: BoxDecoration(color: AppColorsV2.inkA(0.55), shape: BoxShape.circle),
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  static double _pulse(double t) => t < 0.5 ? t * 2 : (1 - t) * 2;
}

class _Composer extends StatelessWidget {
  const _Composer({required this.s, required this.controller, required this.onSend});

  final V2State s;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    // With the keyboard up the nav is hidden (see V2AppBody), so the composer
    // sits just above the keyboard instead of above a nav that isn't there.
    // Otherwise it clears the glass nav entirely: the design tucked the field
    // 12pt under the glass, where the nav covered half of it.
    final keyboardUp = View.of(context).viewInsets.bottom > 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, keyboardUp ? 10 : navClearance(context) + 6),
      child: Column(children: [
        // Booking talks to the API about a real match; a sample chat has none.
        if (!s.isSampleChat) ...[
          V2TapTarget(
            onTap: () => s.go(V2Screen.bill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColorsV2.whiteA(0.7),
                border: Border.all(color: AppColorsV2.inkA(0.06)),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(children: [
                Icon(Icons.calendar_month_rounded, size: 15, color: AppColorsV2.wisteria),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    s.booking == null
                        ? s.t('Đặt bàn cho bữa ăn này', 'Schedule this meal')
                        : s.billSub,
                    style: AppTextV2.name(color: AppColorsV2.inkA(0.65), size: 11.5)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Text('›', style: AppTextV2.name(color: AppColorsV2.wisteria, size: 15)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(children: [
          if (s.hasActiveMatch) ...[
            // Send a photo into the chat; the picker runs behind the button
            // which shows a spinner while the upload lands.
            V2TapTarget(
              key: const Key('chat-attach'),
              onTap: s.imageSending
                  ? () {}
                  : () async {
                      // The picker dialog runs on the navigator, and the
                      // toast lands above the glass nav: capture both before
                      // awaiting so context is still safe to use.
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final bottom = navClearance(context);
                      // ignore: use_build_context_synchronously
                      final ok = await s.sendImage();
                      if (ok == false && messenger != null && s.hasActiveMatch) {
                        // Silent: a cancelled picker shouldn't nag.
                        messenger.hideCurrentSnackBar();
                        // keep messenger/bottom referenced for parity with
                        // the toast call sites above.
                        // ignore: unused_local_variable
                        final _ = bottom;
                      }
                    },
              child: Tooltip(
                message: s.t('Gửi ảnh', 'Send a photo'),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  child: s.imageSending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColorsV2.wisteria,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: AppColorsV2.wisteria,
                          size: 24,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Container(
              // 48pt of field inside the 1pt border.
              height: V2Layout.minTap + 2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColorsV2.inkA(0.07)),
                borderRadius: BorderRadius.circular(999),
              ),
              // Fills the pill so the whole pill, not just the text line, takes the tap.
              child: TextField(
                controller: controller,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.center,
                onSubmitted: (_) => onSend(),
                onChanged: (_) => s.notifyTyping(),
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintText: s.t('Nhắn tin…', 'Message…'),
                  hintStyle: AppTextV2.body(color: AppColorsV2.inkA(0.4), size: 13),
                ),
                style: AppTextV2.body(size: 13),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Empty field: the chat's quick emoji in one tap (long-press to
          // change it), the way Messenger offers its like.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final empty = value.text.trim().isEmpty;
              return GestureDetector(
                onLongPress: () => showQuickEmojiPicker(context, s),
                child: V2TapTarget(
                onTap: empty ? () => s.sendRealMessage(s.quickEmoji) : onSend,
                child: Container(
                  key: Key(empty ? 'chat-like' : 'chat-send'),
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: empty ? Colors.transparent : AppColorsV2.wisteria,
                    shape: BoxShape.circle,
                  ),
                  child: empty
                      ? Center(child: Text(s.quickEmoji, style: const TextStyle(fontSize: 24)))
                      : const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                ),
                ),
              );
            },
          ),
        ]),
      ]),
    );
  }
}

/// ⋮ in the chat header: unmatch, block, report. Each destructive action asks
/// first; the result is a short snackbar in the user's language.
class _SafetyMenu extends StatelessWidget {
  const _SafetyMenu({required this.s});
  final V2State s;

  Future<void> _onSelected(BuildContext context, String action) async {
    final name = s.chatPartner.name;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final bottom = navClearance(context);
    switch (action) {
      case 'unmatch':
        if (!await showV2Confirm(
            context,
            title: s.t('Bỏ ghép với $name?', 'Unmatch $name?'),
            body: s.t('Cuộc trò chuyện sẽ bị xoá ở cả hai phía.', 'The chat is removed for both of you.'),
            cancelLabel: s.t('Huỷ', 'Cancel'),
            confirmLabel: s.t('Đồng ý', 'Confirm'))) {
          return;
        }
        final ok = await s.unmatchActive();
        showV2Toast(messenger,
            ok ? s.t('Đã bỏ ghép', 'Unmatched') : s.t('Không bỏ ghép được, thử lại sau', 'Could not unmatch, try again'),
            bottom: bottom);
      case 'block':
        if (!await showV2Confirm(
            context,
            title: s.t('Chặn $name?', 'Block $name?'),
            body: s.t('Hai bạn sẽ không thấy nhau nữa.', 'You will no longer see each other.'),
            cancelLabel: s.t('Huỷ', 'Cancel'),
            confirmLabel: s.t('Đồng ý', 'Confirm'))) {
          return;
        }
        final ok = await s.blockActivePartner();
        showV2Toast(messenger,
            ok ? s.t('Đã chặn $name', 'Blocked $name') : s.t('Không chặn được, thử lại sau', 'Could not block, try again'),
            bottom: bottom);
      case 'report':
        if (!context.mounted) return;
        final reason = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            backgroundColor: AppColorsV2.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(s.t('Báo cáo $name', 'Report $name'), style: AppTextV2.cardTitle()),
            children: [
              for (final r in kReportReasons)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, r.$1),
                  child: Text(s.t(r.$2, r.$3)),
                ),
            ],
          ),
        );
        if (reason == null) return;
        final ok = await s.reportActivePartner(reason);
        if (!context.mounted) return;
        showV2Toast(messenger,
            ok ? s.t('Đã gửi báo cáo. Cảm ơn bạn!', 'Report sent. Thank you!') : s.t('Không gửi được báo cáo', 'Could not send the report'),
            bottom: bottom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: const Key('chat-safety-menu'),
      icon: const Icon(Icons.more_vert, color: AppColorsV2.ink),
      onSelected: (a) => _onSelected(context, a),
      itemBuilder: (_) => [
        PopupMenuItem(value: 'unmatch', child: Text(s.t('Bỏ ghép', 'Unmatch'))),
        PopupMenuItem(value: 'block', child: Text(s.t('Chặn', 'Block'))),
        PopupMenuItem(
          value: 'report',
          child: Text(s.t('Báo cáo', 'Report'), style: const TextStyle(color: AppColorsV2.alert)),
        ),
      ],
    );
  }
}

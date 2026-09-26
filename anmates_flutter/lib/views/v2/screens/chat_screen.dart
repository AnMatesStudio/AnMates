import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/app_theme_v2.dart';
import '../../../theme/v2_layout.dart';
import '../v2_kit.dart';
import '../v2_state.dart';

/// **D1 · Chat.** Real message history (`GET /matches/:id/messages`) plus a
/// live WebSocket connection for new ones (`ChatSocket` in
/// services/chat_socket.dart — fully built already, just never wired into the
/// v2 UI until now).
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
              onTap: () => s.go(V2Screen.swipe),
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
                if (!s.isSampleChat)
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
                  Text(s.chatPartner.name, style: AppTextV2.name(size: 15)),
                  Text(s.chatSub,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextV2.meta().copyWith(fontSize: 11)),
                ],
              ),
            ),
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

    final msgs = s.messages;
    if (msgs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            s.t('Match mới — gửi tin nhắn đầu tiên đi!',
                'New match — send the first message!'),
            textAlign: TextAlign.center,
            style: AppTextV2.name(color: AppColorsV2.inkA(0.5), size: 13),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: [
        for (final m in msgs)
          Align(
            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.74,
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                decoration: BoxDecoration(
                  gradient: m.mine ? AppGradientsV2.cta : null,
                  color: m.mine ? null : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(m.mine ? 18 : 5),
                    bottomRight: Radius.circular(m.mine ? 5 : 18),
                  ),
                ),
                child: Text(
                  m.text,
                  style: AppTextV2.body(
                    color: m.mine ? Colors.white : AppColorsV2.ink,
                    size: 13.5,
                  ).copyWith(height: 1.4),
                ),
              ),
            ),
          ),
      ],
    );
  }
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
          V2TapTarget(
            onTap: onSend,
            child: Container(
              width: 38, height: 38,
              decoration: const BoxDecoration(
                color: AppColorsV2.wisteria, shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }
}

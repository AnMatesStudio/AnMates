import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_detail_state.dart';

/// Cubit for a single match's chat thread.
///
/// Owns the inbound StreamSubscription so close() guarantees the WS is torn
/// down. Without this guarantee the WS would leak across page navigations.
///
/// Flow:
///   1. start(matchId): load history (REST) + connect WS, emit Loaded.
///   2. sendMessage(content): optimistic local append, then send over WS.
///      The server echoes the message back through the inbound stream and
///      the echo replaces the optimistic placeholder (matched by id).
///   3. close(): cancel subscription, disconnect WS, super.close().
class ChatDetailCubit extends Cubit<ChatDetailState> {
  final ChatRepository _repo;
  StreamSubscription<ChatMessage>? _inboundSub;
  String? _matchId;

  ChatDetailCubit(this._repo) : super(const ChatDetailInitial());

  /// Open a chat thread.
  Future<void> start({required String matchId}) async {
    _matchId = matchId;
    emit(const ChatDetailLoading());

    final historyResult = await _repo.getHistory(matchId: matchId);
    if (!historyResult.isSuccess) {
      emit(ChatDetailError(historyResult.failure!.message));
      return;
    }

    emit(ChatDetailLoaded(messages: historyResult.data!, isConnected: false));

    // Subscribe to inbound stream. Errors from the stream are non-fatal —
    // we keep the UI on Loaded and let the user retry sends.
    await _inboundSub?.cancel();
    _inboundSub = _repo
        .connectToMatch(matchId)
        .listen(_onInbound, onError: _onStreamError, cancelOnError: false);

    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(isConnected: true));
    }
  }

  void _onInbound(ChatMessage incoming) {
    final current = state;
    if (current is! ChatDetailLoaded) return;

    // Replace any optimistic placeholder with the same content+sender — keeps
    // the list de-duplicated when our own message echoes back from server.
    final messages = List<ChatMessage>.from(current.messages);
    final placeholderIdx = messages.indexWhere(
      (m) =>
          m.status == ChatMessageStatus.sending &&
          m.senderId == incoming.senderId &&
          m.content == incoming.content,
    );
    if (placeholderIdx >= 0) {
      messages[placeholderIdx] = incoming;
    } else {
      messages.add(incoming);
    }
    emit(current.copyWith(messages: messages));
  }

  void _onStreamError(Object error) {
    final current = state;
    if (current is ChatDetailLoaded) {
      emit(current.copyWith(isConnected: false));
    }
  }

  /// Send a message. Optimistically appends a sending-status placeholder;
  /// the real server-echo will replace it via [_onInbound].
  Future<void> sendMessage({
    required String content,
    ChatMessageType type = ChatMessageType.text,
  }) async {
    final current = state;
    if (current is! ChatDetailLoaded) return;
    if (_matchId == null) return;
    if (content.trim().isEmpty) return;

    final placeholder = ChatMessage(
      id: '_optim_${DateTime.now().microsecondsSinceEpoch}',
      matchId: _matchId!,
      senderId: '_me', // resolved server-side; UI compares to currentUserId
      content: content,
      type: type,
      createdAt: DateTime.now(),
      status: ChatMessageStatus.sending,
    );

    emit(
      current.copyWith(
        messages: [...current.messages, placeholder],
        isSending: true,
      ),
    );

    final result = await _repo.sendMessage(
      matchId: _matchId!,
      content: content,
      type: type,
    );

    final after = state;
    if (after is! ChatDetailLoaded) return;

    if (!result.isSuccess) {
      // Mark the placeholder as failed so UI can render retry.
      final updated = after.messages
          .map(
            (m) => m.id == placeholder.id
                ? m.copyWith(status: ChatMessageStatus.failed)
                : m,
          )
          .toList(growable: false);
      emit(after.copyWith(messages: updated, isSending: false));
    } else {
      emit(after.copyWith(isSending: false));
    }
  }

  @override
  Future<void> close() async {
    await _inboundSub?.cancel();
    _inboundSub = null;
    await _repo.disconnect();
    return super.close();
  }
}

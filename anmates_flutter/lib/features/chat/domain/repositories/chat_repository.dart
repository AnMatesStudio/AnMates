import '../../../auth/domain/repositories/auth_repository.dart' show Result;
import '../entities/chat_conversation.dart';
import '../entities/chat_message.dart';

export '../../../auth/domain/repositories/auth_repository.dart' show Result;

/// Domain contract for chat.
abstract class ChatRepository {
  /// One-shot list of all matches with chat threads.
  Future<Result<List<ChatConversation>>> getConversations();

  /// Paginated message history (newest first → reversed for UI).
  Future<Result<List<ChatMessage>>> getHistory({
    required String matchId,
    int limit,
  });

  /// Open a real-time stream of inbound messages for a single match.
  /// The returned [Stream] completes (with onDone) when the connection is
  /// torn down — either by `disconnect()` or by a network error after the
  /// configured retry budget is exhausted.
  Stream<ChatMessage> connectToMatch(String matchId);

  /// Send a message over the open WS connection.
  /// Returns the server-confirmed message on success (with a real id).
  Future<Result<ChatMessage>> sendMessage({
    required String matchId,
    required String content,
    ChatMessageType type,
  });

  /// Tear down the WS for the currently connected match.
  Future<void> disconnect();
}

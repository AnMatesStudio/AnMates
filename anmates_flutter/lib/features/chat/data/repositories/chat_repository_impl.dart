import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/chat_websocket_datasource.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remote;
  final ChatWebSocketDataSource _ws;

  ChatRepositoryImpl({
    required ChatRemoteDataSource remote,
    required ChatWebSocketDataSource ws,
  }) : _remote = remote,
       _ws = ws;

  @override
  Future<Result<List<ChatConversation>>> getConversations() async {
    try {
      final convs = await _remote.getConversations();
      return Result.success(convs);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<ChatMessage>>> getHistory({
    required String matchId,
    int limit = 50,
  }) async {
    try {
      final history = await _remote.getHistory(matchId: matchId, limit: limit);
      return Result.success(history);
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Stream<ChatMessage> connectToMatch(String matchId) => _ws.connect(matchId);

  @override
  Future<Result<ChatMessage>> sendMessage({
    required String matchId,
    required String content,
    ChatMessageType type = ChatMessageType.text,
  }) async {
    try {
      await _ws.sendRaw(matchId: matchId, content: content, type: type);
      // The server echoes the message back through the WS stream with its
      // real id/timestamp; we return a placeholder confirmation here.
      // Optimistic UI in the cubit will reconcile when the echo arrives.
      return Result.success(
        ChatMessage(
          id: '_sent_${DateTime.now().microsecondsSinceEpoch}',
          matchId: matchId,
          senderId: '_me',
          content: content,
          type: type,
          createdAt: DateTime.now(),
        ),
      );
    } on Failure catch (f) {
      return Result.failure(f);
    } catch (e) {
      return Result.failure(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<void> disconnect() => _ws.disconnect();
}

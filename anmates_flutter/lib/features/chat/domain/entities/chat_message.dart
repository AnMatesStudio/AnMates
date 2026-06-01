/// Domain entity for a chat message.
/// Pure Dart — no JSON, no Flutter imports, no Firebase.
class ChatMessage {
  final String id;
  final String matchId;
  final String senderId;
  final String content;
  final ChatMessageType type;
  final DateTime createdAt;

  /// Local-only fields used by the UI to render send progress.
  /// Set by the BLoC when emitting optimistic messages, then cleared
  /// once the server confirms receipt.
  final ChatMessageStatus status;

  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
    this.status = ChatMessageStatus.delivered,
  });

  bool isFromMe(String currentUserId) => senderId == currentUserId;

  ChatMessage copyWith({ChatMessageStatus? status, String? id}) {
    return ChatMessage(
      id: id ?? this.id,
      matchId: matchId,
      senderId: senderId,
      content: content,
      type: type,
      createdAt: createdAt,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChatMessage &&
      other.id == id &&
      other.matchId == matchId &&
      other.senderId == senderId &&
      other.content == content &&
      other.type == type &&
      other.createdAt == createdAt &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, matchId, senderId, content, type, createdAt, status);
}

enum ChatMessageType {
  text,
  viewOnce, // single-view photo
  system, // e.g. "Linh sent a kèo"
}

enum ChatMessageStatus {
  /// Optimistically displayed; waiting for server ack.
  sending,

  /// Confirmed received by server.
  delivered,

  /// Send failed; UI shows retry.
  failed,
}

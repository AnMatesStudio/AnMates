/// Summary of a single match's chat thread, as shown in the chat list.
class ChatConversation {
  final String matchId;
  final String partnerName;
  final String? partnerAvatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  /// Algorithmic match score (0.0 – 1.0).
  final double matchScore;

  const ChatConversation({
    required this.matchId,
    required this.partnerName,
    this.partnerAvatarUrl,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.matchScore = 0.0,
  });

  bool get hasUnread => unreadCount > 0;

  @override
  bool operator ==(Object other) =>
      other is ChatConversation &&
      other.matchId == matchId &&
      other.partnerName == partnerName &&
      other.lastMessage == lastMessage &&
      other.lastMessageAt == lastMessageAt &&
      other.unreadCount == unreadCount;

  @override
  int get hashCode => Object.hash(
    matchId,
    partnerName,
    lastMessage,
    lastMessageAt,
    unreadCount,
  );
}

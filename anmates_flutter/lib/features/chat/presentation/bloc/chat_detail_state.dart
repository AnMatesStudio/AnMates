import '../../domain/entities/chat_message.dart';

/// Sealed state for the per-match detail screen.
sealed class ChatDetailState {
  const ChatDetailState();
}

class ChatDetailInitial extends ChatDetailState {
  const ChatDetailInitial();
}

class ChatDetailLoading extends ChatDetailState {
  const ChatDetailLoading();
}

class ChatDetailLoaded extends ChatDetailState {
  /// Chronological list (oldest first → newest last).
  /// UI typically reverses for ListView.builder(reverse: true).
  final List<ChatMessage> messages;

  /// True when the WS is connected and inbound stream is live.
  final bool isConnected;

  /// True when a sendMessage call is in flight.
  final bool isSending;

  const ChatDetailLoaded({
    required this.messages,
    required this.isConnected,
    this.isSending = false,
  });

  ChatDetailLoaded copyWith({
    List<ChatMessage>? messages,
    bool? isConnected,
    bool? isSending,
  }) {
    return ChatDetailLoaded(
      messages: messages ?? this.messages,
      isConnected: isConnected ?? this.isConnected,
      isSending: isSending ?? this.isSending,
    );
  }
}

class ChatDetailError extends ChatDetailState {
  final String message;
  const ChatDetailError(this.message);
}

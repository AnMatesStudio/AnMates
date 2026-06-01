import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/chat_conversation.dart';
import '../../domain/repositories/chat_repository.dart';

sealed class ChatListState {
  const ChatListState();
}

class ChatListInitial extends ChatListState {
  const ChatListInitial();
}

class ChatListLoading extends ChatListState {
  const ChatListLoading();
}

class ChatListLoaded extends ChatListState {
  final List<ChatConversation> conversations;
  const ChatListLoaded(this.conversations);
}

class ChatListError extends ChatListState {
  final String message;
  const ChatListError(this.message);
}

/// Cubit for the chat-tab list. Stateless beyond the list itself; refreshable.
class ChatListCubit extends Cubit<ChatListState> {
  final ChatRepository _repo;
  ChatListCubit(this._repo) : super(const ChatListInitial());

  Future<void> load() async {
    emit(const ChatListLoading());
    final result = await _repo.getConversations();
    if (result.isSuccess) {
      emit(ChatListLoaded(result.data!));
    } else {
      emit(ChatListError(result.failure!.message));
    }
  }
}

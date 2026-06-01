import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/chat_conversation.dart';
import '../../domain/entities/chat_message.dart';

/// REST datasource for the chat feature.
/// Handles list-of-conversations and paginated history. Real-time
/// inbound/outbound goes through ChatWebSocketDataSource.
class ChatRemoteDataSource {
  final Dio _dio;

  ChatRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient().client;

  /// GET /api/v1/conversations
  Future<List<ChatConversation>> getConversations() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/conversations',
      );
      final list = (response.data?['data'] as List?) ?? const [];
      return list
          .map((e) => _conversationFromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapToFailure(e, 'Không tải được danh sách trò chuyện');
    }
  }

  /// GET /api/v1/matches/:matchId/messages?limit=N
  /// Backend returns newest-first; we reverse for chronological UI display.
  Future<List<ChatMessage>> getHistory({
    required String matchId,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/matches/$matchId/messages',
        queryParameters: {'limit': limit},
      );
      final list = (response.data?['data'] as List?) ?? const [];
      return list
          .map((e) => _messageFromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList(growable: false);
    } on DioException catch (e) {
      throw _mapToFailure(e, 'Không tải được lịch sử tin nhắn');
    }
  }

  ChatConversation _conversationFromJson(Map<String, dynamic> j) {
    try {
      return ChatConversation(
        matchId: j['match_id'] as String,
        partnerName: j['partner_name'] as String,
        partnerAvatarUrl: j['partner_avatar_url'] as String?,
        lastMessage: j['last_message'] as String?,
        lastMessageAt: j['last_message_at'] != null
            ? DateTime.parse(j['last_message_at'] as String)
            : null,
        unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
        matchScore: (j['score'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      throw DataParsingFailure('Malformed conversation: $e');
    }
  }

  ChatMessage _messageFromJson(Map<String, dynamic> j) {
    try {
      return ChatMessage(
        id: j['id'] as String,
        matchId: j['match_id'] as String,
        senderId: j['sender_id'] as String,
        content: (j['content'] as String?) ?? '',
        type: _typeFromWire(j['msg_type'] as String? ?? 'text'),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
    } catch (e) {
      throw DataParsingFailure('Malformed message: $e');
    }
  }

  ChatMessageType _typeFromWire(String s) {
    switch (s) {
      case 'view_once':
        return ChatMessageType.viewOnce;
      case 'system':
        return ChatMessageType.system;
      case 'text':
      default:
        return ChatMessageType.text;
    }
  }

  Failure _mapToFailure(DioException e, String fallback) {
    final body = e.response?.data;
    var message = fallback;
    if (body is Map<String, dynamic>) {
      final err = body['error'];
      if (err is Map<String, dynamic>) {
        message = (err['message'] as String?) ?? fallback;
      }
    }
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return AuthFailure(message: message, code: 'unauthorized');
    }
    if (code != null && code >= 500) {
      return ServerFailure(message);
    }
    return NetworkFailure(message: message, statusCode: code);
  }
}

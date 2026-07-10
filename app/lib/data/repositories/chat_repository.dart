import '../models/chat_message.dart';
import '../models/profile.dart';

const int kMaxChatMessageLength = 500;

class ChatException implements Exception {
  const ChatException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class ChatRepository {
  Stream<List<ChatMessage>> watchGroupMessages(String groupId);

  Future<void> sendMessage({
    required String groupId,
    required Profile sender,
    required String text,
  });
}

String normalizeChatMessageText(String text) {
  final normalized = text.trim().replaceAll(RegExp(r'\s+\n'), '\n');
  if (normalized.isEmpty) {
    throw const ChatException('Mesaj boş olamaz.');
  }
  if (normalized.length > kMaxChatMessageLength) {
    throw const ChatException('Mesaj en fazla 500 karakter olabilir.');
  }
  return normalized;
}

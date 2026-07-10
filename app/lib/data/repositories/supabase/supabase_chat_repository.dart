import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/chat_message.dart';
import '../../models/profile.dart';
import '../chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  SupabaseChatRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<ChatMessage>> watchGroupMessages(String groupId) {
    return _client
        .from('class_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .asyncMap(_hydrateMessages);
  }

  @override
  Future<void> sendMessage({
    required String groupId,
    required Profile sender,
    required String text,
  }) async {
    final body = normalizeChatMessageText(text);
    try {
      await _client.from('class_messages').insert({
        'group_id': groupId,
        'user_id': sender.id,
        'body': body,
      });
    } on PostgrestException catch (e) {
      throw ChatException('Mesaj gönderilemedi: ${e.message}');
    }
  }

  Future<List<ChatMessage>> _hydrateMessages(
    List<Map<String, dynamic>> rows,
  ) async {
    final messages = rows.map(ChatMessage.fromMap).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final latestMessages = messages.length > 100
        ? messages.sublist(messages.length - 100)
        : messages;
    final userIds = latestMessages.map((m) => m.userId).toSet().toList();
    if (userIds.isEmpty) return latestMessages;

    final profiles = await _client
        .from('profiles')
        .select('id, display_name, avatar_url, animal')
        .inFilter('id', userIds);
    final profilesById = {for (final row in profiles) row['id'] as String: row};

    return [
      for (final message in latestMessages)
        message.copyWith(
          authorDisplayName:
              profilesById[message.userId]?['display_name'] as String?,
          authorAvatarUrl:
              profilesById[message.userId]?['avatar_url'] as String?,
          authorAnimal: profilesById[message.userId]?['animal'] as String?,
        ),
    ];
  }
}

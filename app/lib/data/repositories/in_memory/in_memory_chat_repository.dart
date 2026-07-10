import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../models/chat_message.dart';
import '../../models/profile.dart';
import '../chat_repository.dart';

class InMemoryChatRepository implements ChatRepository {
  final _uuid = const Uuid();
  final Map<String, List<ChatMessage>> _messagesByGroup = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<List<ChatMessage>> watchGroupMessages(String groupId) async* {
    yield _messagesFor(groupId);
    await for (final _ in _changes.stream) {
      yield _messagesFor(groupId);
    }
  }

  @override
  Future<void> sendMessage({
    required String groupId,
    required Profile sender,
    required String text,
  }) async {
    final body = normalizeChatMessageText(text);
    final messages = _messagesByGroup.putIfAbsent(groupId, () => []);
    messages.add(
      ChatMessage(
        id: _uuid.v4(),
        groupId: groupId,
        userId: sender.id,
        body: body,
        createdAt: DateTime.now(),
        authorDisplayName: sender.displayName,
        authorAvatarUrl: sender.avatarUrl,
        authorAnimal: sender.animal,
      ),
    );
    _changes.add(null);
  }

  List<ChatMessage> _messagesFor(String groupId) {
    final messages = [...?_messagesByGroup[groupId]]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final latestMessages = messages.length > 100
        ? messages.sublist(messages.length - 100)
        : messages;
    return List.unmodifiable(latestMessages);
  }

  void dispose() => _changes.close();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/chat_message.dart';
import '../repositories/chat_repository.dart';
import '../repositories/in_memory/in_memory_chat_repository.dart';
import '../repositories/supabase/supabase_chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseChatRepository(Supabase.instance.client);
  }
  final repo = InMemoryChatRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final classMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  groupId,
) {
  return ref.watch(chatRepositoryProvider).watchGroupMessages(groupId);
});

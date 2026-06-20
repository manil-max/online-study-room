import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;

import '../../models/presence.dart';
import '../presence_repository.dart';

/// Supabase tabanlı presence deposu. UI hiç değişmeden bellek-içi yerine geçer.
class SupabasePresenceRepository implements PresenceRepository {
  SupabasePresenceRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> setPresence(Presence presence) async {
    // user_id birincil anahtar → upsert tek satırı günceller.
    await _client.from('presence').upsert(presence.toMap());
  }

  @override
  Stream<List<Presence>> watchGroupPresence(String groupId) {
    return _client
        .from('presence')
        .stream(primaryKey: ['user_id'])
        .eq('group_id', groupId)
        .map((rows) => rows.map(Presence.fromMap).toList());
  }
}

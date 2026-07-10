import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/nudge.dart';
import '../../models/profile.dart';
import '../nudge_repository.dart';

class SupabaseNudgeRepository implements NudgeRepository {
  SupabaseNudgeRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<List<Nudge>> watchReceivedNudges(String userId) {
    return _client
        .from('nudges')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .asyncMap(_hydrateNudges);
  }

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) async {
    try {
      final row = await _client.rpc(
        'send_nudge',
        params: {
          'p_group_id': groupId,
          'p_recipient_id': recipient.id,
          'p_message': normalizeNudgeMessage(message),
        },
      );
      return Nudge.fromMap(Map<String, dynamic>.from(row as Map)).copyWith(
        senderDisplayName: sender.displayName,
        senderAvatarUrl: sender.avatarUrl,
      );
    } on PostgrestException catch (e) {
      throw NudgeException(_friendlyMessage(e.message));
    }
  }

  @override
  Future<void> markRead(String nudgeId) async {
    try {
      await _client.rpc('mark_nudge_read', params: {'p_nudge_id': nudgeId});
    } on PostgrestException catch (e) {
      throw NudgeException('Dürtme okundu işaretlenemedi: ${e.message}');
    }
  }

  Future<List<Nudge>> _hydrateNudges(List<Map<String, dynamic>> rows) async {
    final nudges = rows.map(Nudge.fromMap).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = nudges.take(50).toList();
    final senderIds = latest.map((n) => n.senderId).toSet().toList();
    if (senderIds.isEmpty) return latest;

    final profiles = await _client
        .from('profiles')
        .select('id, display_name, avatar_url')
        .inFilter('id', senderIds);
    final profilesById = {for (final row in profiles) row['id'] as String: row};

    return [
      for (final nudge in latest)
        nudge.copyWith(
          senderDisplayName:
              profilesById[nudge.senderId]?['display_name'] as String?,
          senderAvatarUrl:
              profilesById[nudge.senderId]?['avatar_url'] as String?,
        ),
    ];
  }

  String _friendlyMessage(String message) {
    if (message.contains('nudge_cooldown')) {
      return 'Aynı kişiyi tekrar dürtmek için biraz bekle.';
    }
    if (message.contains('cannot_nudge_self')) {
      return 'Kendine dürtme gönderemezsin.';
    }
    if (message.contains('not_group_member')) {
      return 'Bu grupta dürtme gönderme yetkin yok.';
    }
    return 'Dürtme gönderilemedi: $message';
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/nudge.dart';
import '../../models/nudge_mute.dart';
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
      // WP-444: susturma kararı **sunucudadır**. RPC susturulmuş alıcı için
      // satır/realtime/outbox üretmez ama gönderene normal bir dürtme satırı
      // döndürür; istemci farkı göremez ve süzgeci atlayamaz.
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

  @override
  Future<List<String>> listMutedNudgeSenderIds() async {
    try {
      final rows = await _client
          .from('nudge_mutes')
          .select('muted_sender_id')
          .eq('user_id', _client.auth.currentUser?.id ?? '');
      return [for (final row in rows) row['muted_sender_id'] as String];
    } on PostgrestException catch (e) {
      throw NudgeException('Dürtme ayarları okunamadı: ${e.message}');
    }
  }

  @override
  Future<List<NudgeMute>> fetchNudgeMutes() async {
    try {
      // Yalnız çağıranın kendi listesi; RPC ad/avatarı susturulan kişi grubu
      // terk etse bile döndürür (`blocked_user_directory` ile aynı desen).
      final rows = await _client.rpc('nudge_mute_directory');
      return [
        for (final row in (rows as List))
          NudgeMute.fromMap(Map<String, dynamic>.from(row as Map)),
      ];
    } on PostgrestException catch (e) {
      throw NudgeException('Dürtme ayarları okunamadı: ${e.message}');
    }
  }

  @override
  Future<void> muteNudgesFrom(String userId) async {
    try {
      await _client.rpc('mute_nudges_from', params: {'p_user_id': userId});
    } on PostgrestException catch (e) {
      throw NudgeException(_friendlyMuteMessage(e.message));
    }
  }

  @override
  Future<void> unmuteNudgesFrom(String userId) async {
    try {
      await _client.rpc('unmute_nudges_from', params: {'p_user_id': userId});
    } on PostgrestException catch (e) {
      throw NudgeException(_friendlyMuteMessage(e.message));
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
      return 'Aynı kişiye 10 dakikada bir dürtme gönderebilirsin.';
    }
    if (message.contains('cannot_nudge_self')) {
      return 'Kendine dürtme gönderemezsin.';
    }
    if (message.contains('not_group_member')) {
      return 'Bu grupta dürtme gönderme yetkin yok.';
    }
    if (message.contains('nudge_blocked')) {
      return 'Engellenen kullanıcıyla dürtme gönderemezsin.';
    }
    return 'Dürtme gönderilemedi: $message';
  }

  String _friendlyMuteMessage(String message) {
    if (message.contains('cannot_mute_self')) {
      return 'Kendini susturamazsın.';
    }
    return 'Dürtme ayarı kaydedilemedi: $message';
  }
}

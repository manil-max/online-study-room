import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../moderation_repository.dart';

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> acceptCommunityTerms(String version) async {
    try {
      await _client.rpc(
        'accept_community_terms',
        params: {'p_version': version},
      );
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    try {
      await _client.rpc('block_user', params: {'p_blocked_id': userId});
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    try {
      await _client.rpc('unblock_user', params: {'p_blocked_id': userId});
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<List<String>> listBlockedUserIds() async {
    final rows = await _client.from('user_blocks').select('blocked_id');
    return [
      for (final r in rows as List) r['blocked_id'] as String,
    ];
  }

  @override
  Future<List<Profile>> fetchBlockedProfiles() async {
    final ids = await listBlockedUserIds();
    if (ids.isEmpty) return const [];

    // profiles_select RLS okumayı kısıtlayabilir; okunamayanlar maskelenir.
    Map<String, Profile> byId = {};
    try {
      final rows = await _client
          .from('profiles')
          .select(
            'id, display_name, avatar_url, created_at, daily_goal_minutes, is_active, animal, monthly_report_opt_in',
          )
          .inFilter('id', ids);
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final p = Profile.fromMap(map);
        byId[p.id] = p;
      }
    } on PostgrestException {
      byId = {};
    }

    final out = <Profile>[];
    for (final id in ids) {
      final known = byId[id];
      if (known != null) {
        out.add(known);
      } else {
        out.add(
          Profile(
            id: id,
            displayName: id.length > 8 ? '${id.substring(0, 8)}…' : id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    }
    out.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return out;
  }

  @override
  Future<void> reportUgc({
    required String targetType,
    required String targetId,
    required String reason,
    String? details,
    String? snapshot,
  }) async {
    try {
      await _client.rpc(
        'report_ugc',
        params: {
          'p_target_type': targetType,
          'p_target_id': targetId,
          'p_reason': reason,
          'p_details': details,
          'p_snapshot': snapshot,
        },
      );
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }
}

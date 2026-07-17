import 'package:supabase_flutter/supabase_flutter.dart';

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

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/exam_countdown.dart';
import '../exam_countdown_repository.dart';

/// Bulut geri sayim RPC istemcisi (migration `0133`).
///
/// `userKey` hicbir RPC'ye gonderilmez: sunucu kullaniciyi `auth.uid()` ile
/// belirler. Boylece istemci baska bir hesabin satirini ne okuyabilir ne yazar.
class SupabaseExamCountdownRepository implements ExamCountdownRepository {
  SupabaseExamCountdownRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<ExamCountdown>> load({required String userKey}) async {
    final raw = await _client.rpc('list_exam_countdowns');
    if (raw is! List) return const [];
    return [
      for (final row in raw) ?ExamCountdown.fromRow(row),
    ];
  }

  @override
  Future<void> upsert({
    required String userKey,
    required ExamCountdown entry,
  }) async {
    await _client.rpc('upsert_exam_countdown', params: entry.toRpcParams());
  }

  @override
  Future<void> delete({required String userKey, required String id}) async {
    await _client.rpc('delete_exam_countdown', params: {'p_id': id});
  }
}

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/faq_entry.dart';
import '../support_repository.dart';

class SupabaseSupportRepository implements SupportRepository {
  SupabaseSupportRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<FaqEntry>> fetchPublishedFaq(String locale) async {
    final rows = await _client
        .from('faq_entries')
        .select('id, locale, question, answer, sort_order')
        .eq('locale', locale)
        .order('sort_order');
    return rows.map(FaqEntry.fromMap).toList();
  }

  @override
  Future<void> submitQuestion({
    required String question,
    required String userId,
  }) async {
    await _client.rpc('submit_faq_question', params: {'p_question': question});
  }
}

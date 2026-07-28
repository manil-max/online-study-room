import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/l10n/app_locale.dart';
import '../models/faq_entry.dart';
import '../repositories/in_memory/in_memory_support_repository.dart';
import '../repositories/support_repository.dart';
import '../repositories/supabase/supabase_support_repository.dart';
import 'auth_providers.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseSupportRepository(Supabase.instance.client);
  }
  return InMemorySupportRepository();
});

final faqEntriesProvider = FutureProvider<List<FaqEntry>>((ref) async {
  final locale = ref.watch(appLanguageProvider) == AppLanguage.english
      ? 'en'
      : 'tr';
  final entries = await ref
      .watch(supportRepositoryProvider)
      .fetchPublishedFaq(locale);
  if (entries.isNotEmpty) return entries;
  return ref.watch(supportRepositoryProvider).fetchPublishedFaq('en');
});

final submitFaqQuestionProvider = Provider<Future<void> Function(String)>((
  ref,
) {
  return (question) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) throw StateError('session_required');
    await ref
        .read(supportRepositoryProvider)
        .submitQuestion(question: question, userId: user.id);
  };
});

import '../models/faq_entry.dart';

abstract class SupportRepository {
  Future<List<FaqEntry>> fetchPublishedFaq(String locale);

  Future<void> submitQuestion({
    required String question,
    required String userId,
  });
}

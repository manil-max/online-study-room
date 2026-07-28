import 'dart:typed_data';

import '../models/faq_entry.dart';

abstract class SupportRepository {
  Future<List<FaqEntry>> fetchPublishedFaq(String locale);

  /// WP-423: destek sorusuna tek ve **opsiyonel** foto eki.
  Future<void> submitQuestion({
    required String question,
    required String userId,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  });
}

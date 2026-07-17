import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';

/// WP-130: reportUgc details yolu repo'da saklanır (RPC p_details).
void main() {
  test('reportUgc stores optional details when non-empty', () async {
    final repo = InMemoryModerationRepository();
    await repo.reportUgc(
      targetType: 'message',
      targetId: 'm1',
      reason: 'other',
      details: '  spam links in chat  ',
    );
    expect(repo.reports, hasLength(1));
    expect(repo.reports.single['details'], '  spam links in chat  ');
  });

  test('reportUgc allows null details', () async {
    final repo = InMemoryModerationRepository();
    await repo.reportUgc(
      targetType: 'user',
      targetId: 'u1',
      reason: 'spam',
      details: null,
    );
    expect(repo.reports.single['details'], isNull);
  });
}

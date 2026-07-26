import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _readRepoFile(String relativePath) {
  final repoRoot = Directory.current.parent.path;
  return File('$repoRoot/$relativePath').readAsStringSync();
}

void main() {
  final repository = _readRepoFile(
    'app/lib/data/repositories/supabase/supabase_presence_repository.dart',
  );
  final repositoryContract = _readRepoFile(
    'app/lib/data/repositories/presence_repository.dart',
  );
  final lifecycle = _readRepoFile(
    'app/lib/data/providers/presence_lifecycle.dart',
  );
  final studyProviders = _readRepoFile(
    'app/lib/data/providers/study_providers.dart',
  );

  test('WP-339 server-derived presence sözleşmesini ve kill switchi korur', () {
    expect(
      repositoryContract,
      contains('PresenceProjectionMode { legacy, shadow, projection }'),
    );
    expect(repository, contains("'apply_multi_group_presence_state'"));
    expect(repository, contains("'heartbeat_multi_group_presence'"));
    expect(repository, contains("'group_live_presence'"));
    expect(repository, contains("primaryKey: ['group_id', 'user_id']"));
    expect(repository, contains('_watchDualGroupPresence'));
  });

  test('auth/geciken grup publishi no-op yapmaz', () {
    expect(
      lifecycle,
      isNot(contains('if (user == null || group == null) return;')),
    );
    expect(
      studyProviders,
      isNot(contains('if (user == null || group == null) return;')),
    );
    expect(lifecycle, contains('heartbeatPresence(presence)'));
  });
}

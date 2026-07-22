import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/firebase_push_config.dart';

void main() {
  group('FirebasePushConfig', () {
    test('all empty values mean push is intentionally not configured', () {
      expect(
        FirebasePushConfig.resolveStatus(
          projectId: '',
          apiKey: '',
          appId: '',
          messagingSenderId: '',
        ),
        FirebasePushConfigStatus.notConfigured,
      );
    });

    test('partial values fail closed instead of silently initializing', () {
      expect(
        FirebasePushConfig.resolveStatus(
          projectId: 'focus-staging',
          apiKey: 'api-key',
          appId: '',
          messagingSenderId: '123456',
        ),
        FirebasePushConfigStatus.incomplete,
      );
    });

    test('four complete Android identifiers enable push', () {
      expect(
        FirebasePushConfig.resolveStatus(
          projectId: 'focus-staging',
          apiKey: 'api-key',
          appId: '1:123456:android:abcdef',
          messagingSenderId: '123456',
        ),
        FirebasePushConfigStatus.configured,
      );
    });
  });
}

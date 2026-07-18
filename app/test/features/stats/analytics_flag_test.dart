import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/stats/analytics/analytics_flag.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('analyticsGridV1Provider', () {
    test('defaults to false (legacy ListView)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(analyticsGridV1Provider), isFalse);
    });

    test('setEnabled(true) persists and flips state', () async {
      SharedPreferences.setMockInitialValues({kAnalyticsGridV1Key: false});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(analyticsGridV1Provider), isFalse);

      await container.read(analyticsGridV1Provider.notifier).setEnabled(true);
      expect(container.read(analyticsGridV1Provider), isTrue);
      expect(prefs.getBool(kAnalyticsGridV1Key), isTrue);

      await container.read(analyticsGridV1Provider.notifier).setEnabled(false);
      expect(container.read(analyticsGridV1Provider), isFalse);
      expect(prefs.getBool(kAnalyticsGridV1Key), isFalse);
    });

    test('reads existing prefs true', () async {
      SharedPreferences.setMockInitialValues({kAnalyticsGridV1Key: true});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(analyticsGridV1Provider), isTrue);
    });
  });
}

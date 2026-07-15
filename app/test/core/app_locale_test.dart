import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  tearDown(() => setActiveAppLocale(const Locale('en')));

  test('manual language choice overrides the system locale', () {
    expect(
      resolvePreferredAppLocale(const Locale('en'), AppLanguage.turkish),
      const Locale('tr'),
    );
    expect(
      resolvePreferredAppLocale(const Locale('tr'), AppLanguage.english),
      const Locale('en'),
    );
    expect(
      resolvePreferredAppLocale(const Locale('tr'), AppLanguage.system),
      const Locale('tr'),
    );
  });

  test(
    'language choice is persisted and updates the active app locale',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(appLanguageProvider), AppLanguage.system);
      await container
          .read(appLanguageProvider.notifier)
          .setLanguage(AppLanguage.turkish);

      expect(container.read(appLanguageProvider), AppLanguage.turkish);
      expect(activeAppLocale, const Locale('tr'));

      final restored = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(restored.dispose);
      expect(restored.read(appLanguageProvider), AppLanguage.turkish);

      // SharedPreferences test eklentisi testler arasında aynı örneği taşır.
      // Sonraki sistem-locale testlerini manuel tercihle kirletme.
      await container
          .read(appLanguageProvider.notifier)
          .setLanguage(AppLanguage.system);
    },
  );
}

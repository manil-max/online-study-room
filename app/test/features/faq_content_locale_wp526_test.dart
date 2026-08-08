import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/faq_entry.dart';
import 'package:online_study_room/data/providers/support_providers.dart';
import 'package:online_study_room/data/repositories/support_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-526: SSS içeriği ARAYÜZÜN dilinde gelmeli.
///
/// Sahip 2026-08-08'de sahada yakaladı: arayüz İngilizceyken SSS soruları ve
/// cevapları Türkçe geliyordu. Kök neden bir tek satırdı:
///
///   ref.watch(appLanguageProvider) == AppLanguage.english ? 'en' : 'tr'
///
/// Dil tercihi ÜÇ değerlidir (`system`, `english`, `turkish`). Bu ifade
/// `system`'i sessizce Türkçe sayar — yani telefonu İngilizce olan ve dile hiç
/// dokunmamış kullanıcı arayüzü İngilizce görür, içeriği Türkçe alır. Aynı
/// hatalı satır iki yerdeydi: `support_providers.dart` ve `faq_screen.dart`.
///
/// 🔴 Bu testin asıl iddiası **`system` + İngilizce cihaz** durumudur. Yalnız
/// `english`/`turkish` durumlarını sınayan bir test eski kodda da yeşil kalırdı
/// ve hatayı hiç görmezdi.
void main() {
  late _RecordingSupportRepository repository;

  Future<ProviderContainer> boot(
    String? languagePreference,
    Locale deviceLocale,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.localeTestValue = deviceLocale;
    addTearDown(binding.platformDispatcher.clearLocaleTestValue);

    SharedPreferences.setMockInitialValues(
      languagePreference == null
          ? <String, Object>{}
          : <String, Object>{'app_language_preference': languagePreference},
    );
    final prefs = await SharedPreferences.getInstance();
    repository = _RecordingSupportRepository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        supportRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    // Dinleyicisiz okuma auto-dispose provider'ı her seferinde yeniden kurar;
    // kayıt listesi o zaman yanıltıcı olurdu.
    container.listen(faqEntriesProvider, (_, _) {});
    return container;
  }

  test('sistem dili secili + cihaz Ingilizce -> icerik EN istenir', () async {
    final container = await boot(null, const Locale('en'));
    await container.read(faqEntriesProvider.future);
    expect(repository.requested, ['en']);
  });

  test('sistem dili secili + cihaz Turkce -> icerik TR istenir', () async {
    final container = await boot(null, const Locale('tr'));
    await container.read(faqEntriesProvider.future);
    expect(repository.requested, ['tr']);
  });

  test('acik English tercihi -> icerik EN istenir', () async {
    final container = await boot('english', const Locale('tr'));
    await container.read(faqEntriesProvider.future);
    expect(repository.requested, ['en']);
  });

  test('acik Turkce tercihi -> icerik TR istenir', () async {
    final container = await boot('turkish', const Locale('en'));
    await container.read(faqEntriesProvider.future);
    expect(repository.requested, ['tr']);
  });

  test('desteklenmeyen cihaz dili -> EN sozlesmesi korunur', () async {
    final container = await boot(null, const Locale('de'));
    await container.read(faqEntriesProvider.future);
    expect(repository.requested, ['en']);
  });

  test('contentLanguageCodeProvider tercihi degil cozulmus dili verir', () async {
    final container = await boot(null, const Locale('en'));
    expect(container.read(contentLanguageCodeProvider), 'en');
    expect(container.read(appLanguageProvider), AppLanguage.system);
  });
}

class _RecordingSupportRepository implements SupportRepository {
  final List<String> requested = [];

  @override
  Future<List<FaqEntry>> fetchPublishedFaq(String locale) async {
    requested.add(locale);
    // Bos donmek yedek 'en' cagrisini tetikler ve kaydi kirletirdi; bu yuzden
    // her dil icin tek bir satir donulur.
    return [
      FaqEntry(
        id: '$locale-1',
        locale: locale,
        question: 'q-$locale',
        answer: 'a-$locale',
        sortOrder: 1,
      ),
    ];
  }

  @override
  Future<void> submitQuestion({
    required String question,
    required String userId,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  }) async {}
}

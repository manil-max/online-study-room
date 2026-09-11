import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/core/utils/duration_format.dart';

/// WP-826 — **`activeAppLocale` ile ekranda çizilen dil AYNI kaynaktan gelmeli.**
///
/// 🔴 Bu dosya bir hata avından doğdu, tasarım tercihinden değil. `activeAppLocale`
/// globalini iki yazar besliyor:
///
///   * `main.dart` `localeResolutionCallback` — Flutter'ın `.locales` listesinden
///     çözdüğü dil. Ekrandaki **bütün** `AppLocalizations` metni budur.
///   * `app_locale.dart` `platformLocale()` — eskiden `.locale` tekilini okuyordu.
///
/// Gerçek cihazda bu ikisi aynı değeri verir, ama aynı olmaları bir **tesadüftür**,
/// sözleşme değil. Ayrıldıkları anda globali hangisinin SON yazdığı derleme
/// sırasına kalıyordu. WP-825'te ölçüldü (`group_cards_wp690_test`, aynı fikstür):
///
///   active=en ... target=android  → süreler "2h 22m"   (başlıklar Türkçe!)
///   active=tr ... target=windows  → süreler "2sa 22dk"
///
/// Yani aynı ekranda başlık Türkçe, süre İngilizce olabiliyordu — ve üç test
/// ürün kodu sağlamken yalnız dar kolda kırmızı düşüyordu.
///
/// Aşağıdaki iddialar tam o ayrışmayı kurar: liste `tr` derken tekil `en` kalır.
/// `platformLocale()` yine `.locale`e dönerse bu dosya kırmızıya düşer.
void main() {
  tearDown(() {
    final dispatcher =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher;
    dispatcher.clearLocalesTestValue();
    dispatcher.clearLocaleTestValue();
  });

  testWidgets('liste ile tekil ayrıştığında ekranın gördüğü dil kazanır', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');

    expect(
      platformLocale().languageCode,
      'tr',
      reason:
          '`platformLocale()` `.locale` tekilini okuyor. Ekran `.locales` '
          'listesinden çözülür: kullanıcı Türkçe arayüzde İngilizce süre görür.',
    );
  });

  testWidgets('ayrışmada süre biçimi arayüzle aynı dili konuşur', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');

    setActiveAppLocale(
      resolvePreferredAppLocale(platformLocale(), AppLanguage.system),
    );
    addTearDown(() => setActiveAppLocale(const Locale('en')));

    expect(
      formatHuman(2 * 3600 + 22 * 60),
      '2sa 22dk',
      reason:
          'Süre "2h 22m" çizildi: global, arayüzün çözdüğü dilden farklı bir '
          'kaynaktan beslenmiş.',
    );
  });

  testWidgets('liste boşsa tekil değere düşülür (exception yok)', (
    tester,
  ) async {
    // `locales.first` boş listede atardı; bu kol o düşüşü sabitler.
    tester.binding.platformDispatcher.localesTestValue = const <Locale>[];
    tester.binding.platformDispatcher.localeTestValue = const Locale('tr');

    expect(platformLocale().languageCode, 'tr');
  });
}

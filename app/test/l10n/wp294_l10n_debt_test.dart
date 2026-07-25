import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:online_study_room/core/notifications/app_push_notification_service.dart';
import 'package:online_study_room/core/tasks/task_deadline.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-294: l10n borcunun **geri gelmemesi** için kapı.
///
/// `scripts/l10n_audit.py` aynı kısıtları CI'da denetler; buradaki testler aynı
/// sözleşmeyi `flutter test` içine de bağlar, çünkü CI kapısı atlanabilir ama
/// paket testi her turda koşuyor.
const _locales = <String>['en', 'tr', 'de', 'ar'];

Map<String, Object?> _catalog(String locale) =>
    jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
        as Map<String, Object?>;

Set<String> _keys(Map<String, Object?> catalog) =>
    catalog.keys.where((key) => !key.startsWith('@')).toSet();

void main() {
  group('katalog eşliği — dört dil', () {
    test('anahtar kümesi dört katalogda birebir aynı', () {
      final catalogs = {
        for (final locale in _locales) locale: _catalog(locale),
      };
      final template = _keys(catalogs['en']!);
      expect(template, isNotEmpty);
      for (final locale in _locales.skip(1)) {
        expect(
          _keys(catalogs[locale]!),
          template,
          reason:
              '$locale kataloğu şablondan (en) ayrıştı — WP-294 öncesinde '
              'denetim yalnız EN/TR bakıyordu, DE/AR sessizce kayabiliyordu',
        );
      }
    });

    test('placeholder\'lar dört dilde de referanslanıyor', () {
      final catalogs = {
        for (final locale in _locales) locale: _catalog(locale),
      };
      final template = catalogs['en']!;
      var checked = 0;
      for (final key in _keys(template)) {
        final metadata = template['@$key'];
        if (metadata is! Map<String, Object?>) continue;
        final placeholders = metadata['placeholders'];
        if (placeholders is! Map<String, Object?>) continue;
        for (final locale in _locales.skip(1)) {
          final value = catalogs[locale]![key];
          for (final placeholder in placeholders.keys) {
            expect(
              value,
              contains('{$placeholder'),
              reason: '$locale/$key içinde {$placeholder} yok',
            );
            checked++;
          }
        }
      }
      // Sayaç, döngünün sessizce boş geçmesine karşı: metadata biçimi değişirse
      // yukarıdaki `continue`'lar her şeyi atlar ve test hiçbir şey doğrulamaz.
      expect(checked, greaterThan(100));
    });

    test('WP-294 anahtarları gerçekten çevrildi (dil başına farklı değer)', () {
      final catalogs = {
        for (final locale in _locales) locale: _catalog(locale),
      };
      // Kopyala-yapıştır İngilizce, "çeviri yapıldı" görüntüsü verip DE/AR
      // kullanıcısını İngilizceye mahkûm ediyordu; sayısal olarak yakalanır.
      for (final key in const <String>[
        'accountHesabiSil',
        'accountSilmeOnayGovdesi',
        'updaterMagazaUzerindenYonetilir',
        'buildTaniBasligi',
        'statsEnVerimliSaat',
      ]) {
        final values = {
          for (final locale in _locales) locale: catalogs[locale]![key],
        };
        expect(
          values.values.toSet(),
          hasLength(_locales.length),
          reason: '$key dillerde aynı metni taşıyor: $values',
        );
      }
    });
  });

  group('gömülü metin regresyonu', () {
    test('elle dil seçen `languageCode == \'tr\'` üçlemesi geri gelmedi', () {
      // 🔴 Bu kalıp katalogu **tamamen atlıyordu**: iki dil elle tutulduğu için
      // DE/AR kullanıcısı İngilizce görüyordu ve denetim (Türkçe karakter
      // arıyordu) İngilizce dalı hiç görmüyordu.
      for (final path in const <String>[
        'lib/features/profile/account_settings_screen.dart',
        'lib/core/config/build_identity_card.dart',
        'lib/core/config/build_configuration_error_app.dart',
      ]) {
        // Yorumlar çıkarılıyor: bu dosyalarda kalıbın **neden** kaldırıldığını
        // anlatan yorumlar var, onlar bulgu değil.
        final code = File(path)
            .readAsStringSync()
            .replaceAll(RegExp(r'//.*'), '');
        expect(
          code,
          isNot(contains("languageCode == 'tr'")),
          reason: '$path yine elle dil seçiyor',
        );
      }
    });

    test('hesap silme akışı ham istisna metni göstermiyor', () {
      // `Text(e.toString())` hem yerelleştirilemez hem sunucu/istisna metnini
      // kullanıcıya sızdırır.
      expect(
        File(
          'lib/features/profile/account_settings_screen.dart',
        ).readAsStringSync(),
        isNot(contains('Text(e.toString())')),
      );
    });

    test('native sayaç bildirimi düzeni string kaynağı kullanıyor', () {
      final layout = File(
        'android/app/src/main/res/layout/timer_notification.xml',
      ).readAsStringSync();
      expect(layout, contains('android:text="@string/action_stop"'));
      expect(layout, isNot(contains('android:text="Durdur"')));
    });
  });

  group('yerele bağlı biçimlendirme', () {
    // `main()` bunu açılışta çağırıyor; testte de gerekli, aksi hâlde
    // `DateFormat` `LocaleDataException` atar.
    setUpAll(initializeDateFormatting);

    test('taskDueDateLabel ay adını yerelden alıyor', () {
      final now = DateTime(2026, 7, 25);
      final due = DateTime(2026, 8, 28);

      final en = taskDueDateLabel(now, due, 'en');
      final tr = taskDueDateLabel(now, due, 'tr');
      final de = taskDueDateLabel(now, due, 'de');

      // Sabit Türkçe ay listesi kaldırıldı; her yerel kendi adını üretmeli.
      expect(en, isNot(tr), reason: 'EN ve TR aynı ay adını verdi');
      expect(en, contains('Aug'));
      expect(tr, contains('Ağu'));
      expect(de, isNotEmpty);
      expect(en, contains('28'));
    });

    test('taskDueDateLabel farklı yılda yılı da yazıyor', () {
      final now = DateTime(2026, 7, 25);
      final nextYear = DateTime(2027, 8, 28);
      expect(taskDueDateLabel(now, nextYear, 'en'), contains('2027'));
      expect(
        taskDueDateLabel(now, DateTime(2026, 8, 28), 'en'),
        isNot(contains('2026')),
      );
    });
  });

  group('bildirim kanalları', () {
    testWidgets('kanal adı ve açıklaması artık ayrı metinler', (tester) async {
      // 🔴 Eskiden `description` alanı adın kopyasıydı ve `_channelFor` ayrı bir
      // Türkçe sabit taşıyordu; iki tanım ayrışmıştı.
      late AppLocalizations l10n;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('tr'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final descriptions = <String>[
        l10n.notificationsDurtmeKanaliAciklamasi,
        l10n.notificationsTestKanaliAciklamasi,
        l10n.notificationsGuncellemeKanaliAciklamasi,
        l10n.notificationsDuyuruKanaliAciklamasi,
      ];
      final names = <String>[
        l10n.coreDurtmeler,
        l10n.notificationsHealthTitle,
        l10n.notificationsGuncellemeBildirimleri,
        l10n.notificationsDuyurular,
      ];
      expect(descriptions.toSet(), hasLength(4));
      for (var i = 0; i < 4; i++) {
        expect(
          descriptions[i],
          isNot(names[i]),
          reason: '${names[i]} kanalının açıklaması hâlâ adın kopyası',
        );
      }
      // Kanal türü listesi ile `_channelFor` eşlemesi tek yerde durur; tür
      // sayısı kanal sayısıyla eşleşmezse bir kanal hiç kurulmaz.
      expect(kNotificationChannelTypes, hasLength(4));
    });
  });
}

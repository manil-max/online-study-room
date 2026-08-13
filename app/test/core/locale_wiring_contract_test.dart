import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-526: "arayüz İngilizce ama içerik Türkçe" hata sınıfına kalıcı kapı.
///
/// Sahip aynı sınıftan hataları üst üste sahada buldu ve haklı olarak
/// "bütün projeyi taramak lazım" dedi. Tek tek düzeltmek yetmez; bu test
/// **kaynak kodu tarar** ve sınıfın geri gelmesini engeller.
///
/// Yakalanan iki desen:
///
/// 1. **Dil tercihini iki değere daraltmak.** `AppLanguage` üç değerlidir
///    (`system`, `english`, `turkish`). `preference == AppLanguage.english ?
///    'en' : 'tr'` yazmak `system`'i sessizce Türkçe sayar. Doğrusu daima
///    `resolvePreferredAppLocale` / `contentLanguageCodeProvider`.
///
/// 2. **Ekrana sabit dil vermek.** `locale: Locale('tr')` gibi bir parametre
///    (takvim/saat seçicilerinde) arayüz dilini yok sayar. Sabit dilli tek bir
///    `showDatePicker` gerçekten üretimdeydi.
///
/// Kapı bilerek dar: yalnız `app/lib` altını, yalnız bu iki deseni arar.
/// Beyaz listeye eklenen her dosyanın yanında NEDEN muaf olduğu yazılıdır.
void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File file) => file.path.replaceAll(r'\', '/');

  test('tarama gercekten dosya goruyor (kapi bos yere yesil kalmasin)', () {
    expect(libDir.existsSync(), isTrue, reason: 'lib/ bulunamadi');
    expect(dartFiles().length, greaterThan(100));
  });

  test('dil tercihi iki degere daraltilmiyor', () {
    // Muaf: tercih enum'unun tanimlandigi dosya ve ayarlardaki secim listesi
    // (orada `AppLanguage.english` bir DEGER, dil karari degil).
    const allowed = {
      'lib/core/l10n/app_locale.dart',
      'lib/features/profile/settings_screen.dart',
      'lib/main.dart',
      'lib/core/l10n/system_localizations.dart',
      // WP-734: ilk acilis dil secimi. Ayarlardaki liste gibi burada da
      // `AppLanguage.*` bir SECENEK DEGERIDIR; ekran dil karari vermez,
      // kullanicinin verdigi karari tercihe yazar.
      'lib/features/onboarding/onboarding_screen.dart',
    };
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final path = rel(file);
      if (allowed.contains(path)) continue;
      final source = file.readAsStringSync();
      if (source.contains('AppLanguage.english') ||
          source.contains('AppLanguage.turkish') ||
          source.contains('AppLanguage.system')) {
        offenders.add(path);
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Bu dosyalar dil tercihini dogrudan okuyor. Tercih uc degerlidir ve '
          '`system` sessizce Turkce sayilir. `contentLanguageCodeProvider` '
          '(sunucu icerigi) veya `Localizations.localeOf(context)` (ekran) '
          'kullanin: $offenders',
    );
  });

  test('ekranlara sabit dil verilmiyor', () {
    // Muaf: uretilen l10n katalogu (destekleneni ilan eder) ve resolver.
    const allowed = {
      'lib/l10n/app_localizations.dart',
      'lib/core/l10n/app_locale.dart',
    };
    final pattern = RegExp(r"""Locale\(\s*['"](tr|en)['"]""");
    final offenders = <String>[];
    for (final file in dartFiles()) {
      final path = rel(file);
      if (allowed.contains(path)) continue;
      for (final line in file.readAsLinesSync()) {
        final code = line.split('//').first;
        if (pattern.hasMatch(code)) {
          offenders.add('$path: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Sabit dil, kullanicinin sectigi dili yok sayar. Takvim/saat '
          'secicilerinde `locale` parametresini hic vermeyin (ortamdan gelir): '
          '$offenders',
    );
  });
}

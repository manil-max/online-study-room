// WP-576: ölü yüzey regresyon kapısı.
//
// Bulgu: iki eksiksiz notifier — `StopwatchNotifier` (WP-60 tur kronometresi,
// kalıcılık anahtarları `clock_stopwatch_state_v1` +
// `clock_stopwatch_study_credited_ms`) ve `WorldCitiesNotifier` (dünya saati
// şehirleri, `world_clock_cities_v1`) — kodda duruyordu ama `lib/` içinde
// tek bir okuyucusu yoktu. Ekranları `1bf619f` ("remove retired clock tools",
// 2026-07-23, WP-264) silmiş, sağlayıcıları bırakmıştı. Aynı sınıftan üçüncü
// bir kalıntı `DashboardGridDensity`ydi: beş değerli enum, `columns` her
// zaman 32, `set()` argümanını yok sayıyor, `dashboard_grid_density` anahtarı
// yalnız yazılıyordu.
//
// Silmek yetmez — bu kapı aynı yüzeyin sessizce geri doğmasını engeller.
// İddia ölçülebilir: izlenen dosyalarda bildirilen **her** provider'ın
// `lib/` içinde gerçek bir tüketicisi vardır. İstisna [_internalOnly]
// listesine **gerekçesiyle** yazılır; bu bilinçli bir karardır.
//
// **Neden cihazda tek seferlik temizlik yok:** emekli anahtarların dördü de
// (aşağıdaki [_retiredPrefsKeys]) artık ne okunuyor ne yazılıyor; toplamı
// birkaç yüz bayt ve SharedPreferences'ta atıl duruyor. Temizlik kodu,
// sildiğimiz ölü yüzeyin yerine yenisini koyardı: ya kalıcı bir
// "temizlendi" bayrağı ya da her açılışta koşan üç `remove()`. Tek gerçek
// risk diriltme anında ortaya çıkar — bayat `clock_stopwatch_study_credited_ms`
// yeni bir kronometreyi sessizce eksik kredilendirir. Bu yüzden kronometre
// geri gelirse `_v2` adlı anahtarlarla gelmelidir; kapı zaten o an kırmızıya
// düşüp bu satırı okutur.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// İzlenen dosya → o dosyada beklenen **en az** provider sayısı.
///
/// Sayı bir taban: regex bozulup hiçbir şey bulamazsa kapı sessizce yeşil
/// kalmasın diye var (bkz. `test_all` dersi: ölçmediğini ölçen kapı).
const Map<String, int> _watchedFiles = <String, int>{
  'lib/data/providers/alarm_providers.dart': 6,
  'lib/features/home/dashboard_providers.dart': 3,
};

/// Yalnız kendi dosyasında okunan, ama oradaki **canlı** bir notifier
/// tarafından gerçekten kullanılan provider'lar.
const Map<String, String> _internalOnly = <String, String>{
  'alarmRepositoryProvider':
      'aynı dosyadaki AlarmsNotifier / TimerPresetsNotifier / '
      'TimerInstancesNotifier okur; üçü de ekranlardan tüketiliyor',
  'epochClockProvider':
      'aynı dosyadaki alarm+sayaç notifierları okur; testte override edilen '
      'saat kaynağı',
};

/// `lib/` içinde bir daha geçmemesi gereken emekli kalıcılık anahtarları.
const List<String> _retiredPrefsKeys = <String>[
  'clock_stopwatch_state_v1',
  'clock_stopwatch_study_credited_ms',
  'world_clock_cities_v1',
  'dashboard_grid_density',
];

/// Üst düzey `final xProvider = ...` bildirimi (girintili olanlar yerel değişken).
final RegExp _providerDecl = RegExp(r'^final\s+(\w+Provider)\s*=', multiLine: true);

/// Üst düzey herhangi bir `final` — isim kuralını atlatan bildirimi yakalar.
final RegExp _topLevelFinal = RegExp(r'^final\s', multiLine: true);

void main() {
  final libDir = Directory('lib');

  List<File> dartFiles() => libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  String rel(File file) => file.path.replaceAll(r'\', '/');

  Map<String, List<String>> declaredProviders() {
    final result = <String, List<String>>{};
    for (final path in _watchedFiles.keys) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path bulunamadi');
      final source = file.readAsStringSync();
      result[path] = _providerDecl
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();
    }
    return result;
  }

  test('tarama gercekten calisiyor (kapi bos yere yesil kalmasin)', () {
    expect(libDir.existsSync(), isTrue, reason: 'lib/ bulunamadi');
    expect(dartFiles().length, greaterThan(100));

    final declared = declaredProviders();
    for (final entry in _watchedFiles.entries) {
      final found = declared[entry.key]!;
      expect(
        found.length,
        greaterThanOrEqualTo(entry.value),
        reason:
            '${entry.key} icinde en az ${entry.value} provider bekleniyordu, '
            '${found.length} bulundu — bildirim regexi mi bozuldu?',
      );

      // Isim kuralini atlatan bildirim (ornegin `final foo = Provider(...)`)
      // kapinin disinda kalirdi; sayilar ayrilirsa kirmizi.
      final topLevel = _topLevelFinal
          .allMatches(File(entry.key).readAsStringSync())
          .length;
      expect(
        topLevel,
        found.length,
        reason:
            '${entry.key} icinde ust duzey final sayisi ($topLevel) provider '
            'bildirimi sayisindan (${found.length}) farkli — `xProvider` adlandirma '
            'kuralina uymayan bir bildirim kapiyi atliyor olabilir',
      );
    }
  });

  test('izlenen dosyalardaki her provider gercekten tuketiliyor', () {
    final declared = declaredProviders();
    final sources = <String, String>{
      for (final file in dartFiles()) rel(file): file.readAsStringSync(),
    };

    final orphans = <String>[];
    for (final entry in declared.entries) {
      for (final name in entry.value) {
        if (_internalOnly.containsKey(name)) continue;
        final pattern = RegExp('\\b$name\\b');
        final hasConsumer = sources.entries.any(
          (e) => e.key != entry.key && pattern.hasMatch(e.value),
        );
        if (!hasConsumer) orphans.add('$name  (${entry.key})');
      }
    }

    expect(
      orphans,
      isEmpty,
      reason:
          'Bu saglayiciyi lib/ icinde okuyan tek bir dosya yok — ekransiz olu '
          'yuzey (WP-576 tam olarak bunu temizledi). Ya tuketiciyi ekle ya '
          'saglayiciyi sil; dosya-ici kalmasi gercekten dogruysa _internalOnly '
          'listesine GEREKCESIYLE yaz.',
    );
  });

  test('_internalOnly listesi curumus degil', () {
    final declared = declaredProviders().values
        .expand((names) => names)
        .toSet();
    for (final name in _internalOnly.keys) {
      expect(
        declared,
        contains(name),
        reason:
            '$name artik izlenen dosyalarda bildirilmiyor; _internalOnly '
            'kaydini sil (muafiyet listesi curumesin)',
      );
    }
  });

  test('emekli kalicilik anahtarlari lib/ icinde geri dogmadi', () {
    final hits = <String>[];
    for (final file in dartFiles()) {
      final source = file.readAsStringSync();
      for (final key in _retiredPrefsKeys) {
        if (source.contains("'$key'") || source.contains('"$key"')) {
          hits.add('${rel(file)} -> $key');
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'Emekli anahtar geri geldi: $hits. Diriltiyorsan yeni bir surum adi '
          'kullan (`_v2`); bayat clock_stopwatch_study_credited_ms yeni '
          'kronometreyi sessizce eksik kredilendirir.',
    );
  });
}

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
//
// **WP-586 genişlemesi — aynı yüzeyin ikinci yarısı.** WP-576'dan sonra zaman
// motorunda iki kalıntı kaldı: `epoch_stopwatch.dart` (`EpochStopwatchState` +
// `EpochStopwatchEngine`, dosyanın tamamı) ve `lap_analysis.dart` içindeki
// `LapAnalysis` + `formatStopwatch`. Dördünün de `lib/` içinde tek bir çağrı
// yeri yoktu; onları yalnız kendi testleri canlı tutuyordu — WP-558'de
// yakalanan desenin aynısı. Aynı dosyadaki `formatCountdown` ise CANLI
// (`features/clock/timers_screen.dart`), o yüzden dosya duruyor.
//
// Kapı burada iki ölçü daha kazanır: (1) emekli sembol/dosya geri doğamaz,
// (2) [_watchedApiFiles] altındaki her üst düzey public bildirimin `lib/`
// içinde gerçek bir tüketicisi vardır — **barrel export etmek tüketici
// sayılmaz**, ölü yüzey tam olarak oradan besleniyordu. Liste TAM tutulur:
// yeni bir public sembol önce buraya yazılmak zorunda, yani tüketici
// zorunluluğunu sessizce atlayamaz.
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

/// WP-586: `lib/` içinde bir daha bildirilmemesi gereken emekli semboller.
const List<String> _retiredSymbols = <String>[
  'EpochStopwatchState',
  'EpochStopwatchEngine',
  'LapAnalysis',
  'formatStopwatch',
];

/// WP-586: tamamı ölü olduğu için silinen dosyalar.
const List<String> _retiredFiles = <String>[
  'lib/core/time_engine/epoch_stopwatch.dart',
];

/// WP-586: her üst düzey public bildiriminin `lib/` içinde gerçek bir
/// tüketicisi olması beklenen dosya → o dosyadaki bildirimlerin **tam** listesi.
///
/// Liste tam olduğu için kapı iki yönden de sıkı: bildirim regexi bozulursa
/// eşleşme tutmaz, yeni bir public sembol de listeye yazılmadan geçemez.
const Map<String, List<String>> _watchedApiFiles = <String, List<String>>{
  'lib/core/time_engine/lap_analysis.dart': <String>['formatCountdown'],
};

/// WP-586: zaman motoru barrel'ı — tüketici sayılmayan tek dosya.
const String _timeEngineBarrel = 'lib/core/time_engine/time_engine.dart';

/// Barrel'da beklenen **en az** export sayısı (taban: regex bozulursa kapı boş
/// yere yeşil kalmasın).
const int _timeEngineMinExports = 9;

/// Üst düzey `final xProvider = ...` bildirimi (girintili olanlar yerel değişken).
final RegExp _providerDecl = RegExp(r'^final\s+(\w+Provider)\s*=', multiLine: true);

/// Üst düzey herhangi bir `final` — isim kuralını atlatan bildirimi yakalar.
final RegExp _topLevelFinal = RegExp(r'^final\s', multiLine: true);

/// WP-586: üst düzey (girintisiz) public tip bildirimi.
final RegExp _publicTypeDecl = RegExp(
  r'^(?:abstract\s+|sealed\s+|base\s+|interface\s+|final\s+)*'
  r'(?:class|enum|mixin|extension|typedef)\s+([A-Za-z]\w*)',
  multiLine: true,
);

/// WP-586: üst düzey public `final`/`const` bildirimi.
final RegExp _publicTopLevelVar = RegExp(
  r'^(?:final|const)\s+(?:[\w<>,\s\?\.]+\s+)?([A-Za-z]\w*)\s*=',
  multiLine: true,
);

/// WP-586: üst düzey public fonksiyon (`String formatCountdown(...)`).
final RegExp _publicTopLevelFn = RegExp(
  r'^[A-Za-z_][\w<>,\s\?\.]*\s+([A-Za-z]\w*)\s*\(',
  multiLine: true,
);

/// WP-586: kaynagin yalniz **kod** satirlari — bastan `//` ile baslayan
/// (doc dahil) satirlar atilir.
///
/// Neden gerekli: bir sembolu neden sildigimizi anlatan yorum, sembolun adini
/// yazmak zorunda; duz metin taramasi o aciklamayi "geri dogdu" sanar. Satir
/// ICI yorum bilerek kirpilmaz — string icindeki `//` kesilip gercek bir
/// kullanim gizlenmesin. Yani kapi bu yonde fazladan siki kalir, gevsek degil.
///
/// Kanaryasi: ayni suzgecten gecen govde uzerinde
/// `izlenen api dosyalarindaki her public sembol tuketiliyor` testi POZITIF
/// bir eslesme bekler; suzgec her seyi silseydi o test kirmizi duserdi.
String _codeOnly(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// WP-586: barrel export satırı.
final RegExp _exportDecl = RegExp(r"^export\s+'([^']+)';", multiLine: true);

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

  /// WP-586: [path] içindeki üst düzey **public** bildirim adları.
  Set<String> publicDeclsOf(String path) {
    final file = File(path);
    expect(file.existsSync(), isTrue, reason: '$path bulunamadi');
    final source = file.readAsStringSync();
    return <String>{
      for (final m in _publicTypeDecl.allMatches(source)) m.group(1)!,
      for (final m in _publicTopLevelVar.allMatches(source)) m.group(1)!,
      for (final m in _publicTopLevelFn.allMatches(source)) m.group(1)!,
    };
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

  test('WP-586: emekli zaman motoru sembolleri lib/ icinde geri dogmadi', () {
    final hits = <String>[];
    for (final file in dartFiles()) {
      final source = _codeOnly(file.readAsStringSync());
      for (final name in _retiredSymbols) {
        if (RegExp('\\b$name\\b').hasMatch(source)) {
          hits.add('${rel(file)} -> $name');
        }
      }
    }

    expect(
      hits,
      isEmpty,
      reason:
          'WP-586 bu sembolleri sildi (tur kronometresi WP-264te ekransiz '
          'kalmisti): $hits. Gercekten diriltiyorsan once TUKETICISINI yaz; '
          'bu listeden cikarmak tek basina kanit degildir.',
    );
  });

  test('WP-586: silinen olu dosyalar ve barrel exportlari tutarli', () {
    for (final path in _retiredFiles) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason:
            '$path WP-586da silindi (icindeki iki sinifin da cagri yeri yoktu). '
            'Geri dogduysa once tuketicisini goster.',
      );
    }

    final barrel = File(_timeEngineBarrel);
    expect(barrel.existsSync(), isTrue, reason: '$_timeEngineBarrel bulunamadi');

    final exports = _exportDecl
        .allMatches(barrel.readAsStringSync())
        .map((m) => m.group(1)!)
        .toList();
    expect(
      exports.length,
      greaterThanOrEqualTo(_timeEngineMinExports),
      reason:
          'barrel icinde en az $_timeEngineMinExports export bekleniyordu, '
          '${exports.length} bulundu — export regexi mi bozuldu, yoksa bir '
          'dosya sessizce mi dustu?',
    );

    final dangling = <String>[
      for (final target in exports)
        if (!File('lib/core/time_engine/$target').existsSync()) target,
    ];
    expect(
      dangling,
      isEmpty,
      reason: 'barrel var olmayan dosyayi export ediyor: $dangling',
    );
  });

  test('WP-586: izlenen api dosyalarinin bildirim listesi guncel', () {
    for (final entry in _watchedApiFiles.entries) {
      expect(
        publicDeclsOf(entry.key),
        entry.value.toSet(),
        reason:
            '${entry.key} icindeki ust duzey public bildirimler _watchedApiFiles '
            'listesiyle uyusmuyor. Yeni sembol eklediysen listeye yaz (ve '
            'tuketici kapisina gir); sildiysen listeden cikar.',
      );
    }
  });

  test('WP-586: izlenen api dosyalarindaki her public sembol tuketiliyor', () {
    final sources = <String, String>{
      for (final file in dartFiles())
        rel(file): _codeOnly(file.readAsStringSync()),
    };

    final orphans = <String>[];
    for (final entry in _watchedApiFiles.entries) {
      for (final name in publicDeclsOf(entry.key)) {
        final pattern = RegExp('\\b$name\\b');
        final hasConsumer = sources.entries.any(
          (e) =>
              e.key != entry.key &&
              e.key != _timeEngineBarrel &&
              pattern.hasMatch(e.value),
        );
        if (!hasConsumer) orphans.add('$name  (${entry.key})');
      }
    }

    expect(
      orphans,
      isEmpty,
      reason:
          'Bu sembolu lib/ icinde kullanan tek bir dosya yok — barrel export '
          'etmek tuketici SAYILMAZ; WP-586 tam olarak boyle bir yuzeyi '
          'temizledi. Ya cagri yerini ekle ya sembolu sil.',
    );
  });
}

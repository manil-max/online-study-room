// WP-699: ana ekran widget'larinin BOYUTU ve ESNEKLIGI.
//
// Sahibin sikayeti uc parcaliydi: (1) varsayilan boyut olculu olsun,
// (2) buyutup kucultulebilsin, (3) her boyutta duzgun gorunsun.
//
// Bu dosya (1) ve (2)'nin **beyan** tarafini olcer: `res/xml/odak_*_widget_info.xml`
// icindeki boyut nitelikleri ile Kotlin tarafindaki esik sabitlerinin ayni
// sayilari soylemesi. (3)'un davranis tarafi JVM testindedir
// (`WidgetSizeClassWp699Test.kt`) — orada gercek genislik/yukseklik degerleriyle
// hangi gorunumun secildigi olculur.
//
// 🔴 Yayin oncesi bulunan uc kusur, iddiaya cevrildi:
//   a) YEDI dosyanin HICBIRINDE `maxResizeWidth`/`maxResizeHeight` yoktu —
//      ust sinir olmadigi icin widget ekrani kaplayacak kadar buyutulebiliyordu
//      ve icerik esnemiyordu.
//   b) `targetCellWidth/Height` yalniz `timer`da vardi ve **1x1**ti; o boyutta
//      HH:MM:SS kronometre ile Basla/Durdur dugmesi yan yana sigmiyor.
//      Diger bes dosyada hic yoktu, yani Android 12+ varsayilan boyutu
//      belirsizdi.
//   c) 🔴 En agiri: hicbir saglayici `onAppWidgetOptionsChanged` metodunu
//      gecersiz kilmiyordu. `HomeWidgetProvider` (home_widget 0.9.3) de
//      kilmiyor. Yani kullanici widget'i yeniden boyutlandirdiginda `onUpdate`
//      HIC cagrilmiyor: `compact` dali yalniz bir sonraki periyodik
//      guncellemede — `updatePeriodMillis=0` olan widget'larda ise ASLA —
//      yeniden hesaplaniyordu. "Buyutup kucultulen versiyon" beyanda vardi,
//      calisan kodda yoktu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String _xmlDir = 'android/app/src/main/res/xml';
const String _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';

/// WP-699 kapsamindaki alti widget. `alarm` BILEREK disarida: WP-696 onu
/// tazeleme yolu olmadigi icin yayin disinda tuttu; boyutunu duzeltmek onu
/// yayina almazdi ve kapsam disidir.
const List<String> _widgets = <String>[
  'timer',
  'clock',
  'countdown',
  'stats',
  'group_goal',
  'leaderboard',
];

/// Saglayici sinifinin adi -> kaynak dosyasi.
const Map<String, String> _providerFiles = <String, String>{
  'TimerWidgetProvider': 'TimerWidget.kt',
  'ClockWidgetProvider': 'ClockWidget.kt',
  'StudyStatsWidgetProvider': 'StatsWidget.kt',
  'GroupGoalWidgetProvider': 'GroupGoalWidget.kt',
  'GroupLeaderboardWidgetProvider': 'LeaderboardWidget.kt',
  'CountdownWidgetProvider': 'CountdownWidget.kt',
};

/// WP-752: boyut ESIKLERI paylasilan zeminde durur (saglayicilar bolundu,
/// esikler tek yerde kaldi ki dokuz widget ayni merdiveni konussun).
const String _thresholdFile = 'WidgetCommon.kt';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path yok');
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

String _infoXml(String widget) => _read('$_xmlDir/odak_${widget}_widget_info.xml');

/// `android:ad="deger"` -> `deger`; yoksa `null`. Yorum satirlari elenir
/// (WP-640 tuzagi: yorumdaki ornek nitelik gercek nitelik sanilmasin).
String? _attr(String xml, String name) {
  final stripped = xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');
  final match = RegExp('android:$name="([^"]*)"').firstMatch(stripped);
  return match?.group(1);
}

/// `110dp` -> `110`.
int _dp(String xml, String name) {
  final raw = _attr(xml, name);
  expect(raw, isNotNull, reason: 'android:$name beyan edilmemis');
  expect(raw, endsWith('dp'), reason: 'android:$name dp cinsinden olmali: $raw');
  final value = int.tryParse(raw!.substring(0, raw.length - 2));
  expect(value, isNotNull, reason: 'android:$name sayiya cevrilemedi: $raw');
  return value!;
}

int _int(String xml, String name) {
  final raw = _attr(xml, name);
  expect(raw, isNotNull, reason: 'android:$name beyan edilmemis');
  final value = int.tryParse(raw!);
  expect(value, isNotNull, reason: 'android:$name sayi degil: $raw');
  return value!;
}

/// Launcher hucre -> dp donusumu. Android'in yayimladigi formul
/// `70 * n - 30`dur: ILK hucre 40dp, her EK hucre 70dp ekler.
/// (`odak_timer_widget_info.xml` basindaki "1 hucre ≈ 40dp" yorumu yalniz
/// n=1 icin dogrudur; n=2'de 110dp, n=4'te 250dp verir — WP-699 o yorumu
/// duzeltti.)
int _cellDp(int cells) => 70 * cells - 30;

/// Kotlin kaynagindan `const val AD = SAYI` satirlarini toplar.
/// Yorum satirlari atlanir.
Map<String, int> _kotlinInts(String fileName) {
  final source = _read('$_kotlinDir/$fileName');
  final pattern = RegExp(r'^\s*(?:internal\s+)?const val (\w+)\s*=\s*(\d+)\b');
  final values = <String, int>{};
  for (final line in source.split('\n')) {
    if (line.trimLeft().startsWith('//')) continue;
    final match = pattern.firstMatch(line);
    if (match != null) values[match.group(1)!] = int.parse(match.group(2)!);
  }
  return values;
}

/// `timer` -> `Timer`, `group_goal` -> `GroupGoal`.
String _pascal(String widget) => widget
    .split('_')
    .map((part) => part[0].toUpperCase() + part.substring(1))
    .join();

void main() {
  group('WP-699 · her widget alt VE ust sinir beyan eder', () {
    for (final widget in _widgets) {
      test('$widget: minResize + maxResize + targetCell hepsi yazili', () {
        final xml = _infoXml(widget);

        expect(
          _attr(xml, 'resizeMode'),
          'horizontal|vertical',
          reason: 'iki eksende de yeniden boyutlandirma acik kalmali',
        );

        // 🔴 Bugunku eksik: ust sinir yok.
        final maxWidth = _dp(xml, 'maxResizeWidth');
        final maxHeight = _dp(xml, 'maxResizeHeight');
        final minResizeWidth = _dp(xml, 'minResizeWidth');
        final minResizeHeight = _dp(xml, 'minResizeHeight');
        final minWidth = _dp(xml, 'minWidth');
        final minHeight = _dp(xml, 'minHeight');
        final targetCellWidth = _int(xml, 'targetCellWidth');
        final targetCellHeight = _int(xml, 'targetCellHeight');

        // Varsayilan boyut iki kanalda da AYNI seyi soylemeli:
        // Android 12+ `targetCell*`e, oncesi `minWidth/minHeight`e bakar.
        // Ayrisirlarsa ayni widget surume gore farkli boyutta acilir.
        expect(
          minWidth,
          _cellDp(targetCellWidth),
          reason:
              '$widget varsayilan genisligi Android 12 oncesi/sonrasi ayrisiyor',
        );
        expect(
          minHeight,
          _cellDp(targetCellHeight),
          reason:
              '$widget varsayilan yuksekligi Android 12 oncesi/sonrasi ayrisiyor',
        );

        // Sahibin sarti: "cok buyuk olmasin". Varsayilan en fazla 3x2 hucre.
        expect(
          targetCellWidth,
          lessThanOrEqualTo(3),
          reason: '$widget varsayilani cok genis aciliyor',
        );
        expect(
          targetCellHeight,
          lessThanOrEqualTo(2),
          reason: '$widget varsayilani cok uzun aciliyor',
        );

        // Kucultme siniri varsayilanin altinda, buyutme siniri ustunde olmali;
        // aksi halde kullanici o yonde hic hareket edemez.
        expect(minResizeWidth, lessThanOrEqualTo(minWidth));
        expect(minResizeHeight, lessThanOrEqualTo(minHeight));
        expect(maxWidth, greaterThan(minWidth));
        expect(maxHeight, greaterThan(minHeight));

        // Ust sinir gercekten sinir olmali: 5 hucreden genis / 3 hucreden uzun
        // bir widget ana ekranin tamamini yutar.
        expect(maxWidth, lessThanOrEqualTo(_cellDp(5)));
        expect(maxHeight, lessThanOrEqualTo(_cellDp(4)));
      });
    }
  });

  group('WP-699 · yeniden boyutlandirma gercekten yeniden cizer', () {
    // 🔴 Kok kusur: `AppWidgetProvider.onAppWidgetOptionsChanged` bos bir
    // govdedir ve `HomeWidgetProvider` onu gecersiz kilmaz. Bu metot
    // yazilmadikca boyut degisimi `onUpdate`i tetiklemez; dar/genis dali
    // ekranda ASLA degismez.
    for (final entry in _providerFiles.entries) {
      test('${entry.key} onAppWidgetOptionsChanged gecersiz kiliyor', () {
        final source = _read('$_kotlinDir/${entry.value}');
        final classStart = source.indexOf('class ${entry.key} ');
        expect(classStart, greaterThan(-1), reason: '${entry.key} bulunamadi');
        // Sinif govdesi: bir sonraki ust duzey `class ` bildirimine kadar.
        final nextClass = source.indexOf('\nclass ', classStart + 1);
        final body = nextClass == -1
            ? source.substring(classStart)
            : source.substring(classStart, nextClass);
        expect(
          body.contains('override fun onAppWidgetOptionsChanged('),
          isTrue,
          reason:
              '${entry.key} yeniden boyutlandirmada kendini cizmiyor; '
              'dar/genis gorunum yalniz bir sonraki periyodik guncellemede '
              '(updatePeriodMillis=0 ise hic) degisir',
        );
      });
    }
  });

  group('WP-699 · XML sinirlari ile Kotlin esikleri ayni sayiyi soyler', () {
    // Esikler Kotlin'de, sinirlar XML'de. Ayrisirlarsa widget ya hic
    // ulasilamayan bir gorunum tanimlar (esik > maxResize) ya da en kucuk
    // halinde bile "genis" sayilir (esik < minResize).
    for (final widget in _widgets) {
      test('$widget esikleri [minResize, maxResize] araliginda', () {
        final xml = _infoXml(widget);
        final minResizeWidth = _dp(xml, 'minResizeWidth');
        final minResizeHeight = _dp(xml, 'minResizeHeight');
        final maxWidth = _dp(xml, 'maxResizeWidth');
        final maxHeight = _dp(xml, 'maxResizeHeight');

        final constants = _kotlinInts(_thresholdFile);
        final prefix = 'WIDGET_${widget.toUpperCase()}';
        for (final suffix in <String>[
          'MEDIUM_WIDTH_DP',
          'WIDE_WIDTH_DP',
          'MEDIUM_HEIGHT_DP',
          'TALL_HEIGHT_DP',
        ]) {
          final name = '${prefix}_$suffix';
          expect(
            constants.containsKey(name),
            isTrue,
            reason: '$name sabiti yok (${_pascal(widget)} esikleri beyan edilmemis)',
          );
        }

        final mediumWidth = constants['${prefix}_MEDIUM_WIDTH_DP']!;
        final wideWidth = constants['${prefix}_WIDE_WIDTH_DP']!;
        final mediumHeight = constants['${prefix}_MEDIUM_HEIGHT_DP']!;
        final tallHeight = constants['${prefix}_TALL_HEIGHT_DP']!;

        expect(mediumWidth, greaterThan(minResizeWidth));
        expect(wideWidth, greaterThan(mediumWidth));
        expect(wideWidth, lessThanOrEqualTo(maxWidth));
        expect(mediumHeight, greaterThan(minResizeHeight));
        expect(tallHeight, greaterThan(mediumHeight));
        expect(tallHeight, lessThanOrEqualTo(maxHeight));
      });
    }
  });

  group('WP-699 · kapsam disi', () {
    // WP-696 `alarm` widget'ini bilerek yayin disinda birakti (tazeleme yolu
    // yok, 30 dk bayat kaliyor). Boyut duzeltmesi onu yayina almazdi; bu
    // iddia dosyanin WP-699 turunda DEGISMEDIGINI sabitler.
    test('alarm widget tanimi WP-699 ile degismedi', () {
      final xml = _infoXml('alarm');
      expect(xml.contains('targetCellWidth'), isFalse);
      expect(xml.contains('maxResizeWidth'), isFalse);
      expect(xml.contains('minResizeWidth'), isFalse);
      expect(_dp(xml, 'minWidth'), 110);
      expect(_dp(xml, 'minHeight'), 80);
    });

    test('AlarmWidgetProvider boyut mantigi almadi', () {
      final source = _read('$_kotlinDir/AlarmWidget.kt');
      final start = source.indexOf('class AlarmWidgetProvider ');
      expect(start, greaterThan(-1));
      final body = source.substring(start);
      expect(body.contains('onAppWidgetOptionsChanged'), isFalse);
      expect(body.contains('widgetSizeClass'), isFalse);
    });
  });
}

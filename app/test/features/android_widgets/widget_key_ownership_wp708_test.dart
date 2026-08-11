// 🔴 WP-708 — GENEL KAPI, YAYIN LISTESI BUYUYUNCE OLCMEYI BIRAKTI.
//
// WP-558 gercek bir israfi kapatmisti: `saveSnapshot` 17 anahtari da yaziyordu
// ve yayindaki tek widget (sayac) `widgetData`ya HIC bakmiyordu. Kapisi
// `anyPublishedConsumesWidgetData` idi -- yani "yayinda veri okuyan biri var
// mi?".
//
// WP-707 dort widget'i yayina alinca o bayrak `true` oldu ve kapi ACILDI:
// okuyucusu olmayan anahtarlar yeniden yazilmaya basladi. Olculdu:
//   sayac turu   : 0 kanal turu  -> 4  (`timer_*`, hicbir saglayici okumaz)
//   istatistik   : 0 kanal turu  -> 37
// Yani kapi, korudugu kosul genislediginde sessizce ISLEVSIZ kaldi. Bu depoda
// tekrarlayan kusur bu: kapi dogru seye bakiyor gorunup eksik kumeyi olcuyor.
//
// Cozum kapiyi gevsetmek DEGIL, kosulu dogru yere baglamak: bir anahtar
// yazilir cunku YAYINDAKI BIR SAGLAYICI ONU OKUR -- yayinda genel olarak
// okuyan biri oldugu icin degil.
//
// Bu dosya Dart tarafindaki sahiplik beyanini `StudyWidgetProviders.kt`nin
// KENDISINDEN turetilen gercekle karsilastirir. Elle yazilan bir liste bir
// sure sonra bayatlar; turetilen liste bayatlayamaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

const _kotlinPath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets/'
    'StudyWidgetProviders.kt';

/// `const val Ad = "anahtar"` -> {Ad: anahtar}
Map<String, String> _keyConstants(String source) {
  final result = <String, String>{};
  final pattern = RegExp(r'const val (\w+) = "([\w_]+)"');
  for (final match in pattern.allMatches(source)) {
    result[match.group(1)!] = match.group(2)!;
  }
  return result;
}

/// Her `class X ... { }` govdesinde gecen `StudyWidgetKeys.Ad` sabitlerini
/// anahtar adlarina cevirir.
Map<String, Set<String>> _keysReadPerProvider(String source) {
  final constants = _keyConstants(source);
  final parts = source.split(RegExp(r'\nclass (\w+)'));
  final names = RegExp(r'\nclass (\w+)')
      .allMatches(source)
      .map((match) => match.group(1)!)
      .toList();
  final result = <String, Set<String>>{};
  for (var index = 0; index < names.length; index++) {
    final body = parts[index + 1];
    result[names[index]] = {
      for (final match in RegExp(r'StudyWidgetKeys\.(\w+)').allMatches(body))
        if (constants.containsKey(match.group(1))) constants[match.group(1)]!,
    };
  }
  return result;
}

void main() {
  final source = File(_kotlinPath).readAsStringSync();
  final readPerProvider = _keysReadPerProvider(source);

  group('WP-708 · anahtar sahipligi Kotlin ile ayni', () {
    test('probe: Kotlin gercekten ayristirildi', () {
      // Ayristirici sessizce bos donerse butun iddialar "hicbir sey okumuyor"
      // diye YESIL gecerdi -- olcum aracinin kendisini once sina.
      expect(readPerProvider, isNotEmpty);
      expect(
        readPerProvider['StudyStatsWidgetProvider'],
        isNotEmpty,
        reason: 'ayristirici sinif govdelerini bulamadi',
      );
    });

    test('her saglayicinin Dart beyani Kotlin ile birebir ayni', () {
      for (final widget in StudyHomeWidget.values) {
        final actual = readPerProvider[widget.androidName];
        if (actual == null) continue; // saglayici baska dosyada (countdown/task)
        expect(
          widget.readKeys,
          actual,
          reason:
              '${widget.androidName}: Dart "${widget.readKeys}" diyor, Kotlin '
              '"$actual" okuyor. Ayrisirsa ya okunmayan anahtar yazilir '
              '(bosuna kanal turu) ya da okunan anahtar yazilmaz (widget bos).',
        );
      }
    });

    test('hicbir saglayicinin okumadigi anahtar YAZILMAZ', () {
      final readByAnyone = <String>{
        for (final keys in readPerProvider.values) ...keys,
      };
      final orphans = AndroidWidgetKeys.all.difference(readByAnyone);
      // Olculdu: `stats_title` / `stats_today` / `stats_week` sabitleri
      // `StudyWidgetKeys` icinde tanimli ama hicbir `onUpdate` okumuyor.
      expect(
        orphans,
        containsAll(<String>{'stats_title', 'stats_today', 'stats_week'}),
        reason:
            'oksuz anahtar listesi degismis; degisiklik bilincliyse bu iddiayi '
            'guncelle, ama once o anahtari GERCEKTEN okuyan var mi bak',
      );
      expect(
        StudyHomeWidget.writableKeys.intersection(orphans),
        isEmpty,
        reason: 'okuyucusu olmayan anahtar hala yaziliyor: bosuna kanal turu',
      );
    });

    test('yayindaki her tuketicinin anahtarlari YAZILABILIR kumede', () {
      for (final widget in StudyHomeWidget.values) {
        if (!widget.isPublished || !widget.consumesWidgetData) continue;
        expect(
          StudyHomeWidget.writableKeys,
          containsAll(widget.readKeys),
          reason:
              '${widget.androidName} yayinda ve veriyi okuyor ama anahtarlari '
              'yazilmiyor: widget kalici olarak native yedek metni gosterir',
        );
      }
    });

    test('veriyi okumayan saglayicinin anahtari yazilmaz', () {
      // Sayac `widgetData`ya hic bakmaz (`consumesWidgetData: false`); WP-707
      // sonrasi `timer_*` yeniden yazilmaya baslamisti.
      expect(StudyHomeWidget.timer.readKeys, isEmpty);
      expect(
        StudyHomeWidget.writableKeys.intersection(AndroidWidgetKeys.timerGroup),
        isEmpty,
        reason: 'sayac widgetData okumuyor ama dort anahtari yine yaziliyor',
      );
    });

    test('yayinda tuketici yoksa yazilabilir kume BOS olur', () {
      // Iki yonlu iddianin diger ucu: kume "her zaman dolu" olsaydi WP-558'in
      // korudugu davranis kaybolurdu ve bunu hicbir iddia yakalamazdi.
      final consumers = StudyHomeWidget.values.where(
        (widget) => widget.consumesWidgetData,
      );
      expect(consumers, isNotEmpty);
      expect(
        consumers.every((widget) => widget.readKeys.isNotEmpty),
        isTrue,
        reason:
            'bir saglayici `consumesWidgetData: true` diyor ama hicbir anahtar '
            'okumuyor: ikisinden biri yalan',
      );
    });
  });
}

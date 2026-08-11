// WP-461: Yayında yalnız 1×1 Başlat/Durdur widget'ı görünür.
// WP-695: yanina sinav geri sayimi eklendi; dosyanin asil konusu
// **katalog <-> manifest esligi**dir, tek bir widget degil.
//
// Tuzak (kartta yazılı): beş widget'ı silmek ya da yeniden tasarlamak. Bu
// yüzden testler "yok mu" diye değil, **dormant mı** diye bakar: sağlayıcı
// sınıfı, xml tanımı ve manifest kaydı yerinde durmalı; yalnız yayından
// düşürülmüş olmalı.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';

String _manifest() => File('android/app/src/main/AndroidManifest.xml')
    .readAsStringSync()
    .replaceAll('\r\n', '\n');

/// Bir sağlayıcının manifest'teki `<receiver …>` başlık bloğu.
String _receiverHeader(String className) {
  final manifest = _manifest();
  final start = manifest.indexOf('android:name=".widgets.$className"');
  expect(start, greaterThan(-1), reason: '$className manifest\'ten silinmiş');
  final blockStart = manifest.lastIndexOf('<receiver', start);
  final blockEnd = manifest.indexOf('>', start);
  return manifest.substring(blockStart, blockEnd);
}

void main() {
  group('yayın allowlist\'i', () {
    // WP-701: yayin listesi uce cikti (sayac + sinav geri sayimi + gorev).
    // Iddia yine **acik**: kazayla acilan/kapanan bir bayrak kirmizi dussun.
    //
    // Bu iddia WP-701 turunda bayat kaldi ve kapiyi kirmizi dusurdu -- yani
    // gorevini yapti. Listeyi genisletirken sirasi da baglayici: enum sirasi
    // katalog sirasidir, katalog ekrani da o sirada cizer.
    test('yayinda yedi widget var; dormant kalan yalniz alarm', () {
      // WP-707: dort uykudaki widget yayina alindi. Sira baglayici: enum
      // sirasi katalog sirasidir, katalog ekrani da o sirada cizer.
      expect(publishedHomeWidgets, [
        HomeWidgetProvider.timer,
        HomeWidgetProvider.studyStats,
        HomeWidgetProvider.groupGoal,
        HomeWidgetProvider.groupLeaderboard,
        HomeWidgetProvider.clock,
        HomeWidgetProvider.countdown,
        HomeWidgetProvider.task,
      ]);
      // Iddia bos kalmasin: en az bir saglayici dormant kalmali, yoksa
      // asagidaki "manifest enabled bayragi" testinin `false` yonu hic
      // olculmez ve sozlesme tek yonlu kalir.
      expect(
        HomeWidgetProvider.values.where((p) => !isHomeWidgetPublished(p)),
        [HomeWidgetProvider.alarm],
        reason: 'alarm widgetinin tazeleme yolu yok (WP-696); yayina alinamaz',
      );
    });

    test('altı sağlayıcının hepsi katalogda kayıtlı kalır', () {
      expect(kHomeWidgetCatalog.length, HomeWidgetProvider.values.length);
      expect(
        kHomeWidgetCatalog.map((entry) => entry.provider).toSet(),
        HomeWidgetProvider.values.toSet(),
        reason: 'dormant widget katalogdan silinmemeli, yalnız kapatılmalı',
      );
    });
  });

  group('manifest sözleşmesi', () {
    // WP-695: olcu yayin bayragindan turetilir. Eskiden `timer` adiyla
    // sabitlenmisti; ikinci bir widget yayina girdiginde iddia bayatladi ve
    // gercekte olctugu seyi (katalog <-> manifest esligi) olcemez oldu.
    test('manifest `enabled` bayragi katalog ile ayni tarafta', () {
      for (final provider in HomeWidgetProvider.values) {
        final header = _receiverHeader(provider.androidClassName);
        expect(
          header.contains('android:enabled="false"'),
          !isHomeWidgetPublished(provider),
          reason: isHomeWidgetPublished(provider)
              ? '${provider.androidClassName} yayinda ama pickerda yok'
              : '${provider.androidClassName} hala pickerda gorunur',
        );
      }
    });

    test('dormant sağlayıcıların xml tanımı ve kaydı silinmedi', () {
      final manifest = _manifest();
      for (final provider in HomeWidgetProvider.values) {
        expect(
          manifest.contains('.widgets.${provider.androidClassName}'),
          isTrue,
          reason: '${provider.androidClassName} manifest\'ten silinmiş',
        );
      }
      final xmlDir = Directory('android/app/src/main/res/xml');
      final infos = xmlDir
          .listSync()
          .map((entity) => entity.uri.pathSegments.last)
          .where((name) => name.endsWith('_widget_info.xml'))
          .toList();
      expect(
        infos.length,
        HomeWidgetProvider.values.length,
        reason: 'widget xml tanımları revizyon için repoda kalmalı',
      );
    });

    test('appwidget alıcıları doğru dışa açıklıkla tanımlı', () {
      for (final provider in HomeWidgetProvider.values) {
        final header = _receiverHeader(provider.androidClassName);
        // Launcher'in baglayabilmesi icin appwidget receiver exported olmali;
        // yayindan dusurme `enabled` ile yapilir, `exported` ile degil.
        expect(
          header.contains('android:exported="true"'),
          isTrue,
          reason: '${provider.androidClassName} exported sözleşmesi bozulmuş',
        );
        expect(
          header.contains('android:permission='),
          isFalse,
          reason: '${provider.androidClassName} beklenmeyen permission taşıyor',
        );
      }
    });
  });

  // 🔴 WP-705: bu iddia YESILDI ama olcmesi gereken seyi olcmuyordu.
  // "Bazi kartlar bayragi okuyor" ile "yayindaki HER widget'in karti var"
  // ayni sey degil; ikincisi hicbir yerde yazili olmadigi icin WP-695'in geri
  // sayimi ve WP-701'in gorev widget'i yayinda oldugu halde katalogda HIC
  // gorunmedi. Cift yonlu olcum artik `widget_catalog_wp705_test.dart`
  // icindedir ve gercek ekrani monte eder.
  //
  // Buraya kalan borc YAPISALDIR: ekran kart listesini elle saymamali.
  test('katalog ekrani kart listesini yayin listesinden turetiyor', () {
    final source = File('lib/features/clock/clock_widgets_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(
      source.contains('for (final provider in publishedHomeWidgets)'),
      isTrue,
      reason: 'kartlar yayin listesinden turetilmeli',
    );
    expect(
      source.contains('isHomeWidgetPublished(HomeWidgetProvider.'),
      isFalse,
      reason:
          'saglayici saglayici elle sayim geri gelmis: yayin listesi '
          'buyudugunde yeni widget yine katalogda gorunmez',
    );
  });

  // WP-558: bu dosya eskiden yalniz manifest METNINI olcuyordu; katalog
  // bayragi ile calisan boru hattinin gercekte ne gonderdigini olcmuyordu.
  group("yayin allowlisti boru hattini da baglar", () {
    late List<String> updated;
    const channel = MethodChannel('home_widget');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      updated = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'updateWidget') {
              final args = call.arguments as Map<Object?, Object?>;
              updated.add(args['android'] as String? ?? '?');
            }
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('yalniz yayindaki saglayiciya updateWidget gonderilir', () async {
      const service = AndroidWidgetService();
      // WP-707: `StudyHomeWidget` uyelerinin HEPSI artik yayinda (dormant
      // kalan tek saglayici `alarm` ve o bu enumda yok). Bu yuzden olcu
      // "kapali olana gonderilmiyor mu" degil, KATALOG BAYRAGININ gercekten
      // kapi oldugu: bayragi kapali sayilan bir uye listeye giremez.
      expect(
        StudyHomeWidget.values.where((widget) => !widget.isPublished),
        isEmpty,
        reason:
            'bir uye yayindan dusuruldiyse asagidaki iddia bayat: kapali '
            'uyeye yayin gitmedigini de olc',
      );

      await service.refresh(widgets: const <StudyHomeWidget>[]);
      expect(updated, isEmpty, reason: 'bos hedef listesi tek tur bile acmaz');

      await service.refresh();
      expect(
        updated,
        StudyHomeWidget.values
            .where((widget) => widget.isPublished)
            .map((widget) => widget.androidName)
            .toList(),
      );
    });

    test('iki enum ayni yayin bayragini okur', () {
      for (final widget in StudyHomeWidget.values) {
        expect(
          widget.isPublished,
          isHomeWidgetPublished(widget.catalogProvider),
          reason: '${widget.androidName} iki listede ayrisiyor',
        );
        expect(widget.androidName, widget.catalogProvider.androidClassName);
      }
    });
  });
}

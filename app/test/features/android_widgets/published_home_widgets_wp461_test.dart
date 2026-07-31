// WP-461: Yayında yalnız 1×1 Başlat/Durdur widget'ı görünür.
//
// Tuzak (kartta yazılı): beş widget'ı silmek ya da yeniden tasarlamak. Bu
// yüzden testler "yok mu" diye değil, **dormant mı** diye bakar: sağlayıcı
// sınıfı, xml tanımı ve manifest kaydı yerinde durmalı; yalnız yayından
// düşürülmüş olmalı.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
    test('yayında tek widget var: 1×1 sayaç', () {
      expect(publishedHomeWidgets, [HomeWidgetProvider.timer]);
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
    test('yalnız sayaç sağlayıcısı etkin', () {
      final timer = _receiverHeader(
        HomeWidgetProvider.timer.androidClassName,
      );
      expect(
        timer.contains('android:enabled="false"'),
        isFalse,
        reason: 'yayındaki widget kapatılmış',
      );

      for (final provider in HomeWidgetProvider.values) {
        if (provider == HomeWidgetProvider.timer) continue;
        final header = _receiverHeader(provider.androidClassName);
        expect(
          header.contains('android:enabled="false"'),
          isTrue,
          reason: '${provider.androidClassName} hâlâ picker\'da görünür',
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

  test('katalog ekranı allowlist bayrağını okuyor', () {
    final source = File('lib/features/clock/clock_widgets_screen.dart')
        .readAsStringSync()
        .replaceAll('\r\n', '\n');
    expect(source.contains('isHomeWidgetPublished'), isTrue);
    expect(
      source.contains('HomeWidgetProvider.timer'),
      isTrue,
      reason: 'sayaç kartı allowlist üzerinden çizilmeli',
    );
  });
}

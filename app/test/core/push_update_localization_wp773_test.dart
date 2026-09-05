import 'dart:io';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/app_push_notification_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-773 (sahip, cihazda, v77): uygulama Ingilizceyken "guncelleme geldi"
/// bildirimi Turkce dustu. Sebep: `release.yml` `enqueue_update`ye sabit
/// Turkce `title`/`body` gonderiyor, dispatcher `update` tipini
/// yerellestirmiyor, uygulama da payload metnini oldugu gibi gosteriyordu.
void main() {
  test('surum bildirimi cihaz dilinde kurulur, payload metni okunmaz', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final tr = lookupAppLocalizations(const Locale('tr'));
    final data = <String, dynamic>{
      'notification_type': 'update',
      'title': 'Odak Kampı güncellendi',
      'body': 'Yeni sürüm indirilmeye hazır.',
      'version_name': '1.0.78',
    };

    final english = localizedUpdatePush(en, data);
    expect(english.title, 'Focus Camp updated');
    expect(english.body, 'Version 1.0.78 is ready to download.');
    expect(english.title, isNot(contains('güncellendi')));

    final turkish = localizedUpdatePush(tr, data);
    expect(turkish.title, 'Odak Kampı güncellendi');
    expect(turkish.body, '1.0.78 sürümü indirilmeye hazır.');

    expect(
      localizedUpdatePush(en, <String, dynamic>{'version_name': '  '}).body,
      'A new version is ready to download.',
    );
  });

  test('showRemote `update` tipinde yerel metni KULLANIR', () {
    final source = File(
      'lib/core/notifications/app_push_notification_service.dart',
    ).readAsStringSync();
    final showRemote = source.substring(source.indexOf('showRemote('));
    expect(showRemote, contains("if (type == 'update')"));
    expect(showRemote, contains('localizedUpdatePush(l10n, message.data)'));
    // Yerellestirme, bos-icerik kapisindan ONCE olmali; yoksa bos payload
    // yerel metni hic ureteme firsati bulamadan doner.
    expect(
      showRemote.indexOf('localizedUpdatePush('),
      lessThan(showRemote.indexOf('if (title.isEmpty && body.isEmpty) return;')),
    );
  });

  /// 🔴 WP-779 — WP-773'un kapattigi kusur BASKA BIR KAPIDAN aciktı.
  ///
  /// `loadSystemLocalizations()` `activeAppLocale` adli bir global degiskeni
  /// okur. Arka plan isolate'i AYRI bir bellek alanidir: orada o global hic
  /// tohumlanmaz ve dil CIHAZIN diline duser. Surum bildirimi tam da uygulama
  /// KAPALIYKEN gelir, yani HER ZAMAN o yoldan gecer.
  ///
  /// Sonuc: uygulamasini Ingilizce yapmis ama cihazi Turkce olan kullanici
  /// bildirimi Turkce alirdi. Metin yerellestirilmis olmasi yetmez, DOGRU
  /// dilde yerellestirilmesi gerekir.
  ///
  /// Bu iddia kaynak metnini olcer, cunku dogru yolun secildigi ancak
  /// gercek bir arka plan isolate'inde kosarak gozlemlenebilirdi.
  test('showRemote dili CIHAZDAN degil KULLANICI TERCIHINDEN okur', () {
    final source = File(
      'lib/core/notifications/app_push_notification_service.dart',
    ).readAsStringSync();
    // 🔴 Kapsam YALNIZ `showRemote` govdesi. Ayni dosyadaki `showNudge`
    // hala `loadSystemLocalizations()` kullanir ve bu DOGRUDUR: durtme
    // bildirimi on planda uretilir, orada `activeAppLocale` tohumlanmistir.
    // Dosyanin tamamina bakan bir iddia, dogru olani yanlis sanip kirmizi
    // yanardi.
    final start = source.indexOf('showRemote(');
    final body = source.substring(
      start,
      source.indexOf('Future<void> showNudge(', start),
    );
    // Yorum satirlari elenir: bu duzeltmeyi ACIKLAYAN yorum, yasakli cagrinin
    // adini ANMAK zorunda. Yorumu kod sanan bir iddia, kendi gerekcesini
    // ihlal sayardi.
    final showRemote = body
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      showRemote,
      contains('loadAppLocalizations(prefs)'),
      reason:
          'Diski okumayan bir yol secilirse arka planda cihaz dili kazanir.',
    );
    expect(
      showRemote,
      isNot(contains('loadSystemLocalizations(')),
      reason:
          'Arka plan isolate`inde `activeAppLocale` bos oldugu icin bu cagri '
          'sessizce cihaz diline duser.',
    );
    // Tercih, dil secilmeden ONCE elde olmali.
    expect(
      showRemote.indexOf('SharedPreferences.getInstance()'),
      lessThan(showRemote.indexOf('loadAppLocalizations(prefs)')),
    );
  });
}

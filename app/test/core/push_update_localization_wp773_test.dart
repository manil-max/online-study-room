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
}

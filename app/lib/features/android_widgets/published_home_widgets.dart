/// WP-461 yayında yalnız 1×1 Başlat/Durdur widget'ını bırakmıştı; WP-695/701
/// geri sayımı ve görev listesini, **WP-707** günlük hedef, grup hedefi,
/// kamp sıralaması ve dijital saati, **WP-726** da WP-718'in minimal sayacını
/// kataloğa aldı. Yayında olmayan tek sağlayıcı `alarm`dır (tazeleme yolu yok
/// — bkz. aşağıdaki not).
///
/// Yayından düşürülen sağlayıcı silinmez: sınıfı, layout'u ve
/// `res/xml/*_widget_info.xml` tanımı revizyon için repoda durur.
/// Yayından düşürme tek yerden yapılır:
///
///  * Android tarafı: `AndroidManifest.xml` içinde `android:enabled="false"`.
///  * Flutter tarafı: bu dosyadaki [HomeWidgetCatalogEntry.published] bayrağı.
///
/// İki taraf ayrışırsa katalog kullanıcıya kurulamayacak bir widget vaat eder;
/// sözleşme testi bu ayrışmayı yakalar.
library;

import 'package:flutter/foundation.dart';

/// Android tarafındaki sağlayıcı sınıf adı (manifest'teki `.widgets.<name>`).
enum HomeWidgetProvider {
  timer('TimerWidgetProvider'),

  /// WP-718/WP-726 — yalnız süreyi gösteren, tüm yüzeyi başlat/durdur olan sayaç.
  minimalTimer('MinimalTimerWidgetProvider'),
  studyStats('StudyStatsWidgetProvider'),
  groupGoal('GroupGoalWidgetProvider'),
  groupLeaderboard('GroupLeaderboardWidgetProvider'),
  clock('ClockWidgetProvider'),
  alarm('AlarmWidgetProvider'),

  /// WP-695 — sınav geri sayımı. Yayında olan **ikinci** widget.
  countdown('CountdownWidgetProvider'),

  /// WP-701 — görev listesi; satırları ana ekrandan işaretlenir.
  task('TaskWidgetProvider');

  const HomeWidgetProvider(this.androidClassName);

  final String androidClassName;
}

@immutable
class HomeWidgetCatalogEntry {
  const HomeWidgetCatalogEntry({
    required this.provider,
    required this.published,
  });

  final HomeWidgetProvider provider;

  /// `false` ise widget dormant'tır: kodu durur, kullanıcıya sunulmaz.
  final bool published;
}

/// Katalogda **her** widget listelenir; yalnız `published` olanlar gösterilir.
const List<HomeWidgetCatalogEntry> kHomeWidgetCatalog = [
  HomeWidgetCatalogEntry(provider: HomeWidgetProvider.timer, published: true),
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.minimalTimer,
    published: true,
  ),
  // WP-707: gunluk hedef widget'i. Yayina alinmasinin sarti seri satirinin
  // gercek veriye baglanmasiydi (`_syncStatsWidgets` -> `stats_streak`);
  // baglanmadan yayina alinsaydi kullanici widget'i buyutunce serisini HEP
  // 0 gorurdu.
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.studyStats,
    published: true,
  ),
  // WP-707: grup hedefi. Verisi `AndroidWidgetSnapshot.goals` icindeki
  // `groupGoalGroup` anahtarlarindan gelir (WP-696 ezme kusuru kapali).
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.groupGoal,
    published: true,
  ),
  // WP-707: kamp siralamasi. Verisi `AndroidWidgetSnapshot.leaderboard`ten.
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.groupLeaderboard,
    published: true,
  ),
  // WP-707: dijital saat. Cizimi native akar (`TextClock`), Flutter'dan veri
  // ISTEMEZ; bu yuzden `StudyHomeWidget` uyesi degil, `kSelfUpdatingHomeWidgets`
  // uyesidir.
  HomeWidgetCatalogEntry(provider: HomeWidgetProvider.clock, published: true),
  // WP-707: alarm BILEREK yayinda degil. Tek tazeleme kaynagi
  // `odak_alarm_widget_info.xml`'deki 30 dakikalik `updatePeriodMillis`;
  // kullanici alarm kurunca widget 30 dakikaya kadar bayat kalir
  // (`hidden_widgets_wp696_test.dart` bunu iddia olarak tutuyor).
  HomeWidgetCatalogEntry(provider: HomeWidgetProvider.alarm, published: false),
  // WP-695: kullanıcı isteği ("bunun widget hâli de gelsin"). Manifest'teki
  // receiver `enabled` bayrağı taşımaz — iki taraf aynı yerde durur.
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.countdown,
    published: true,
  ),
  // WP-701: kullanıcı isteği ("task widget'ında yaptıklarını oradan
  // işaretleseler güzel olur"). Manifest'teki receiver `enabled` bayrağı
  // taşımaz — iki taraf aynı yerde durur.
  HomeWidgetCatalogEntry(provider: HomeWidgetProvider.task, published: true),
];

/// Yayındaki widget'lar — katalog ekranı ve sözleşme testi bunu okur.
List<HomeWidgetProvider> get publishedHomeWidgets => [
  for (final entry in kHomeWidgetCatalog)
    if (entry.published) entry.provider,
];

bool isHomeWidgetPublished(HomeWidgetProvider provider) =>
    publishedHomeWidgets.contains(provider);

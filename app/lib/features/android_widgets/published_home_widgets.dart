/// WP-461: Yayında **yalnız 1×1 Başlat/Durdur** ana ekran widget'ı vardır.
///
/// Diğer beş widget silinmedi: sağlayıcı sınıfları, layout'ları ve
/// `res/xml/*_widget_info.xml` tanımları revizyon için repoda duruyor.
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
  studyStats('StudyStatsWidgetProvider'),
  groupGoal('GroupGoalWidgetProvider'),
  groupLeaderboard('GroupLeaderboardWidgetProvider'),
  clock('ClockWidgetProvider'),
  alarm('AlarmWidgetProvider');

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
    provider: HomeWidgetProvider.studyStats,
    published: false,
  ),
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.groupGoal,
    published: false,
  ),
  HomeWidgetCatalogEntry(
    provider: HomeWidgetProvider.groupLeaderboard,
    published: false,
  ),
  HomeWidgetCatalogEntry(provider: HomeWidgetProvider.clock, published: false),
  HomeWidgetCatalogEntry(provider: HomeWidgetProvider.alarm, published: false),
];

/// Yayındaki widget'lar — katalog ekranı ve sözleşme testi bunu okur.
List<HomeWidgetProvider> get publishedHomeWidgets => [
  for (final entry in kHomeWidgetCatalog)
    if (entry.published) entry.provider,
];

bool isHomeWidgetPublished(HomeWidgetProvider provider) =>
    publishedHomeWidgets.contains(provider);

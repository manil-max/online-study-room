import 'package:flutter/widgets.dart';

import '../../core/tour/tour_models.dart';
import '../../l10n/app_localizations.dart';

/// WP-324: ürün yüzeylerinin kısa, sürümlü ve yerelleştirilmiş tur içerikleri.
///
/// Motor [TourDefinition] dışında ürün bilgisi taşımaz. Böylece metin, boş
/// durum ve hedef seçimi feature katmanında kalır.
abstract final class AppTours {
  /// Ana ekran turu — **tek adım**.
  ///
  /// 🔴 WP-417 (sahip cihaz testi): *"sadece edit kısmını gösterelim."* Genel
  /// bakış adımı ve arkasından zincirlenen sayaç turu kaldırıldı.
  /// WP-488: adım **çapasız**. Düzenle butonu kaldırıldığı için gösterilecek
  /// bir hedef yok; `TourStep.anchor` null iken balon ekranın ortasında
  /// hedefsiz çizilir.
  ///
  /// 🔴 WP-837 (sürüm 3 → 4, sahip): balon ekranın **ne olduğunu** söylesin,
  /// tek bir eylemi (sayacı başlat) değil. WP-799'un `isEmpty` çatalı da
  /// düştü: tek cümle iki durumda da doğru — pano boşken "kart ekle",
  /// doluyken "yerlerini değiştir" aynı cümlenin içinde. Sürüm artışı şart,
  /// metin değişti.
  static TourDefinition home(AppLocalizations l10n) => TourDefinition(
    id: 'home',
    version: 4,
    steps: [
      TourStep(
        id: 'overview',
        title: l10n.homeAnaSayfa,
        text: l10n.tourHomeOverview,
      ),
    ],
  );

  /// Pano düzenleme modu turu — **tek adım**, WP-837 (sahip).
  ///
  /// Karta uzun basınca açılan mod bugüne dek hiç tanıtılmıyordu: kullanıcı
  /// kendini ızgaralı, tutamaçlı bir ekranın içinde buluyordu. Balon çapasız:
  /// mod ekranın tamamını değiştiriyor, işaret edilecek tek bir öğe yok.
  static TourDefinition dashboardEdit(AppLocalizations l10n) => TourDefinition(
    id: 'dashboard_edit',
    version: 1,
    steps: [
      TourStep(
        id: 'arrange',
        title: l10n.homePanoyuDuzenle,
        text: l10n.tourDashboardEditOverview,
      ),
    ],
  );

  /// İstatistik turu — **tek adım**, WP-837 (sahip).
  ///
  /// 🔴 Sürüm **2**'den başlar, 1'den değil. `stats.v1` tarihte gerçekten
  /// kullanıldı (WP-324 dönem tanıtımı) ve WP-417'de kaldırıldı; o turu görmüş
  /// kullanıcının cihazında `tour.stats.v1.<uid>` anahtarı hâlâ duruyor. v1
  /// denseydi bu WP'nin balonu tam da eski kullanıcılara hiç görünmezdi.
  static TourDefinition stats(AppLocalizations l10n) => TourDefinition(
    id: 'stats',
    version: 2,
    steps: [
      TourStep(
        id: 'overview',
        title: l10n.statsIstatistik,
        text: l10n.tourStatsOverview,
      ),
    ],
  );

  static TourDefinition groups(
    AppLocalizations l10n, {
    required GlobalKey contentAnchor,
    required GlobalKey switcherAnchor,
    required bool hasGroup,
  }) => TourDefinition(
    id: 'groups',
    version: 1,
    steps: [
      TourStep(
        id: hasGroup ? 'overview' : 'empty',
        title: l10n.desktopGruplar,
        text: hasGroup ? l10n.tourGroupsOverview : l10n.tourGroupsEmpty,
        anchor: contentAnchor,
      ),
      if (hasGroup)
        TourStep(
          id: 'switch',
          title: l10n.classroomGrupDegistir,
          text: l10n.tourGroupsSwitch,
          anchor: switcherAnchor,
        ),
    ],
  );

  static TourDefinition campfire(
    AppLocalizations l10n, {
    required GlobalKey? campfireAnchor,
    required bool hasGroup,
  }) => TourDefinition(
    id: 'campfire',
    version: 1,
    steps: [
      TourStep(
        id: hasGroup ? 'overview' : 'empty',
        title: l10n.coreKampAtesi,
        text: hasGroup ? l10n.tourCampfireOverview : l10n.tourCampfireEmpty,
        // Grup yokken sahnede bulunmayan bir öğeyi işaretleme.
        anchor: hasGroup ? campfireAnchor : null,
      ),
    ],
  );

  // 🔴 WP-417: istatistik **dönem** tanıtımı kaldırılmıştı (sahip isteğini geri
  // aldı). WP-837'de geri gelen şey o değil: dönem seçicisini işaret eden
  // çapalı adım değil, ekranın ne olduğunu söyleyen tek çapasız balon.
  // Tanımı için yukarıdaki [stats].

  static TourDefinition profile(
    AppLocalizations l10n, {
    required GlobalKey identityAnchor,
    required GlobalKey actionsAnchor,
  }) => TourDefinition(
    id: 'profile',
    version: 1,
    steps: [
      TourStep(
        id: 'identity',
        title: l10n.profileProfil,
        text: l10n.tourProfileOverview,
        anchor: identityAnchor,
      ),
      TourStep(
        id: 'actions',
        title: l10n.profileAyarlar,
        text: l10n.tourProfileActions,
        anchor: actionsAnchor,
      ),
    ],
  );
}

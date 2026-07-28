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
  /// bakış adımı ve arkasından zincirlenen sayaç turu kaldırıldı; ana ekranda
  /// artık yalnız kartları düzenleme düğmesi tanıtılır. Boş panoda metin aynı,
  /// başlık kullanıcının o an gördüğü duruma göre değişir.
  static TourDefinition home(
    AppLocalizations l10n, {
    required GlobalKey editAnchor,
    required bool isEmpty,
  }) => TourDefinition(
    id: 'home',
    version: 1,
    steps: [
      TourStep(
        id: 'edit',
        title: isEmpty ? l10n.homeAnaSayfanBos : l10n.homeKartlariDuzenle,
        text: l10n.tourHomeEdit,
        anchor: editAnchor,
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

  // 🔴 WP-417: istatistik dönem tanıtımı **tamamen kaldırıldı**. Sahip bunu
  // v55'te kendisi istemişti, cihazda görünce isteğini geri aldı. Tur tanımı,
  // ekrandaki çıpası ve dört dildeki metin anahtarları birlikte silindi;
  // yarısı duran bir tur ölü anahtar bırakır.

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

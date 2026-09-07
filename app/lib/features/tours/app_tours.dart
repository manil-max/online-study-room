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
  /// 🔴 WP-799 (sürüm 2 → 3): onboarding'in hemen ardından yeni kullanıcıya
  /// söylenen İLK cümle *"Karta uzun bas: düzenleme açılır"* idi — yani
  /// uygulamanın ilk öğrettiği şey kart düzenlemekti. WP-417 sayaç turunu
  /// kaldırırken yerine bir şey koymamıştı; onboarding'in son sayfası ise
  /// zaten *"Ana sayfada sayacı başlatarak…"* diyordu. Balon artık o cümleyi
  /// sürdürür (*Hazırsın → Sayacı başlat*) ve sayaç varsayılan panonun ilk
  /// kartıdır (`defaultDashboardLayout`), yani işaret ettiği şey gerçekten
  /// orada. Sürüm artışı şart: metin davranışı değişti, turu bir kez daha
  /// görmek doğrudur.
  ///
  /// Metinler MEVCUT anahtarlardan seçildi (bu WP `l10n/**`e dokunmuyor) ve
  /// balon iki satır sınırına uymak zorunda (`app_tours_test.dart`):
  /// `onboardingReadyBody` üç satıra taşıyordu, ölçülüp elendi.
  ///
  /// [isEmpty] ölü bir anahtar değil: pano boşken ekranda sayaç kartı YOKTUR
  /// (`home_screen.dart` `_EmptyDashboard`), o yüzden o dalda balon kart
  /// eklemeyi söyler — ekranın kendi düğmesiyle aynı sözü.
  static TourDefinition home(
    AppLocalizations l10n, {
    required bool isEmpty,
  }) => TourDefinition(
    id: 'home',
    version: 3,
    steps: [
      TourStep(
        id: isEmpty ? 'add' : 'start',
        title: isEmpty ? l10n.homeAnaSayfanBos : l10n.onboardingReadyTitle,
        text: isEmpty ? l10n.homeKartEkle : l10n.statsKisiselBosEylem,
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

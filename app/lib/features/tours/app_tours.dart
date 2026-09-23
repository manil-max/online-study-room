import 'package:flutter/widgets.dart';

import '../../core/tour/tour_models.dart';
import '../../l10n/app_localizations.dart';

/// WP-324: ürün yüzeylerinin sürümlü ve yerelleştirilmiş tur içerikleri.
///
/// Motor [TourDefinition] dışında ürün bilgisi taşımaz. Böylece metin, boş
/// durum ve hedef seçimi feature katmanında kalır.
///
/// 🔴 WP-920 (sahip, bu dosyadaki eski "kısa tut" kararlarının ÜSTÜNDE):
/// *"kartlardaki bilgiler çok az, hiçbir şeyi anlatmıyor … çok karta gerek
/// yok, karttaki bilgileri arttır; ekrana yetmezse yeni kart ekle."*
/// Kart SAYISI değişmedi; her kartın gövdesi ekranın ne olduğunu, orada ne
/// yapılabildiğini ve nasıl yapıldığını anlatan birkaç cümle oldu. Her iddia
/// koddan doğrulandı (ekran dosyaları her tanımın yorumunda). Metin değiştiği
/// için **her turun sürümü bir arttı** — eski turu görmüş kullanıcı yenisini
/// bir kez görür. Kapılar: `app_tours_test.dart` (satır/karakter tavanı ve
/// alt sınırı), `rich_tours_wp920_test.dart` (320×568, yazı ölçeği 2.0).
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
  ///
  /// WP-920 (sürüm 4 → 5): tek kart kaldı ama artık panoyu, sayaç kartını
  /// (ders + mod seçimi, "Çalışmaya başla", hedefe dokunup değiştirme —
  /// `classroom/widgets/study_timer_card.dart`) ve uzun basınca açılan
  /// düzenlemeyi (`home_screen.dart` `_MatrixCard.onLongPress`) anlatıyor.
  static TourDefinition home(AppLocalizations l10n) => TourDefinition(
    id: 'home',
    version: 5,
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
  ///
  /// WP-920 (sürüm 1 → 2): taşıma (`LongPressDraggable`), köşe tutamaçları ve
  /// alttaki −/+ boyut paneli, kırmızı "Kaldır", üst şeritteki "+ Kart ekle",
  /// otomatik kayıt (`dashboardLayoutProvider.setBounds(persist: true)`) ve
  /// "Bitti" (✓) ile çıkış — hepsi `home_screen.dart` içinde.
  static TourDefinition dashboardEdit(AppLocalizations l10n) => TourDefinition(
    id: 'dashboard_edit',
    version: 2,
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
  ///
  /// WP-920 (sürüm 2 → 3, yine ileri — hiçbir zaman geri ya da atlanmış bir
  /// numaraya değil): dönem çipleri (`stats_period_bar.dart`), oklar ve
  /// başlıktan tarih seçme (`stats_range_navigator.dart`), Kişisel/Grup
  /// sekmeleri ve rekorların yalnız "Tümü"de çıkması
  /// (`personal_period_cards.dart` `showRecords`).
  static TourDefinition stats(AppLocalizations l10n) => TourDefinition(
    id: 'stats',
    version: 3,
    steps: [
      TourStep(
        id: 'overview',
        title: l10n.statsIstatistik,
        text: l10n.tourStatsOverview,
      ),
    ],
  );

  /// Ayarlar turu — **iki adım**, WP-849 (sahip).
  ///
  /// Sahip "tek kart; sığmazsa 2. kart olabilir" dedi. Anlatılacak üç yer var
  /// (görünüm, izinler, hesap/veri dışa aktarma) ve üçü tek balonun iki satır
  /// kapısına (`app_tours_test.dart`) sığmadı; bu yüzden iki balon. Çapasız:
  /// Ayarlar masaüstünde de mobilde de farklı dizilir, işaret edilecek sabit
  /// bir öğe yok.
  ///
  /// WP-920 (sürüm 1 → 2): iki kart kaldı — bölümler (Görünüm, Bildirimler,
  /// İzinler, Hesap, Gizlilik, Hakkında, Yardım; `settings_screen.dart`) tek
  /// balonun satır tavanına sığmıyor. İkinci kartın başlığı artık yalnız
  /// "Hesap" değil, anlattığı üç bölümün adı.
  static TourDefinition settings(AppLocalizations l10n) => TourDefinition(
    id: 'settings',
    version: 2,
    steps: [
      TourStep(
        id: 'overview',
        title: l10n.profileAyarlar,
        text: l10n.tourSettingsOverview,
      ),
      TourStep(
        id: 'account',
        title: l10n.tourSettingsMoreTitle,
        text: l10n.tourSettingsAccount,
      ),
    ],
  );

  /// WP-920 (sürüm 1 → 2): grup odasının içeriği (kamp ateşi, kamp hayvanı,
  /// grup hedefi, sıralama, trend; başlıktaki sohbet ve dişli — dişli davet
  /// kodunu taşıyan `ClassDetailScreen`'i açar) ve değiştiricinin aynı
  /// menüdeki oluştur/katıl/keşfet seçenekleri (`class_switcher.dart`).
  static TourDefinition groups(
    AppLocalizations l10n, {
    required GlobalKey contentAnchor,
    required GlobalKey switcherAnchor,
    required bool hasGroup,
  }) => TourDefinition(
    id: 'groups',
    version: 2,
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

  /// WP-920 (sürüm 1 → 2): çalışanın parlak, diğerlerinin soluk çizilmesi,
  /// yerel saate bağlı gök ve hayvana dokununca açılan kampçı sayfası (bugünkü
  /// süre, seri, profil, dürtme) — `classroom/widgets/campfire_scene.dart`.
  static TourDefinition campfire(
    AppLocalizations l10n, {
    required GlobalKey? campfireAnchor,
    required bool hasGroup,
  }) => TourDefinition(
    id: 'campfire',
    version: 2,
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

  /// WP-920 (sürüm 1 → 2): fotoğraf/ad düzenleme, Başarılar kartı (taç, XP,
  /// rozetler; `profile/widgets/gamification_card.dart`), çalışma kayıtları
  /// ve Ayarlar satırları (`profile_screen.dart`).
  static TourDefinition profile(
    AppLocalizations l10n, {
    required GlobalKey identityAnchor,
    required GlobalKey actionsAnchor,
  }) => TourDefinition(
    id: 'profile',
    version: 2,
    steps: [
      TourStep(
        id: 'identity',
        title: l10n.profileProfil,
        text: l10n.tourProfileOverview,
        anchor: identityAnchor,
      ),
      TourStep(
        id: 'actions',
        title: l10n.tourProfileActionsTitle,
        text: l10n.tourProfileActions,
        anchor: actionsAnchor,
      ),
    ],
  );
}

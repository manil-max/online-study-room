import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/animals/camp_animal.dart';
import '../../core/l10n/app_locale.dart';
import '../../core/stats/istanbul_calendar.dart';
import '../../core/tour/tour_controller.dart';
import '../../core/utils/duration_format.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/admin_providers.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../admin/admin_screen.dart';
import '../desktop/desktop_page_scaffold.dart';
import '../home/dday_prefs.dart';
import '../notifications/announcements_screen.dart';
import 'widgets/unread_announcement_dot.dart';
import '../notifications/notification_permissions_screen.dart';
import '../onboarding/onboarding_prefs.dart';
import '../safety/blocked_users_screen.dart';
import '../safety/muted_nudges_screen.dart';
import '../support/faq_screen.dart';
import 'about_screen.dart';
import 'account_settings_screen.dart';
import 'appearance_screen.dart';
import 'data_export_screen.dart';
import 'feedback_screen.dart';
import 'widgets/camp_animal_picker.dart';
import 'widgets/goal_editor_dialog.dart';
import 'widgets/unread_message_badge.dart';

/// Ayarlar: davranışları değiştirmeden, bulunabilir bilgi mimarisi sunar.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.embedded = false});

  /// Desktop master-detail içinde gömülü: AppBar yok (WP-53).
  final bool embedded;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Seçim anında (realtime beklemeden) tile'ı güncellemek için optimistik id.
  String? _animalOverride;

  /// WP-686 — masaustu master-detay dalinda secili ayar bolumu.
  ///
  /// `null` = ilk bolum. Yalniz kap >= [kSettingsMasterDetailBand] iken
  /// anlamlidir; akan sutun dalinda yedi bolumun hepsi zaten cizilir.
  String? _selectedSectionId;

  Future<void> _pickAnimal() async {
    final profile = ref.read(authStateProvider).value;
    if (profile == null) return;
    final currentId = _animalOverride ?? profile.animal;
    final shownId = campAnimalFor(userId: profile.id, animalId: currentId).id;

    final picked = await showCampAnimalPicker(context, currentId: shownId);
    if (picked == null || picked == currentId || !mounted) return;

    // 🔴 WP-610: burada hic `try` yoktu. Ag/sunucu hatasinda yazma
    // dusuyor, istisna global yutucuya (`observability_service.dart`
    // `onError`) gidiyor ve kullanici NE hata NE onay goruyordu. Ustelik
    // hemen alttaki `setState` de calismadigi icin secim ekranda bile
    // gorunmuyordu. Dogru desen ayni depoda zaten var:
    // `social_profile_screen.dart` `_setTitle` -- `catch (_)` + mesaj.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).updateAnimal(picked);
      ref.invalidate(groupMembersProvider);
      if (!mounted) return;
      setState(() => _animalOverride = picked);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileKampHayvaniGuncellendi)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileKampHayvaniKaydedilemedi)),
      );
    }
  }

  /// WP-555: gunluk hedef uygulamada **tek** noktadan (sayac karti) degistirilebiliyordu
  /// ve Ayarlar'da `goal` kelimesi hic gecmiyordu. Diyalog yeniden yazilmadi;
  /// `showGoalEditorDialog` ayni sinirlarla (en az 15 dk, 0-23 sa / 0-59 dk)
  /// paylasilan yerinden cagriliyor.
  Future<void> _editDailyGoal(int currentMinutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final result = await showGoalEditorDialog(
      context,
      initialMinutes: currentMinutes,
    );
    if (result == null || !mounted) return;
    // 🔴 WP-610: yakalama dali `on AuthException` idi; oysa
    // `updateDailyGoal` bu turu HIC atmaz -- ag/sunucu hatasi
    // `PostgrestException` / `ClientException` olarak gelir ve dalin
    // yanindan gecip global yutucuya giderdi. Gunluk hedef seriyi ve
    // ilerleme halkasini besledigi icin sessiz kayip istatistigi de yanlis
    // gosteriyordu.
    try {
      await ref.read(authRepositoryProvider).updateDailyGoal(result);
      ref.invalidate(authStateProvider);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileGunlukHedefGuncellendi)),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.profileGunlukHedefKaydedilemedi)),
      );
    }
  }

  /// WP-575: sınav tarihi **tek** noktadan (Ayarlar) ayarlanır; pano kartı
  /// yalnız okur.
  ///
  /// 🔴 WP-632 bunu değiştirdi: asıl düzenleme artık **kartın kendisinde**
  /// (en fazla üç sınav, ad, sıra, öne çıkarma). Bu satır yine de duruyor ve
  /// çalışıyor — `docs/URUN-POLITIKALARI.md` §1 regresyon politikası gereği
  /// kullanıcının bildiği yol kaybolmaz. Buradan yalnız **öne çıkan** (yoksa
  /// ilk) sınavın tarihi değiştirilir; hiç kayıt yoksa ilkini oluşturur.
  Future<void> _pickExamDate() async {
    final today = istanbulDay(ref.read(ddayClockProvider)());
    final initial = ref.read(examDateProvider) ?? today;
    // `showDatePicker`, `initialDate` aralığın dışına düşerse assert ile çöker.
    // Kayıtlı sınav tarihi geçmişte kaldığında (geri sayım bittiğinde) bu
    // kolayca olur, o yüzden sınırlar seçili tarihi kapsayacak şekilde açılır.
    var first = DateTime(today.year - 1, 1, 1);
    var last = DateTime(today.year + 10, 12, 31);
    if (initial.isBefore(first)) first = initial;
    if (initial.isAfter(last)) last = initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    final list = ref.read(examListProvider);
    final target =
        list.priority ?? (list.entries.isEmpty ? null : list.entries.first);
    if (target == null) {
      await ref.read(examListProvider.notifier).add(name: '', day: picked);
    } else {
      await ref.read(examListProvider.notifier).update(target.id, day: picked);
    }
  }

  /// Ayarlardaki temizle düğmesi: yalnız hedef kaydı siler, listedeki diğer
  /// sınavlara dokunmaz.
  Future<void> _clearExamDate() async {
    final list = ref.read(examListProvider);
    final target =
        list.priority ?? (list.entries.isEmpty ? null : list.entries.first);
    if (target == null) return;
    await ref.read(examListProvider.notifier).remove(target.id);
  }

  Future<void> _resetTours() async {
    await ref.read(tourControllerProvider.notifier).resetAll();
    await ref.read(onboardingCompletedProvider.notifier).reset();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).profileTanitimTurlariSifirlandi,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(appLanguageProvider);
    final profile = ref.watch(authStateProvider).value;
    final isAdmin = ref.watch(adminIsSuperAdminProvider).value ?? false;
    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final examDate = ref.watch(examDateProvider);
    final unreadAnnouncements = ref.watch(unreadAnnouncementCountProvider);
    // WP-421: zincirin ikinci halkasi.
    final unreadReplies =
        ref.watch(unreadFeedbackReplyCountProvider).value ?? 0;
    final animal = profile == null
        ? null
        : campAnimalFor(
            userId: profile.id,
            animalId: _animalOverride ?? profile.animal,
          );

    // 🔴 WP-679 — burasi `DesktopReadingBody(maxWidth: 760)` idi: masaustunde
    // TEK sutun, ortalanmis. Olcum (2026-08-10, `WP679 | AYARLAR-PANEL`):
    // icerik 1920 px pencerede de 2560 px pencerede de **772 px** cizildi ve
    // dikeyde 680 px'lik panele altI bolum sigmadigi icin ekran uzun bir
    // mobil kaydirmaya donuyordu. Ayni bolumler artik kabin genisligine gore
    // 1/2/3 sutuna akar (SPEC §3 A2) — bkz. [ProfileFlowColumns].
    //
    // 🔴 WP-686: ayni yedi bolum artik IKI duzen dalinda birden cizilir
    // (akan sutunlar ve master-detay), o yuzden once VERI olarak toplanir.
    // Iki dal da bu listeyi okur — bir bolumu birinde ekleyip otekinde
    // unutmak mumkun degil.
    final categories = <_SettingsCategory>[
      _SettingsCategory(
        id: 'appearance',
        icon: Icons.palette_outlined,
        title: l10n.settingsSectionAppearance,
        cards: [
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.color_lens_outlined),
              title: Text(l10n.profileGorunumVeAtmosferTemalari),
              subtitle: Text(l10n.profileGorunumVeAtmosfer),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => AppearanceScreen())),
            ),
          ),
          _SettingsCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: DropdownButtonFormField<AppLanguage>(
                key: ValueKey(language),
                initialValue: language,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.profileUygulamaDili,
                  helperText: l10n.profileDilDegisikligiAnindaUygulanir,
                  prefixIcon: const Icon(Icons.language_outlined),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: AppLanguage.system,
                    child: Text(l10n.profileDilSistemVarsayilani),
                  ),
                  DropdownMenuItem(
                    value: AppLanguage.turkish,
                    child: Text(l10n.profileDilTurkce),
                  ),
                  DropdownMenuItem(
                    value: AppLanguage.english,
                    child: Text(l10n.profileDilIngilizce),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(appLanguageProvider.notifier).setLanguage(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
      _SettingsCategory(
        id: 'notifications',
        icon: Icons.notifications_outlined,
        title: l10n.settingsSectionNotifications,
        cards: [
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(l10n.profileBildirimMerkezi),
              subtitle: Text(l10n.profileDurtmeHatirlaticiDuyuruVe),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationPermissionsScreen(),
                ),
              ),
            ),
          ),
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(l10n.notificationsDuyurular),
              subtitle: Text(l10n.notificationsUygulamaVeGrubunaOzel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadAnnouncements > 0) ...[
                    UnreadAnnouncementDot(
                      key: const Key('announcements-unread-dot'),
                      count: unreadAnnouncements,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AnnouncementsScreen()),
              ),
            ),
          ),
        ],
      ),
      _SettingsCategory(
        id: 'account',
        icon: Icons.manage_accounts_outlined,
        title: l10n.settingsSectionAccount,
        cards: [
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.manage_accounts),
              title: Text(l10n.profileHesabimiYonet),
              subtitle: Text(l10n.profileEpostaSifreVeGuvenli),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AccountSettingsScreen()),
              ),
            ),
          ),
          // WP-514: sayaç tanılama kaydı buradan **Hakkında**'daki gizli
          // geliştirici bölümüne taşındı. Normal kullanıcı için Hesap
          // bölümünde anlamı yoktu; kayıt hâlâ her cihazda tutuluyor ve
          // sürüm satırına yedi kez dokununca okunabiliyor.
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.download_outlined),
              title: Text(l10n.exportMyData),
              subtitle: Text(l10n.exportMyDataSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DataExportScreen()),
              ),
            ),
          ),
          if (isAdmin)
            _SettingsCard(
              child: ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: Text(l10n.profileYonetim),
                subtitle: Text(l10n.profileOzetlerVeKullaniciRaporlari),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => AdminScreen())),
              ),
            ),
        ],
      ),
      _SettingsCategory(
        id: 'study',
        icon: Icons.school_outlined,
        title: l10n.settingsSectionStudyPreferences,
        cards: [
          _SettingsCard(
            child: ListTile(
              key: const Key('settings-daily-goal'),
              leading: const Icon(Icons.flag_outlined),
              title: Text(l10n.profileGunlukHedef),
              // Deger `activeAppLocale` global'i yerine ekranin kendi
              // dilinden turetilir; ayni satir iki dilde de dogru okur.
              subtitle: Text(
                formatHumanForLocale(goalMinutes * 60, l10n.localeName),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: profile == null ? null : () => _editDailyGoal(goalMinutes),
            ),
          ),
          _SettingsCard(
            child: ListTile(
              key: const Key('settings-exam-date'),
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.profileSinavTarihi),
              subtitle: Text(
                examDate == null
                    ? l10n.homeSinavTarihiSecilmedi
                    : MaterialLocalizations.of(
                        context,
                      ).formatFullDate(examDate),
              ),
              // Seçilen tarih **geri alınabilir** olmalı: iptal edilen
              // bir tarih seçici ile "temizle" ayırt edilemez, bu yüzden
              // silme ayrı bir eylemdir.
              trailing: examDate == null
                  ? const Icon(Icons.chevron_right)
                  : IconButton(
                      key: const Key('settings-exam-date-clear'),
                      tooltip: l10n.profileSinavTarihiniTemizle,
                      icon: const Icon(Icons.close),
                      onPressed: _clearExamDate,
                    ),
              onTap: _pickExamDate,
            ),
          ),
          _SettingsCard(
            child: ListTile(
              leading: Text(
                animal?.emoji ?? '🦊',
                style: const TextStyle(fontSize: 26),
              ),
              title: Text(l10n.profileKampHayvanin),
              subtitle: Text(
                animal == null
                    ? l10n.profileSeniTemsilEdenHayvani
                    : l10n.profileDegistir,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: profile == null ? null : _pickAnimal,
            ),
          ),
          _SettingsCard(
            child: ListTile(
              key: const Key('reset-introduction-tours'),
              leading: const Icon(Icons.restart_alt_outlined),
              title: Text(l10n.profileTanitimTurlariniSifirla),
              subtitle: Text(l10n.profileTanitimTurlariAciklama),
              onTap: profile == null ? null : _resetTours,
            ),
          ),
        ],
      ),
      _SettingsCategory(
        id: 'privacy',
        icon: Icons.shield_outlined,
        title: l10n.settingsSectionPrivacySecurity,
        cards: [
          _SettingsCard(
            child: ListTile(
              leading: const Icon(Icons.block),
              title: Text(l10n.safetyBlockedUsersTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
              ),
            ),
          ),
          // WP-459: D/WP-444 Faz 2'nin susturma ekrani ayarlarin
          // Guvenlik bolumune baglanir; ekran D'de, giris B'de.
          _SettingsCard(
            child: ListTile(
              key: const Key('settings-muted-nudges'),
              leading: const Icon(Icons.notifications_off_outlined),
              title: Text(l10n.safetyMutedNudgesTitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MutedNudgesScreen()),
              ),
            ),
          ),
        ],
      ),
      _SettingsCategory(
        id: 'about',
        icon: Icons.info_outline,
        title: l10n.settingsSectionAboutLegal,
        cards: [
          _SettingsCard(
            child: ListTile(
              key: const Key('settings-about-updates'),
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.profileSurumVeGuncellemeler),
              subtitle: Text(l10n.aboutSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
          ),
          _SettingsCard(
            child: ListTile(
              key: const Key('settings-feedback'),
              leading: const Icon(Icons.feedback_outlined),
              // WP-420: "Geri bildirim gönder" değil **"Geri bildirim"**
              // — ekran artık hem gönderme hem geçmiş sekmesini taşıyor.
              title: Text(l10n.feedbackTitle),
              subtitle: Text(l10n.profileHataVeyaOneriniBize),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (unreadReplies > 0) ...[
                    UnreadMessageBadge(
                      key: const Key('feedback-row-reply-badge'),
                      count: unreadReplies,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: profile == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                    ),
            ),
          ),
        ],
      ),
      // WP-514: SSS iki kat derindeydi (Ayarlar → Hakkında → SSS) ve
      // sahip bulamıyordu. Kendi "Yardım" bölümüyle Ayarlar'ın **en
      // altında** duruyor — yardım aranan yer listenin sonudur.
      _SettingsCategory(
        id: 'help',
        icon: Icons.help_outline,
        title: l10n.settingsSectionHelp,
        cards: [
          _SettingsCard(
            child: ListTile(
              key: const Key('settings-faq'),
              leading: const Icon(Icons.help_outline),
              title: Text(l10n.faqTitle),
              subtitle: Text(l10n.faqSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const FaqScreen())),
            ),
          ),
        ],
      ),
    ];

    // Yatay kenar boslugu iki dalda da AYNI (16 + 16). Master-detay esigi bu
    // boslugun ICINDEKI kaba gore olculur — panelin dis genisligine gore degil.
    final padding = getSafePadding(
      context,
      const EdgeInsets.fromLTRB(16, 12, 16, 24),
    );

    // SPEC §3 A2 — WP-679'un akan sutun duzeni. Mobil dal ve 1056 px'in
    // altindaki her kap bunu BIREBIR kullanir; tek satiri degismedi.
    Widget flow() => ListView(
      padding: padding,
      children: [
        ProfileFlowColumns(
          sections: [
            for (final category in categories)
              _SettingsSection(title: category.title, children: category.cards),
          ],
        ),
      ],
    );

    // SPEC §3 A1 / §5 — 280 kategori + 16 + 760 detay.
    Widget masterDetail() {
      final selected = categories.firstWhere(
        (category) => category.id == _selectedSectionId,
        orElse: () => categories.first,
      );
      return Padding(
        padding: padding,
        child: ProfileDesktopBody(
          // [kSettingsMasterDetailBand] (1056) bir **esik**tir, tavan degil:
          // satirin sigabilecegi en dar kap. Tavan SPEC §2.3'un izgara
          // toplamidir (1440); arada kalan yeri detay sutunu alir.
          maxWidth: DesktopBreakpoints.maxContentWidth,
          child: DesktopMasterDetail(
            masterWidth: kSettingsMasterWidth,
            spacing: kSettingsPaneSpacing,
            // Iki-pane karari YUKARIDA, KABIN genisligine gore verildi.
            // Widget kendi esigini burada tekrar olcerse `Padding`ten sonra
            // kalan bandi gorur; 1088 px'lik panelde kalan 1056 px, widget'in
            // 1200'luk varsayilan esiginin ALTINDA kalir ve ikinci pane
            // yazilir ama HIC cizilmezdi.
            breakpoint: 0,
            master: DesktopSectionList(
              key: kSettingsMasterListKey,
              items: [
                for (final category in categories)
                  DesktopSectionItem(
                    id: category.id,
                    icon: category.icon,
                    label: category.title,
                  ),
              ],
              selectedId: selected.id,
              onSelected: (id) => setState(() => _selectedSectionId = id),
            ),
            detail: ListView(
              key: kSettingsDetailPaneKey,
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    selected.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                // 🔴 SPEC §5 SAPMASI, GEREKCESI OLCUM. Tablo ayarlari
                // `xlarge`da "large ile ayni" sayar, yani 280 + 16 + 760 =
                // 1056 px'lik sabit bir satir. Olculdu (2026-08-11,
                // `WP686PANEL`): 1920 ve 2560 px pencerede panel 1472, kap
                // 1440 px acilir; 1056'lik sabit satir panelin **384 px**'ini
                // (kabin %27'si) bos birakiyordu — sahibin 2 numarali
                // sikayetinin ("tek sutun ortada, iki yan bos") panel icindeki
                // hali. SPEC §3 A1 tablosu tavani SATIRA degil SUTUNA koyar
                // ("detay sutunu: kalan, maks. 760"), o yuzden detay kartlari
                // SPEC §3 A2 akisina verilir: `large` bandinda detay 760 px
                // olur ve akis TEK sutun dondurur (bugunku dizilim birebir),
                // `xlarge` bandinda 1144 px olur ve iki 560 px'lik sutuna
                // akar — ikisi de 760 tavanin altinda.
                ProfileFlowColumns(
                  // `_SettingsSection` kartlari 10 px arayla yigar; akis da
                  // ayni sayiyi kullanir, aksi halde detay dali kartlari
                  // bitisik cizerdi.
                  spacing: 10,
                  sections: selected.cards,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final body = isDesktopWindow
        ? LayoutBuilder(
            builder: (context, constraints) {
              // 🔴 Olculen sey KAP genisligidir, PENCERE degil.
              // `showDesktopPanel` ayarlari 920 / 1088 / 1472 px'lik bir
              // `Dialog` icinde acar ve panelin icindeki `MediaQuery` hala
              // TUM pencereyi verir. SPEC §1.2'nin 1200 px'lik PENCERE
              // esigine bakan bir dal 1200 px'lik pencerede tetiklenirdi ama
              // o pencerede kaba yalniz 1056 px duser — tam olarak
              // master-detay satirinin boyu. Esik bu yuzden KABA baglidir.
              if (!constraints.maxWidth.isFinite) return flow();
              final band = constraints.maxWidth - padding.horizontal;
              return band < kSettingsMasterDetailBand ? flow() : masterDetail();
            },
          )
        : flow();

    if (widget.embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAyarlar)),
      body: body,
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Card(clipBehavior: Clip.antiAlias, child: child);
}

/// WP-686 — bir ayar bolumu, iki duzen dalinin ORTAK verisi.
///
/// [icon] yalniz master-detay dalinda (kategori listesinde) cizilir; akan
/// sutun dalinda bolumler bugunku gibi yalniz basliklariyla gorunur.
class _SettingsCategory {
  const _SettingsCategory({
    required this.id,
    required this.icon,
    required this.title,
    required this.cards,
  });

  final String id;
  final IconData icon;
  final String title;
  final List<Widget> cards;
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1) const SizedBox(height: 10),
        ],
      ],
    ),
  );
}

// ===========================================================================
// WP-679 — AYARLAR VE ALT EKRANLARIN ORTAK MASAUSTU DUZEN OLCULERI
// ===========================================================================
//
// Bu iki widget + iki sabit `settings_screen.dart` icinde durur cunku WP-679'un
// SAHIP yol listesi bu dizinde yeni dosya acmaz ve Ayarlar bu ekran ailesinin
// merkezidir: Hesabim, Gorunum, Disa aktarma, Hakkinda, Yasal, Geri bildirim ve
// SSS'ye buradan girilir. Olcunun tek kaynagi olmasi, her ekranin kendi
// sihirli sayisini uydurmasindan iyidir.
//
// Kaynak: `docs/design/DESKTOP-UI-SPEC.md` §2.3 (tavanlar), §3 A2/A3
// (arketipler), §4 (oluk 24 px). Ornek alinan iki dosya:
// `features/stats/widgets/stats_desktop_layout.dart` (WP-673) ve
// `features/profile/profile_screen.dart` `_ProfileBody` (WP-674).

/// SPEC §4: masaustu izgara olugu 24 px (WinUI: >640 px pencerede 24 epx).
const double kProfileGridGutter = 24;

// ===========================================================================
// WP-686 — AYARLAR MASTER-DETAY (SPEC §3 A1 + §5)
// ===========================================================================

/// SPEC §3 A1 tablosu: master sutunu **280** px.
const double kSettingsMasterWidth = 280;

/// SPEC §3 A1 tablosu: iki pane arasi bosluk **16** px.
const double kSettingsPaneSpacing = 16;

/// Master-detaya gecis bandi — **KAP** genisligi, pencere genisligi degil.
///
/// 280 + 16 + 760 = **1056**. Ayni sayi `desktop_surface.dart` icindeki
/// `DesktopSurface.panelWidthLarge` (1088) turetiminin de girdisidir:
/// 1056 + 32 (panel kenar boslugu) = 1088. Yani `large` panel tam olarak bu
/// satir sigsin diye acildi (WP-684).
///
/// 🔴 Neden pencere degil KAP: WP-679 olctu — ayarlar masaustunde
/// pencereyi HIC almaz, `showDesktopPanel`in verdigi banda oturur. WP-684 o
/// bandi pencereye bagladi; esik yine de bandin kendisine bakar, cunku ayni
/// ekran `Ctrl+,` yolunda AppBar'li bir kabukta, tam pencere yolunda ise 32
/// px'lik kenar boslugundan sonra kalan yerde cizilir.
const double kSettingsMasterDetailBand =
    kSettingsMasterWidth +
    kSettingsPaneSpacing +
    DesktopBreakpoints.maxFormWidth;

/// Kategori (master) sutununun anahtari — testler CIZILEN kutuyu olcer.
const Key kSettingsMasterListKey = Key('settings-master-list');

/// Detay pane'inin anahtari.
const Key kSettingsDetailPaneKey = Key('settings-detail-pane');

/// Iki sutuna gecis bandi — **kap** genisligi, pencere genisligi degil.
///
/// 🔴 SPEC SAPMASI, GEREKCESI OLCUM:
/// SPEC §1.2 merdiveni PENCERE genisligini okur ve iki pane esigini 1200 px
/// koyar. Bu ekran ailesi masaustunde pencereyi HIC almaz: `profile_screen`
/// Ayarlar'i `showDesktopPanel` ile acar, o da `DesktopSurface.panelWidth`
/// (920 px) genisliginde sabit bir `Dialog`tur ve pencereyle BUYUMEZ.
/// 2026-08-10 olcumu (`WP679 | AYARLAR-PANEL`): ayarlar icerigi 1920 px
/// pencerede de 2560 px pencerede de **772 px** cizildi; kabin kendisi 888 px.
/// Yani 1200'e bagli bir ikinci-sutun dali yazildigi gun olu kod olurdu —
/// depoda kayitli "bitmis backend + baglanmamis UI" hatasinin aynisi.
/// `desktop_surface.dart` bu WP'nin SAHIP yollarinda degil, yani panel
/// genisletilemez; o yuzden karar KABIN genisliginden verilir.
///
/// 880 = 2 x 428 + 24 (oluk). 428 px, Material 3'un asgari pane genisliginin
/// (360) ustundedir ve olculen 888 px'lik panel bandi tam bu basamaga duser.
const double kProfileTwoColumnBand = 880;

/// SPEC §3 A2 — bagimsiz bloklarin akitildigi sutun sayisi.
///
/// | kap (band) | sutun |
/// |---|---|
/// | < 880 | 1 |
/// | 880 – 1439 | 2 |
/// | >= 1440 | 3 (SPEC §2.3 izgara toplami 1440 = 3 x 480) |
int profileFlowColumns(double band) {
  if (!band.isFinite || band < kProfileTwoColumnBand) return 1;
  if (band < DesktopBreakpoints.maxContentWidth) return 2;
  return 3;
}

/// Masaustunde govdeyi SPEC §2.3 tavaninda tutar ve **basa** yaslar.
///
/// Hizalama WP-674'un `profile_screen.dart` icindeki `_startAligned`
/// karariyla birebir aynidir (Fluent/WinUI: serit yanindaki icerik sutunu
/// tavanina kadar buyur, sonra sola yasli kalir; artan yer saga bosluk olur).
///
/// Mobilde `child` **oldugu gibi** gecer — SPEC §7: mobil dal degismez.
class ProfileDesktopBody extends StatelessWidget {
  const ProfileDesktopBody({
    required this.maxWidth,
    required this.child,
    super.key,
  });

  /// Duz metin / prose: **600 px** = 80 karakter x 7.5 (WCAG 2.1 SC 1.4.8).
  ///
  /// 🔴 SPEC §2.3'un isaretledigi hata: `DesktopSurface.readingWidth = 760`
  /// prose icin 101 karakter eder. Form icin dogru, duz metin icin yanlis.
  const ProfileDesktopBody.prose({required Widget child, Key? key})
    : this(maxWidth: DesktopBreakpoints.maxProseWidth, child: child, key: key);

  /// Form / ayar satiri: **760 px** = 600 (etiket olcu tavani) + 160 (kontrol).
  const ProfileDesktopBody.form({required Widget child, Key? key})
    : this(maxWidth: DesktopBreakpoints.maxFormWidth, child: child, key: key);

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) return child;
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        // SPEC §6 "BAGLA, ATMA": siniri masaustu yuzeyi koyar. Distaki kutu
        // zaten ayni tavani verdigi icin icerideki ortalama etkisizdir.
        child: DesktopContent(
          maxWidth: maxWidth,
          padding: EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

/// Bos / hata durumlarini masaustu yuzeyine baglar (SPEC §6) ve prose
/// tavaninda tutar. DIKEY ortalama korunur: [DesktopContent] DISTA durur,
/// `Center` icinde kalir — tersi sirada `Align(topCenter)` mesaji yukari
/// yapistirirdi.
///
/// 🔴 Neden gerekli: `desktop_stretch_contract` OLCUM 4, ekranin cizilen
/// agacinda bir masaustu yuzeyi arar. Bir ekranin EN SIK gorulen hali bos
/// durumdur (taze kurulumda kayit/ders yoktur); o dal baglanmazsa kapi
/// kirmizi kalir ve "ekran mobil agacina bagli" der — hakli olarak.
class ProfileDesktopCentered extends StatelessWidget {
  const ProfileDesktopCentered({
    required this.child,
    this.maxWidth = DesktopBreakpoints.maxProseWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < maxWidth
            ? constraints.maxWidth
            : maxWidth;
        // Yatayda BASA yasli (WP-674 Fluent karari), dikeyde ORTALI.
        // 🔴 Bunu ortalamak olculebilir bir kusur uretiyordu: 2560 px'lik
        // pencerede AppBar basligi 16 px'te, ortalanan bos mesaj 1529 px'te
        // bitiyor ve aradaki aralik 1513 px oluyordu — SPEC §2.3'un 1440 px
        // izgara tavaninin ustu (`desktop_stretch_contract` OLCUM 1).
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: width,
            child: DesktopContent(
              maxWidth: width,
              padding: EdgeInsets.zero,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// FAB'i pencerenin sag alt kosesine degil, ICERIK SUTUNUNUN sag alt kosesine
/// koyar.
///
/// 🔴 Olculdu (`desktop_stretch_contract`, `dersler` yuzeyi): icerik 1440 px'te
/// tavanlansa bile "Ders ekle" dugmesi 1920 px'lik pencerede 1884 px'te,
/// 2560 px'te 2524 px'te boyaniyordu. Kullanicinin gozu, sol ustteki basliktan
/// iki bucuk metre otedeki dugmeye gidiyordu — sahibin sikayetinin ta kendisi.
/// Dugme, ikonu, etiketi ve eylemi degismedi; yalniz **yeri** icerigin yanina
/// alindi (SPEC §7: islev degismez).
class ProfileContentEndFabLocation extends FloatingActionButtonLocation {
  const ProfileContentEndFabLocation(this.contentWidth);

  /// Ekranin kendi SPEC §2.3 tavani (ornegin dersler 1440, sayac gunlugu 760).
  final double contentWidth;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final base = FloatingActionButtonLocation.endFloat.getOffset(geometry);
    final limit = contentWidth - geometry.floatingActionButtonSize.width;
    return Offset(base.dx < limit ? base.dx : limit, base.dy);
  }

  @override
  String toString() => 'ProfileContentEndFabLocation($contentWidth)';
}

/// [ProfileFlowColumns] sutunlarinin key onu: `profile-flow-column-0`, `-1`…
const String kProfileFlowColumnKeyPrefix = 'profile-flow-column-';

/// Bagimsiz bloklarin (bolum / kart) 1–3 sutuna akitilmasi (SPEC §3 A2).
///
/// Sutunlar **donusumlu** doldurulur (0,2,4… sol; 1,3,5… orta/sag). Sebep
/// `StatsSectionColumns` ile ayni: blok yukseklikleri farkli; `Wrap` her satiri
/// en uzun bloga hizalar ve aralarda tirtikli bosluk birakir. Hicbir blok
/// gizlenmez, yalniz yeri degisir (SPEC §7: islev degismez).
class ProfileFlowColumns extends StatelessWidget {
  const ProfileFlowColumns({
    required this.sections,
    this.spacing = 0,
    this.columnMaxWidth = DesktopBreakpoints.maxFormWidth,
    super.key,
  });

  final List<Widget> sections;

  /// Ayni sutundaki iki blok arasi dikey bosluk. Ayarlar'da **0**: her
  /// `_SettingsSection` kendi 24 px alt boslugunu zaten tasiyor, buraya ikinci
  /// bir bosluk koymak mobil ciktiyi degistirirdi.
  final double spacing;

  /// Tek bir sutunun SPEC §2.3 tavani.
  final double columnMaxWidth;

  Widget _stack(List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0 && spacing > 0) SizedBox(height: spacing),
        items[i],
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    // SPEC §7: mobil agac bugunku ciktisini birebir korur.
    if (!isDesktopWindow) return _stack(sections);
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = profileFlowColumns(
          constraints.maxWidth,
        ).clamp(1, sections.length);
        if (columns <= 1) {
          return ProfileDesktopBody(
            maxWidth: columnMaxWidth,
            child: _stack(sections),
          );
        }
        final buckets = List.generate(columns, (_) => <Widget>[]);
        for (var i = 0; i < sections.length; i++) {
          buckets[i % columns].add(sections[i]);
        }
        final rowWidth =
            columns * columnMaxWidth + kProfileGridGutter * (columns - 1);
        return ProfileDesktopBody(
          // SPEC §2.3: izgara toplami 1440'ta durur.
          maxWidth: rowWidth < DesktopBreakpoints.maxContentWidth
              ? rowWidth
              : DesktopBreakpoints.maxContentWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < buckets.length; i++) ...[
                if (i > 0) const SizedBox(width: kProfileGridGutter),
                Expanded(
                  // Testler sutunu KEY'den bulur: olculecek sey cizilen
                  // kutudur, kaynakta `Expanded` gormek kanit degildir.
                  key: ValueKey('$kProfileFlowColumnKeyPrefix$i'),
                  child: _stack(buckets[i]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

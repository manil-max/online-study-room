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
import '../admin/admin_screen.dart';
import '../desktop/desktop_surface.dart';
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
    await ref.read(examDateProvider.notifier).set(picked);
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

    final list = ListView(
      padding: getSafePadding(
        context,
        const EdgeInsets.fromLTRB(16, 12, 16, 24),
      ),
      children: [
        DesktopReadingBody(
          maxWidth: DesktopSurface.readingWidth,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingsSection(
                title: l10n.settingsSectionAppearance,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.color_lens_outlined),
                      title: Text(l10n.profileGorunumVeAtmosferTemalari),
                      subtitle: Text(l10n.profileGorunumVeAtmosfer),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AppearanceScreen()),
                      ),
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
                            ref
                                .read(appLanguageProvider.notifier)
                                .setLanguage(value);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionNotifications,
                children: [
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
                        MaterialPageRoute(
                          builder: (_) => const AnnouncementsScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionAccount,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.manage_accounts),
                      title: Text(l10n.profileHesabimiYonet),
                      subtitle: Text(l10n.profileEpostaSifreVeGuvenli),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AccountSettingsScreen(),
                        ),
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
                        MaterialPageRoute(
                          builder: (_) => const DataExportScreen(),
                        ),
                      ),
                    ),
                  ),
                  if (isAdmin)
                    _SettingsCard(
                      child: ListTile(
                        leading: const Icon(
                          Icons.admin_panel_settings_outlined,
                        ),
                        title: Text(l10n.profileYonetim),
                        subtitle: Text(l10n.profileOzetlerVeKullaniciRaporlari),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => AdminScreen()),
                        ),
                      ),
                    ),
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionStudyPreferences,
                children: [
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
                      onTap: profile == null
                          ? null
                          : () => _editDailyGoal(goalMinutes),
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
                              onPressed: () =>
                                  ref.read(examDateProvider.notifier).clear(),
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
              _SettingsSection(
                title: l10n.settingsSectionPrivacySecurity,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      leading: const Icon(Icons.block),
                      title: Text(l10n.safetyBlockedUsersTitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BlockedUsersScreen(),
                        ),
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
                        MaterialPageRoute(
                          builder: (_) => const MutedNudgesScreen(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              _SettingsSection(
                title: l10n.settingsSectionAboutLegal,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      key: const Key('settings-about-updates'),
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.profileSurumVeGuncellemeler),
                      subtitle: Text(l10n.aboutSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      ),
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
                              MaterialPageRoute(
                                builder: (_) => const FeedbackScreen(),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
              // WP-514: SSS iki kat derindeydi (Ayarlar → Hakkında → SSS) ve
              // sahip bulamıyordu. Kendi "Yardım" bölümüyle Ayarlar'ın **en
              // altında** duruyor — yardım aranan yer listenin sonudur.
              _SettingsSection(
                title: l10n.settingsSectionHelp,
                children: [
                  _SettingsCard(
                    child: ListTile(
                      key: const Key('settings-faq'),
                      leading: const Icon(Icons.help_outline),
                      title: Text(l10n.faqTitle),
                      subtitle: Text(l10n.faqSubtitle),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const FaqScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return list;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileAyarlar)),
      body: list,
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

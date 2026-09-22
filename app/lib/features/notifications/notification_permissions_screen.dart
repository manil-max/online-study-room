import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import '../clock/clock_widgets_screen.dart';
import '../permissions/permissions_screen.dart';
import 'notification_center_screen.dart';

/// WP-286: bildirim tercihleri, cihaz izinleri ve aylık rapor için tek giriş.
class NotificationPermissionsScreen extends ConsumerStatefulWidget {
  const NotificationPermissionsScreen({super.key});

  @override
  ConsumerState<NotificationPermissionsScreen> createState() =>
      _NotificationPermissionsScreenState();
}

class _NotificationPermissionsScreenState
    extends ConsumerState<NotificationPermissionsScreen> {
  bool? _monthlyReportOptInOverride;
  bool _savingMonthlyReport = false;

  Future<void> _setMonthlyReportOptIn(bool value, bool previousValue) async {
    // Snackbar'ı `await`ten önce yakala: mesaj kullanıcı sekme değiştirse de
    // düşsün, `context` üzerinden asenkron arama yapılmasın.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() {
      _monthlyReportOptInOverride = value;
      _savingMonthlyReport = true;
    });
    try {
      await ref.read(authRepositoryProvider).updateMonthlyReportOptIn(value);
      ref.invalidate(authStateProvider);
    } catch (_) {
      // 🔴 WP-620: anahtar geri alınıyordu ama kullanıcıya **hiçbir şey**
      // söylenmiyordu. Ekranda görünen tek şey düğmenin kendiliğinden eski
      // yerine dönmesiydi; kullanıcı bunu "dokunuşum kaydolmadı" değil
      // "arayüz takıldı" diye okuyor ve tekrar tekrar deniyordu. Yarım doğru
      // (geri alma) tam doğruya çevrildi: geri al **ve** söyle.
      if (!mounted) return;
      setState(() => _monthlyReportOptInOverride = previousValue);
      messenger.showSnackBar(
        SnackBar(
          key: const Key('monthly-report-save-failed'),
          content: Text(l10n.notificationsAylikRaporKaydedilemedi),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingMonthlyReport = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(authStateProvider).value;
    // 🔴 WP-626: profil yokken varsayılan AÇIK'tı. Hiç kimseye tek bir rapor
    // e-postası gönderilmediği hâlde ekran "açık" gösteriyordu; bilinmeyen
    // durumun varsayılanı vaat değil sessizlik olmalı.
    final reportOptIn =
        _monthlyReportOptInOverride ?? profile?.monthlyReportOptIn ?? false;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.profileBildirimMerkezi),
          // 🔴 WP-683: iki sekme ikonu bir `Flex` içinde yan yana duran iki
          // etikettir; aralarındaki mesafe SPEC KURAL 2.2'nin ölçtüğü
          // mesafenin ta kendisidir. Tavansız hâlde 2560 px'lik pencerede
          // ikonlar ~1200 px arayla duruyordu. Aynı çözüm Saat ekranında da
          // kullanıldı (`ClockCommandStrip`).
          bottom: const _TabStrip(),
        ),
        body: TabBarView(
          children: [
            NotificationCenterScreen(
              embedded: true,
              footer: Card(
                child: SwitchListTile(
                  key: const Key('monthly-report-opt-in'),
                  secondary: const Icon(Icons.mark_email_unread_outlined),
                  // 🔴 WP-626: bu satır var olmayan bir özelliği vaat
                  // ediyordu. `send-report` fonksiyonunu hiçbir cron, iş akışı
                  // veya istemci çağırmıyor; iki fonksiyon da hiçbir yerde
                  // deploy edilmiyor ve e-posta sağlayıcı anahtarı hiç
                  // tanımlanmıyor. Kullanıcı bugüne kadar tek bir rapor
                  // e-postası almadı. Eski alt satır ("Özetler ve kullanıcı
                  // raporları" — aslında yönetim kartının metni) vaadi
                  // pekiştiriyordu. Anahtar tercihi kaydetmeye devam ediyor
                  // ama artık gönderimin başlamadığını SÖYLÜYOR.
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(l10n.profileAylikCalismaRaporuEposta),
                      ),
                      const SizedBox(width: 8),
                      _ComingSoonBadge(
                        label: l10n.notificationsAylikRaporYakinda,
                      ),
                    ],
                  ),
                  subtitle: Text(
                    l10n.notificationsAylikRaporHenuzGonderilmiyor,
                  ),
                  value: reportOptIn,
                  onChanged: profile == null || _savingMonthlyReport
                      ? null
                      : (value) => _setMonthlyReportOptIn(
                          value,
                          profile.monthlyReportOptIn,
                        ),
                ),
              ),
            ),
            // İkinci sekmenin gövdesi başka bir özelliğin dosyasıdır
            // (`clock/clock_widgets_screen.dart`) ve WP-683'ün SAHİP yolları
            // dışındadır; bu yüzden o dosya değiştirilmedi, yalnız BURADAN
            // aynı banda alındı. Sonuç kullanıcı için aynı: satır 632 px'te
            // durur.
            //
            // 🔴 WP-907: iOS'ta o ekranın iki yarısı da yanlış yüzeydir —
            // Android widget kataloğu çizilmez, başlık "masaüstü" der. iOS'ta
            // sekme yalnız İzinler ekranına giden tek eylemi taşır (Android'de
            // izinler de oradan yönetilir). Android/Windows değişmedi.
            if (_isIos)
              const NotificationDesktopBand(child: _IosPermissionsTab())
            else
              const NotificationDesktopBand(
                child: ClockWidgetsScreen(embedded: true),
              ),
          ],
        ),
      ),
    );
  }
}

/// WP-907: platform `defaultTargetPlatform` üzerinden okunur; testte
/// `debugDefaultTargetPlatformOverride = TargetPlatform.iOS` ile enjekte edilir.
bool get _isIos => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// WP-907: iOS'ta ikinci sekme. Widget kataloğu ve Android izin özeti yok;
/// yalnız İzinler ekranına giden düğme (iOS'ta orada bildirim izni yönetilir).
class _IosPermissionsTab extends StatelessWidget {
  const _IosPermissionsTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return ListView(
      key: const Key('notification-ios-permissions-tab'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          l10n.permissionsTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.permissionsSettingsSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            key: const Key('notification-ios-open-permissions'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PermissionsScreen(),
              ),
            ),
            icon: const Icon(Icons.admin_panel_settings_outlined),
            label: Text(l10n.clockIzinlerEkraniniAc),
          ),
        ),
      ],
    );
  }
}

/// Sekme şeridi: masaüstünde [kNotificationBlockMaxWidth] ile tavanlanır,
/// mobilde bugünkü `TabBar`ın **birebir kendisidir** (SPEC §7).
class _TabStrip extends StatelessWidget implements PreferredSizeWidget {
  const _TabStrip();

  static const TabBar _bar = TabBar(
    tabs: [
      Tab(icon: Icon(Icons.notifications_outlined)),
      Tab(icon: Icon(Icons.security_outlined)),
    ],
  );

  @override
  Size get preferredSize => _bar.preferredSize;

  @override
  Widget build(BuildContext context) =>
      const NotificationDesktopBand(child: _bar);
}

/// WP-626: "henüz yok" rozeti. Renk tema paletinden bağımsız değil ama
/// `tertiary`/`onTertiary` çifti her iki temada da okunur kalıyor; sabit
/// değer verilirse kırmızı temada kaybolan uyarı rozetinin hatası tekrarlanır.
class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('monthly-report-coming-soon'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

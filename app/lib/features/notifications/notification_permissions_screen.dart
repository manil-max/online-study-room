import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../l10n/app_localizations.dart';
import '../clock/clock_widgets_screen.dart';
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
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.notifications_outlined)),
              Tab(icon: Icon(Icons.security_outlined)),
            ],
          ),
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
            const ClockWidgetsScreen(embedded: true),
          ],
        ),
      ),
    );
  }
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

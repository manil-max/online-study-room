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
    final reportOptIn =
        _monthlyReportOptInOverride ?? profile?.monthlyReportOptIn ?? true;
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
                  title: Text(l10n.profileAylikCalismaRaporuEposta),
                  subtitle: Text(l10n.profileOzetlerVeKullaniciRaporlari),
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

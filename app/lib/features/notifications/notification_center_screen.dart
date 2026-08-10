import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/nudge_notification_service.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/push_notification_providers.dart';
import '../../data/models/push_notification.dart';
import '../../l10n/app_localizations.dart';

/// WP-683 — masaüstünde bir bildirim bloğunun genişlik tavanı.
///
/// 🔴 Türetildi, seçilmedi. SPEC KURAL 2.2 bir etiket–değer satırının **sert
/// tavanını 600 px** koyar (80 karakter × 7.5 px; WCAG 2.1 SC 1.4.8). Bu
/// ekrandaki satırlar `Card` içindeki `ListTile`/`SwitchListTile`lerdir; yatay
/// iç dolgu 2 × 16 = 32 px, yani 600 px'lik bir satırın sığdığı en geniş kart
/// **632 px**'tir. 632, 4'ün katıdır (WinUI ölçek platosu kuralı, SPEC §1.2).
/// Kardeş masaüstü ekranları aynı sayıyı aynı türetmeyle kullanıyor
/// (`kClockBlockMaxWidth`, `kGroupBlockMaxWidth`); ikinci bir dil icat edilmedi.
///
/// 🔴 ÖLÇÜLEN KUSUR (WP-683 öncesi, `desktop_wp683_screens_test.dart`):
///
/// | ekran | 1008 | 1200 | 1920 | 2560 | panel (920) |
/// |---|---:|---:|---:|---:|---:|
/// | bildirim merkezi — en geniş kart | 976 | 1168 | **1888** | **2528** | 888 |
/// | bildirim izinleri — etiket→değer | 812 | 1004 | **1724** | **2364** | 724 |
///
/// "Aylık çalışma raporu (E-posta)" etiketinden "Yakında" rozetine 2364 px:
/// SPEC KURAL 2.2'nin tarif ettiği göz sıçraması mesafesinin dört katı.
const double kNotificationBlockMaxWidth =
    DesktopBreakpoints.maxLabelValueWidth + 32;

/// Masaüstünde içeriği [kNotificationBlockMaxWidth] ile tavanlar ve yatayda
/// ortalar; **mobilde çocuğu olduğu gibi geçirir** (SPEC §7: mobil dal
/// değişmez, ağaca tek bir düğüm bile eklenmez).
///
/// 🔴 Tavan `MediaQuery`den DEĞİL kaptan kurulur. Ayarlar masaüstünde
/// `showDesktopPanel` ile açılır ve bu ekranlar 920 px'lik bir `SizedBox`
/// içinde çizilir; `MediaQuery.sizeOf` orada hâlâ **tüm pencereyi** verir.
/// Pencereden karar veren bir tavan panelde yanlış davranırdı.
class NotificationDesktopBand extends StatelessWidget {
  const NotificationDesktopBand({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopWindow) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kNotificationBlockMaxWidth),
        child: child,
      ),
    );
  }
}

String _formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Bildirim Merkezi: hangi bildirimi alacağının ve sessiz saatlerin tek
/// yerden yönetildiği **ayar** ekranı.
///
/// WP-304 düzeni: üstte gündelik ayarlar, en altta tanı/test kartı. Alarm ve
/// zamanlayıcı satırı kaldırıldı (Saat sekmesinde zaten var), duyurular
/// Ayarlar'a taşındı (`AnnouncementsScreen`), kişisel çalışma hatırlatıcıları
/// tamamen kaldırıldı — alarm aynı işi sesli ve ertelemeli yapıyordu.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({
    super.key,
    this.embedded = false,
    this.footer,
  });

  final bool embedded;
  final Widget? footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ekran açıkken hatırlatıcı planlaması tercihlerle senkron kalsın.
    ref.watch(reminderSyncListenerProvider);
    final prefs = ref.watch(notificationPreferencesProvider);
    final l10n = AppLocalizations.of(context);

    final body = NotificationDesktopBand(
      child: ListView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 28),
        ),
        children: [
          // WP-304: önce gündelik ayarlar, tanı/test kartı en altta. Eskiden
          // "yerel test / uzak test" düğmeleri listenin başındaydı; kullanıcı
          // ayar aramaya gelip önce hata ayıklama araçlarıyla karşılaşıyordu.
          const _PermissionCard(),
          const SizedBox(height: 10),
          _TypesCard(prefs: prefs),
          const SizedBox(height: 10),
          _QuietHoursCard(prefs: prefs),
          if (footer != null) ...[const SizedBox(height: 10), footer!],
          const SizedBox(height: 10),
          const _PushHealthCard(),
        ],
      ),
    );
    if (embedded) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsBildirimMerkezi)),
      body: body,
    );
  }
}

class _PushHealthCard extends ConsumerWidget {
  const _PushHealthCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(pushHealthProvider);
    if (health.readiness == PushHealthReadiness.unsupported) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ready =
        health.readiness == PushHealthReadiness.ready &&
        health.deviceRegistered;
    final statusText = switch (health.readiness) {
      PushHealthReadiness.notConfigured =>
        l10n.notificationsRemoteNotConfigured,
      PushHealthReadiness.incompleteConfiguration =>
        l10n.notificationsRemoteIncomplete,
      PushHealthReadiness.permissionRequired =>
        l10n.notificationsPermissionRequired,
      PushHealthReadiness.registering => l10n.notificationsPhoneRegistering,
      PushHealthReadiness.ready =>
        health.deviceRegistered
            ? l10n.notificationsPhoneReady
            : l10n.notificationsPhoneRegistering,
      PushHealthReadiness.error => l10n.notificationsConnectionError,
      PushHealthReadiness.unsupported => l10n.notificationsRemoteNotConfigured,
    };
    final statusColor = ready
        ? theme.colorScheme.primary
        : health.readiness == PushHealthReadiness.error ||
              health.readiness == PushHealthReadiness.incompleteConfiguration
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    final lastReceived = health.snapshot.lastReceivedAt;
    final lastDelivery = lastReceived == null
        ? l10n.notificationsLastDeliveryNever
        : l10n.notificationsLastDelivery(
            MaterialLocalizations.of(
              context,
            ).formatTimeOfDay(TimeOfDay.fromDateTime(lastReceived.toLocal())),
          );
    final selfTest = health.selfTestStatus;
    final failureKind = classifyPushSelfTestFailure(selfTest);
    final failureCode = selfTest?.errorCode ?? health.errorCode;
    final selfTestCoolingDown = health.errorCode == 'push_test_cooldown';
    final selfTestText = selfTestCoolingDown
        ? l10n.notificationsRemoteTestCooldown
        : selfTest?.state == PushSelfTestDeliveryState.sent &&
              health.selfTestReceived
        ? l10n.notificationsRemoteTestSent(
            ((health.selfTestElapsed?.inMilliseconds ?? 0) / 1000)
                .toStringAsFixed(1),
          )
        : selfTest?.terminal == true ||
              (health.errorCode?.startsWith('push_test_') ?? false)
        ? '${l10n.notificationsRemoteTestFailed} '
              '[$failureKind${failureCode == null ? '' : ': $failureCode'}]'
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: statusColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.notificationsHealthTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.notificationsHealthSubtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.notificationsRefreshHealth,
                  onPressed: health.syncing
                      ? null
                      : () => ref.read(pushHealthProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(statusText, style: TextStyle(color: statusColor)),
            const SizedBox(height: 10),
            _HealthRow(
              label: l10n.notificationsOsPermission,
              enabled: health.snapshot.notificationsEnabled,
            ),
            const SizedBox(height: 6),
            _HealthRow(
              label: l10n.notificationsPhoneRegistration,
              enabled: health.deviceRegistered,
            ),
            Text(
              lastDelivery,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (health.localTestSucceeded) ...[
              const SizedBox(height: 6),
              Text(
                l10n.notificationsLocalTestSent,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            if (selfTestText != null) ...[
              const SizedBox(height: 6),
              Text(
                selfTestText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: selfTestCoolingDown
                      ? theme.colorScheme.onSurfaceVariant
                      : selfTest?.state == PushSelfTestDeliveryState.sent &&
                            health.selfTestReceived
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: health.syncing
                      ? null
                      : () => ref
                            .read(pushHealthProvider.notifier)
                            .runLocalTest(),
                  icon: const Icon(Icons.phone_android),
                  label: Text(l10n.notificationsLocalTest),
                ),
                FilledButton.tonalIcon(
                  onPressed: ready && !health.syncing
                      ? () => ref
                            .read(pushHealthProvider.notifier)
                            .runRemoteTest()
                      : null,
                  icon: health.syncing
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_done_outlined),
                  label: Text(l10n.notificationsRemoteTest),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.enabled});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle_outline : Icons.cancel_outlined,
          size: 18,
          color: enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          enabled
              ? l10n.notificationsStatusOpen
              : l10n.notificationsStatusClosed,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(icon, color: theme.colorScheme.primary),
            title: Text(title),
            subtitle: Text(subtitle),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

/// Cihaz izin durumunu açıkça gösterir (§WP-36 kabul: sınırlar görünür olmalı).
class _PermissionCard extends ConsumerWidget {
  const _PermissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // 🔴 WP-611: bu düğme masaüstünde "bozuk düğme"ydi. `initialize()` FLN'e
    // Android-only ayar veriyor, Windows `ArgumentError` atıyor ve `granted`
    // hiç hesaplanmadığı için SnackBar satırına gelinmiyordu: basıyorsun,
    // hiçbir şey olmuyor. Masaüstünde kontrol edilecek bir izin YOK — düğmeyi
    // göstermek yerine nedenini yazıyoruz.
    final supported = ref
        .watch(reminderNotificationServiceProvider)
        .isSupported;
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.notificationsCihazIzinleri,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              key: const Key('notification_permission_note'),
              supported
                  ? l10n.notificationsBildirimlerCihazIznineBaglidir
                  : l10n.notificationsIzinMasaustundeGecersiz,
              style: theme.textTheme.bodySmall?.copyWith(
                color: supported
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.error,
              ),
            ),
            if (supported) ...[
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  onPressed: () async {
                    final granted = await ref
                        .read(reminderNotificationServiceProvider)
                        .requestPermissionIfNeeded();
                    await ref
                        .read(pushHealthProvider.notifier)
                        .synchronize(force: true);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          granted
                              ? l10n.notificationsBildirimIzniVerildi
                              : l10n.notificationsBildirimIzniVerilmediSistem,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: Text(l10n.notificationsBildirimIzniniKontrolEt),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypesCard extends ConsumerWidget {
  const _TypesCard({required this.prefs});

  final NotificationPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    // 🔴 WP-611: iki akıllı hatırlatıcı masaüstünde tamamen erişilemezdi —
    // anahtarın `onChanged`i izin çağrısını `await` ediyor, çağrı istisna
    // atıyor ve tercih satırına HİÇ gelinmiyordu: anahtar geri kapanıyor,
    // ekranda hata yok. Tercihi sessizce yazmak da yanlış olurdu (bildirim
    // yine gelmezdi); satır devre dışı bırakılıp nedeni alt yazıya yazılır.
    final smartSupported = ref
        .watch(reminderNotificationServiceProvider)
        .isSupported;
    return _SectionCard(
      icon: Icons.tune,
      title: l10n.notificationsBildirimTurleri,
      subtitle: l10n.notificationsHangiBildirimleriAlmakIstedigini,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.waving_hand_outlined),
          title: Text(l10n.notificationsDurtmeBildirimleri),
          subtitle: Text(l10n.notificationsSinifArkadaslarinSeniDurttugunde),
          value: prefs.nudgeNotificationsEnabled,
          onChanged: (value) async {
            if (value) {
              await ref
                  .read(nudgeNotificationServiceProvider)
                  .requestPermissionIfNeeded();
            }
            await notifier.setNudgeNotificationsEnabled(value);
          },
        ),
        const Divider(height: 1),
        SwitchListTile(
          key: const Key('notification_smart_streak_switch'),
          secondary: const Icon(Icons.local_fire_department_outlined),
          title: Text(l10n.smartStreakReminder),
          subtitle: Text(
            smartSupported
                ? l10n.smartStreakReminderBody
                : l10n.notificationsHatirlaticiMasaustundeYok,
          ),
          value: prefs.smartStreakReminderEnabled,
          onChanged: !smartSupported
              ? null
              : (value) async {
                  if (value) {
                    await ref
                        .read(reminderNotificationServiceProvider)
                        .requestPermissionIfNeeded();
                  }
                  await notifier.setSmartStreakReminderEnabled(value);
                },
        ),
        const Divider(height: 1),
        SwitchListTile(
          key: const Key('notification_smart_weekly_switch'),
          secondary: const Icon(Icons.calendar_view_week_outlined),
          title: Text(l10n.smartWeeklySummary),
          subtitle: Text(
            smartSupported
                ? l10n.smartWeeklySummaryBody
                : l10n.notificationsHatirlaticiMasaustundeYok,
          ),
          value: prefs.smartWeeklySummaryEnabled,
          onChanged: !smartSupported
              ? null
              : (value) async {
                  if (value) {
                    await ref
                        .read(reminderNotificationServiceProvider)
                        .requestPermissionIfNeeded();
                  }
                  await notifier.setSmartWeeklySummaryEnabled(value);
                },
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.campaign_outlined),
          title: Text(l10n.notificationsDuyurular),
          subtitle: Text(l10n.notificationsUygulamaVeGrupDuyurularini),
          value: prefs.announcementsEnabled,
          onChanged: notifier.setAnnouncementsEnabled,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.new_releases_outlined),
          title: Text(l10n.notificationsGuncellemeBildirimleri),
          subtitle: Text(l10n.notificationsYeniSurumCikincaHaber),
          value: prefs.updatesEnabled,
          onChanged: notifier.setUpdatesEnabled,
        ),
      ],
    );
  }
}

class _QuietHoursCard extends ConsumerWidget {
  const _QuietHoursCard({required this.prefs});

  final NotificationPreferences prefs;

  Future<void> _pickTime(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final current = isStart ? prefs.quietStartMinutes : prefs.quietEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await ref
        .read(notificationPreferencesProvider.notifier)
        .setQuietHours(
          startMinutes: isStart ? minutes : prefs.quietStartMinutes,
          endMinutes: isStart ? prefs.quietEndMinutes : minutes,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return _SectionCard(
      icon: Icons.bedtime_outlined,
      title: l10n.notificationsSessizSaatler,
      subtitle: l10n.notificationsBuAraliktaDurtmeVe,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.do_not_disturb_on_outlined),
          title: Text(l10n.notificationsSessizSaatleriEtkinlestir),
          value: prefs.quietHoursEnabled,
          onChanged: notifier.setQuietHoursEnabled,
        ),
        if (prefs.quietHoursEnabled) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bedtime),
            title: Text(l10n.notificationsBaslangic),
            trailing: Text(
              _formatMinutes(prefs.quietStartMinutes),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickTime(context, ref, isStart: true),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: Text(l10n.notificationsBitis),
            trailing: Text(
              _formatMinutes(prefs.quietEndMinutes),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickTime(context, ref, isStart: false),
          ),
        ],
      ],
    );
  }
}

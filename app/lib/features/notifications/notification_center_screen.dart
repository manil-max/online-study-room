import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/nudge_notification_service.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/announcement.dart';
import '../../data/models/study_reminder.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/notification_providers.dart';
import '../../data/providers/push_notification_providers.dart';
import '../../data/models/push_notification.dart';
import '../../data/repositories/notification_repository.dart';
import '../../l10n/app_localizations.dart';
import '../clock/alarms_screen.dart';

List<String> _weekdayLabels(AppLocalizations l10n) => [
  l10n.notificationsPzt,
  l10n.notificationsSal,
  l10n.notificationsCar,
  l10n.notificationsPer,
  l10n.notificationsCum,
  l10n.notificationsCmt,
  l10n.notificationsPaz,
];

String _formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Bildirim Merkezi (§WP-36): dürtme, hatırlatıcı, alarm/zamanlayıcı, duyuru,
/// güncelleme ve sessiz saatlerin tek yerden yönetildiği ekran.
class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ekran açıkken hatırlatıcı planlaması tercihlerle senkron kalsın.
    ref.watch(reminderSyncListenerProvider);
    final prefs = ref.watch(notificationPreferencesProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationsBildirimMerkezi)),
      body: ListView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 28),
        ),
        children: [
          const _PermissionCard(),
          const SizedBox(height: 10),
          const _PushHealthCard(),
          const SizedBox(height: 10),
          _TypesCard(prefs: prefs),
          const SizedBox(height: 10),
          _QuietHoursCard(prefs: prefs),
          const SizedBox(height: 10),
          _RemindersCard(prefs: prefs),
          const SizedBox(height: 10),
          const _AnnouncementsCard(),
        ],
      ),
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
              l10n.notificationsBildirimlerCihazIznineBaglidir,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
          secondary: const Icon(Icons.local_fire_department_outlined),
          title: Text(l10n.smartStreakReminder),
          subtitle: Text(l10n.smartStreakReminderBody),
          value: prefs.smartStreakReminderEnabled,
          onChanged: (value) async {
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
          secondary: const Icon(Icons.calendar_view_week_outlined),
          title: Text(l10n.smartWeeklySummary),
          subtitle: Text(l10n.smartWeeklySummaryBody),
          value: prefs.smartWeeklySummaryEnabled,
          onChanged: (value) async {
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
          secondary: const Icon(Icons.alarm_outlined),
          title: Text(l10n.notificationsCalismaHatirlaticilari),
          subtitle: Text(
            l10n.notificationsPlanladiginHatirlaticilariYerelBildirimle,
          ),
          value: prefs.remindersEnabled,
          onChanged: notifier.setRemindersEnabled,
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
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: Text(l10n.notificationsAlarmVeZamanlayici),
          subtitle: Text(l10n.notificationsSaatSekmesindenYonetilir),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AlarmsScreen())),
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

class _RemindersCard extends ConsumerWidget {
  const _RemindersCard({required this.prefs});

  final NotificationPreferences prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remindersAsync = ref.watch(myRemindersProvider);
    final l10n = AppLocalizations.of(context);

    return _SectionCard(
      icon: Icons.alarm_add_outlined,
      title: l10n.notificationsHatirlaticilar,
      subtitle: l10n.notificationsBelirliSaatlerdeCalismaHatirlaticisi,
      children: [
        remindersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(l10n.authBeklenmeyenBirHataOlustu),
          ),
          data: (reminders) {
            if (reminders.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  l10n.notificationsHenuzHatirlaticinYokAsagidan,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (final reminder in reminders)
                  _ReminderTile(reminder: reminder),
              ],
            );
          },
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              onPressed: () => _openReminderDialog(context, ref),
              icon: const Icon(Icons.add),
              label: Text(l10n.notificationsHatirlaticiEkle),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  const _ReminderTile({required this.reminder});

  final StudyReminder reminder;

  String _daysLabel(AppLocalizations l10n) {
    if (reminder.weekdays.isEmpty) return l10n.notificationsHerGun;
    final sorted = [...reminder.weekdays]..sort();
    if (sorted.length == 7) return l10n.notificationsHerGun;
    final weekdayLabels = _weekdayLabels(l10n);
    return sorted.map((d) => weekdayLabels[d - 1]).join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) async {
        await ref
            .read(notificationRepositoryProvider)
            .deleteReminder(reminder.id);
        ref.invalidate(myRemindersProvider);
      },
      child: SwitchListTile(
        secondary: Text(
          '${reminder.hour.toString().padLeft(2, '0')}:${reminder.minute.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        title: Text(reminder.title),
        subtitle: Text(_daysLabel(l10n)),
        value: reminder.enabled,
        onChanged: (value) async {
          await ref
              .read(notificationRepositoryProvider)
              .upsertReminder(reminder.copyWith(enabled: value));
          ref.invalidate(myRemindersProvider);
        },
      ),
    );
  }
}

class _AnnouncementsCard extends ConsumerWidget {
  const _AnnouncementsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(notificationPreferencesProvider);
    final announcementsAsync = ref.watch(myAnnouncementsProvider);
    final read = ref.watch(readAnnouncementIdsProvider).value ?? const {};
    final l10n = AppLocalizations.of(context);

    return _SectionCard(
      icon: Icons.campaign_outlined,
      title: l10n.notificationsDuyurular,
      subtitle: l10n.notificationsUygulamaVeGrubunaOzel,
      children: [
        if (!prefs.announcementsEnabled)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.notificationsUygulamaVeGrupDuyurularini,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          announcementsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.authBeklenmeyenBirHataOlustu),
            ),
            data: (announcements) {
              if (announcements.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.notificationsSimdilikDuyuruYok,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final a in announcements)
                    _AnnouncementTile(
                      announcement: a,
                      unread: !read.contains(a.id),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _AnnouncementTile extends ConsumerWidget {
  const _AnnouncementTile({required this.announcement, required this.unread});

  final Announcement announcement;
  final bool unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      leading: unread
          ? Icon(Icons.circle, size: 12, color: theme.colorScheme.primary)
          : const Icon(Icons.circle_outlined, size: 12),
      title: Text(
        announcement.title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
      subtitle: Text(announcement.message),
      isThreeLine: true,
      onTap: unread
          ? () async {
              final user = ref.read(authStateProvider).value;
              if (user == null) return;
              await ref
                  .read(notificationRepositoryProvider)
                  .markAnnouncementRead(
                    userId: user.id,
                    announcementId: announcement.id,
                  );
              ref.invalidate(readAnnouncementIdsProvider);
            }
          : null,
    );
  }
}

Future<void> _openReminderDialog(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final user = ref.read(authStateProvider).value;
  if (user == null) return;
  final result = await showDialog<StudyReminder>(
    context: context,
    builder: (_) => _ReminderDialog(userId: user.id),
  );
  if (result == null) return;
  try {
    await ref.read(notificationRepositoryProvider).upsertReminder(result);
    ref.invalidate(myRemindersProvider);
  } on NotificationException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.authBeklenmeyenBirHataOlustu)),
      );
    }
  }
}

class _ReminderDialog extends StatefulWidget {
  const _ReminderDialog({required this.userId});

  final String userId;

  @override
  State<_ReminderDialog> createState() => _ReminderDialogState();
}

class _ReminderDialogState extends State<_ReminderDialog> {
  final _titleController = TextEditingController();
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  final Set<int> _weekdays = {};

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_titleController.text.isEmpty) {
      _titleController.text = AppLocalizations.of(
        context,
      ).notificationsCalismaZamani;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final weekdayLabels = _weekdayLabels(l10n);
    return AlertDialog(
      title: Text(l10n.notificationsYeniHatirlatici),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l10n.notificationsBaslik,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: Text(l10n.notificationsSaat),
              trailing: Text(
                _time.format(context),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (picked != null) setState(() => _time = picked);
              },
            ),
            const SizedBox(height: 8),
            Text(l10n.notificationsGunlerBosHerGun),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(weekdayLabels[d - 1]),
                    selected: _weekdays.contains(d),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _weekdays.add(d);
                      } else {
                        _weekdays.remove(d);
                      }
                    }),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.notificationsVazgec),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop(
              StudyReminder(
                id: '',
                userId: widget.userId,
                title: title,
                hour: _time.hour,
                minute: _time.minute,
                weekdays: _weekdays.toList()..sort(),
                createdAt: DateTime.now(),
              ),
            );
          },
          child: Text(l10n.notificationsKaydet),
        ),
      ],
    );
  }
}

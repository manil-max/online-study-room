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
import '../../data/repositories/notification_repository.dart';
import '../clock/alarms_screen.dart';

const List<String> _weekdayLabels = [
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
  'Paz',
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

    return Scaffold(
      appBar: AppBar(title: const Text('Bildirim Merkezi')),
      body: ListView(
        padding: getSafePadding(context, const EdgeInsets.fromLTRB(16, 12, 16, 28)),
        children: [
          const _PermissionCard(),
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
                    'Cihaz izinleri',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Bildirimler cihaz iznine bağlıdır. Alarm ve hatırlatıcılar yalnız '
              'Android’de yerel bildirim olarak çalışır; sistem izni kapalıysa '
              'gösterilmez. Uygulama kapalıyken tam-zamanlı teslim garanti edilmez.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () async {
                  final granted = await ref
                      .read(reminderNotificationServiceProvider)
                      .requestPermissionIfNeeded();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted
                            ? 'Bildirim izni verildi.'
                            : 'Bildirim izni verilmedi. Sistem ayarlarından açabilirsin.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Bildirim iznini kontrol et'),
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
    return _SectionCard(
      icon: Icons.tune,
      title: 'Bildirim türleri',
      subtitle: 'Hangi bildirimleri almak istediğini seç',
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.waving_hand_outlined),
          title: const Text('Dürtme bildirimleri'),
          subtitle: const Text('Sınıf arkadaşların seni dürttüğünde bildir'),
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
          secondary: const Icon(Icons.alarm_outlined),
          title: const Text('Çalışma hatırlatıcıları'),
          subtitle: const Text('Planladığın hatırlatıcıları yerel bildirimle al'),
          value: prefs.remindersEnabled,
          onChanged: notifier.setRemindersEnabled,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.campaign_outlined),
          title: const Text('Duyurular'),
          subtitle: const Text('Uygulama ve grup duyurularını göster'),
          value: prefs.announcementsEnabled,
          onChanged: notifier.setAnnouncementsEnabled,
        ),
        const Divider(height: 1),
        SwitchListTile(
          secondary: const Icon(Icons.new_releases_outlined),
          title: const Text('Güncelleme bildirimleri'),
          subtitle: const Text('Yeni sürüm çıkınca haber ver'),
          value: prefs.updatesEnabled,
          onChanged: notifier.setUpdatesEnabled,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.timer_outlined),
          title: const Text('Alarm ve zamanlayıcı'),
          subtitle: const Text('Saat sekmesinden yönetilir'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AlarmsScreen()),
          ),
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
    await ref.read(notificationPreferencesProvider.notifier).setQuietHours(
          startMinutes: isStart ? minutes : prefs.quietStartMinutes,
          endMinutes: isStart ? prefs.quietEndMinutes : minutes,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationPreferencesProvider.notifier);
    return _SectionCard(
      icon: Icons.bedtime_outlined,
      title: 'Sessiz saatler',
      subtitle: 'Bu aralıkta dürtme ve hatırlatıcı bildirimi gösterilmez',
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.do_not_disturb_on_outlined),
          title: const Text('Sessiz saatleri etkinleştir'),
          value: prefs.quietHoursEnabled,
          onChanged: notifier.setQuietHoursEnabled,
        ),
        if (prefs.quietHoursEnabled) ...[
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.bedtime),
            title: const Text('Başlangıç'),
            trailing: Text(
              _formatMinutes(prefs.quietStartMinutes),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () => _pickTime(context, ref, isStart: true),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Bitiş'),
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

    return _SectionCard(
      icon: Icons.alarm_add_outlined,
      title: 'Hatırlatıcılar',
      subtitle: 'Belirli saatlerde çalışma hatırlatıcısı kur',
      children: [
        remindersAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Hatırlatıcılar yüklenemedi: $e'),
          ),
          data: (reminders) {
            if (reminders.isEmpty) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Text(
                  'Henüz hatırlatıcın yok. Aşağıdan bir tane ekleyebilirsin.',
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
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: () => _openReminderDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Hatırlatıcı ekle'),
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

  String get _daysLabel {
    if (reminder.weekdays.isEmpty) return 'Her gün';
    final sorted = [...reminder.weekdays]..sort();
    if (sorted.length == 7) return 'Her gün';
    return sorted.map((d) => _weekdayLabels[d - 1]).join(', ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(reminder.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
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
        subtitle: Text(_daysLabel),
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

    return _SectionCard(
      icon: Icons.campaign_outlined,
      title: 'Duyurular',
      subtitle: 'Uygulama ve grubuna özel duyurular',
      children: [
        if (!prefs.announcementsEnabled)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Duyurular kapalı. Görmek için üstteki “Duyurular” anahtarını aç.',
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
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Duyurular yüklenemedi: $e'),
            ),
            data: (announcements) {
              if (announcements.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Şimdilik duyuru yok.',
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
              await ref.read(notificationRepositoryProvider).markAnnouncementRead(
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
  } on NotificationException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
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
  final _titleController = TextEditingController(text: 'Çalışma zamanı');
  TimeOfDay _time = const TimeOfDay(hour: 20, minute: 0);
  final Set<int> _weekdays = {};

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Yeni hatırlatıcı'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Başlık',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.access_time),
              title: const Text('Saat'),
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
            const Text('Günler (boş = her gün)'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(_weekdayLabels[d - 1]),
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
          child: const Text('Vazgeç'),
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
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

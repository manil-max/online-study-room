import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/notifications/alarm_notification_service.dart';
import '../../core/time_engine/alarm_scheduler.dart';
import '../../core/time_engine/clock_permissions.dart';
import '../../core/time_engine/exact_alarm_permission.dart';
import '../../data/models/alarm_rule.dart';
import '../../data/providers/alarm_providers.dart';
import 'alarm_ringing_screen.dart';

class AlarmsScreen extends ConsumerWidget {
  const AlarmsScreen({super.key, this.embedded = false});

  /// Clock hub içinde gömülüyse AppBar gizlenir.
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alarmsState = ref.watch(alarmsProvider);
    final exactAsync = ref.watch(exactAlarmStatusProvider);

    final body = Column(
      children: [
        exactAsync.when(
          data: (status) {
            if (status != ExactAlarmStatus.denied) {
              return const SizedBox.shrink();
            }
            return MaterialBanner(
              content: Text(
                '${AppLocalizations.of(context).clockKesinAlarmIzniKapali} '
                '${AppLocalizations.of(context).clockSaatUygulamasiKalitesiIcin}',
              ),
              leading: const Icon(Icons.warning_amber_rounded),
              actions: [
                TextButton(
                  onPressed: () async {
                    await ref
                        .read(alarmNotificationServiceProvider)
                        .requestExactAlarmPermission();
                    ref.invalidate(exactAlarmStatusProvider);
                  },
                  child: Text(AppLocalizations.of(context).clockIzinVer),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        ),
        Expanded(
          child: alarmsState.when(
            data: (alarms) {
              if (alarms.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.alarm_off_outlined,
                          size: 56,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).clockHenuzBirAlarmOlusturmadiniz,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).clockTekrarlayanGunlerTekGunluk,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                itemCount: alarms.length,
                itemBuilder: (context, index) {
                  return _AlarmTile(alarm: alarms[index]);
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                AppLocalizations.of(context).authBeklenmeyenBirHataOlustu,
              ),
            ),
          ),
        ),
      ],
    );

    if (embedded) {
      return Scaffold(
        body: body,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(context, ref),
          icon: const Icon(Icons.add),
          label: Text(AppLocalizations.of(context).coreAlarm),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).clockKisiselAlarmlar),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppLocalizations.of(context).clockAlarmEkle,
            onPressed: () => _openEditor(context, ref),
          ),
        ],
      ),
      body: body,
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref, {
    AlarmRule? existing,
  }) async {
    // App-kapalı çalma için izinleri hatırlat / iste
    final perms = await ClockPermissions.instance.ensureForAlarm();
    if (!perms.allOk && context.mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context).clockAlarmIzinleri),
          content: Text(
            '${AppLocalizations.of(context).clockAppKapaliykenAlarmCalmasi}\n\n'
            '• ${perms.missingLabels(AppLocalizations.of(context)).join('\n• ')}\n\n'
            '${AppLocalizations.of(context).clockSimdiAyarlariAcmakIster}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).updaterSonra),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppLocalizations.of(context).clockIzinleriAc),
            ),
          ],
        ),
      );
      if (go == true) {
        if (!perms.notifications) {
          await ClockPermissions.instance.requestNotifications();
          await ClockPermissions.instance.openNotificationSettings();
        }
        if (!perms.exactAlarm) {
          await ClockPermissions.instance.openExactAlarmSettings();
        }
        if (!perms.batteryUnrestricted) {
          await ClockPermissions.instance.openBatterySettings();
        }
        if (!perms.fullScreenIntent) {
          await ClockPermissions.instance.openFullScreenSettings();
        }
      }
    }

    if (!context.mounted) return;
    final result = await showModalBottomSheet<AlarmRule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AlarmEditorSheet(initial: existing),
    );
    if (result != null) {
      await ref.read(alarmsProvider.notifier).saveAlarm(result);
    }
  }
}

class _AlarmTile extends ConsumerWidget {
  const _AlarmTile({required this.alarm});

  final AlarmRule alarm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final next = AlarmScheduler.nextFire(alarm, now);
    final skipActive =
        alarm.skipNextOn != null &&
        alarm.skipNextOn!.year == (next?.year ?? 0) &&
        alarm.skipNextOn!.month == (next?.month ?? 0) &&
        alarm.skipNextOn!.day == (next?.day ?? 0);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.timeLabel,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w300,
                          height: 1.05,
                          color: alarm.isActive
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (alarm.label.isNotEmpty) alarm.label,
                          alarm.daysSummary(AppLocalizations.of(context)),
                          if (alarm.antiSnooze)
                            AppLocalizations.of(context).clockAntisnooze,
                          if (alarm.crescendo)
                            AppLocalizations.of(context).clockKademeliSes,
                        ].join(' · '),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (next != null && alarm.isActive)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            skipActive
                                ? AppLocalizations.of(
                                    context,
                                  ).clockSonrakiAtlandi
                                : '${AppLocalizations.of(context).clockSiradakiAlarm}: '
                                      '${_fmtNext(context, next)}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Switch(
                  value: alarm.isActive,
                  onChanged: (v) {
                    ref.read(alarmsProvider.notifier).toggleAlarm(alarm.id, v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () {
                    ref
                        .read(alarmsProvider.notifier)
                        .skipNext(alarm.id, skip: !skipActive);
                  },
                  icon: Icon(
                    skipActive ? Icons.event_available : Icons.event_busy,
                    size: 18,
                  ),
                  label: Text(
                    skipActive
                        ? AppLocalizations.of(context).clockAtlamayGeriAl
                        : AppLocalizations.of(context).clockSonrakiniAtla,
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    await showModalBottomSheet<AlarmRule>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => _AlarmEditorSheet(initial: alarm),
                    ).then((r) {
                      if (r != null) {
                        ref.read(alarmsProvider.notifier).saveAlarm(r);
                      }
                    });
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(AppLocalizations.of(context).profileDuzenle),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final isAndroid = !kIsWeb && Platform.isAndroid;
                    if (isAndroid) {
                      // Native: USAGE_ALARM MediaPlayer + kilit ekranı
                      await ref
                          .read(alarmNotificationServiceProvider)
                          .previewNativeRing(alarm);
                      return;
                    }
                    if (!context.mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AlarmRingingScreen(alarm: alarm),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_circle_outline, size: 18),
                  label: Text(AppLocalizations.of(context).clockOnizle),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).profileSil,
                  onPressed: () {
                    ref.read(alarmsProvider.notifier).deleteAlarm(alarm.id);
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtNext(BuildContext context, DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final t = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(d));
    if (diff == 0) return '${l10n.coreBugun} $t';
    if (diff == 1) return '${l10n.coreYarin} $t';
    return '${DateFormat.Md(locale).format(d)} $t';
  }
}

class _AlarmEditorSheet extends StatefulWidget {
  const _AlarmEditorSheet({this.initial});

  final AlarmRule? initial;

  @override
  State<_AlarmEditorSheet> createState() => _AlarmEditorSheetState();
}

class _AlarmEditorSheetState extends State<_AlarmEditorSheet> {
  late TimeOfDay _time;
  late TextEditingController _label;
  late Set<int> _days;
  late bool _antiSnooze;
  late bool _crescendo;
  late bool _vibrate;
  late int _snooze;

  Map<int, String> _dayLabels(BuildContext context) => {
    1: AppLocalizations.of(context).statsPzt,
    2: AppLocalizations.of(context).statsSal,
    3: AppLocalizations.of(context).statsCar,
    4: AppLocalizations.of(context).statsPer,
    5: AppLocalizations.of(context).statsCum,
    6: AppLocalizations.of(context).statsCmt,
    7: AppLocalizations.of(context).statsPaz,
  };

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _time = i != null
        ? TimeOfDay(hour: i.hour, minute: i.minute)
        : TimeOfDay.now();
    _label = TextEditingController(text: i?.label ?? '');
    _days = {...?i?.days};
    _antiSnooze = i?.antiSnooze ?? false;
    _crescendo = i?.crescendo ?? true;
    _vibrate = i?.vibrate ?? true;
    _snooze = i?.snoozeMinutes ?? 5;
  }

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null
                  ? AppLocalizations.of(context).clockYeniAlarmYeniAlarm
                  : AppLocalizations.of(context).clockAlarmDuzenle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).profileSaat),
              trailing: Text(
                _time.format(context),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              onTap: () async {
                final t = await showTimePicker(
                  context: context,
                  initialTime: _time,
                );
                if (t != null) setState(() => _time = t);
              },
            ),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).clockEtiket,
                hintText: AppLocalizations.of(context).clockOrnSabahRutini,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).clockTekrar,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final d in _dayLabels(context).entries)
                  FilterChip(
                    label: Text(d.value),
                    selected: _days.contains(d.key),
                    onSelected: (sel) {
                      setState(() {
                        if (sel) {
                          _days.add(d.key);
                        } else {
                          _days.remove(d.key);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text(AppLocalizations.of(context).statsHaftaIci),
                  onPressed: () => setState(() => _days = {1, 2, 3, 4, 5}),
                ),
                ActionChip(
                  label: Text(AppLocalizations.of(context).notificationsHerGun),
                  onPressed: () =>
                      setState(() => _days = {1, 2, 3, 4, 5, 6, 7}),
                ),
                ActionChip(
                  label: Text(AppLocalizations.of(context).commonBirKez),
                  onPressed: () => setState(() => _days = {}),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).clockKademeliSes30Sn),
              subtitle: Text(
                AppLocalizations.of(context).clockCrescendoAniYuksekSes,
              ),
              value: _crescendo,
              onChanged: (v) => setState(() => _crescendo = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).clockAntisnooze),
              subtitle: Text(
                AppLocalizations.of(context).clockKapatmakIcinMatematikSorusu,
              ),
              value: _antiSnooze,
              onChanged: (v) => setState(() => _antiSnooze = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).clockTitresim),
              value: _vibrate,
              onChanged: (v) => setState(() => _vibrate = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppLocalizations.of(context).clockErteleme),
              trailing: DropdownButton<int>(
                value: _snooze,
                items: const [5, 10, 15, 20]
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(
                          AppLocalizations.of(context).clockMDk(m.toString()),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _snooze = v);
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                final alarm = AlarmRule(
                  id: widget.initial?.id ?? const Uuid().v4(),
                  hour: _time.hour,
                  minute: _time.minute,
                  days: _days.toList()..sort(),
                  label: _label.text.trim().isEmpty
                      ? AppLocalizations.of(context).clockYeniAlarm
                      : _label.text.trim(),
                  isActive: widget.initial?.isActive ?? true,
                  snoozeMinutes: _snooze,
                  skipNextOn: widget.initial?.skipNextOn,
                  antiSnooze: _antiSnooze,
                  crescendo: _crescendo,
                  vibrate: _vibrate,
                );
                Navigator.of(context).pop(alarm);
              },
              child: Text(AppLocalizations.of(context).profileKaydet),
            ),
          ],
        ),
      ),
    );
  }
}

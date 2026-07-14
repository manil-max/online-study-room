import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/time_engine/alarm_scheduler.dart';
import '../../core/utils/duration_format.dart';
import '../../data/providers/alarm_providers.dart';
import '../../data/providers/study_providers.dart';
import '../classroom/widgets/study_timer_card.dart';
import 'alarms_screen.dart';
import 'stopwatch_screen.dart';
import 'timers_screen.dart';
import 'widgets/standby_clock_view.dart';
import 'world_clock_screen.dart';

/// Saat Merkezi sekmeleri — tek satır ikon şeridi (kaydırma yok).
/// Sıra: Saat+Odak · Alarm · Timer · Krono · Dünya
/// (Widget/izinler → Ayarlar · Bildirim & izinler)
enum ClockTab { home, alarm, multiTimer, stopwatch, world }

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  ClockTab _tab = ClockTab.home;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if ((_tab == ClockTab.home) && mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTabChanged(ClockTab tab) => setState(() => _tab = tab);

  /// Saat + çalışma sayacı birleşik ana yüzey.
  Widget _buildHome(BuildContext context) {
    final theme = Theme.of(context);
    final timeStr = DateFormat.Hm().format(_now);
    final secStr = DateFormat('ss').format(_now);
    final dateStr = DateFormat(
      'EEEE, d MMMM',
      Localizations.localeOf(context).toLanguageTag(),
    ).format(_now);

    final alarms = ref.watch(alarmsProvider).asData?.value ?? const [];
    DateTime? next;
    String? nextLabel;
    for (final a in alarms.where((a) => a.isActive)) {
      final n = AlarmScheduler.nextFire(a, _now);
      if (n == null) continue;
      if (next == null || n.isBefore(next)) {
        next = n;
        nextLabel = a.label.isNotEmpty ? a.label : a.timeLabel;
      }
    }

    final study = ref.watch(studyTimerProvider);
    final studyRunning = study.isRunning;
    final live = (study.isRunning && study.startedAt != null)
        ? _now.difference(study.startedAt!).inSeconds
        : 0;
    final studySeconds = study.accumulatedSeconds + live;
    final target = study.phaseTargetSeconds;
    final studyDisplay = target == null
        ? studySeconds
        : (target - studySeconds).clamp(0, target);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Büyük saat
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  color: theme.colorScheme.onSurface,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14, left: 4),
                child: Text(
                  secStr,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w300,
                    color: theme.colorScheme.primary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          dateStr.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 1.4,
          ),
        ),
        if (next != null) ...[
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm),
              title: Text(
                AppLocalizations.of(context).clockAlarmDateformathmformatnext(
                  DateFormat.Hm().format(next),
                ),
              ),
              subtitle: Text(nextLabel ?? ''),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onTabChanged(ClockTab.alarm),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Çalışma sayacı — birleşik
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).clockCalismaOturumu,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      studyRunning
                          ? AppLocalizations.of(context).commonCalsyor
                          : AppLocalizations.of(context).desktopHazir,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: studyRunning
                            ? theme.colorScheme.primary
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatHms(studyDisplay),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w300,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        final n = ref.read(studyTimerProvider.notifier);
                        if (studyRunning) {
                          unawaited(n.stop());
                        } else {
                          n.start();
                        }
                      },
                      icon: Icon(studyRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        studyRunning
                            ? AppLocalizations.of(context).profileDurdur
                            : AppLocalizations.of(context).desktopBaslat,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          useSafeArea: true,
                          builder: (_) => const Padding(
                            padding: EdgeInsets.all(16),
                            child: SingleChildScrollView(
                              child: StudyTimerCard(),
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune),
                      label: Text(AppLocalizations.of(context).clockModDers),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).clockWidgetVeIzinler,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  /// Eşit genişlikte ikon+kısa etiket — kaydırma yok, tek ekrana sığar.
  Widget _buildIconStrip() {
    final items = <(ClockTab, IconData, String, Key)>[
      (
        ClockTab.home,
        Icons.schedule,
        AppLocalizations.of(context).profileSaat,
        Key('clock_tab_home'),
      ),
      (
        ClockTab.alarm,
        Icons.alarm,
        AppLocalizations.of(context).coreAlarm,
        Key('clock_tab_alarm'),
      ),
      (
        ClockTab.multiTimer,
        Icons.hourglass_empty,
        AppLocalizations.of(context).clockTimer,
        Key('clock_tab_timer'),
      ),
      (
        ClockTab.stopwatch,
        Icons.timer_outlined,
        AppLocalizations.of(context).clockKrono,
        Key('clock_tab_stopwatch'),
      ),
      (
        ClockTab.world,
        Icons.public,
        AppLocalizations.of(context).clockDunya,
        Key('clock_tab_world'),
      ),
    ];

    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _StripItem(
                  key: item.$4,
                  icon: item.$2,
                  label: item.$3,
                  selected: _tab == item.$1,
                  onTap: () => _onTabChanged(item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_tab) {
      ClockTab.home => _buildHome(context),
      ClockTab.alarm => const AlarmsScreen(embedded: true),
      ClockTab.multiTimer => const TimersScreen(embedded: true),
      ClockTab.stopwatch => const StopwatchScreen(embedded: true),
      ClockTab.world => const WorldClockScreen(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (!isDesktopWindow && orientation == Orientation.landscape) {
          return const StandByClockView();
        }

        final content = _buildTabBody();

        // Windows: AppBar/sağ panel yok — sol rail + şerit + içerik.
        return Scaffold(
          appBar: isDesktopWindow
              ? null
              : AppBar(
                  title: Text(AppLocalizations.of(context).clockSaatMerkezi),
                  centerTitle: true,
                ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                child: _buildIconStrip(),
              ),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

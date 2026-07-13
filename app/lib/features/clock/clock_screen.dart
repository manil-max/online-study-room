import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/time_engine/alarm_scheduler.dart';
import '../../data/providers/alarm_providers.dart';
import '../../data/providers/study_providers.dart';
import '../classroom/widgets/study_timer_card.dart';
import '../desktop/desktop_page_scaffold.dart';
import 'alarms_screen.dart';
import 'stopwatch_screen.dart';
import 'timers_screen.dart';
import 'widgets/standby_clock_view.dart';
import 'world_clock_screen.dart';

/// Saat Merkezi sekmeleri (KALITE-PROGRAMI §8.4 Saat 2 IA).
enum ClockTab {
  clock,
  world,
  alarm,
  multiTimer,
  stopwatch,
  focus,
}

class ClockScreen extends ConsumerStatefulWidget {
  const ClockScreen({super.key});

  @override
  ConsumerState<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends ConsumerState<ClockScreen> {
  ClockTab _tab = ClockTab.clock;
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_tab == ClockTab.clock && mounted) {
        setState(() => _now = DateTime.now());
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onTabChanged(ClockTab tab) {
    setState(() => _tab = tab);

    // Odak sekmesine geçince study timer pomodoro/stopwatch hizası
    // yalnız sayaç duruyorken (V8-A state bozulmasın).
    final timerState = ref.read(studyTimerProvider);
    if (!timerState.isRunning && tab == ClockTab.focus) {
      // Varsayılan odak: pomodoro tercih edilmez — mevcut mod korunur.
    }
  }

  Widget _buildLocalClock(BuildContext context) {
    final timeStr = DateFormat.Hm().format(_now);
    final secStr = DateFormat('ss').format(_now);
    final dateStr = DateFormat('EEEE, d MMMM', 'tr_TR').format(_now);
    final theme = Theme.of(context);

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

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                      fontSize: 88,
                      fontWeight: FontWeight.w200,
                      color: theme.colorScheme.onSurface,
                      height: 1.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 18, left: 4),
                    child: Text(
                      secStr,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w300,
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              dateStr.toUpperCase(),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.6,
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: 28),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text('Sıradaki alarm · ${DateFormat.Hm().format(next)}'),
                  subtitle: Text(nextLabel ?? ''),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _onTabChanged(ClockTab.alarm),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.public, size: 18),
                  label: const Text('Dünya'),
                  onPressed: () => _onTabChanged(ClockTab.world),
                ),
                ActionChip(
                  avatar: const Icon(Icons.alarm, size: 18),
                  label: const Text('Alarm'),
                  onPressed: () => _onTabChanged(ClockTab.alarm),
                ),
                ActionChip(
                  avatar: const Icon(Icons.hourglass_bottom, size: 18),
                  label: const Text('Timer'),
                  onPressed: () => _onTabChanged(ClockTab.multiTimer),
                ),
                ActionChip(
                  avatar: const Icon(Icons.timer_outlined, size: 18),
                  label: const Text('Kronometre'),
                  onPressed: () => _onTabChanged(ClockTab.stopwatch),
                ),
                ActionChip(
                  avatar: const Icon(Icons.psychology_outlined, size: 18),
                  label: const Text('Odak'),
                  onPressed: () => _onTabChanged(ClockTab.focus),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Yatay çevir → StandBy masa saati',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelector({bool compact = false}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ClockTab>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment(
            value: ClockTab.clock,
            icon: Icon(Icons.schedule, key: compact ? null : const Key('clock_tab_clock')),
            label: compact ? null : const Text('Saat'),
          ),
          ButtonSegment(
            value: ClockTab.world,
            icon: const Icon(Icons.public, key: Key('clock_tab_world')),
            label: compact ? null : const Text('Dünya'),
          ),
          ButtonSegment(
            value: ClockTab.alarm,
            icon: const Icon(Icons.alarm, key: Key('clock_tab_alarm')),
            label: compact ? null : const Text('Alarm'),
          ),
          ButtonSegment(
            value: ClockTab.multiTimer,
            icon: const Icon(Icons.hourglass_empty, key: Key('clock_tab_timer')),
            label: compact ? null : const Text('Timer'),
          ),
          ButtonSegment(
            value: ClockTab.stopwatch,
            icon: const Icon(Icons.timer_outlined, key: Key('clock_tab_stopwatch')),
            label: compact ? null : const Text('Kronometre'),
          ),
          ButtonSegment(
            value: ClockTab.focus,
            icon: const Icon(Icons.av_timer, key: Key('clock_tab_focus')),
            label: compact ? null : const Text('Odak'),
          ),
        ],
        selected: {_tab},
        onSelectionChanged: (set) => _onTabChanged(set.first),
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_tab) {
      ClockTab.clock => _buildLocalClock(context),
      ClockTab.world => const WorldClockScreen(embedded: true),
      ClockTab.alarm => const AlarmsScreen(embedded: true),
      ClockTab.multiTimer => const TimersScreen(embedded: true),
      ClockTab.stopwatch => const StopwatchScreen(embedded: true),
      ClockTab.focus => const Padding(
          padding: EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topCenter,
            child: StudyTimerCard(),
          ),
        ),
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

        if (isDesktopWindow) {
          return DesktopPageScaffold(
            title: 'Saat Merkezi',
            subtitle:
                'Dünya saati, alarm, çoklu timer, kronometre ve odak oturumu.',
            icon: Icons.schedule_outlined,
            actions: [
              FilledButton.tonalIcon(
                onPressed: toggleDesktopCompactMode,
                icon: const Icon(Icons.picture_in_picture_alt_outlined),
                label: const Text('Compact Focus'),
              ),
            ],
            child: SingleChildScrollView(
              child: DesktopContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModeSelector(),
                    const SizedBox(height: 20),
                    DesktopResponsiveColumns(
                      breakpoint: 1040,
                      secondaryWidth: 300,
                      primary: DesktopPanel(
                        child: SizedBox(
                          height: 520,
                          child: content,
                        ),
                      ),
                      secondary: DesktopPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saat araçları',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            const _DesktopClockHint(
                              icon: Icons.alarm,
                              title: 'Exact alarm',
                              detail: 'Android 12+ kesin zamanlama',
                            ),
                            const _DesktopClockHint(
                              icon: Icons.timelapse,
                              title: 'Epoch motor',
                              detail: 'Doze dayanıklı süre',
                            ),
                            const _DesktopClockHint(
                              icon: Icons.keyboard_command_key,
                              title: 'Compact Focus',
                              detail: 'Ctrl + Shift + M',
                            ),
                            const Divider(height: 28),
                            Text(
                              'Odak sekmesi çalışma oturumunu (sunucu kayıtlı) yönetir. '
                              'Alarm ve çoklu timer cihaz yerelidir.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Saat Merkezi'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 420;
                    return _buildModeSelector(compact: compact);
                  },
                ),
              ),
              const SizedBox(height: 12),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

class _DesktopClockHint extends StatelessWidget {
  const _DesktopClockHint({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(detail),
      dense: true,
    );
  }
}

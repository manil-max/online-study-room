import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/desktop/desktop_window.dart';
import '../../data/providers/study_providers.dart';
import '../classroom/widgets/study_timer_card.dart';
import '../desktop/desktop_page_scaffold.dart';
import 'widgets/standby_clock_view.dart';

enum ClockTab { clock, stopwatch, countdown, pomodoro }

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

    final timerState = ref.read(studyTimerProvider);
    final notifier = ref.read(studyTimerProvider.notifier);

    // Yalnızca sayaç duruyorken modu değiştir
    if (!timerState.isRunning) {
      if (tab == ClockTab.stopwatch) {
        notifier.setMode(TimerMode.stopwatch);
      } else if (tab == ClockTab.countdown) {
        notifier.setMode(TimerMode.countdown);
      } else if (tab == ClockTab.pomodoro) {
        notifier.setMode(TimerMode.pomodoro);
      }
    }
  }

  Widget _buildClockView(BuildContext context) {
    final timeStr = DateFormat.Hm().format(_now);
    final dateStr = DateFormat('EEEE, d MMMM', 'tr_TR').format(_now);
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w300,
              color: theme.colorScheme.onSurface,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateStr.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector({bool compact = false}) {
    return SegmentedButton<ClockTab>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: ClockTab.clock,
          icon: const Icon(Icons.schedule),
          label: compact ? null : const Text('Saat'),
        ),
        ButtonSegment(
          value: ClockTab.stopwatch,
          icon: const Icon(Icons.timer_outlined),
          label: compact ? null : const Text('Kronometre'),
        ),
        ButtonSegment(
          value: ClockTab.countdown,
          icon: const Icon(Icons.hourglass_empty),
          label: compact ? null : const Text('Timer'),
        ),
        ButtonSegment(
          value: ClockTab.pomodoro,
          icon: const Icon(Icons.av_timer),
          label: compact ? null : const Text('Odak'),
        ),
      ],
      selected: {_tab},
      onSelectionChanged: (set) => _onTabChanged(set.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (!isDesktopWindow && orientation == Orientation.landscape) {
          return const StandByClockView();
        }

        Widget content;
        if (_tab == ClockTab.clock) {
          content = _buildClockView(context);
        } else {
          // Timer, Kronometre, Odak modları için mevcut sayacı göster
          content = const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.topCenter,
              child: StudyTimerCard(),
            ),
          );
        }

        if (isDesktopWindow) {
          return DesktopPageScaffold(
            title: 'Saat Merkezi',
            subtitle:
                'Saati izle, kronometreyi yönet veya yapılandırılmış bir odak oturumu başlat.',
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
                        child: SizedBox(height: 420, child: content),
                      ),
                      secondary: DesktopPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Odak araçları',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                            const _DesktopClockHint(
                              icon: Icons.keyboard_command_key,
                              title: 'Compact Focus',
                              detail: 'Ctrl + Shift + M',
                            ),
                            const _DesktopClockHint(
                              icon: Icons.push_pin_outlined,
                              title: 'Her zaman üstte',
                              detail: 'Ctrl + Shift + P',
                            ),
                            const Divider(height: 28),
                            Text(
                              'Sayaç çalışırken mod değiştirilmez. Oturumu durdurduktan sonra başka bir moda geçebilirsin.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
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
          appBar: AppBar(title: const Text('Saat Merkezi'), centerTitle: true),
          body: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 350;
                    return _buildModeSelector(compact: compact);
                  },
                ),
              ),
              const SizedBox(height: 24),
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

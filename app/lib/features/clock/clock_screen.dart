import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers/study_providers.dart';
import '../classroom/widgets/study_timer_card.dart';
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

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
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

        return Scaffold(
          appBar: AppBar(
            title: const Text('Saat Merkezi'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 350;
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

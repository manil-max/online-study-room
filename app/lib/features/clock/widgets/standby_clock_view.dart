import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';

class StandByClockView extends ConsumerStatefulWidget {
  const StandByClockView({super.key});

  @override
  ConsumerState<StandByClockView> createState() => _StandByClockViewState();
}

class _StandByClockViewState extends ConsumerState<StandByClockView> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(studyTimerProvider);
    final theme = Theme.of(context);

    final timeStr = DateFormat.Hm().format(_now);
    final dateStr = DateFormat('EEEE, d MMMM', 'tr_TR').format(_now);

    Widget? activeTimerWidget;
    if (timerState.isRunning) {
      final elapsed = timerState.startedAt != null
          ? _now.difference(timerState.startedAt!).inSeconds
          : 0;
      final target = timerState.phaseTargetSeconds;
      final displaySeconds = target == null
          ? elapsed
          : (target - elapsed).clamp(0, target);
      
      String modeText = '';
      if (timerState.mode == TimerMode.pomodoro) {
        modeText = timerState.phase == TimerPhase.work ? 'Odak' : 'Mola';
      } else if (timerState.mode == TimerMode.countdown) {
        modeText = 'Geri Sayım';
      } else {
        modeText = 'Kronometre';
      }

      activeTimerWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 8),
          Text(
            '$modeText: ${formatHms(displaySeconds)}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // StandBy için siyah arka plan
      body: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 200,
                    fontWeight: FontWeight.w200,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr.toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white.withValues(alpha: 0.5),
                    letterSpacing: 2,
                  ),
                ),
                if (activeTimerWidget != null) ...[
                  const SizedBox(height: 32),
                  activeTimerWidget,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

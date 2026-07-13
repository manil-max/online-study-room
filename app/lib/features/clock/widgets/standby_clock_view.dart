import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/time_engine/alarm_scheduler.dart';
import '../../../core/time_engine/burn_in_offset.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/alarm_providers.dart';
import '../../../data/providers/study_providers.dart';

/// Yatay masa saati — gece kırmızı ton + AMOLED burn-in kayması (WP-60).
class StandByClockView extends ConsumerStatefulWidget {
  const StandByClockView({super.key});

  @override
  ConsumerState<StandByClockView> createState() => _StandByClockViewState();
}

class _StandByClockViewState extends ConsumerState<StandByClockView> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  final _burnIn = BurnInOffset(amplitude: 14);

  @override
  void initState() {
    super.initState();
    // Sistem UI'yi gizle + gece düşük parlaklık (AMOLED masa saati)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _applyBrightness();
    _burnIn.tick(_now);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final n = DateTime.now();
      final hourChanged = n.hour != _now.hour;
      _burnIn.tick(n);
      setState(() => _now = n);
      if (hourChanged) _applyBrightness();
    });
  }

  void _applyBrightness() {
    final night = _now.hour >= 21 || _now.hour < 7;
    // 0.0–1.0 uygulama parlaklığı (null = sistem)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: night ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.black,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  bool get _isNight {
    final h = _now.hour;
    return h >= 21 || h < 7;
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(studyTimerProvider);
    final alarms = ref.watch(alarmsProvider).asData?.value ?? const [];

    final timeStr = DateFormat.Hm().format(_now);
    final dateStr = DateFormat('EEEE, d MMMM', 'tr_TR').format(_now);

    // Gece: düşük mavi / kırmızı-turuncu (melatonin dostu)
    final clockColor = _isNight
        ? const Color(0xFFB91C1C)
        : const Color(0xFFE2E8F0);
    final subColor = _isNight
        ? const Color(0xFF7F1D1D)
        : const Color(0xFF94A3B8);

    // Sıradaki alarm
    DateTime? nextAlarm;
    String? nextLabel;
    for (final a in alarms.where((a) => a.isActive)) {
      final n = AlarmScheduler.nextFire(a, _now);
      if (n == null) continue;
      if (nextAlarm == null || n.isBefore(nextAlarm)) {
        nextAlarm = n;
        nextLabel = a.label.isNotEmpty ? a.label : a.timeLabel;
      }
    }

    Widget? activeTimerWidget;
    if (timerState.isRunning) {
      final elapsed = timerState.startedAt != null
          ? _now.difference(timerState.startedAt!).inSeconds
          : 0;
      final target = timerState.phaseTargetSeconds;
      final displaySeconds = target == null
          ? elapsed
          : (target - elapsed).clamp(0, target);

      String modeText = switch (timerState.mode) {
        TimerMode.pomodoro =>
          timerState.phase == TimerPhase.work ? 'Odak' : 'Mola',
        TimerMode.countdown => 'Geri Sayım',
        TimerMode.stopwatch => 'Kronometre',
      };

      activeTimerWidget = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, color: clockColor, size: 22),
          const SizedBox(width: 8),
          Text(
            '$modeText: ${formatHms(displaySeconds)}',
            style: TextStyle(
              color: clockColor,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          // Tek dokunuş: immersive toggle (çıkış için orientation de yeter)
        },
        child: Center(
          child: Transform.translate(
            offset: Offset(_burnIn.dx, _burnIn.dy),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 200,
                        fontWeight: FontWeight.w200,
                        color: clockColor,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dateStr.toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: subColor,
                        letterSpacing: 2,
                      ),
                    ),
                    if (nextAlarm != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Alarm ${DateFormat.Hm().format(nextAlarm)}'
                        '${nextLabel != null ? ' · $nextLabel' : ''}',
                        style: TextStyle(
                          fontSize: 16,
                          color: subColor,
                        ),
                      ),
                    ],
                    if (activeTimerWidget != null) ...[
                      const SizedBox(height: 28),
                      activeTimerWidget,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

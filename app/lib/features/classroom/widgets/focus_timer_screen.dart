import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import 'clock_style.dart';

/// Tam ekran odak modunu açar (§3.12). Sistem çubukları gizlenir; çıkışta
/// (ekran kapanınca) geri yüklenir.
Future<void> openFocusTimer(BuildContext context) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const FocusTimerScreen(),
    ),
  );
}

/// Dikkat dağıtmayan tam ekran sayaç: yalnız büyük canlı süre + ders etiketi +
/// büyük başlat/durdur. "Başka kronometre gerekmesin" hedefi için sade odak modu.
class FocusTimerScreen extends ConsumerStatefulWidget {
  const FocusTimerScreen({super.key});

  @override
  ConsumerState<FocusTimerScreen> createState() => _FocusTimerScreenState();
}

class _FocusTimerScreenState extends ConsumerState<FocusTimerScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Tam ekran: sistem çubuklarını gizle (web'de etkisiz, sorun değil).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = ref.watch(studyTimerProvider);
    final notifier = ref.read(studyTimerProvider.notifier);
    final recorded = ref.watch(todayRecordedSecondsProvider);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    Subject? selected;
    for (final s in subjects) {
      if (s.id == timer.subjectId) selected = s;
    }

    final liveExtra = (timer.isRunning && timer.startedAt != null)
        ? DateTime.now().difference(timer.startedAt!).inSeconds
        : 0;
    final todayTotal = recorded + (liveExtra > 0 ? liveExtra : 0);
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    final pct = goalSeconds > 0 ? todayTotal / goalSeconds : 0.0;
    final clockStyle = ref.watch(clockStyleProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Builder(
                builder: (iconContext) => IconButton(
                  tooltip: 'Saat görünümü',
                  icon: const Icon(Icons.tune),
                  onPressed: () => showClockStyleMenu(iconContext, ref),
                ),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                tooltip: 'Küçült',
                icon: const Icon(Icons.fullscreen_exit),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 5,
                        backgroundColor: selected != null
                            ? subjectColor(selected.color)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        selected?.name ?? 'Genel',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Dar ekranda büyük saat taşmasın diye ölçekle (FittedBox).
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: StudyClock(
                        seconds: liveExtra,
                        pctToGoal: pct,
                        running: timer.isRunning,
                        style: clockStyle,
                        fontSize: 72,
                        diameter: 300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bugün ${formatHumanSeconds(todayTotal)}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 96,
                    height: 96,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        backgroundColor: timer.isRunning
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                      onPressed: timer.isRunning ? notifier.stop : notifier.start,
                      child: Icon(
                        timer.isRunning ? Icons.stop : Icons.play_arrow,
                        size: 44,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

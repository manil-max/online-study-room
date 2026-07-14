import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/subject.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';

class CompactFocusView extends ConsumerStatefulWidget {
  const CompactFocusView({super.key});

  @override
  ConsumerState<CompactFocusView> createState() => _CompactFocusViewState();
}

class _CompactFocusViewState extends ConsumerState<CompactFocusView> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(studyTimerProvider).isRunning) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int _displaySeconds(StudyTimerState state) {
    final startedAt = state.startedAt;
    if (!state.isRunning || startedAt == null) {
      return state.phaseTargetSeconds ?? 0;
    }
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final target = state.phaseTargetSeconds;
    return target == null ? elapsed : (target - elapsed).clamp(0, target);
  }

  String _subjectName(String? id, List<Subject> subjects) {
    if (id == null) return 'Ders seçilmedi';
    for (final subject in subjects) {
      if (subject.id == id) return subject.name;
    }
    return 'Ders seçilmedi';
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.value;
    final theme = Theme.of(context);

    if (user == null) {
      return Material(
        color: theme.colorScheme.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Çalışmayı kaydetmek için giriş yapmalısın.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: toggleDesktopCompactMode,
                  icon: const Icon(Icons.open_in_full),
                  label: const Text('Tam pencereye dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final state = ref.watch(studyTimerProvider);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    final running = state.isRunning;
    final status = state.phase == TimerPhase.rest
        ? 'Mola'
        : running
        ? 'Odaklanıyor'
        : 'Hazır';
    final mode = switch (state.mode) {
      TimerMode.stopwatch => 'Kronometre',
      TimerMode.countdown => 'Geri sayım',
      TimerMode.pomodoro => 'Pomodoro ${state.cycle}/${state.cycles}',
    };

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$status · $mode',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge,
                        ),
                        Text(
                          _subjectName(state.subjectId, subjects),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListenableBuilder(
                    listenable: desktopWindowListenable,
                    builder: (context, _) {
                      final pinned = isDesktopAlwaysOnTop;
                      return IconButton(
                        tooltip: pinned
                            ? 'Üstte tut açık — kapat'
                            : 'Her zaman üstte tut',
                        isSelected: pinned,
                        onPressed: toggleDesktopAlwaysOnTop,
                        icon: Icon(
                          pinned ? Icons.push_pin : Icons.push_pin_outlined,
                        ),
                        selectedIcon: Icon(
                          Icons.push_pin,
                          color: theme.colorScheme.primary,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Tam pencereye dön',
                    onPressed: toggleDesktopCompactMode,
                    icon: const Icon(Icons.open_in_full),
                  ),
                ],
              ),
              const Spacer(),
              Semantics(
                liveRegion: true,
                label: '$status, ${formatHms(_displaySeconds(state))}',
                child: Text(
                  formatHms(_displaySeconds(state)),
                  key: const ValueKey('compact-focus-time'),
                  style: theme.textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton.icon(
                  key: const ValueKey('compact-focus-toggle'),
                  onPressed: running
                      ? () => ref.read(studyTimerProvider.notifier).stop()
                      : ref.read(studyTimerProvider.notifier).start,
                  icon: Icon(running ? Icons.stop : Icons.play_arrow),
                  label: Text(running ? 'Durdur ve kaydet' : 'Başlat'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

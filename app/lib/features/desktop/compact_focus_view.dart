import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/subject.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';

class CompactFocusView extends ConsumerStatefulWidget {
  const CompactFocusView({
    super.key,
    this.onToggleCompact = toggleDesktopCompactMode,
    this.onTogglePin = toggleDesktopAlwaysOnTop,
  });

  /// Mini pencereden tam pencereye dönüş.
  final Future<void> Function() onToggleCompact;

  /// "Her zaman üstte" anahtarı.
  final Future<void> Function() onTogglePin;

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

  /// Mini pencere kabuğu **değiştirdiği** için `DesktopHomeShell` — ve onunla
  /// birlikte tüm `CallbackShortcuts` katmanı — ağaçtan çıkar. Ctrl+Shift+M
  /// yeniden bağlanmazsa mini pencere bir klavye tuzağıdır: tuş seni içeri
  /// sokar, dışarı çıkaramaz (WP-569 cihaz ölçümü).
  Widget _withCompactShortcuts(Widget child) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyM,
          control: true,
          shift: true,
        ): () =>
            widget.onToggleCompact(),
        const SingleActivator(
          LogicalKeyboardKey.keyP,
          control: true,
          shift: true,
        ): () =>
            widget.onTogglePin(),
      },
      child: Focus(autofocus: true, child: child),
    );
  }

  String _subjectName(String? id, List<Subject> subjects) {
    if (id == null) return AppLocalizations.of(context).desktopDersSecilmedi;
    for (final subject in subjects) {
      if (subject.id == id) return subject.name;
    }
    return AppLocalizations.of(context).desktopDersSecilmedi;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final user = auth.value;
    final theme = Theme.of(context);

    if (user == null) {
      return _withCompactShortcuts(
        Material(
          color: theme.colorScheme.surface,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_outline, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).desktopCalismayiKaydetmekIcinGiris,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: widget.onToggleCompact,
                    icon: const Icon(Icons.open_in_full),
                    label: Text(
                      AppLocalizations.of(context).desktopTamPencereyeDon,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final state = ref.watch(studyTimerProvider);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    final running = state.isRunning;
    final status = state.phase == TimerPhase.rest
        ? AppLocalizations.of(context).desktopMola
        : running
        ? AppLocalizations.of(context).desktopOdaklaniyor
        : AppLocalizations.of(context).desktopHazir;
    final mode = switch (state.mode) {
      TimerMode.stopwatch => AppLocalizations.of(context).desktopKronometre,
      TimerMode.countdown => AppLocalizations.of(context).desktopGeriSayim,
      TimerMode.pomodoro =>
        '${AppLocalizations.of(context).classroomPomodoro} '
            '${state.cycle}/${state.cycles}',
    };

    return _withCompactShortcuts(
      Material(
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
                              ? '${AppLocalizations.of(context).desktopUstteTut} · '
                                    '${AppLocalizations.of(context).desktopKapat}'
                              : AppLocalizations.of(
                                  context,
                                ).desktopHerZamanUstteTut,
                          isSelected: pinned,
                          onPressed: widget.onTogglePin,
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
                      tooltip: AppLocalizations.of(
                        context,
                      ).desktopTamPencereyeDon,
                      onPressed: widget.onToggleCompact,
                      icon: const Icon(Icons.open_in_full),
                    ),
                  ],
                ),
                // Mini pencere 320×180'e kadar küçülebiliyor. Sabit yükseklikli
                // saat + iki `Spacer` bu boyda Column'u taşırıyordu (ölçüm: 320×180'de
                // RenderFlex OVERFLOWING). Kalan alan saate verilir, sığmazsa
                // saat küçülür — pencere hiçbir boyda taşmaz.
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Semantics(
                        liveRegion: true,
                        label: AppLocalizations.of(context)
                            .desktopStatusFormathmsdisplaysecondsstate(
                              formatHms(_displaySeconds(state)),
                              status,
                            ),
                        child: Text(
                          formatHms(_displaySeconds(state)),
                          key: const ValueKey('compact-focus-time'),
                          style: theme.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: FilledButton.icon(
                    key: const ValueKey('compact-focus-toggle'),
                    onPressed: running
                        ? () => ref.read(studyTimerProvider.notifier).stop()
                        : ref.read(studyTimerProvider.notifier).start,
                    icon: Icon(running ? Icons.stop : Icons.play_arrow),
                    label: Text(
                      running
                          ? AppLocalizations.of(context).desktopDurdurVeKaydet
                          : AppLocalizations.of(context).desktopBaslat,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

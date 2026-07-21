import 'package:online_study_room/l10n/app_localizations.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/anchored_menu.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../home/dashboard_card.dart';
import '../../profile/session_history_screen.dart';
import '../../profile/subjects_screen.dart';
import '../../profile/widgets/goal_editor_dialog.dart';
import '../../profile/widgets/manual_session_dialog.dart';
import 'clock_style.dart';
import 'focus_timer_screen.dart';
import 'timer_mode_controls.dart';

/// Çalışma sayacı kartı: bugünkü toplam + canlı süre + başlat/durdur.
/// Her saniye yeniden çizmek için kendi periyodik zamanlayıcısı vardır.
/// [size] dar alana (küçük kart) uyum için: küçükken saat/yazılar küçülür.
class StudyTimerCard extends ConsumerStatefulWidget {
  const StudyTimerCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<StudyTimerCard> createState() => _StudyTimerCardState();
}

class _StudyTimerCardState extends ConsumerState<StudyTimerCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Idle'da saniyelik setState yok (Windows IndexedStack + ölçek altında jank).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTicker(ref.read(studyTimerProvider).isRunning);
    });
  }

  void _syncTicker(bool isRunning) {
    if (isRunning) {
      if (_ticker != null) return;
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      return;
    }
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Faz geçişi/bitişinde geri bildirim: ses + titreşim + (ekran öndeyse) uyarı.
  /// Kalıcı bildirim §5'e ait; burada yalnız uygulama-içi tetik (state machine
  /// olayı dışarı veriyor, UI tepki veriyor).
  void _onTimerEvent(TimerEvent event) {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.alert);
    final l10n = AppLocalizations.of(context);
    final msg = switch (event) {
      TimerEvent.workDone => l10n.classroomMola,
      TimerEvent.breakDone => l10n.classroomCalismayaBasla,
      TimerEvent.countdownDone => l10n.homeBitti,
      TimerEvent.allDone => l10n.homeBitti,
    };
    final route = ModalRoute.of(context);
    if (route?.isCurrent ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
    }
  }

  Future<void> _editGoal(BuildContext context, int currentMinutes) async {
    final result = await showGoalEditorDialog(
      context,
      initialMinutes: currentMinutes,
    );
    if (result == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final genericError = AppLocalizations.of(
      context,
    ).authBeklenmeyenBirHataOlustu;
    try {
      await ref.read(authRepositoryProvider).updateDailyGoal(result);
      ref.invalidate(authStateProvider);
    } on AuthException {
      messenger.showSnackBar(SnackBar(content: Text(genericError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = ref.watch(studyTimerProvider);
    // Çalışıyorsa saniyelik UI tick; durunca ticker kapalı (Windows perf).
    _syncTicker(timer.isRunning);
    final recorded = ref.watch(todayRecordedSecondsProvider);
    final todayKey = dayOf(DateTime.now());

    // Faz geçişinde ses/titreşim/uyarı (§2H).
    // WP-250: "durdurmada ekranı dondur" bloğu KALDIRILDI. Dondurulan değer
    // ekranın kendi gösterdiği sayıydı ve `stop()` sırasındaki kare çiziminde
    // zaten şişmiş olabiliyordu → hata kalıcılaşıyordu. Artık toplam, notifier'ın
    // bildirdiği settling* alanlarından türetilir (bkz. resolveTodayDisplayTotal).
    ref.listen<StudyTimerState>(studyTimerProvider, (prev, next) {
      if (prev == null) return;
      if (next.eventSeq != prev.eventSeq && next.lastEvent != null) {
        _onTimerEvent(next.lastEvent!);
      }
    });

    final now = DateTime.now();
    final elapsed = (timer.isRunning && timer.startedAt != null)
        ? now.difference(timer.startedAt!).inSeconds
        : 0;
    final target = timer.phaseTargetSeconds;
    final inWork = timer.phase == TimerPhase.work;
    // Büyük saat: kronometre yukarı sayar; geri sayım/pomodoro kalanı geri sayar
    // (dururken hedefin tamamını gösterir).
    final displaySeconds = target == null
        ? elapsed
        : (timer.isRunning ? (target - elapsed).clamp(0, target) : target);
    // Bugünün toplamına yalnız ÇALIŞMA fazının canlı süresi eklenir (mola hariç).
    // WP-250: durdurma başladığı an (isStopping) canlı akış kesilir; aradaki
    // saniyeler settling* alanlarıyla taşınır → ne zıplama ne düşme.
    final liveWork = (timer.isRunning && !timer.isStopping && inWork)
        ? elapsed
        : 0;
    final todayTotal = resolveTodayDisplayTotal(
      recordedToday: recorded,
      liveWorkSeconds: liveWork,
      settlingSeconds: timer.settlingSeconds,
      settlingBaseline: timer.settlingBaseline,
      settlingDay: timer.settlingDay,
      today: todayKey,
    );
    final notifier = ref.read(studyTimerProvider.notifier);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;
    final streak = ref.watch(currentStreakProvider);
    final pct = goalSeconds > 0
        ? (todayTotal / goalSeconds).clamp(0.0, 1.0)
        : 0.0;
    final reached = goalSeconds > 0 && todayTotal >= goalSeconds;
    // Saat halkası/renk geçişi: timer modunda FAZ ilerlemesi, kronometrede hedef.
    final clockPct = target == null
        ? pct
        : (target > 0 ? (elapsed / target).clamp(0.0, 1.0) : 0.0);
    final clockStyle = ref.watch(clockStyleProvider);

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final small = constraints.maxWidth < 280;
          final isLarge = constraints.maxWidth >= 400;

          return Stack(
            children: [
              // Saat görünümü + tam ekran odak modu (§3.12).
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      ).classroomGecmisOturumlar,
                      icon: const Icon(Icons.history),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SessionHistoryScreen(),
                        ),
                      ),
                    ),
                    Builder(
                      builder: (iconContext) => IconButton(
                        tooltip: AppLocalizations.of(
                          context,
                        ).classroomSaatGorunumu,
                        icon: const Icon(Icons.tune),
                        onPressed: () => showClockStyleMenu(iconContext, ref),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(
                        context,
                      ).classroomTamEkranOdak,
                      icon: const Icon(Icons.fullscreen),
                      onPressed: () => openFocusTimer(context),
                    ),
                  ],
                ),
              ),
              // Seri (streak) — yalnız varsa (§3.7).
              if (streak > 0)
                Positioned(
                  top: 14,
                  left: 14,
                  child: _StreakChip(streak: streak, compact: small),
                ),
              Padding(
                // Üstteki ikon/seri rozetiyle çakışmasın diye üst boşluk biraz fazla.
                padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context).classroomBugun,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Dar kartta taşmasın diye ölçekle.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatHumanSeconds(todayTotal),
                          maxLines: 1,
                          style: theme.textTheme.headlineMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: StudyClock(
                          seconds: displaySeconds,
                          pctToGoal: clockPct,
                          running: timer.isRunning,
                          style: clockStyle,
                          fontSize: small ? 34 : (isLarge ? 56 : 40),
                          diameter: small ? 130 : (isLarge ? 220 : 160),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Çalışırken faz göstergesi; dururken mod seçici + ayarlar.
                      if (timer.isRunning) ...[
                        TimerPhaseIndicator(timer: timer),
                        const SizedBox(height: 8),
                        TimerVerificationNotice(timer: timer),
                        if (timer.mode != TimerMode.stopwatch)
                          const SizedBox(height: 16),
                      ] else ...[
                        const TimerModeControls(),
                        const SizedBox(height: 16),
                      ],
                      _GoalProgress(
                        todaySeconds: todayTotal,
                        goalSeconds: goalSeconds,
                        pct: pct,
                        reached: reached,
                        onEdit: () => _editGoal(context, goalMinutes),
                      ),
                      const SizedBox(height: 16),
                      _SubjectSelector(
                        subjects: subjects,
                        selectedId: timer.subjectId,
                        running: timer.isRunning,
                        onSelect: notifier.selectSubject,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: timer.isRunning
                            ? FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: theme.colorScheme.error,
                                ),
                                onPressed: notifier.stop,
                                icon: const Icon(Icons.stop),
                                label: Text(
                                  AppLocalizations.of(context).classroomDurdur,
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: notifier.start,
                                icon: const Icon(Icons.play_arrow),
                                label: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).classroomCalismayaBasla,
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: () => addManualSessionFlow(context, ref),
                        icon: const Icon(Icons.edit_calendar, size: 18),
                        label: Text(
                          AppLocalizations.of(context).classroomManuelSureEkle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Sayaç için ders seçici — kapalıyken seçili dersi (veya "Genel"i) gösteren
/// bir "dropdown" hap; dururken dokununca ders listesi alt sayfası açılır
/// (Claude Code model seçici mantığı). Çalışırken kilitlidir (yalnız etiket).
/// Ders seçimi opsiyoneldir (§3.7).
class _SubjectSelector extends StatelessWidget {
  const _SubjectSelector({
    required this.subjects,
    required this.selectedId,
    required this.running,
    required this.onSelect,
  });

  final List<Subject> subjects;
  final String? selectedId;
  final bool running;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Subject? selected;
    for (final s in subjects) {
      if (s.id == selectedId) selected = s;
    }

    final dotColor = selected != null
        ? subjectColor(selected.color)
        : theme.colorScheme.onSurfaceVariant;
    final label = selected?.name ?? AppLocalizations.of(context).classroomGenel;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: dotColor),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.labelLarge),
        if (!running) ...[
          const SizedBox(width: 2),
          Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ],
    );

    // Çalışırken: kilitli etiket (değiştirilemez).
    if (running) {
      return Center(child: content);
    }

    // Dururken: dokununca seçim alt sayfası.
    return Center(
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openPicker(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: content,
          ),
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showAnchoredMenu<_SubjectMenuResult>(
      context: context,
      items: [
        PopupMenuItem<_SubjectMenuResult>(
          enabled: false,
          height: 32,
          child: Text(
            AppLocalizations.of(context).classroomDers,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        PopupMenuItem<_SubjectMenuResult>(
          value: const _SubjectMenuResult.pick(null),
          child: _subjectMenuRow(
            theme,
            'Genel (ders yok)',
            theme.colorScheme.onSurfaceVariant,
            selectedId == null,
          ),
        ),
        for (final s in subjects)
          PopupMenuItem<_SubjectMenuResult>(
            value: _SubjectMenuResult.pick(s.id),
            child: _subjectMenuRow(
              theme,
              s.name,
              subjectColor(s.color),
              selectedId == s.id,
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<_SubjectMenuResult>(
          value: const _SubjectMenuResult.edit(),
          child: Row(
            children: [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 12),
              Text(AppLocalizations.of(context).classroomDersleriDuzenle),
            ],
          ),
        ),
      ],
    );
    if (result == null) return;
    if (result.isEdit) {
      if (context.mounted) {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const SubjectsScreen()));
      }
      return;
    }
    onSelect(result.subjectId);
  }
}

/// Ders menüsü sonucu: bir ders seç (null = Genel) veya dersleri düzenle.
class _SubjectMenuResult {
  const _SubjectMenuResult.pick(this.subjectId) : isEdit = false;
  const _SubjectMenuResult.edit() : subjectId = null, isEdit = true;

  final String? subjectId;
  final bool isEdit;
}

Widget _subjectMenuRow(
  ThemeData theme,
  String label,
  Color dot,
  bool selected,
) {
  return Row(
    children: [
      CircleAvatar(radius: 6, backgroundColor: dot),
      const SizedBox(width: 12),
      Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
      if (selected)
        Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
    ],
  );
}

/// Günlük hedef ilerleme çubuğu — bugünkü süre / hedef + yüzde; hedefe ulaşınca
/// yeşile döner. Dokununca hedef düzenlenir (§3.7).
class _GoalProgress extends StatelessWidget {
  const _GoalProgress({
    required this.todaySeconds,
    required this.goalSeconds,
    required this.pct,
    required this.reached,
    required this.onEdit,
  });

  final int todaySeconds;
  final int goalSeconds;
  final double pct;
  final bool reached;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Hedefe ulaşınca yeşil (chart-2), yoksa birincil renk.
    final barColor = reached
        ? subjectColor('chart-2')
        : theme.colorScheme.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).classroomGunlukHedef,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '%${(pct * 100).round()}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: reached ? barColor : null,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 14, color: muted),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${formatHumanSeconds(todaySeconds)} / ${formatHumanSeconds(goalSeconds)}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hedef serisi rozeti: ateş ikonu + üst üste günlük hedef tutturulan gün sayısı.
/// [compact] (dar kart) modunda yalnız ikon + sayı gösterir.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak, this.compact = false});

  final int streak;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12, vertical: 6),
      decoration: BoxDecoration(
        color: subjectColor('chart-5').withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            size: compact ? 18 : 22,
            color: subjectColor('chart-5'),
          ),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: subjectColor('chart-5'),
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 3),
            Text(
              'hedef serisi',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

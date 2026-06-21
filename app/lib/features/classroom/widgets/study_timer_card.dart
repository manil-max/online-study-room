import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/anchored_menu.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../profile/subjects_screen.dart';
import '../../profile/widgets/goal_editor_dialog.dart';
import '../../profile/widgets/manual_session_dialog.dart';
import 'clock_style.dart';
import 'focus_timer_screen.dart';

/// Çalışma sayacı kartı: bugünkü toplam + canlı süre + başlat/durdur.
/// Her saniye yeniden çizmek için kendi periyodik zamanlayıcısı vardır.
class StudyTimerCard extends ConsumerStatefulWidget {
  const StudyTimerCard({super.key});

  @override
  ConsumerState<StudyTimerCard> createState() => _StudyTimerCardState();
}

class _StudyTimerCardState extends ConsumerState<StudyTimerCard> {
  Timer? _ticker;

  /// Durdur/Mola anında "Bugün" toplamını geçici dondurur: biten oturum
  /// veritabanına yazılıp kayıtlı toplam güncellenene kadar değer düşmesin.
  int? _frozenTotal;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _editGoal(BuildContext context, int currentMinutes) async {
    final result =
        await showGoalEditorDialog(context, initialMinutes: currentMinutes);
    if (result == null) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updateDailyGoal(result);
      ref.invalidate(authStateProvider);
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timer = ref.watch(studyTimerProvider);
    final recorded = ref.watch(todayRecordedSecondsProvider);

    // Durdurma anında o anki toplamı dondur (kayıtlı toplam yetişene kadar).
    ref.listen<StudyTimerState>(studyTimerProvider, (prev, next) {
      final wasRunning = prev?.isRunning ?? false;
      if (wasRunning && !next.isRunning && prev?.startedAt != null) {
        final extra = DateTime.now().difference(prev!.startedAt!).inSeconds;
        _frozenTotal =
            ref.read(todayRecordedSecondsProvider) + (extra > 0 ? extra : 0);
      }
    });

    final liveExtra = (timer.isRunning && timer.startedAt != null)
        ? DateTime.now().difference(timer.startedAt!).inSeconds
        : 0;
    final base = recorded + liveExtra;
    // Kayıtlı toplam dondurulan değere yetiştiyse dondurmayı bırak.
    if (_frozenTotal != null && base >= _frozenTotal!) _frozenTotal = null;
    final todayTotal = _frozenTotal ?? base;
    final notifier = ref.read(studyTimerProvider.notifier);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];

    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;
    final streak = ref.watch(currentStreakProvider);
    final pct =
        goalSeconds > 0 ? (todayTotal / goalSeconds).clamp(0.0, 1.0) : 0.0;
    final reached = goalSeconds > 0 && todayTotal >= goalSeconds;
    final clockStyle = ref.watch(clockStyleProvider);

    return Card(
      child: Stack(
        children: [
          // Saat görünümü + tam ekran odak modu (§3.12).
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                Builder(
                  builder: (iconContext) => IconButton(
                    tooltip: 'Saat görünümü',
                    icon: const Icon(Icons.tune),
                    onPressed: () => showClockStyleMenu(iconContext, ref),
                  ),
                ),
                IconButton(
                  tooltip: 'Tam ekran odak',
                  icon: const Icon(Icons.fullscreen),
                  onPressed: () => openFocusTimer(context),
                ),
              ],
            ),
          ),
          // Seri (streak) — yalnız varsa (§3.7).
          if (streak > 0)
            Positioned(top: 14, left: 14, child: _StreakChip(streak: streak)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  'Bugün',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatHumanSeconds(todayTotal),
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                StudyClock(
                  seconds: liveExtra,
                  pctToGoal: pct,
                  running: timer.isRunning,
                  style: clockStyle,
                  fontSize: 40,
                  diameter: 160,
                ),
                const SizedBox(height: 16),
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
                          label: const Text('Durdur'),
                        )
                      : FilledButton.icon(
                          onPressed: notifier.start,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Çalışmaya başla'),
                        ),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () => addManualSessionFlow(context, ref),
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Manuel süre ekle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sayaç için ders seçici — kapalıyken seçili dersi (veya "Genel") gösteren
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
    final label = selected?.name ?? 'Genel';

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
            'Ders',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        PopupMenuItem<_SubjectMenuResult>(
          value: const _SubjectMenuResult.pick(null),
          child: _subjectMenuRow(theme, 'Genel (ders yok)',
              theme.colorScheme.onSurfaceVariant, selectedId == null),
        ),
        for (final s in subjects)
          PopupMenuItem<_SubjectMenuResult>(
            value: _SubjectMenuResult.pick(s.id),
            child: _subjectMenuRow(
                theme, s.name, subjectColor(s.color), selectedId == s.id),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem<_SubjectMenuResult>(
          value: _SubjectMenuResult.edit(),
          child: Row(
            children: [
              Icon(Icons.tune, size: 20),
              SizedBox(width: 12),
              Text('Dersleri düzenle'),
            ],
          ),
        ),
      ],
    );
    if (result == null) return;
    if (result.isEdit) {
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SubjectsScreen()),
        );
      }
      return;
    }
    onSelect(result.subjectId);
  }
}

/// Ders menüsü sonucu: bir ders seç (null = Genel) veya "Dersleri düzenle".
class _SubjectMenuResult {
  const _SubjectMenuResult.pick(this.subjectId) : isEdit = false;
  const _SubjectMenuResult.edit()
      : subjectId = null,
        isEdit = true;

  final String? subjectId;
  final bool isEdit;
}

Widget _subjectMenuRow(
    ThemeData theme, String label, Color dot, bool selected) {
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
    final barColor = reached ? subjectColor('chart-2') : theme.colorScheme.primary;

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
                Text('Günlük hedef',
                    style: theme.textTheme.labelMedium?.copyWith(color: muted)),
                const Spacer(),
                Text('%${(pct * 100).round()}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: reached ? barColor : null,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(width: 6),
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

/// Seri (streak) rozeti: ateş ikonu + üst üste hedef tutturulan gün sayısı.
class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: subjectColor('chart-5').withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department,
              size: 22, color: subjectColor('chart-5')),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: subjectColor('chart-5'),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'günlük seri',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

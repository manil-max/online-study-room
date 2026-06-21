import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../../profile/widgets/manual_session_dialog.dart';

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

    return Card(
      child: Padding(
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
            Text(
              formatHms(liveExtra),
              style: theme.textTheme.displaySmall?.copyWith(
                fontFeatures: const [],
                color: timer.isRunning
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (subjects.isNotEmpty) ...[
              _SubjectSelector(
                subjects: subjects,
                selectedId: timer.subjectId,
                running: timer.isRunning,
                onSelect: notifier.selectSubject,
              ),
              const SizedBox(height: 16),
            ],
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
    );
  }
}

/// Sayaç için ders seçici. Dururken seçilebilir çipler; çalışırken seçili dersi
/// (veya "Derssiz") küçük etiket olarak gösterir. Ders seçimi opsiyoneldir.
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

    // Çalışırken: yalnızca aktif ders etiketi (değiştirilemez).
    if (running) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (selected != null) ...[
            CircleAvatar(radius: 5, backgroundColor: subjectColor(selected.color)),
            const SizedBox(width: 6),
            Text(selected.name, style: theme.textTheme.labelLarge),
          ] else
            Text(
              'Derssiz',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
        ],
      );
    }

    // Dururken: "Genel" (derssiz) + her ders için seçilebilir çip.
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Genel'),
          selected: selectedId == null,
          onSelected: (_) => onSelect(null),
        ),
        for (final s in subjects)
          ChoiceChip(
            avatar: CircleAvatar(
              radius: 6,
              backgroundColor: subjectColor(s.color),
            ),
            label: Text(s.name),
            selected: selectedId == s.id,
            onSelected: (_) => onSelect(s.id),
          ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../../profile/subjects_screen.dart';
import '../../profile/widgets/manual_session_dialog.dart';
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
      child: Stack(
        children: [
          // Tam ekran odak modu (§3.12).
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              tooltip: 'Tam ekran odak',
              icon: const Icon(Icons.fullscreen),
              onPressed: () => openFocusTimer(context),
            ),
          ),
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

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ders seç', style: theme.textTheme.titleMedium),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  radius: 6,
                  backgroundColor: theme.colorScheme.onSurfaceVariant,
                ),
                title: const Text('Genel (ders yok)'),
                trailing: selectedId == null
                    ? Icon(Icons.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () {
                  onSelect(null);
                  Navigator.pop(ctx);
                },
              ),
              for (final s in subjects)
                ListTile(
                  leading: CircleAvatar(
                    radius: 6,
                    backgroundColor: subjectColor(s.color),
                  ),
                  title: Text(s.name),
                  trailing: selectedId == s.id
                      ? Icon(Icons.check, color: theme.colorScheme.primary)
                      : null,
                  onTap: () {
                    onSelect(s.id);
                    Navigator.pop(ctx);
                  },
                ),
              const Divider(height: 8),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Dersleri düzenle'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SubjectsScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

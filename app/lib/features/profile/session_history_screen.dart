import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/study_stats.dart';
import '../../core/theme/subject_colors.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/study_session.dart';
import '../../data/models/subject.dart';
import '../../data/providers/group_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import 'widgets/manual_session_dialog.dart';

/// Çalışma kayıtları: kullanıcının oturumları (yeni → eski), güne göre gruplu.
/// Manuel süre ekleme, düzenleme ve silme (project.md §3.5 — esnek manuel giriş).
class SessionHistoryScreen extends ConsumerWidget {
  const SessionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionsAsync = ref.watch(userSessionsProvider);
    final hasGroup = ref.watch(userGroupProvider).value != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Çalışma kayıtlarım')),
      floatingActionButton: hasGroup
          ? FloatingActionButton.extended(
              onPressed: () => _addManual(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Manuel ekle'),
            )
          : null,
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Kayıtlar yüklenemedi: $e')),
        data: (sessions) {
          if (!hasGroup) {
            return _centerInfo(theme,
                'Kayıt eklemek için önce bir gruba katıl veya grup oluştur.');
          }
          if (sessions.isEmpty) {
            return _centerInfo(
                theme, 'Henüz kaydın yok. "Manuel ekle" ile geçmiş süre ekleyebilirsin.');
          }
          return _SessionList(sessions: sessions);
        },
      ),
    );
  }

  Widget _centerInfo(ThemeData theme, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );

  Future<void> _addManual(BuildContext context, WidgetRef ref) =>
      addManualSessionFlow(context, ref);
}

/// Oturumları güne göre gruplar. **Bugün** ayrı ayrı (saat aralığıyla); **geçmiş
/// günler** tek katlanabilir özet kayıtta toplanır — dokununca oturumlar açılır
/// (§3.10). Liste şişmez, eski günler tek satır.
class _SessionList extends ConsumerWidget {
  const _SessionList({required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = dayOf(DateTime.now());

    // Güne göre grupla (sessions zaten yeni → eski sıralı).
    final byDay = <DateTime, List<StudySession>>{};
    for (final s in sessions) {
      byDay.putIfAbsent(s.day, () => []).add(s);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        for (final day in days)
          if (isSameDay(day, today))
            _TodaySection(
              total: secondsOnDay(byDay[day]!, day),
              sessions: byDay[day]!,
            )
          else
            _PastDayTile(
              day: day,
              total: secondsOnDay(byDay[day]!, day),
              sessions: byDay[day]!,
            ),
      ],
    );
  }
}

/// Bugünün bölümü: başlık + her oturum ayrı satır (canlı takip).
class _TodaySection extends StatelessWidget {
  const _TodaySection({required this.total, required this.sessions});

  final int total;
  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Bugün', style: theme.textTheme.titleSmall),
              Text(
                formatHuman(total),
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
        ),
        for (final s in sessions) _SessionTile(session: s),
        const Divider(height: 16),
      ],
    );
  }
}

/// Geçmiş bir gün: katlanabilir tek özet kayıt (gün + toplam + oturum sayısı);
/// açılınca o günün oturumları görünür (düzenleme/silme yine mümkün).
class _PastDayTile extends StatelessWidget {
  const _PastDayTile({
    required this.day,
    required this.total,
    required this.sessions,
  });

  final DateTime day;
  final int total;
  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: const Border(),
      title: Row(
        children: [
          Expanded(
            child: Text(
              _longDate(day),
              style: theme.textTheme.titleSmall,
            ),
          ),
          Text(
            formatHuman(total),
            style: theme.textTheme.titleSmall
                ?.copyWith(color: theme.colorScheme.primary),
          ),
        ],
      ),
      subtitle: Text(
        '${sessions.length} oturum',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [for (final s in sessions) _SessionTile(session: s)],
    );
  }
}

/// Saat:dakika (iki haneli) — oturum saat aralığı için.
String _hm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

const _kMonths = [
  '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', //
  'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
];
const _kWeekdays = [
  '', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
];

/// "21 Haziran 2026 Cumartesi" — okunaklı uzun tarih.
String _longDate(DateTime d) =>
    '${d.day} ${_kMonths[d.month]} ${d.year} ${_kWeekdays[d.weekday]}';

/// Tek bir oturum satırı: süre, kaynak rozeti, düzenle/sil menüsü.
class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final StudySession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isManual = session.source == StudySource.manual;

    // Oturumun dersini bul (silinmiş/derssiz olabilir → null).
    final subjects = ref.watch(userSubjectsProvider).value ?? const [];
    Subject? subject;
    for (final s in subjects) {
      if (s.id == session.subjectId) subject = s;
    }
    // Hem sayaç hem manuel oturumda gerçek saat aralığı gösterilir; manuel giriş
    // artık eklendiği andaki saate "bitmiş gibi" yerleştiği için saat anlamlıdır
    // (manuel/sayaç ayrımı baştaki ikonla korunur: edit_calendar / timer).
    final sourceLabel = '${_hm(session.start)}–${_hm(session.end)}';

    return ListTile(
      leading: Icon(
        isManual ? Icons.edit_calendar : Icons.timer_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(formatHuman(session.durationSeconds)),
      subtitle: subject == null
          ? Text(sourceLabel)
          : Row(
              children: [
                CircleAvatar(
                    radius: 5, backgroundColor: subjectColor(subject.color)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    '$sourceLabel · ${subject.name}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) {
          if (v == 'edit') {
            _edit(context, ref);
          } else if (v == 'delete') {
            _delete(context, ref);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Düzenle')),
          PopupMenuItem(value: 'delete', child: Text('Sil')),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final subjects = ref.read(userSubjectsProvider).value ?? const [];
    final result = await showManualSessionDialog(
      context,
      initialDate: session.start,
      initialSeconds: session.durationSeconds,
      initialSubjectId: session.subjectId,
      subjects: subjects,
    );
    if (result == null) return;

    final range = manualSessionRange(result.date, result.seconds);
    await ref.read(studyRepositoryProvider).updateSession(
          StudySession(
            id: session.id,
            userId: session.userId,
            subjectId: result.subjectId,
            start: range.start,
            end: range.end,
            durationSeconds: result.seconds,
            // Düzenlenen oturum manuel sayılır (kaynak ayrımı istatistiği etkilemez).
            source: StudySource.manual,
          ),
        );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı sil'),
        content: const Text('Bu çalışma kaydı silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(studyRepositoryProvider).deleteSession(session.id);
  }
}

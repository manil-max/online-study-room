import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/desktop/desktop_window.dart';
import '../../core/tasks/task_deadline.dart';
import '../../core/tasks/task_sections.dart';
import '../../data/models/user_task.dart';
import '../../data/providers/user_task_providers.dart';
import 'clock_desktop_layout.dart';

/// Araçlar → Görevler: tam CRUD (WP-198), bölümlü bilgi mimarisi (WP-450).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Yazma sürerken aynı satırın ikinci kez tetiklenmesini engeller; çift tap
  /// aksi hâlde aynı occurrence'ı açıp kapatarak kullanıcıyı yanıltır.
  final Set<String> _pendingToggles = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openEditor({UserTask? existing}) async {
    final result = await showModalBottomSheet<_TaskDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _TaskEditorSheet(existing: existing),
    );
    if (result == null || !mounted) return;
    final actions = ref.read(userTaskActionsProvider);
    if (existing == null) {
      await actions.add(
        rawTitle: result.title,
        dueAt: result.dueAt,
        recurrence: result.recurrence,
        intervalDays: result.intervalDays,
      );
    } else {
      await actions.update(
        existing.copyWith(
          title: result.title,
          dueAt: result.dueAt,
          recurrence: result.recurrence,
          intervalDays: result.intervalDays,
          clearDueAt: result.dueAt == null,
          clearAnchorDate: result.recurrence != UserTaskRecurrence.daily,
        ),
      );
    }
  }

  /// Satır tamamlama + geri alma tek yoldan geçer: optimistic durum değiştiyse
  /// aynı occurrence'ı geri açan bir undo aksiyonu sunulur.
  Future<void> _toggle(UserTask task) async {
    if (_pendingToggles.contains(task.id)) return;
    setState(() => _pendingToggles.add(task.id));
    final wasCompleted = task.completed;
    try {
      await ref.read(userTaskActionsProvider).toggle(task.id);
    } finally {
      if (mounted) setState(() => _pendingToggles.remove(task.id));
    }
    if (!mounted) return;
    final current = ref
        .read(userTasksProvider)
        .value
        ?.where((item) => item.id == task.id)
        .firstOrNull;
    if (current == null || current.completed == wasCompleted) return;

    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${task.title} · ${current.completed ? l10n.taskListCompletedSemantic : l10n.taskListIncompleteSemantic}',
          ),
          action: SnackBarAction(
            label: l10n.taskListUndo,
            onPressed: () => _toggle(current),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(userTaskDayRefreshLifecycleProvider);
    final l10n = AppLocalizations.of(context);
    // Optimistic yazma arka planda hata verirse: state geri alınır + uyarı (WP-J).
    ref.listen(userTaskMutationErrorProvider, (prev, next) {
      if (prev == null) return;
      if (next <= prev || !mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger
        ?..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l10n.taskListSyncError)));
    });
    final allAsync = ref.watch(userTasksProvider);
    final now = DateTime.now();

    // 🔴 WP-678: iki sekmelik `TabBar` bandın tamamına yayılıyordu — ölçüm
    // 2560 px'lik pencerede "Aktif" → "Tamamlananlar" mesafesini **1319 px**
    // buldu (1920'de 999 px). SPEC KURAL 2.2 sert tavanı 600 px. Masaüstünde
    // şerit [kClockStripMaxWidth] ile sınırlanır ve sola hizalanır; sekme
    // sayısı, sırası ve denetleyicisi aynı kalır.
    final tabBar = TabBar(
      controller: _tabs,
      tabs: [
        Tab(text: l10n.taskListActive),
        Tab(text: l10n.taskListCompletedSection),
      ],
    );

    final body = Column(
      children: [
        if (isDesktopWindow)
          ClockCommandStrip(child: tabBar)
        else
          tabBar,
        Expanded(
          child: allAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _TaskSyncError(
              onRetry: () => ref.invalidate(userTasksProvider),
            ),
            data: (all) {
              final entries = groupTasksBySection([
                for (final t in all)
                  if (t.isRecurring || !t.completed) t,
              ], now);
              final done =
                  [
                    for (final t in all)
                      if (t.completed && !t.isRecurring) t,
                  ]..sort((a, b) {
                    final ac = a.completedAt ?? a.createdAt;
                    final bc = b.completedAt ?? b.createdAt;
                    return bc.compareTo(ac);
                  });
              return TabBarView(
                controller: _tabs,
                children: [
                  _TaskSectionedPane(
                    entries: entries,
                    now: now,
                    pending: _pendingToggles,
                    onToggle: _toggle,
                    onEdit: (t) => _openEditor(existing: t),
                    onDelete: (id) =>
                        ref.read(userTaskActionsProvider).remove(id),
                  ),
                  _TaskListPane(
                    entries: [
                      for (final task in done)
                        TaskSectionEntry(
                          task: task,
                          section: TaskSection.other,
                        ),
                    ],
                    now: now,
                    emptyLabel: l10n.taskListEmpty,
                    pending: _pendingToggles,
                    completedStyle: true,
                    onToggle: _toggle,
                    onEdit: (t) => _openEditor(existing: t),
                    onDelete: (id) =>
                        ref.read(userTaskActionsProvider).remove(id),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () => _openEditor(),
          tooltip: l10n.taskListAdd,
          child: const Icon(Icons.add),
        ),
        body: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.taskListTitle)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: l10n.taskListAdd,
        child: const Icon(Icons.add),
      ),
      body: body,
    );
  }
}

/// Aktif sekme: Bugün · Tekrarlanan · Diğer başlıklarıyla tek kaydırma yüzeyi.
class _TaskSectionedPane extends StatelessWidget {
  const _TaskSectionedPane({
    required this.entries,
    required this.now,
    required this.pending,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final List<TaskSectionEntry> entries;
  final DateTime now;
  final Set<String> pending;
  final ValueChanged<UserTask> onToggle;
  final ValueChanged<UserTask> onEdit;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (entries.isEmpty) {
      return Center(
        child: Text(
          l10n.taskListEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final sections = <(TaskSection, String)>[
      (TaskSection.today, l10n.taskListSectionToday),
      (TaskSection.recurring, l10n.taskListSectionRecurring),
      (TaskSection.other, l10n.taskListSectionOther),
    ];

    Widget row(TaskSectionEntry entry) => _TaskRow(
      entry: entry,
      now: now,
      busy: pending.contains(entry.task.id),
      onToggle: onToggle,
      onEdit: onEdit,
      onDelete: onDelete,
    );

    // 🔴 WP-678 masaüstü kolu: her BÖLÜM (Bugün · Tekrarlanan · Diğer) bir A2
    // bloğudur ve yan yana akar. Tek sütun 1392 px'lik bandı yiyordu; bölüm
    // sırası, başlıkları, sayaçları ve satır davranışı (tamamla / düzenle /
    // sil, tekrarlayan rozeti, sırası gelmemiş occurrence'ın tıklanamaz
    // olması) birebir korunur — yalnız bloklar yan yana dizilir.
    if (isDesktopWindow) {
      final blocks = <Widget>[];
      for (final (section, label) in sections) {
        final items = tasksInSection(entries, section);
        if (items.isEmpty) continue;
        blocks.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TaskSectionHeader(label: label, count: items.length),
              for (final entry in items) row(entry),
            ],
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
        children: [ClockBlockGrid(blocks: blocks)],
      );
    }

    final children = <Widget>[];
    for (final (section, label) in sections) {
      final items = tasksInSection(entries, section);
      if (items.isEmpty) continue;
      children.add(_TaskSectionHeader(label: label, count: items.length));
      for (final entry in items) {
        children.add(row(entry));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      children: children,
    );
  }
}

class _TaskSectionHeader extends StatelessWidget {
  const _TaskSectionHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 6),
      child: Semantics(
        header: true,
        child: Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tamamlananlar sekmesi: bölümsüz düz liste, satır tap'i geri alır.
class _TaskListPane extends StatelessWidget {
  const _TaskListPane({
    required this.entries,
    required this.now,
    required this.emptyLabel,
    required this.pending,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.completedStyle = false,
  });

  final List<TaskSectionEntry> entries;
  final DateTime now;
  final String emptyLabel;
  final Set<String> pending;
  final ValueChanged<UserTask> onToggle;
  final ValueChanged<UserTask> onEdit;
  final ValueChanged<String> onDelete;
  final bool completedStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (entries.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    Widget row(TaskSectionEntry entry) => _TaskRow(
      entry: entry,
      now: now,
      busy: pending.contains(entry.task.id),
      completedStyle: completedStyle,
      onToggle: onToggle,
      onEdit: onEdit,
      onDelete: onDelete,
    );

    // 🔴 WP-678 masaüstü kolu: düz liste gazete sütunlarına akıtılır.
    // [clockColumnChunks] BİTİŞİK böler, dönüşümlü değil — bu liste tamamlanma
    // tarihine göre sıralıdır ve dönüşümlü dağıtım sırayı okunamaz hâle
    // getirirdi. Hiçbir satır düşmez.
    if (isDesktopWindow) {
      // Sütun sayısı PENCEREDEN değil kalan BANTTAN okunur; 1920 px'lik
      // pencerede karar verilecek genişlik 1392 px'tir.
      return LayoutBuilder(
        builder: (context, constraints) {
          final chunks = clockColumnChunks(
            entries,
            clockBlockColumns(constraints.maxWidth),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 88),
            children: [
              ClockBlockGrid(
                blocks: [
                  for (final chunk in chunks)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < chunk.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          row(chunk[i]),
                        ],
                      ],
                    ),
                ],
              ),
            ],
          );
        },
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) => row(entries[i]),
    );
  }
}

/// Tek görev satırı.
///
/// Tüm satır tamamlama hedefidir; düzenle/sil ikincil kontrollerdir ve kendi
/// 48 dp dokunma alanlarıyla satır tap'ini yutmadan çalışır.
class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.entry,
    required this.now,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.completedStyle = false,
  });

  final TaskSectionEntry entry;
  final DateTime now;
  final bool busy;
  final ValueChanged<UserTask> onToggle;
  final ValueChanged<UserTask> onEdit;
  final ValueChanged<String> onDelete;
  final bool completedStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final task = entry.task;
    final color = taskUrgencyColor(now, task.dueAt, theme.colorScheme);
    final kind = taskUrgencyKind(now, task.dueAt);
    final overdue = !task.completed && kind == TaskUrgencyKind.overdue;
    final stateLabel = task.completed
        ? l10n.taskListCompletedSemantic
        : l10n.taskListIncompleteSemantic;
    // Sırası gelmemiş occurrence bugün kapatılamaz; satır tap'i kapalıdır ki
    // kullanıcı sessiz bir senkron hatasına koşmasın.
    final tappable = !busy && entry.nextOccurrenceDay == null;

    return MergeSemantics(
      child: Semantics(
        checked: task.completed,
        label: '${task.title}, $stateLabel',
        child: ListTile(
          minLeadingWidth: 40,
          onTap: tappable ? () => onToggle(task) : null,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : ExcludeSemantics(
                      child: Icon(
                        task.completed
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: task.completed
                            ? theme.colorScheme.primary
                            : color,
                      ),
                    ),
            ),
          ),
          title: Text(
            task.title,
            style: theme.textTheme.bodyLarge?.copyWith(
              decoration: task.completed ? TextDecoration.lineThrough : null,
              color: task.completed
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Rozet ve süre bilgisi başlıkla aynı satırı paylaşmaz: büyük metin
          // ölçeğinde tek satır zorlaması satırı taşırıyordu.
          subtitle: Wrap(
            spacing: 10,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (task.isRecurring) _RecurrenceBadge(task: task),
              _TaskRowSubtitle(
                entry: entry,
                now: now,
                overdue: overdue,
                color: completedStyle
                    ? theme.colorScheme.onSurfaceVariant
                    : color,
                completedStyle: completedStyle,
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: l10n.taskListEdit,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => onEdit(task),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: l10n.taskListDelete,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: () => onDelete(task.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecurrenceBadge extends StatelessWidget {
  const _RecurrenceBadge({required this.task});

  final UserTask task;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    // WP-480 kapsamı DIŞI: bu rozet listede ikon yanında duran **dar** bir
    // etikettir ve zaten aralığı söylüyor (`Her 3 günde bir`). Uzun özet
    // cümlesi buraya sığmaz; kısa sözcük dağarcığı bilinçli olarak korunuyor.
    final label = task.intervalDays > 1
        ? l10n.taskListRepeatEvery(task.intervalDays)
        : (task.completed ? '+1' : l10n.taskListDailyBadge);
    return Tooltip(
      message: label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRowSubtitle extends StatelessWidget {
  const _TaskRowSubtitle({
    required this.entry,
    required this.now,
    required this.overdue,
    required this.color,
    required this.completedStyle,
  });

  final TaskSectionEntry entry;
  final DateTime now;
  final bool overdue;
  final Color color;
  final bool completedStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final task = entry.task;
    final nextDay = entry.nextOccurrenceDay;

    if (nextDay != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_repeat_outlined, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              l10n.taskListNextOccurrence(
                taskDueDateLabel(now, nextDay, l10n.localeName),
              ),
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    if (task.dueAt == null) {
      return Text(
        // WP-480: liste satırı aralığı söylüyor; eskiden N ne olursa olsun
        // "Günlük yenilenen" yazıyordu.
        task.isRecurring
            ? taskRecurrenceSummary(l10n, task.intervalDays)
            : l10n.taskListNoDue,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          overdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            completedStyle
                ? taskDueDateLabel(now, task.dueAt!, l10n.localeName)
                : '${taskRemainingShort(l10n, now, task.dueAt)} · ${taskDueDateLabel(now, task.dueAt!, l10n.localeName)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TaskSyncError extends StatelessWidget {
  const _TaskSyncError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 32),
            const SizedBox(height: 8),
            Text(l10n.taskListSyncError, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.taskListRetry)),
          ],
        ),
      ),
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.recurrence,
    required this.intervalDays,
    this.dueAt,
  });
  final String title;
  final DateTime? dueAt;
  final UserTaskRecurrence recurrence;
  final int intervalDays;
}

class _TaskEditorSheet extends StatefulWidget {
  const _TaskEditorSheet({this.existing});
  final UserTask? existing;

  @override
  State<_TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends State<_TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _hours;
  late final TextEditingController _interval;
  DateTime? _pickedDate;
  late UserTaskRecurrence _recurrence;
  var _mode = 0; // 0 none, 1 date, 2 remaining

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _hours = TextEditingController(text: '24');
    _interval = TextEditingController(text: '${e?.intervalDays ?? 1}');
    _recurrence = e?.recurrence ?? UserTaskRecurrence.once;
    if (e?.dueAt != null) {
      _mode = 1;
      _pickedDate = e!.dueAt!.toLocal();
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _hours.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _pickedDate ?? now,
    );
    if (d == null) return;
    setState(() {
      _pickedDate = d;
      _mode = 1;
    });
  }

  void _submit() {
    final title = UserTask.normalizeTitle(_title.text);
    if (title == null) return;
    DateTime? due;
    if (_mode == 1 && _pickedDate != null) {
      due = dueAtFromCalendarDate(_pickedDate!);
    } else if (_mode == 2) {
      final h = int.tryParse(_hours.text.trim()) ?? 0;
      if (h > 0) due = dueAtFromRemaining(Duration(hours: h));
    }
    Navigator.pop(
      context,
      _TaskDraft(
        title: title,
        dueAt: due,
        recurrence: _recurrence,
        intervalDays: _draftIntervalDays,
      ),
    );
  }

  /// Formdaki geçerli tekrar aralığı. WP-480: hem gönderim hem de **metin**
  /// buradan okur; iki ayrı yerde ayrıştırılırsa etiket ile kaydedilen değer
  /// birbirinden kayar.
  int get _draftIntervalDays {
    if (_recurrence != UserTaskRecurrence.daily) return 1;
    return (int.tryParse(_interval.text.trim()) ?? 1).clamp(1, 365);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null ? l10n.taskListAdd : l10n.taskListEdit,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              autofocus: true,
              maxLength: UserTask.maxTitleLength,
              decoration: InputDecoration(
                hintText: l10n.taskListHint,
                border: const OutlineInputBorder(),
              ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              // WP-480: başlık ve ipucu seçilen aralığı söylüyor. Eskiden ikisi
              // de sabit "günlük" metniydi; ipucu N>1'de yanlış bilgi veriyordu
              // ("gece yarısı yeniden aktif olur" yalnız N=1 için doğru).
              title: Text(taskRecurrenceSummary(l10n, _draftIntervalDays)),
              subtitle: Text(taskRecurrenceHint(l10n, _draftIntervalDays)),
              value: _recurrence == UserTaskRecurrence.daily,
              onChanged: (daily) => setState(() {
                _recurrence = daily
                    ? UserTaskRecurrence.daily
                    : UserTaskRecurrence.once;
              }),
            ),
            if (_recurrence == UserTaskRecurrence.daily) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _interval,
                keyboardType: TextInputType.number,
                // Aralık değişince üstteki özet ve ipucu da tazelenir.
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.taskListRepeatIntervalLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(l10n.taskListNoDue)),
                ButtonSegment(value: 1, label: Text(l10n.taskListDueDate)),
                ButtonSegment(value: 2, label: Text(l10n.taskListRemaining)),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            const SizedBox(height: 8),
            if (_mode == 1)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _pickedDate == null
                      ? l10n.taskListDueDate
                      : '${_pickedDate!.year}-${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.day.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
            if (_mode == 2)
              TextField(
                controller: _hours,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.taskListRemaining,
                  suffixText: 'h',
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _submit,
              child: Text(
                widget.existing == null ? l10n.taskListAdd : l10n.taskListEdit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

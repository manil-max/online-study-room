import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/tasks/task_deadline.dart';
import '../../data/models/user_task.dart';
import '../../data/providers/user_task_providers.dart';

/// Araçlar → Görevler: tam CRUD (WP-198).
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

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
      );
    } else {
      await actions.update(
        existing.copyWith(
          title: result.title,
          dueAt: result.dueAt,
          recurrence: result.recurrence,
          clearDueAt: result.dueAt == null,
        ),
      );
    }
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

    final body = Column(
      children: [
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l10n.taskListActive),
            Tab(text: l10n.taskListCompletedSection),
          ],
        ),
        Expanded(
          child: allAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _TaskSyncError(
              onRetry: () => ref.invalidate(userTasksProvider),
            ),
            data: (all) {
              final active = sortUserTasksByDue([
                for (final t in all)
                  if (!t.completed || t.isDaily) t,
              ]);
              final done =
                  [
                    for (final t in all)
                      if (t.completed && !t.isDaily) t,
                  ]..sort((a, b) {
                    final ac = a.completedAt ?? a.createdAt;
                    final bc = b.completedAt ?? b.createdAt;
                    return bc.compareTo(ac);
                  });
              return TabBarView(
                controller: _tabs,
                children: [
                  _TaskListPane(
                    tasks: active,
                    now: now,
                    emptyLabel: l10n.taskListEmpty,
                    onToggle: (id) =>
                        ref.read(userTaskActionsProvider).toggle(id),
                    onEdit: (t) => _openEditor(existing: t),
                    onDelete: (id) =>
                        ref.read(userTaskActionsProvider).remove(id),
                  ),
                  _TaskListPane(
                    tasks: done,
                    now: now,
                    emptyLabel: l10n.taskListEmpty,
                    completedStyle: true,
                    onToggle: (id) =>
                        ref.read(userTaskActionsProvider).toggle(id),
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

class _TaskListPane extends StatelessWidget {
  const _TaskListPane({
    required this.tasks,
    required this.now,
    required this.emptyLabel,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.completedStyle = false,
  });

  final List<UserTask> tasks;
  final DateTime now;
  final String emptyLabel;
  final ValueChanged<String> onToggle;
  final ValueChanged<UserTask> onEdit;
  final ValueChanged<String> onDelete;
  final bool completedStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    if (tasks.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final task = tasks[i];
        final color = taskUrgencyColor(now, task.dueAt, theme.colorScheme);
        final kind = taskUrgencyKind(now, task.dueAt);
        final overdue = !task.completed && kind == TaskUrgencyKind.overdue;
        return ListTile(
          leading: IconButton(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            tooltip: task.completed
                ? l10n.taskListIncompleteSemantic
                : l10n.taskListCompletedSemantic,
            onPressed: () => onToggle(task.id),
            icon: Icon(
              task.completed
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: task.completed ? theme.colorScheme.primary : color,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: task.completed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
              if (task.isDaily) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: task.completed
                      ? l10n.taskListDailyStreakStep
                      : l10n.taskListDailyRefresh,
                  child: Semantics(
                    label: task.completed
                        ? l10n.taskListDailyStreakStep
                        : l10n.taskListDailyRefresh,
                    child: Icon(
                      Icons.repeat,
                      size: 17,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  task.completed ? '+1' : l10n.taskListDailyBadge,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
          subtitle: task.dueAt == null
              ? Text(
                  l10n.taskListNoDue,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              : Builder(
                  builder: (context) {
                    final subColor = completedStyle
                        ? theme.colorScheme.onSurfaceVariant
                        : color;
                    return Row(
                      children: [
                        Icon(
                          overdue
                              ? Icons.warning_amber_rounded
                              : Icons.schedule_rounded,
                          size: 14,
                          color: subColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            completedStyle
                                ? taskDueDateLabel(now, task.dueAt!)
                                : '${taskRemainingShort(l10n, now, task.dueAt)} · ${taskDueDateLabel(now, task.dueAt!)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: subColor,
                              fontWeight: overdue
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
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
        );
      },
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
  const _TaskDraft({required this.title, required this.recurrence, this.dueAt});
  final String title;
  final DateTime? dueAt;
  final UserTaskRecurrence recurrence;
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
  DateTime? _pickedDate;
  late UserTaskRecurrence _recurrence;
  var _mode = 0; // 0 none, 1 date, 2 remaining

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _hours = TextEditingController(text: '24');
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
      _TaskDraft(title: title, dueAt: due, recurrence: _recurrence),
    );
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
              title: Text(l10n.taskListDailyRefresh),
              subtitle: Text(l10n.taskListDailyRefreshHint),
              value: _recurrence == UserTaskRecurrence.daily,
              onChanged: (daily) => setState(() {
                _recurrence = daily
                    ? UserTaskRecurrence.daily
                    : UserTaskRecurrence.once;
              }),
            ),
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

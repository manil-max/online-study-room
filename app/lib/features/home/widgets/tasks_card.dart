import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/user_task.dart';
import '../../../data/providers/user_task_providers.dart';
import '../dashboard_card.dart';

/// Home dashboard: günlük/haftalık görev listesi (WP-188). XP bağı yok.
class TasksCard extends ConsumerStatefulWidget {
  const TasksCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<TasksCard> createState() => _TasksCardState();
}

class _TasksCardState extends ConsumerState<TasksCard> {
  TaskScope _scope = TaskScope.daily;

  Future<void> _addTask() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.taskListAdd),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: UserTask.maxTitleLength,
            decoration: InputDecoration(
              hintText: l10n.taskListHint,
              border: const OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: Text(l10n.taskListAdd),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (title == null || !mounted) return;
    await ref.read(userTaskActionsProvider).add(_scope, title);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(userTasksProvider(_scope));

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          // Minik / kısa hücrelerde taşmayı önle (dashboard render matrisi).
          final ultraCompact = h < 100 || w < 180;
          final compact = h < 160;

          final header = Row(
            children: [
              Icon(
                Icons.checklist_outlined,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.taskListTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!ultraCompact)
                Semantics(
                  button: true,
                  label: l10n.taskListAdd,
                  child: IconButton(
                    tooltip: l10n.taskListAdd,
                    icon: const Icon(Icons.add),
                    onPressed: _addTask,
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                ),
            ],
          );

          if (ultraCompact) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: header,
            );
          }

          final scopeToggle = SegmentedButton<TaskScope>(
            segments: [
              ButtonSegment(
                value: TaskScope.daily,
                label: Text(l10n.taskListDaily),
                icon: const Icon(Icons.today_outlined, size: 16),
              ),
              ButtonSegment(
                value: TaskScope.weekly,
                label: Text(l10n.taskListWeekly),
                icon: const Icon(Icons.date_range_outlined, size: 16),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (s) {
              if (s.isEmpty) return;
              setState(() => _scope = s.first);
            },
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );

          final body = tasksAsync.when(
            loading: () => const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => Center(
              child: Text(
                l10n.taskListEmpty,
                style: theme.textTheme.bodySmall,
              ),
            ),
            data: (tasks) {
              if (tasks.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      l10n.taskListEmpty,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _TaskTile(
                    task: task,
                    dense: compact,
                    onToggle: () => ref
                        .read(userTaskActionsProvider)
                        .toggle(_scope, task.id),
                    onDelete: () => ref
                        .read(userTaskActionsProvider)
                        .remove(_scope, task.id),
                  );
                },
              );
            },
          );

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                if (!compact) ...[
                  scopeToggle,
                  const SizedBox(height: 4),
                ],
                Expanded(child: body),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    this.dense = false,
  });

  final UserTask task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      decoration: task.completed ? TextDecoration.lineThrough : null,
      color: task.completed
          ? theme.colorScheme.onSurfaceVariant
          : theme.colorScheme.onSurface,
    );
    final minTap = dense ? 40.0 : 48.0;

    return Semantics(
      label: task.completed
          ? '${l10n.taskListCompletedSemantic}: ${task.title}'
          : '${l10n.taskListIncompleteSemantic}: ${task.title}',
      child: ListTile(
        dense: true,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 0,
        leading: IconButton(
          tooltip: task.completed
              ? l10n.taskListIncompleteSemantic
              : l10n.taskListCompletedSemantic,
          onPressed: onToggle,
          constraints: BoxConstraints(minWidth: minTap, minHeight: minTap),
          icon: Icon(
            task.completed
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: task.completed
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        ),
        title: Text(
          task.title,
          style: style,
          maxLines: dense ? 1 : 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: l10n.taskListDelete,
          onPressed: onDelete,
          constraints: BoxConstraints(minWidth: minTap, minHeight: minTap),
          icon: Icon(
            Icons.delete_outline,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

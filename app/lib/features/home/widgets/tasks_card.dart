import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/tasks/task_deadline.dart';
import '../../../data/models/user_task.dart';
import '../../../data/providers/user_task_providers.dart';
import '../dashboard_card.dart';

/// Home dashboard: görev listesi — gör + renk + işaretle (WP-199).
/// Ekleme/düzenleme yok (Araçlar sekmesi).
class TasksCard extends ConsumerWidget {
  const TasksCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;
  static const int _maxVisible = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userTaskDayRefreshLifecycleProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final tasksAsync = ref.watch(userTasksProvider);
    final now = DateTime.now();

    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;
          final ultraCompact = h < 100 || w < 180;
          final compact = h < 160;

          final activeCount = tasksAsync.maybeWhen(
            data: (all) => all.where((t) => !t.completed).length,
            orElse: () => 0,
          );

          final header = Row(
            children: [
              Icon(
                Icons.checklist_rounded,
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
              if (activeCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          );

          if (ultraCompact) {
            return Padding(padding: const EdgeInsets.all(8), child: header);
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Divider(
                  height: 12,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
                Expanded(
                  child: tasksAsync.when(
                    loading: () => const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, _) => _EmptyTasks(
                      label: l10n.taskListSyncError,
                      onRetry: () => ref.invalidate(userTasksProvider),
                    ),
                    data: (all) {
                      final active = sortUserTasksByDue([
                        for (final t in all)
                          if (!t.completed || t.isDaily) t,
                      ]);
                      if (active.isEmpty) {
                        return _EmptyTasks(label: l10n.taskListEmpty);
                      }
                      final show = active.take(TasksCard._maxVisible).toList();
                      final more = active.length - show.length;
                      return ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: show.length + (more > 0 ? 1 : 0),
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        itemBuilder: (context, i) {
                          if (i >= show.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                l10n.taskListMore(more),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }
                          return _HomeTaskTile(
                            task: show[i],
                            now: now,
                            dense: compact,
                            onToggle: () => ref
                                .read(userTaskActionsProvider)
                                .toggle(show[i].id),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.label, this.onRetry});

  final String label;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.task_alt_rounded,
            size: 30,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).taskListRetry),
            ),
          ],
        ],
      ),
    );
  }
}

class _HomeTaskTile extends StatelessWidget {
  const _HomeTaskTile({
    required this.task,
    required this.now,
    required this.onToggle,
    this.dense = false,
  });

  final UserTask task;
  final DateTime now;
  final VoidCallback onToggle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final color = taskUrgencyColor(now, task.dueAt, theme.colorScheme);
    final kind = taskUrgencyKind(now, task.dueAt);
    final overdue = kind == TaskUrgencyKind.overdue;
    final hasDue = task.dueAt != null;
    final remaining = taskRemainingShort(l10n, now, task.dueAt);

    return Semantics(
      button: true,
      label: overdue
          ? '${l10n.taskListOverdue}: ${task.title}'
          : '${task.completed ? l10n.taskListCompletedSemantic : l10n.taskListIncompleteSemantic}: ${task.title}',
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: dense ? 7 : 9, horizontal: 2),
          child: Row(
            children: [
              Icon(
                task.completed
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 20,
                color: task.completed ? theme.colorScheme.primary : color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: task.completed
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                    decoration: task.completed
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
              ),
              if (task.isDaily) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message: task.completed
                      ? l10n.taskListDailyStreakStep
                      : l10n.taskListDailyRefresh,
                  child: Icon(
                    Icons.repeat,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (task.completed)
                  Text(
                    '+1',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
              const SizedBox(width: 8),
              _RemainingChip(
                text: remaining,
                color: hasDue ? color : theme.colorScheme.onSurfaceVariant,
                filled: hasDue,
                strong: overdue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sağ uçta kalan-süre rozeti. Süreli görevlerde renk-dolgulu, süresizde düz.
class _RemainingChip extends StatelessWidget {
  const _RemainingChip({
    required this.text,
    required this.color,
    required this.filled,
    required this.strong,
  });

  final String text;
  final Color color;
  final bool filled;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }
}

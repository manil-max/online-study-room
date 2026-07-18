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
            ],
          );

          if (ultraCompact) {
            return Padding(
              padding: const EdgeInsets.all(8),
              child: header,
            );
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 4),
                Expanded(
                  child: tasksAsync.when(
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
                    data: (all) {
                      final active = sortUserTasksByDue([
                        for (final t in all)
                          if (!t.completed) t,
                      ]);
                      if (active.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.taskListEmpty,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      }
                      final show = active.take(_maxVisible).toList();
                      final more = active.length - show.length;
                      return ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          for (final task in show)
                            _HomeTaskTile(
                              task: task,
                              now: now,
                              dense: compact,
                              onToggle: () => ref
                                  .read(userTaskActionsProvider)
                                  .toggle(task.id),
                            ),
                          if (more > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                l10n.taskListMore(more),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
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
    final minTap = dense ? 40.0 : 48.0;

    return Semantics(
      label: overdue
          ? '${l10n.taskListOverdue}: ${task.title}'
          : '${l10n.taskListIncompleteSemantic}: ${task.title}',
      child: ListTile(
        dense: true,
        visualDensity: dense ? VisualDensity.compact : VisualDensity.standard,
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 0,
        leading: IconButton(
          tooltip: l10n.taskListCompletedSemantic,
          onPressed: onToggle,
          constraints: BoxConstraints(minWidth: minTap, minHeight: minTap),
          icon: Icon(Icons.radio_button_unchecked, color: color),
        ),
        title: Text(
          task.title,
          maxLines: dense ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        trailing: overdue
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.taskListOverdue,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Icon(Icons.circle, size: 10, color: color),
      ),
    );
  }
}

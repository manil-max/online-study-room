import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/tasks/task_deadline.dart';
import '../../../core/tasks/task_sections.dart';
import '../../../data/providers/user_task_providers.dart';
import '../../android_widgets/widget_deep_link.dart';
import '../dashboard_card.dart';
import 'card_scaffold.dart';

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

          // Rozet yalnız bugün işlem bekleyen görevleri sayar; sırası gelmemiş
          // tekrarlanan görev kullanıcıya bugünün borcu gibi görünmemeli.
          final activeCount = tasksAsync.maybeWhen(
            data: (all) => tasksInSection(
              groupTasksBySection([
                for (final t in all)
                  if (t.isRecurring || !t.completed) t,
              ], now),
              TaskSection.today,
            ).where((entry) => !entry.task.completed).length,
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
              // WP-799: baslik diger TUM pano kartlariyla ayni sozlesmeden
              // gelir ([cardTitle] -> titleMedium). Burasi tek istisnaydi
              // (titleSmall + w700), yani ayni panoda iki farkli baslik olcusu.
              Expanded(child: cardTitle(context, l10n.taskListTitle)),
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
            return Padding(padding: const EdgeInsets.all(16), child: header);
          }

          // WP-799: ic bosluk artik [CardScaffold]'un varsayilani (`all(16)`)
          // ile ayni; eskiden bu kart tek basina `fromLTRB(12, 8, 12, 6)` ve
          // `all(8)` kullaniyordu ve panoda kartlarin kenari hizalanmiyordu.
          return Padding(
            padding: const EdgeInsets.all(16),
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
                  // 🔴 WP-799: govde artik kendi yuksekligini BILIR.
                  // Once kart her hucrede ayni 6 satiri denerdi; `all(16)`
                  // ic bosluguyla dar telefonun tam hucresinde bu 26 px
                  // tasiyordu (olcum: `card_scroll_inventory_test.dart`),
                  // yani son satir kullanicinin gormedigi bir kaydiricinin
                  // icinde kaliyordu. Kaydirici hala guvenlik agi, ama artik
                  // normal durum degil.
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) => tasksAsync.when(
                      loading: () => const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, _) => _EmptyTasks(
                        label: l10n.taskListSyncError,
                        actionLabel: l10n.taskListRetry,
                        onAction: () => ref.invalidate(userTasksProvider),
                      ),
                      data: (all) {
                        // Kart önce "bugün ne var" sorusunu yanıtlar: Bugün
                        // bölümü üstte, ileri tarihliler ve sırası gelmemiş
                        // tekrarlananlar altında kalır (WP-450).
                        final entries = groupTasksBySection([
                          for (final t in all)
                            if (t.isRecurring || !t.completed) t,
                        ], now);
                        final active = [
                          ...tasksInSection(entries, TaskSection.today),
                          ...tasksInSection(entries, TaskSection.other),
                          ...tasksInSection(entries, TaskSection.recurring),
                        ];
                        if (active.isEmpty) {
                          // 🔴 WP-799: [_EmptyTasks] bir eylem parametresi
                          // TASIYORDU ama yalniz hata dali onu geciyordu; bos dal
                          // cikissizdi. Kart bilerek bir ekleme yuzeyi degil
                          // (WP-199), o yuzden eylem kullaniciyi gorevlerin
                          // gercek ekranina goturur. Iki seviyeli rota
                          // (`Araclar` sekmesi + `ClockTab.tasks`) icin hazir
                          // mekanizma `widget_deep_link.dart`tadir; ikinci
                          // seviyeyi `clock_screen.dart` kendi cozer.
                          return _EmptyTasks(
                            label: l10n.taskListEmpty,
                            actionLabel: l10n.taskListAdd,
                            onAction: () => ref
                                .read(widgetRouteProvider.notifier)
                                .open(WidgetRoute.tasks),
                          );
                        }
                        // Satir yuksekligi: satirin en uzun ogesi kalan-sure
                        // rozetidir (`_RemainingChip`: 2 x 3 px dolgu +
                        // labelSmall satiri) = 22 px; ustune `_HomeTaskTile`in
                        // dikey boslugu ve 1 px ayirici. 22 TAHMIN DEGIL:
                        // `card_scroll_inventory_test.dart` 20 ile genis
                        // telefonun iki hucresinde 4.0 px tasma olctu.
                        final rowHeight = 22 + 2 * (compact ? 7 : 9) + 1;
                        var capacity = bodyConstraints.hasBoundedHeight
                            ? (bodyConstraints.maxHeight / rowHeight).floor()
                            : TasksCard._maxVisible;
                        capacity = capacity.clamp(1, TasksCard._maxVisible);
                        // "+N daha" satiri da bir liste ogesidir ve yer kaplar;
                        // sigmayacaksa gosterilen satir sayisindan dusulur.
                        if (active.length > capacity && capacity > 1) {
                          capacity -= 1;
                        }
                        final show = active.take(capacity).toList();
                        final more = active.length - show.length;
                        return ListView.separated(
                          // WP-508: bayrak verilmezse dikey `ListView`
                          // `AlwaysScrollableScrollPhysics`e düşer ve sığan
                          // içerikte bile sürüklemeyi yutar.
                          physics: kCardOverflowScrollPhysics,
                          primary: false,
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
                            final entry = show[i];
                            return _HomeTaskTile(
                              entry: entry,
                              now: now,
                              dense: compact,
                              // Sırası gelmemiş occurrence tamamlanamaz; tap
                              // kapalıdır ki kullanıcı hataya koşmasın.
                              onToggle: entry.nextOccurrenceDay != null
                                  ? null
                                  : () => ref
                                        .read(userTaskActionsProvider)
                                        .toggle(entry.task.id),
                            );
                          },
                        );
                      },
                    ),
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
  const _EmptyTasks({required this.label, this.actionLabel, this.onAction});

  final String label;

  /// Eylem etiketi. WP-799'a kadar sabit "Tekrar dene" idi, yani dugme yalniz
  /// hata dalinda anlamliydi ve bos dal onu hic kullanamiyordu.
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 🔴 WP-799: bos/hata durumu bir eylem dugmesi TASIYOR, yani bu
    // blok kartin en uzun bos durumu. Kisa hucrede olculdu: eylemle birlikte
    // 3.0 px tasiyor ve `RenderFlex` uyarisi veriyordu (yani dugmenin bir
    // kismi hic gorunmuyordu). WP-508 sozlesmesi: sigiyorsa jest dis sayfaya
    // gider, tasiyorsa kart kendi icinde kayar.
    final body = Center(
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
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 6),
            TextButton(
              key: const Key('tasks-card-empty-action'),
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      // Sinirsiz yukseklikte kaydirici KURULMAZ (viewport sinirsiz kisit
      // alamaz); o kontrol [cardScrollIfOverflows] belgesinde cagirana birakildi.
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? cardScrollIfOverflows(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: body,
              ),
            )
          : body,
    );
  }
}

class _HomeTaskTile extends StatelessWidget {
  const _HomeTaskTile({
    required this.entry,
    required this.now,
    required this.onToggle,
    this.dense = false,
  });

  final TaskSectionEntry entry;
  final DateTime now;
  final VoidCallback? onToggle;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final task = entry.task;
    final nextDay = entry.nextOccurrenceDay;
    final color = nextDay != null
        ? theme.colorScheme.onSurfaceVariant
        : taskUrgencyColor(now, task.dueAt, theme.colorScheme);
    final kind = taskUrgencyKind(now, task.dueAt);
    final overdue = nextDay == null && kind == TaskUrgencyKind.overdue;
    final hasDue = nextDay == null && task.dueAt != null;
    final remaining = nextDay != null
        ? taskDueDateLabel(now, nextDay, l10n.localeName)
        : taskRemainingShort(l10n, now, task.dueAt);

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
              if (task.isRecurring) ...[
                const SizedBox(width: 6),
                Tooltip(
                  // WP-480: ana ekran kartı da aynı özet fonksiyonundan okur.
                  message: task.completed && task.intervalDays == 1
                      ? l10n.taskListDailyStreakStep
                      : taskRecurrenceSummary(l10n, task.intervalDays),
                  child: Icon(
                    Icons.repeat,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                ),
                if (task.completed && task.intervalDays == 1)
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

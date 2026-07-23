import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../core/desktop/desktop_window.dart';
import 'alarms_screen.dart';
import 'tasks_screen.dart';
import 'timers_screen.dart';

/// Araçlar sekmeleri — Alarm · Timer · Görevler.
/// Yön değişimi ürün yüzeyini değiştirmez; yatayda da aynı Araçlar akışı kalır.
enum ClockTab { alarm, multiTimer, tasks }

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> {
  ClockTab _tab = ClockTab.alarm;

  void _onTabChanged(ClockTab tab) => setState(() => _tab = tab);

  /// Eşit genişlikte ikon+kısa etiket — kaydırma yok, tek ekrana sığar.
  Widget _buildIconStrip() {
    final items = <(ClockTab, IconData, String, Key)>[
      (
        ClockTab.alarm,
        Icons.alarm,
        AppLocalizations.of(context).coreAlarm,
        Key('clock_tab_alarm'),
      ),
      (
        ClockTab.multiTimer,
        Icons.hourglass_empty,
        AppLocalizations.of(context).clockTimer,
        Key('clock_tab_timer'),
      ),
      (
        ClockTab.tasks,
        Icons.checklist_outlined,
        AppLocalizations.of(context).clockTasks,
        Key('clock_tab_tasks'),
      ),
    ];

    return Material(
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          children: [
            for (final item in items)
              Expanded(
                child: _StripItem(
                  key: item.$4,
                  icon: item.$2,
                  label: item.$3,
                  selected: _tab == item.$1,
                  onTap: () => _onTabChanged(item.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBody() {
    return switch (_tab) {
      ClockTab.alarm => const AlarmsScreen(embedded: true),
      ClockTab.multiTimer => const TimersScreen(embedded: true),
      ClockTab.tasks => const TasksScreen(embedded: true),
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildTabBody();

    // Windows: AppBar/sağ panel yok — sol rail + şerit + içerik.
    return Scaffold(
      appBar: isDesktopWindow
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context).navTools),
              centerTitle: true,
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: _buildIconStrip(),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

class _StripItem extends StatelessWidget {
  const _StripItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

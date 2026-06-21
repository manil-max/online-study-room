import 'package:flutter/material.dart';

import '../../../core/widgets/number_stepper.dart';

/// Günlük hedefi (saat + dakika) düzenleme diyaloğu (§3.7). Sonuç: yeni hedef
/// (toplam dakika) veya iptal → null. En az 15 dk.
Future<int?> showGoalEditorDialog(
  BuildContext context, {
  required int initialMinutes,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _GoalEditorDialog(initialMinutes: initialMinutes),
  );
}

class _GoalEditorDialog extends StatefulWidget {
  const _GoalEditorDialog({required this.initialMinutes});

  final int initialMinutes;

  @override
  State<_GoalEditorDialog> createState() => _GoalEditorDialogState();
}

class _GoalEditorDialogState extends State<_GoalEditorDialog> {
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialMinutes ~/ 60;
    _minutes = widget.initialMinutes % 60;
  }

  int get _total => _hours * 60 + _minutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Günlük hedef'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Her gün ulaşmak istediğin çalışma süresi. Seri (🔥) bu hedefe bağlı.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NumberStepper(
                  label: 'Saat',
                  value: _hours,
                  min: 0,
                  max: 23,
                  onChanged: (v) => setState(() => _hours = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NumberStepper(
                  label: 'Dakika',
                  value: _minutes,
                  min: 0,
                  max: 59,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _total < 15 ? null : () => Navigator.pop(context, _total),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

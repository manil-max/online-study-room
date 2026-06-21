import 'package:flutter/material.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../data/models/subject.dart';

/// Manuel süre girişi/düzenlemesi için diyalog. Tarih (gelecek olamaz) + saat/dakika
/// (+ opsiyonel ders) alır; sonucu `(date, seconds, subjectId)` döndürür. İptal → null.
/// Bkz. project.md §3.5 (manuel giriş esnek) ve §3.7 (ders opsiyonel).
Future<({DateTime date, int seconds, String? subjectId})?>
    showManualSessionDialog(
  BuildContext context, {
  DateTime? initialDate,
  int? initialSeconds,
  String? initialSubjectId,
  List<Subject> subjects = const [],
}) {
  return showDialog<({DateTime date, int seconds, String? subjectId})>(
    context: context,
    builder: (_) => _ManualSessionDialog(
      initialDate: initialDate,
      initialSeconds: initialSeconds,
      initialSubjectId: initialSubjectId,
      subjects: subjects,
    ),
  );
}

class _ManualSessionDialog extends StatefulWidget {
  const _ManualSessionDialog({
    this.initialDate,
    this.initialSeconds,
    this.initialSubjectId,
    this.subjects = const [],
  });

  final DateTime? initialDate;
  final int? initialSeconds;
  final String? initialSubjectId;
  final List<Subject> subjects;

  @override
  State<_ManualSessionDialog> createState() => _ManualSessionDialogState();
}

class _ManualSessionDialogState extends State<_ManualSessionDialog> {
  late DateTime _date;
  late int _hours;
  late int _minutes;
  late String? _subjectId;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    final secs = widget.initialSeconds ?? 0;
    _hours = secs ~/ 3600;
    _minutes = (secs % 3600) ~/ 60;
    _subjectId = widget.initialSubjectId;
  }

  bool get _isEdit => widget.initialSeconds != null;
  int get _totalSeconds => _hours * 3600 + _minutes * 60;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now, // gelecek tarih seçilemez
      locale: const Locale('tr'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = '${_date.day}.${_date.month}.${_date.year}';

    return AlertDialog(
      title: Text(_isEdit ? 'Süreyi düzenle' : 'Manuel süre ekle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Tarih'),
            subtitle: Text(dateLabel),
            trailing: TextButton(
              onPressed: _pickDate,
              child: const Text('Değiştir'),
            ),
          ),
          const SizedBox(height: 8),
          Text('Süre', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _NumberStepper(
                  label: 'Saat',
                  value: _hours,
                  min: 0,
                  max: 23,
                  onChanged: (v) => setState(() => _hours = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberStepper(
                  label: 'Dakika',
                  value: _minutes,
                  min: 0,
                  max: 59,
                  step: 5,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
              ),
            ],
          ),
          if (widget.subjects.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Ders (opsiyonel)', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Genel'),
                  selected: _subjectId == null,
                  onSelected: (_) => setState(() => _subjectId = null),
                ),
                for (final s in widget.subjects)
                  ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 6,
                      backgroundColor: subjectColor(s.color),
                    ),
                    label: Text(s.name),
                    selected: _subjectId == s.id,
                    onSelected: (_) => setState(() => _subjectId = s.id),
                  ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _totalSeconds <= 0
              ? null
              : () => Navigator.pop(
                    context,
                    (date: _date, seconds: _totalSeconds, subjectId: _subjectId),
                  ),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

/// Basit +/- sayaç (saat/dakika seçimi için).
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              onPressed: value > min
                  ? () => onChanged((value - step).clamp(min, max))
                  : null,
              icon: const Icon(Icons.remove),
            ),
            Text('$value', style: theme.textTheme.titleLarge),
            IconButton.filledTonal(
              onPressed: value < max
                  ? () => onChanged((value + step).clamp(min, max))
                  : null,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

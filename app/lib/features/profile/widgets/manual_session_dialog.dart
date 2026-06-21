import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';

/// Manuel süre ekleme akışı (her ekrandan çağrılabilir): aktif sınıf/kullanıcı
/// kontrolü + ders seçimli diyalog + `study_sessions`'a yazma. Oturumu seçilen
/// günün ortasına (12:00) yerleştirir. Sınıf yoksa kullanıcıyı uyarır.
Future<void> addManualSessionFlow(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authStateProvider).value;
  final group = ref.read(userGroupProvider).value;
  if (user == null || group == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Önce bir sınıfa katıl ya da sınıf oluştur.')),
    );
    return;
  }
  final subjects = ref.read(userSubjectsProvider).value ?? const [];
  final result = await showManualSessionDialog(context, subjects: subjects);
  if (result == null) return;

  final start =
      DateTime(result.date.year, result.date.month, result.date.day, 12, 0);
  await ref.read(studyRepositoryProvider).addSession(
        StudySession(
          id: const Uuid().v4(),
          userId: user.id,
          groupId: group.id,
          subjectId: result.subjectId,
          start: start,
          end: start.add(Duration(seconds: result.seconds)),
          durationSeconds: result.seconds,
          source: StudySource.manual,
        ),
      );
}

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

/// Basit +/- sayaç (saat/dakika seçimi için). +/- tuşuna **basılı tutunca**
/// sabit hızda artırıp azaltır (tek tek basmakla uğraşmamak için).
class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
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
            _HoldRepeatButton(
              icon: Icons.remove,
              enabled: value > min,
              onStep: () => onChanged((value - 1).clamp(min, max)),
            ),
            Text('$value', style: theme.textTheme.titleLarge),
            _HoldRepeatButton(
              icon: Icons.add,
              enabled: value < max,
              onStep: () => onChanged((value + 1).clamp(min, max)),
            ),
          ],
        ),
      ],
    );
  }
}

/// Dolgu-tonlu ikon buton: dokununca bir kez, **basılı tutunca** kısa bir
/// gecikmeden sonra sabit hızda tekrar tekrar [onStep] çağırır.
class _HoldRepeatButton extends StatefulWidget {
  const _HoldRepeatButton({
    required this.icon,
    required this.enabled,
    required this.onStep,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onStep;

  @override
  State<_HoldRepeatButton> createState() => _HoldRepeatButtonState();
}

class _HoldRepeatButtonState extends State<_HoldRepeatButton> {
  Timer? _delay;
  Timer? _repeat;

  void _start() {
    if (!widget.enabled) return;
    widget.onStep(); // ilk dokunuş hemen
    // Basılı tutulursa kısa gecikmeden sonra sabit hızda tekrarla.
    _delay = Timer(const Duration(milliseconds: 400), () {
      _repeat = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (widget.enabled) {
          widget.onStep();
        } else {
          _stop();
        }
      });
    });
  }

  void _stop() {
    _delay?.cancel();
    _repeat?.cancel();
    _delay = null;
    _repeat = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listener (gesture arena dışı) basışı güvenilir yakalar; IconButton yalnız
    // görsel/erişilebilirlik için (onPressed boş — gerçek artış Listener'da).
    return Listener(
      onPointerDown: widget.enabled ? (_) => _start() : null,
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: IconButton.filledTonal(
        onPressed: widget.enabled ? () {} : null,
        icon: Icon(widget.icon),
      ),
    );
  }
}

import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/widgets/number_stepper.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';

/// Manuel oturumu "eklendiği anda bitmiş gibi" yerleştirir (WP-107).
///
/// Takvim günü ve saat-dakika **Europe/Istanbul** wall-clock'undan alınır
/// (cihaz TZ'sinden bağımsız). `end` = seçilen günde İstanbul'un şu anki saati;
/// `start = end - süre`. Süre günün geçen kısmından uzunsa `start` İstanbul
/// 00:00'a kenetlenir. Dönüş değerleri UTC instant'tır (DB yazımı için).
({DateTime start, DateTime end}) manualSessionRange(
  DateTime date,
  int seconds, {
  DateTime? now,
}) {
  // istanbul_calendar import'u TZ verisini yükler.
  final loc = tz.getLocation('Europe/Istanbul');
  final istNow = now == null
      ? istanbulNow()
      : tz.TZDateTime.from(now.toUtc(), loc);

  final dayStart = tz.TZDateTime(loc, date.year, date.month, date.day);
  var end = tz.TZDateTime(
    loc,
    date.year,
    date.month,
    date.day,
    istNow.hour,
    istNow.minute,
  );
  var start = end.subtract(Duration(seconds: seconds));
  if (start.isBefore(dayStart)) {
    start = dayStart;
    end = start.add(Duration(seconds: seconds));
  }
  return (start: start.toUtc(), end: end.toUtc());
}

/// Manuel süre ekleme akışı (her ekrandan çağrılabilir): aktif kullanıcı
/// kontrolü + ders seçimli diyalog + `study_sessions`'a yazma. Oturumu seçilen
/// günde eklendiği andaki saatte bitmiş gibi yerleştirir ([manualSessionRange]).
/// Kullanıcı yoksa uyarır.
Future<void> addManualSessionFlow(BuildContext context, WidgetRef ref) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).profileOnceGirisYap)),
    );
    return;
  }
  final subjects = ref.read(userSubjectsProvider).value ?? [];
  final result = await showManualSessionDialog(context, subjects: subjects);
  if (result == null) return;

  final range = manualSessionRange(result.date, result.seconds);
  await ref
      .read(studyRepositoryProvider)
      .addSession(
        StudySession(
          id: Uuid().v4(),
          userId: user.id,
          subjectId: result.subjectId,
          start: range.start,
          end: range.end,
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
      locale: Locale('tr'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateLabel = '${_date.day}.${_date.month}.${_date.year}';

    return AlertDialog(
      title: Text(
        _isEdit
            ? AppLocalizations.of(context).profileSureyiDuzenle
            : AppLocalizations.of(context).profileManuelSureEkle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_today),
            title: Text(AppLocalizations.of(context).profileTarih),
            subtitle: Text(dateLabel),
            trailing: TextButton(
              onPressed: _pickDate,
              child: Text(AppLocalizations.of(context).profileDegistir),
            ),
          ),
          SizedBox(height: 8),
          Text(
            AppLocalizations.of(context).profileSure,
            style: theme.textTheme.labelLarge,
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NumberStepper(
                  label: AppLocalizations.of(context).profileSaat,
                  value: _hours,
                  min: 0,
                  max: 23,
                  onChanged: (v) => setState(() => _hours = v),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: NumberStepper(
                  label: AppLocalizations.of(context).profileDakika,
                  value: _minutes,
                  min: 0,
                  max: 59,
                  onChanged: (v) => setState(() => _minutes = v),
                ),
              ),
            ],
          ),
          if (widget.subjects.isNotEmpty) ...[
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).profileDersOpsiyonel,
              style: theme.textTheme.labelLarge,
            ),
            SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(AppLocalizations.of(context).profileGenel),
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
          child: Text(AppLocalizations.of(context).profileVazgec),
        ),
        FilledButton(
          onPressed: _totalSeconds <= 0
              ? null
              : () => Navigator.pop(context, (
                  date: _date,
                  seconds: _totalSeconds,
                  subjectId: _subjectId,
                )),
          child: Text(AppLocalizations.of(context).profileKaydet),
        ),
      ],
    );
  }
}

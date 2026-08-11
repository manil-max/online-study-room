import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../../core/prefs/app_prefs.dart';
import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/widgets/number_stepper.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';

/// Manuel oturumu "eklendiği anda bitmiş gibi" yerleştirir (WP-107; WP-203 gece
/// yarısı düzeltmesi).
///
/// Takvim günü ve saat-dakika **Europe/Istanbul** wall-clock'undan alınır
/// (cihaz TZ'sinden bağımsız).
/// - **Bugün** seçiliyse `end = gerçek şu an` (İstanbul), `start = end - süre`.
///   Süre uzunsa oturum gece yarısını doğal olarak aşar; günlük toplam
///   `dayOf(start)` ile hesaplandığından ilerleme **çoğunlukla çalışmanın olduğu
///   güne** (ör. dün akşamı) sayılır. **00:00 kenetleme yok → gelecek-bitiş yok.**
/// - **Geçmiş gün** seçiliyse `end = o günün 23:59:59`'u (gelecek-bitiş üretmez),
///   `start = end - süre`.
///
/// Dönüş değerleri UTC instant'tır (DB yazımı için).
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

  final isToday =
      date.year == istNow.year &&
      date.month == istNow.month &&
      date.day == istNow.day;

  // Bugün → gerçek şu an (dakika hassasiyeti); geçmiş gün → o günün sonu.
  final end = isToday
      ? tz.TZDateTime(
          loc,
          istNow.year,
          istNow.month,
          istNow.day,
          istNow.hour,
          istNow.minute,
        )
      : tz.TZDateTime(loc, date.year, date.month, date.day, 23, 59, 59);
  final start = end.subtract(Duration(seconds: seconds));
  return (start: start.toUtc(), end: end.toUtc());
}

/// WP-253: manuel eklemenin çalışan sayaçla çakışıp çakışmadığı (saf karar —
/// widget'sız test edilebilsin diye ayrı).
///
/// Yalnız **bugün + sayaç çalışıyor** kombinasyonu engellenir; geçmiş günlerde
/// manuel oturum o günün 23:59:59'unda biter, canlı oturumla kesişemez.
bool isManualAddBlocked({
  required DateTime date,
  required bool timerRunning,
  DateTime? now,
}) {
  if (!timerRunning) return false;
  return isSameDay(dayOf(date), dayOf(now ?? DateTime.now()));
}

/// WP-697: manuel kayıtta **son seçilen ders** (kullanıcı başına).
///
/// 🔴 Sayacın `selected_study_subject.<uid>` anahtarı bilerek PAYLAŞILMAZ.
/// İkisi farklı niyettir: sayaç "şu an ne çalışıyorum", manuel giriş "geçmişe
/// hangi dersi işliyorum". Paylaşılsaydı, Matematik sayacı çalışırken elle bir
/// Fizik kaydı girmek sayacın seçili dersini de Fizik'e çevirirdi. Ayrıca
/// `study_providers.dart` bu WP'nin sahip yollarında değil; oradaki özel sabiti
/// buradan kopyalamak iki dosyayı sessizce birbirine bağlardı.
const kManualSessionGeneralSubject = '__general__';

/// [kManualSessionGeneralSubject] ile aynı sözleşme: yazılmamış anahtar "hiç
/// seçim yapılmadı", sabit değer ise "bilinçli olarak Genel" demektir.
String manualSessionSubjectKey(String userId) =>
    'manual_session_subject.$userId';

/// Hatırlanan seçimi döndürür. Tercih yalnız **görünen listede varsa**
/// uygulanır: silinmiş/erişilemeyen ders yerelde diriltilmez, Genel'e düşer.
String? rememberedManualSubjectId(
  SharedPreferences prefs,
  String userId,
  List<Subject> subjects,
) {
  final stored = prefs.getString(manualSessionSubjectKey(userId));
  if (stored == null || stored == kManualSessionGeneralSubject) return null;
  return subjects.any((s) => s.id == stored) ? stored : null;
}

/// Seçimi kalıcılaştırır. `null` → Genel (silmek yerine sabit yazılır, yoksa
/// "hiç seçim yok" ile ayırt edilemezdi).
Future<void> rememberManualSubjectId(
  SharedPreferences prefs,
  String userId,
  String? subjectId,
) {
  return prefs.setString(
    manualSessionSubjectKey(userId),
    subjectId ?? kManualSessionGeneralSubject,
  );
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
  final subjectsAsync = ref.read(userSubjectsProvider);
  final subjects = subjectsAsync.value ?? <Subject>[];
  final prefs = ref.read(sharedPreferencesProvider);
  final result = await showManualSessionDialog(
    context,
    subjects: subjects,
    // WP-697: son seçim kalıcı; her açılışta Genel'e düşmez.
    initialSubjectId: rememberedManualSubjectId(prefs, user.id, subjects),
    // Ne ders var ne de sebebi: ekran sessizce boş kalmasın.
    subjectsError: subjects.isEmpty ? subjectsAsync.error : null,
  );
  if (result == null) return;

  // WP-253: bugüne manuel ekleme, çalışan sayacın aralığıyla FİZİKSEL olarak
  // çakışır (end = şimdi, start = şimdi - süre; sayaç da şu ana kadar sayıyor)
  // → aynı dakikalar iki kez toplanır. Geçmiş gün seçilirse `end = 23:59:59`
  // olduğundan çakışma imkânsız, o akış serbest bırakılır (geniş yasak meşru
  // kullanımı kırardı). Guard butona değil BU AKIŞA konur; `addManualSessionFlow`
  // hem sayaç kartından hem oturum geçmişi ekranından çağrılıyor.
  if (isManualAddBlocked(
    date: result.date,
    timerRunning: ref.read(studyTimerProvider).isRunning,
  )) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context).profileSayacCalisirkenEklenemez,
        ),
      ),
    );
    return;
  }

  // WP-697: çevrimdışıyken liste yerel aynadan gelebilir; o ayna sunucuda
  // silinmiş bir dersi gösteriyorsa yazılan satır `subject_id` yabancı anahtar
  // ihlaline düşer. Kayıt outbox'ta ölmesin diye, ELDE TAZE SUNUCU LİSTESİ
  // VARKEN doğrulanır ve gerekiyorsa Genel'e indirilir — sessizce değil,
  // kullanıcıya söylenerek.
  var subjectId = result.subjectId;
  final latest = ref.read(userSubjectsProvider);
  final confirmed = latest.hasError ? null : latest.value;
  if (subjectId != null &&
      confirmed != null &&
      !confirmed.any((s) => s.id == subjectId)) {
    subjectId = null;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).studySelectedSubjectUnavailable,
          ),
        ),
      );
    }
  }
  await rememberManualSubjectId(prefs, user.id, subjectId);

  final range = manualSessionRange(result.date, result.seconds);
  await ref
      .read(studyRepositoryProvider)
      .addSession(
        StudySession(
          id: Uuid().v4(),
          userId: user.id,
          subjectId: subjectId,
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
  Object? subjectsError,
}) {
  return showDialog<({DateTime date, int seconds, String? subjectId})>(
    context: context,
    builder: (_) => _ManualSessionDialog(
      initialDate: initialDate,
      initialSeconds: initialSeconds,
      initialSubjectId: initialSubjectId,
      subjects: subjects,
      subjectsError: subjectsError,
    ),
  );
}

class _ManualSessionDialog extends StatefulWidget {
  const _ManualSessionDialog({
    this.initialDate,
    this.initialSeconds,
    this.initialSubjectId,
    this.subjects = const [],
    this.subjectsError,
  });

  final DateTime? initialDate;
  final int? initialSeconds;
  final String? initialSubjectId;
  final List<Subject> subjects;

  /// Ders listesi hiç okunamadıysa sebebi (çevrimdışı + önbellek yok).
  final Object? subjectsError;

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
      // WP-526: locale VERILMEZ. Sabit `Locale('tr')` takvimi Ingilizce
      // kullaniciya da Turkce gosteriyordu; parametre bos birakilinca picker
      // ortamdaki (arayuzun) dilini kullanir.
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
                  label: AppLocalizations.of(context).classroomSaat,
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
          if (widget.subjects.isEmpty && widget.subjectsError != null) ...[
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(
                context,
              ).profileDerslerYuklenemediE('${widget.subjectsError}'),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
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

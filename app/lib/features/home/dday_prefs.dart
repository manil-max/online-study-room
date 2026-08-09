import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import '../../core/stats/istanbul_calendar.dart';

/// WP-575 — sınav geri sayımı için cihazda tutulan tek takvim tarihi.
///
/// Değer bir **an** değil **takvim günü**dür ve `YYYY-MM-DD` olarak saklanır.
/// Epoch milisaniyesi yazılsaydı geri okurken cihaz offset'ine bağlı bir *an*
/// elde edilirdi; UTC+3 dışındaki bir cihazda bu an kullanıcının seçtiği günün
/// bir öncesine/sonrasına düşerdi. Aynı sınıf hata bu depoda iki kez üretime
/// çıktı (WP-561, WP-571).
const kExamDateKey = 'dday.exam_date_v1';

/// Gün anahtarını prefs biçimine çevirir (`2026-06-20`).
String encodeExamDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Prefs değerini gün anahtarına çevirir; bozuk/eksik değer `null` döner —
/// kart o zaman "tarih seçilmedi" dalına düşer, çökmez.
DateTime? decodeExamDay(String? raw) {
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Seçilen sınav gününe kalan gün sayısı.
///
/// [examDay] kullanıcının seçtiği **takvim tarihi**dir; [now] bir **an**dır ve
/// ürünün tek gün sınırından — [istanbulDay] — geçirilir.
///
/// 🔴 Burada `examDay.difference(now).inDays` YAZILMAZ. İki değer farklı
/// türdedir ("gün" ve "an"), bu yüzden çıkan sayı cihaz saatine göre bir gün
/// oynar: UTC cihazda İstanbul 00:00–03:00 penceresinde bir gün **fazla**,
/// UTC+4 ve doğusunda İstanbul akşamında bir gün **eksik** çıkar. Tam bu hata
/// bu depoda iki kez üretime çıktı (WP-561 gün anahtarı çift çevrimi, WP-571
/// "Bugün özeti" kartının yanlış günü seçmesi).
int daysUntilExam({required DateTime examDay, required DateTime now}) {
  final today = istanbulDay(now);
  // Fark **takvim** farkıdır: iki uç da UTC'ye sabitlenir, böylece cihazın yaz
  // saati geçişindeki 23/25 saatlik günü `inDays` aşağı yuvarlayamaz.
  final from = DateTime.utc(today.year, today.month, today.day);
  final to = DateTime.utc(examDay.year, examDay.month, examDay.day);
  return to.difference(from).inDays;
}

/// Geri sayımın test edilebilir tek saat kaynağı (`userTaskClockProvider` ile
/// aynı desen).
final ddayClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Sınav tarihi (cihazda kalıcı, hesaptan bağımsız). `null` = seçilmedi.
class ExamDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => decodeExamDay(
    ref.watch(sharedPreferencesProvider).getString(kExamDateKey),
  );

  Future<void> set(DateTime day) async {
    final normalized = DateTime(day.year, day.month, day.day);
    state = normalized;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kExamDateKey, encodeExamDay(normalized));
  }

  /// `showDatePicker` iptali ile "temizle" ayırt edilemez; silme bu yüzden
  /// ayrı bir eylemdir (Ayarlar satırındaki temizle düğmesi).
  Future<void> clear() async {
    state = null;
    await ref.read(sharedPreferencesProvider).remove(kExamDateKey);
  }
}

final examDateProvider = NotifierProvider<ExamDateNotifier, DateTime?>(
  ExamDateNotifier.new,
);

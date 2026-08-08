import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:online_study_room/l10n/app_localizations.dart';

import '../stats/istanbul_calendar.dart';
import '../theme/warning_tokens.dart';
import '../../data/models/user_task.dart';

/// Europe/Istanbul gününün sonu (23:59:59.999 local → UTC).
DateTime dueAtFromCalendarDate(DateTime calendarDay, {DateTime? now}) {
  final day = istanbulDay(calendarDay);
  final loc = tz.getLocation('Europe/Istanbul');
  final endLocal = tz.TZDateTime(
    loc,
    day.year,
    day.month,
    day.day,
    23,
    59,
    59,
    999,
  );
  return endLocal.toUtc();
}

/// Şimdi + süre (UTC).
DateTime dueAtFromRemaining(Duration remaining, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return n.toUtc().add(remaining);
}

/// Aktif liste sırası (WP-J):
/// 1. Günlük (daily) görevler her zaman üstte, süreli/tek-sefer altta.
/// 2. Her grup içinde tamamlananlar sona.
/// 3. dueAt artan; null en sona; eşitlikte sortOrder/createdAt.
List<UserTask> sortUserTasksByDue(List<UserTask> tasks) {
  final copy = [...tasks];
  copy.sort((a, b) {
    if (a.isRecurring != b.isRecurring) return a.isRecurring ? -1 : 1;
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad == null && bd == null) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.createdAt.compareTo(b.createdAt);
    }
    if (ad == null) return 1;
    if (bd == null) return -1;
    final c = ad.compareTo(bd);
    if (c != 0) return c;
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return a.createdAt.compareTo(b.createdAt);
  });
  return copy;
}

/// Gecikmiş mi? (dueAt < now, tamamlanmamış varsayımı çağıranda).
bool isTaskOverdue(DateTime now, DateTime? dueAt) {
  if (dueAt == null) return false;
  return dueAt.toUtc().isBefore(now.toUtc());
}

/// Kalan süre spektrumu (WP-197).
///
/// - süresiz: nötr outline
/// - gecikti: güçlü kırmızı
/// - >7g: sakin primary
/// - ~1–7g: sarı→turuncu lerp
/// - <24s: turuncu→kırmızı
///
/// 🔴 WP-541: ton skalası korunur ama **açıklık zeminden türetilir**. Eskiden
/// dönen değerler sabit hex'ti (`0xFFB91C1C` vb.) ve tema paletinden bağımsızdı:
/// "Gecikti" kırmızısı 11 koyu temanın hepsinde 2.13–2.89 kontrast veriyordu,
/// yani metin-dışı 3.0 tabanının bile altındaydı; `soft_cream` gibi açık
/// temalarda ise "yakın"/"sakin" 1.97–2.56'ya düşüyordu. Aynı sınıf hata
/// uyarı rozetinde WP-358'de yaşandı — çözüm oradaki ile aynı: renk sabit
/// değil, **zeminin fonksiyonu**.
///
/// `taskUrgencyKind` a11y etiketi ekran okuyucuyu zaten kurtarıyordu; bu
/// düzeltme gözle okuyanı kurtarır.
Color taskUrgencyColor(DateTime now, DateTime? dueAt, ColorScheme scheme) {
  return _readableOnSurfaces(_rawUrgencyColor(now, dueAt, scheme), scheme);
}

/// Ton seçimi (WP-197 spektrumu) — kontrast düzeltmesinden önceki ham renk.
Color _rawUrgencyColor(DateTime now, DateTime? dueAt, ColorScheme scheme) {
  if (dueAt == null) {
    return scheme.onSurfaceVariant;
  }
  final n = now.toUtc();
  final d = dueAt.toUtc();
  if (d.isBefore(n)) {
    return const Color(0xFFB91C1C); // koyu kırmızı
  }
  final hours = d.difference(n).inMinutes / 60.0;
  if (hours >= 7 * 24) {
    return scheme.primary;
  }
  if (hours >= 24) {
    // 7g → 1g: sakin → turuncu
    final t = 1.0 - ((hours - 24) / (6 * 24)).clamp(0.0, 1.0);
    return Color.lerp(scheme.primary, const Color(0xFFF59E0B), t)!;
  }
  if (hours >= 6) {
    // 24s → 6s: turuncu
    final t = 1.0 - ((hours - 6) / 18).clamp(0.0, 1.0);
    return Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEA580C), t)!;
  }
  // <6s: turuncu → kırmızı
  final t = 1.0 - (hours / 6).clamp(0.0, 1.0);
  return Color.lerp(const Color(0xFFEA580C), const Color(0xFFDC2626), t)!;
}

/// Rengi **tonunu koruyarak** okunur hâle getirir.
///
/// İki zemin birden gözetilir, çünkü aynı renk iki farklı yüzeyde çiziliyor:
/// ana ekran kartı [ColorScheme.surface] üstünde (`tasks_card.dart`), Görevler
/// listesi ise scaffold ([ColorScheme.surfaceContainerLowest]) üstünde
/// (`tasks_screen.dart`). Yalnız birine göre çözmek diğerini sessizce kırar.
///
/// Saf ve deterministiktir: aynı renk + aynı şema her zaman aynı sonucu verir.
Color _readableOnSurfaces(Color color, ColorScheme scheme) {
  final backgrounds = <Color>[scheme.surface, scheme.surfaceContainerLowest];
  double worst(Color candidate) => backgrounds
      .map((background) => contrastRatio(candidate, background))
      .reduce(math.min);

  var best = color;
  var bestRatio = worst(color);
  if (bestRatio >= kMinTextContrast) return color;

  // Açıklığı iki yönde de adım adım dener; hedefi ilk tutturan kazanır, böylece
  // renk gereğinden fazla bozulmaz. Yön sabitlenmez: orta parlaklıktaki bir
  // zeminde doğru yön hangisiyse o bulunur.
  final hsl = HSLColor.fromColor(color);
  for (var step = 1; step <= 25; step++) {
    final delta = step * 0.04;
    for (final lightness in <double>[
      hsl.lightness + delta,
      hsl.lightness - delta,
    ]) {
      if (lightness < 0.0 || lightness > 1.0) continue;
      final candidate = hsl.withLightness(lightness).toColor();
      final ratio = worst(candidate);
      if (ratio > bestRatio) {
        best = candidate;
        bestRatio = ratio;
      }
      if (ratio >= kMinTextContrast) return candidate;
    }
  }
  return best;
}

/// a11y: yalnız renge güvenme — etiket anahtarı.
enum TaskUrgencyKind { none, calm, soon, urgent, overdue }

TaskUrgencyKind taskUrgencyKind(DateTime now, DateTime? dueAt) {
  if (dueAt == null) return TaskUrgencyKind.none;
  final n = now.toUtc();
  final d = dueAt.toUtc();
  if (d.isBefore(n)) return TaskUrgencyKind.overdue;
  final hours = d.difference(n).inMinutes / 60.0;
  if (hours >= 24) return TaskUrgencyKind.calm;
  if (hours >= 6) return TaskUrgencyKind.soon;
  return TaskUrgencyKind.urgent;
}

/// Kısa kalan-süre etiketi (chip için): `Süresiz` / `Gecikti` / `3g` / `5s`
/// / `12dk`. Gün→saat→dakika en kaba birime yuvarlar (min 1dk).
String taskRemainingShort(
  AppLocalizations l10n,
  DateTime now,
  DateTime? dueAt,
) {
  if (dueAt == null) return l10n.taskListNoDue;
  final diff = dueAt.toUtc().difference(now.toUtc());
  if (diff.isNegative) return l10n.taskListOverdue;
  final days = diff.inDays;
  if (days >= 1) return l10n.taskListDaysShort(days);
  final hours = diff.inHours;
  if (hours >= 1) return l10n.taskListHoursShort(hours);
  final mins = diff.inMinutes;
  return l10n.taskListMinutesShort(mins < 1 ? 1 : mins);
}

/// İnsan-okur bitiş tarihi (yalnız gün): `28 Ağu`, yıl farklıysa `28 Ağu 2027`.
///
/// 🔴 WP-294: ay kısaltmaları eskiden Türkçe sabit bir listeydi — DE/AR/EN
/// kullanıcısı Türkçe ay görüyordu. Katalog anahtarı **açılmadı**: bu 12 değer
/// `intl`'in kendi CLDR verisinde zaten var ve `DateFormat` yerelin gün/ay
/// sırasını da doğru kurar (Arapça'da sıra farklı). `locale` bilinçli olarak
/// zorunlu parametre: varsayılan bırakılırsa çağıran yeri geçmeyi unutur ve hata
/// sessizce geri döner.
String taskDueDateLabel(DateTime now, DateTime dueAt, String locale) {
  final d = dueAt.toLocal();
  final pattern = d.year == now.year
      ? DateFormat.MMMd(locale)
      : DateFormat.yMMMd(locale);
  return pattern.format(d);
}

/// WP-480: tekrarlayan görevin **aralığını söyleyen** özet metni.
///
/// WP-449/450 N-günlük tekrarı getirdi (`upsert_user_task(p_interval_days, …)`,
/// sunucu sözleşmesi `0109`), ama yüzeyler sabit "günlük yenilenen" metnini
/// göstermeye devam etti: veri N gün, metin 1 gündü. Metin üretimi tek yerde
/// toplandı ki dördüncü bir yüzey eklendiğinde tekrar ayrışmasın.
String taskRecurrenceSummary(AppLocalizations l10n, int intervalDays) =>
    l10n.taskListRepeatSummary(_safeIntervalDays(intervalDays));

/// Tamamlandıktan sonra görevin ne zaman geri geleceğini anlatan ipucu.
///
/// Çoğul biçim önemli: "gece yarısı yeniden aktif olur" cümlesi yalnız N=1 için
/// doğrudur, N>1'de **yanlış bilgi**dir.
String taskRecurrenceHint(AppLocalizations l10n, int intervalDays) =>
    l10n.taskListRepeatHint(_safeIntervalDays(intervalDays));

/// Aralık sunucuda 1–365 aralığına kısılıyor; metin katmanı bozuk bir değerle
/// çoğul seçemesin diye aynı sınır burada da uygulanır.
int _safeIntervalDays(int intervalDays) => intervalDays.clamp(1, 365);

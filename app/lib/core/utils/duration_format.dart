import '../l10n/app_locale.dart';

/// Saniyeyi `SS:DD:SS` (saat:dakika:saniye) biçiminde verir. Canlı sayaç için.
String formatHms(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// Saniyeyi uygulamanın etkin diliyle kısa biçimde verir.
///
/// İngilizce: "2h 15m", "15m", "40s". Türkçe: "2 sa 15 dk",
/// "15 dk", "40 sn". Manuel dil tercihi de dahil uygulamanın etkin locale'i
/// tek doğruluk kaynağıdır.
String formatHuman(int totalSeconds) {
  return formatHumanForLocale(totalSeconds, activeAppLocale.languageCode);
}

/// [languageCode] için kısa, kullanıcıya görünen süre biçimini üretir.
/// Testlerde ve platform dışı çağrılarda dili açıkça sabitlemek için ayrıdır.
String formatHumanForLocale(int totalSeconds, String languageCode) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final isTurkish = languageCode.toLowerCase() == 'tr';
  final hour = isTurkish ? 'sa' : 'h';
  final minute = isTurkish ? 'dk' : 'm';
  final second = isTurkish ? 'sn' : 's';
  if (h > 0) return m > 0 ? '$h$hour $m$minute' : '$h$hour';
  if (m > 0) return '$m$minute';
  return '$seconds$second';
}

/// Saniyeyi etkin dilde kısa biçimde, saniyeyi de dahil ederek verir.
String formatHumanSeconds(int totalSeconds) {
  return formatHumanSecondsForLocale(
    totalSeconds,
    activeAppLocale.languageCode,
  );
}

/// [languageCode] için saniyeyi de içeren kısa süre biçimi üretir.
String formatHumanSecondsForLocale(int totalSeconds, String languageCode) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  final isTurkish = languageCode.toLowerCase() == 'tr';
  final hour = isTurkish ? 'sa' : 'h';
  final minute = isTurkish ? 'dk' : 'm';
  final second = isTurkish ? 'sn' : 's';
  if (h > 0) return '$h$hour $m$minute $s$second';
  if (m > 0) return '$m$minute $s$second';
  return '$s$second';
}

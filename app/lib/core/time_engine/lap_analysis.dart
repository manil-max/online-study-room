/// Geri sayim sure metni.
///
/// WP-586: bu dosyadaki `LapAnalysis` ve `formatStopwatch` kaldirildi — tur
/// kronometresi ekrani WP-264'te silinmisti, ikisinin de `lib/` icinde tek bir
/// cagri yeri kalmamisti. Dosya adi `features/clock/timers_screen.dart` onu bu
/// yoldan import ettigi icin korundu.
String formatCountdown(Duration d) {
  final total = d.inSeconds.clamp(0, 1 << 30);
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

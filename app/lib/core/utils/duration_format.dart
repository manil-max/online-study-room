/// Saniyeyi `SS:DD:SS` (saat:dakika:saniye) biçiminde verir. Canlı sayaç için.
String formatHms(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(h)}:${two(m)}:${two(s)}';
}

/// Saniyeyi okunabilir Türkçe biçimde verir: "2 sa 15 dk", "15 dk", "40 sn".
String formatHuman(int totalSeconds) {
  final seconds = totalSeconds < 0 ? 0 : totalSeconds;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '$h sa $m dk';
  if (m > 0) return '$m dk';
  return '$seconds sn';
}

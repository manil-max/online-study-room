import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-237: grafik eksenleri için ortak yardımcılar (X etiket adımı + Y ölçeği).
///
/// Amaç: yer varken **her günün** numarası görünsün (eskiden sabit her 2–3
/// günde bir yazılıyordu) ve çizgi/çubuk grafiklerinde eksik olan **Y ekseni
/// ölçeği** tek yerden gelsin.

/// [count] etiket için, [maxWidth] piksele sığacak en küçük atlama adımı.
///
/// Her etiket ~[labelWidth] piksel yer kaplar; sığdığı kadar etiketi (ideal:
/// hepsini) gösterir. Genişlik bilinmiyorsa (0/negatif) 1 döner → her etiket.
int axisLabelStep(int count, double maxWidth, {double labelWidth = 22}) {
  if (count <= 1) return 1;
  if (maxWidth <= 0) return 1;
  final capacity = (maxWidth / labelWidth).floor();
  if (capacity >= count) return 1;
  if (capacity <= 1) return count;
  return (count / capacity).ceil();
}

/// Y ekseni için ~4–5 yatay çizgi verecek "yuvarlak" dakika aralığı.
///
/// [maxMinutes] serideki en yüksek değerdir (dakika). Dönen aralık dakika
/// cinsindedir; grid + sol etiket ortak kullanır.
double niceMinuteInterval(double maxMinutes) {
  if (maxMinutes <= 0) return 15;
  const candidates = <double>[
    5,
    10,
    15,
    30,
    60,
    120,
    180,
    240,
    360,
    480,
    600,
    720,
    1440,
  ];
  final target = maxMinutes / 4; // ~4 aralık hedefi
  for (final c in candidates) {
    if (c >= target) return c;
  }
  return candidates.last;
}

/// Eksen boyunca tek birim: en yüksek değer ≥ 90 dk ise saat, yoksa dakika.
bool axisUsesHours(double maxMinutes) => maxMinutes >= 90;

/// Y ekseni etiketi. [useHours] true ise saat ("1.5s"), değilse dakika ("30dk").
/// Tam sayıda saatte ondalık gösterilmez.
String chartYLabel(
  double minutes,
  AppLocalizations l10n, {
  required bool useHours,
}) {
  if (useHours) {
    final h = minutes / 60;
    final text = h == h.roundToDouble()
        ? h.toStringAsFixed(0)
        : h.toStringAsFixed(1);
    return '$text${l10n.statsSaatKisa}';
  }
  return '${minutes.round()}${l10n.statsDakikaKisa}';
}

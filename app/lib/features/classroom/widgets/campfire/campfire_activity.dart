/// WP-61/62: grup çalışma yoğunluğundan kamp ateşi aktivite durumu.
///
/// Eşikler `docs/CAMPFIRE-R2-TASARIM.md` §3 ile sabittir.
enum CampfireActivity {
  /// Kimse çalışmıyor — köz + sönük glow.
  empty,

  /// 1–2 çalışan — orta alev.
  low,

  /// ≥3 çalışan — tam alev + duman + köz parçacıkları.
  high,
}

/// [studyingCount] → empty / low / high.
CampfireActivity campfireActivityFor(int studyingCount) {
  if (studyingCount <= 0) return CampfireActivity.empty;
  if (studyingCount <= 2) return CampfireActivity.low;
  return CampfireActivity.high;
}

/// Eski vektör painter ile uyumlu 0..1 yoğunluk (rozetsiz iç hesap).
double campfireIntensityFor(int studyingCount) {
  if (studyingCount <= 0) return 0.24;
  return (0.55 + studyingCount * 0.09).clamp(0.55, 1.0);
}

/// WP-323: "tur şimdi başlayabilir mi?" kararı — **saf fonksiyon**.
///
/// Kuyruk yönetimi burada; kararın kendisi widget'a gömülseydi ancak ekran
/// pompalayarak test edilebilirdi ve her koşul ayrı ayrı sınanamazdı.
library;

/// Turun başlamasını engelleyen nedenler. Sıra **anlamlı**: ilk eşleşen dönülür,
/// böylece "neden başlamadı" sorusunun tek ve kararlı bir cevabı olur.
enum TourBlockReason {
  /// Bu tur (bu sürümü) daha önce görülmüş/atlanmış.
  alreadySeen,

  /// Kullanıcı yok — anahtar kullanıcıya özel, oturumsuz yazılacak yer yok.
  noUser,

  /// Başka bir tur zaten çalışıyor.
  otherTourRunning,

  /// Ekranın üstünde bir yol var: diyalog, alt sayfa, başka sayfa.
  /// İzin diyalogları ve güncelleme bildirimi buraya düşer — motorun onları
  /// **tanıması gerekmez**, "üstümde bir şey var" bilgisi yeter.
  routeNotCurrent,

  /// Uygulama ön planda değil (işletim sistemi izin diyaloğu, arka plan).
  appNotResumed,
}

/// Engel yoksa `null` döner.
///
/// 🔴 Engel varsa tur **görüldü sayılmaz**, yalnız ertelenir: aksi halde
/// açılışta izin diyaloğuyla karşılaşan kullanıcı turu bir daha hiç göremezdi.
TourBlockReason? tourBlockReason({
  required bool seen,
  required bool hasUser,
  required bool otherTourRunning,
  required bool routeIsCurrent,
  required bool appResumed,
}) {
  if (seen) return TourBlockReason.alreadySeen;
  if (!hasUser) return TourBlockReason.noUser;
  if (otherTourRunning) return TourBlockReason.otherTourRunning;
  if (!routeIsCurrent) return TourBlockReason.routeNotCurrent;
  if (!appResumed) return TourBlockReason.appNotResumed;
  return null;
}

/// Engel kalıcı mı (bir daha denemeye değmez), yoksa geçici mi (ertelenir)?
bool isPermanentBlock(TourBlockReason reason) =>
    reason == TourBlockReason.alreadySeen;

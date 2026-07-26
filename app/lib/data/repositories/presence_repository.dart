import '../models/presence.dart';

/// V3 projection geçişinin istemci tarafı kapısı.
///
/// Varsayılan [legacy] kalır; staging/cihaz kabulü yapılmadan yeni read model
/// eski `presence` tablosunun yerini alamaz. [shadow] iki yolu birlikte
/// yazar/okur; [projection] yalnız server-derived sözleşmesini kullanır.
enum PresenceProjectionMode { legacy, shadow, projection }

/// Presence publish/flush sağlığı; kullanıcı eylemi bu bilgi için beklemez.
class PresenceSyncStatus {
  const PresenceSyncStatus({
    required this.pendingCount,
    this.oldestPendingAt,
    this.lastError,
  });

  const PresenceSyncStatus.idle() : this(pendingCount: 0);

  final int pendingCount;
  final DateTime? oldestPendingAt;
  final Object? lastError;
}

/// Canlı "kim çalışıyor" durumunun deposu. Kullanıcı başına tek satır (upsert).
abstract class PresenceRepository {
  /// Kullanıcının kanonik canlı durumunu yazar/günceller.
  ///
  /// V3 modunda client group fan-out yapmaz; RPC aktif üyeliklerden projection
  /// üretir. Legacy modda geçici fallback satırı güncellenir.
  Future<void> setPresence(Presence presence);

  /// Aynı kanonik durumun lease'ini tazeler.
  Future<void> heartbeatPresence(Presence presence);

  /// Bir sınıftaki projection/legacy üyelerin canlı durumunu izler.
  Stream<List<Presence>> watchGroupPresence(String groupId);

  /// Destek/telemetri için kuyruk yaşını ve son hatayı görünür kılar.
  Future<PresenceSyncStatus> readSyncStatus();
}

import 'package:flutter/foundation.dart';

/// Canlı çalışma durumu (bkz. project.md §3.5).
enum PresenceStatus { studying, onBreak, offline }

/// Legacy `public.presence` tablosunun **gerçek** kolonları
/// (`supabase/migrations/0001_initial_schema.sql:66-74`).
///
/// 🔴 Bu liste şemanın aynasıdır, dilek listesi değildir. Yeni bir alan ancak
/// tabloya kolon ekleyen bir ileri migration yazıldıktan **sonra** buraya girer.
/// Sırası tablo tanımıyla aynıdır. Bkz. [Presence.toMap] ve WP-363.
const List<String> kLegacyPresenceColumns = [
  'user_id',
  'group_id',
  'status',
  'started_at',
  'today_seconds',
  'subject_id',
  'updated_at',
];

/// Bir kullanıcının canlı sınıftaki anlık durumu. Supabase `presence` tablosuna
/// karşılık gelir; Realtime ile yayılır.
@immutable
class Presence {
  const Presence({
    required this.userId,
    required this.status,
    required this.todaySeconds,
    this.groupId,
    this.startedAt,
    this.subjectId,
    this.updatedAt,
    this.leaseExpiresAt,
  });

  final String userId;

  /// Kullanıcının içinde bulunduğu sınıf (presence sorguları sınıfa göre süzülür).
  final String? groupId;

  final PresenceStatus status;

  /// Mevcut çalışma/mola durumunun başladığı an (anlık süre buradan hesaplanır).
  final DateTime? startedAt;

  /// Kullanıcının bugünkü toplam çalışma süresi (saniye).
  final int todaySeconds;

  final String? subjectId;

  /// Satırın en son yazıldığı an (sunucu `updated_at`). Heartbeat her yazımda
  /// tazeler; uygulama öldürülünce heartbeat durur ve bu değer bayatlar →
  /// çevrimdışı tespiti (§WP-5) bunu kullanır. Bellek-içi/eski satırlarda `null`.
  final DateTime? updatedAt;

  /// V3 projection'ın kanonik lease bitişi. Heartbeat projection satırını
  /// yazmadığından, aktiflik bu alandan türetilir.
  final DateTime? leaseExpiresAt;

  bool get isStudying => status == PresenceStatus.studying;

  Presence copyWith({
    String? groupId,
    PresenceStatus? status,
    DateTime? startedAt,
    int? todaySeconds,
    String? subjectId,
    DateTime? updatedAt,
    DateTime? leaseExpiresAt,
  }) {
    return Presence(
      userId: userId,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      todaySeconds: todaySeconds ?? this.todaySeconds,
      subjectId: subjectId ?? this.subjectId,
      updatedAt: updatedAt ?? this.updatedAt,
      leaseExpiresAt: leaseExpiresAt ?? this.leaseExpiresAt,
    );
  }

  factory Presence.fromMap(Map<String, dynamic> map) {
    final started = map['started_at'] as String?;
    final updated = map['updated_at'] as String?;
    final leaseExpires = map['lease_expires_at'] as String?;
    return Presence(
      userId: map['user_id'] as String,
      groupId: map['group_id'] as String?,
      status: PresenceStatus.values.byName(map['status'] as String),
      startedAt: started == null ? null : DateTime.parse(started),
      todaySeconds: (map['today_seconds'] as int?) ?? 0,
      subjectId: map['subject_id'] as String?,
      updatedAt: updated == null ? null : DateTime.parse(updated),
      leaseExpiresAt: leaseExpires == null
          ? null
          : DateTime.parse(leaseExpires),
    );
  }

  /// Legacy `public.presence` tablosunun **satır eşlemesi**.
  ///
  /// 🔴 WP-363: Buraya tabloda **olmayan** bir alan eklemek, yazmayı sessizce
  /// öldürür. `from('presence').upsert(...)` bilinmeyen bir kolon görünce
  /// PostgREST'te hata döner; çağrı zinciri bu hatayı yuttuğu için kullanıcı
  /// kendini yerel cache'ten aktif görmeye devam eder, **karşı taraf hiçbir şey
  /// görmez.** Tam olarak bu oldu: WP-339 modele `leaseExpiresAt` ekleyince
  /// payload'a `lease_expires_at` da girdi, ama o kolon yalnız V3 projeksiyon
  /// tablolarında (`0081`) ve `live_study_runs`ta (`0082`) var — legacy
  /// `presence` tablosunda **yok**. Sonuç: v49 ve v50'de presence sunucuya hiç
  /// yazılamadı.
  ///
  /// Anahtarlar [kLegacyPresenceColumns] ile sınırlıdır ve bu bir testle
  /// kilitlenmiştir. Projeksiyon yolu bu eşlemeyi kullanmaz; o taraf
  /// `apply_multi_group_presence_state` RPC'sine açık parametre geçer.
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'group_id': groupId,
      'status': status.name,
      // UTC olarak yaz: Supabase timestamptz round-trip'inde saat dilimi kaymasın,
      // böylece anlık süre (now - started_at) doğru hesaplanır.
      'started_at': startedAt?.toUtc().toIso8601String(),
      'today_seconds': todaySeconds,
      'subject_id': subjectId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Presence &&
      other.userId == userId &&
      other.groupId == groupId &&
      other.status == status &&
      other.startedAt == startedAt &&
      other.todaySeconds == todaySeconds &&
      other.subjectId == subjectId &&
      other.updatedAt == updatedAt &&
      other.leaseExpiresAt == leaseExpiresAt;

  @override
  int get hashCode => Object.hash(
    userId,
    groupId,
    status,
    startedAt,
    todaySeconds,
    subjectId,
    updatedAt,
    leaseExpiresAt,
  );
}

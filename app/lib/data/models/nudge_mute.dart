import 'package:flutter/foundation.dart';

/// WP-444: "yalnız dürtmesini sessize al" tercihi.
///
/// Engellemeden (`user_blocks`) **bağımsızdır**: susturulan kişi mesajlaşma,
/// profil ve grup açısından normal üyedir; yalnız dürtmesi alıcıya ulaşmaz.
/// Tercih hesap kapsamlıdır (cihaz değil), bu yüzden ikinci cihazda da geçerlidir
/// ve kullanıcı istediği an geri açabilir.
@immutable
class NudgeMute {
  const NudgeMute({
    required this.mutedUserId,
    required this.mutedAt,
    this.displayName,
    this.avatarUrl,
  });

  /// Dürtmesi susturulan kişinin kimliği.
  final String mutedUserId;

  /// Tercihin oluşturulma zamanı (sunucu saati).
  final DateTime mutedAt;

  /// Yönetim ekranı için ad; okunamazsa null (ekran maskeli ad üretir).
  final String? displayName;

  final String? avatarUrl;

  factory NudgeMute.fromMap(Map<String, dynamic> map) {
    return NudgeMute(
      mutedUserId: (map['muted_sender_id'] ?? map['id']) as String,
      mutedAt: DateTime.parse(map['muted_at'] as String),
      displayName: map['display_name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'muted_sender_id': mutedUserId,
      'muted_at': mutedAt.toIso8601String(),
      'display_name': displayName,
      'avatar_url': avatarUrl,
    };
  }
}

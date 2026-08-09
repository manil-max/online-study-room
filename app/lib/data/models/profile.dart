import 'package:flutter/foundation.dart';

/// Varsayılan günlük hedef (dakika) — 6 saat. Bkz. project.md §3.7.
const int kDefaultDailyGoalMinutes = 360;

/// Kullanıcı profili. Supabase `profiles` tablosuna karşılık gelir (bkz. project.md §6).
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
    this.dailyGoalMinutes = kDefaultDailyGoalMinutes,
    this.isActive = true,
    this.animal,
    // WP-630: aylik rapor icin ACIK riza gerekir; on isaretli onay kutusu
    // gecerli riza degildir. Sunucu tarafi esi: `0125`.
    this.monthlyReportOptIn = false,
    this.titleAchievementId,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final bool isActive;

  /// Günlük çalışma hedefi (dakika). Seri (streak) ve hedef ilerleme buna bağlı.
  final int dailyGoalMinutes;

  /// Kamp ateşi sahnesinde kullanıcıyı temsil eden hayvanın kimliği (§2G).
  /// Seçilmemişse null; UI kullanıcıya göre deterministik varsayılan atar.
  final String? animal;

  final bool monthlyReportOptIn;

  /// WP-475: profilde gösterilen ünvan — kazanılmış bir başarımın kimliği.
  /// Seçilmemişse null. "Kazanılmış mı" kontrolü sunucudadır (0115 trigger);
  /// istemci burada yalnız gösterir.
  final String? titleAchievementId;

  Profile copyWith({
    String? displayName,
    String? avatarUrl,
    int? dailyGoalMinutes,
    bool? isActive,
    String? animal,
    bool? monthlyReportOptIn,
    String? titleAchievementId,

    /// Ünvanı kaldırmak için: `titleAchievementId: null` "değiştirme" demek
    /// olduğundan temizleme ayrı bayrakla istenir.
    bool clearTitle = false,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      isActive: isActive ?? this.isActive,
      animal: animal ?? this.animal,
      monthlyReportOptIn: monthlyReportOptIn ?? this.monthlyReportOptIn,
      titleAchievementId: clearTitle
          ? null
          : (titleAchievementId ?? this.titleAchievementId),
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      dailyGoalMinutes:
          (map['daily_goal_minutes'] as int?) ?? kDefaultDailyGoalMinutes,
      isActive: map['is_active'] as bool? ?? true,
      animal: map['animal'] as String?,
      // 🔴 WP-630: sutun okunamadiginda (eski satir, kisitli kolon secimi,
      // cevrimdisi yedek profil) rizayi VAR saymak, kullanicinin hic vermedigi
      // bir izni uydurmaktir. Bilinmiyorsa yok sayilir.
      monthlyReportOptIn: map['monthly_report_opt_in'] as bool? ?? false,
      titleAchievementId: map['title_achievement_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'daily_goal_minutes': dailyGoalMinutes,
      'is_active': isActive,
      'animal': animal,
      'monthly_report_opt_in': monthlyReportOptIn,
      'title_achievement_id': titleAchievementId,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.createdAt == createdAt &&
      other.dailyGoalMinutes == dailyGoalMinutes &&
      other.isActive == isActive &&
      other.animal == animal &&
      other.monthlyReportOptIn == monthlyReportOptIn &&
      other.titleAchievementId == titleAchievementId;

  @override
  int get hashCode => Object.hash(
    id,
    displayName,
    avatarUrl,
    createdAt,
    dailyGoalMinutes,
    isActive,
    animal,
    monthlyReportOptIn,
    titleAchievementId,
  );
}

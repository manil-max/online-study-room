/// Bir kullanıcının belirli bir GÜNDEKİ toplam çalışma süresi (saniye).
///
/// Grup geneli istatistikler ham oturum satırları yerine bu **per-user-per-gün**
/// toplamlardan hesaplanır; böylece istemciye akan veri oturum sayısıyla değil,
/// (üye × aktif gün) ile sınırlı kalır (bkz. OPTIMIZATIONS.md F1).
class DailyStat {
  const DailyStat({
    required this.userId,
    required this.day,
    required this.seconds,
  });

  final String userId;

  /// Gün (saat sıfırlanmış, yerel/Europe-Istanbul gün sınırı).
  final DateTime day;
  final int seconds;

  /// Supabase `group_daily_totals` RPC satırından üretir.
  factory DailyStat.fromMap(Map<String, dynamic> map) {
    final rawDay = map['day'];
    final day = rawDay is DateTime ? rawDay : DateTime.parse(rawDay as String);
    return DailyStat(
      userId: map['user_id'] as String,
      day: DateTime(day.year, day.month, day.day),
      seconds: (map['seconds'] as num).toInt(),
    );
  }
}

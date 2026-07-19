// WP-164: analitik RPC/aggregate satır modelleri (ham session yok).

class UserDayTotal {
  const UserDayTotal({required this.day, required this.seconds});

  final DateTime day;
  final int seconds;

  factory UserDayTotal.fromMap(Map<String, dynamic> map) {
    final rawDay = map['day'];
    final day = rawDay is DateTime ? rawDay : DateTime.parse(rawDay as String);
    return UserDayTotal(
      day: DateTime(day.year, day.month, day.day),
      seconds: (map['seconds'] as num).toInt(),
    );
  }
}

class GroupContributionRow {
  const GroupContributionRow({required this.userId, required this.seconds});

  final String userId;
  final int seconds;

  factory GroupContributionRow.fromMap(Map<String, dynamic> map) {
    return GroupContributionRow(
      userId: map['user_id'] as String,
      seconds: (map['seconds'] as num).toInt(),
    );
  }
}

class GroupLeaderboardPoint {
  const GroupLeaderboardPoint({
    required this.day,
    required this.userId,
    required this.seconds,
  });

  final DateTime day;
  final String userId;
  final int seconds;

  factory GroupLeaderboardPoint.fromMap(Map<String, dynamic> map) {
    final rawDay = map['day'];
    final day = rawDay is DateTime ? rawDay : DateTime.parse(rawDay as String);
    return GroupLeaderboardPoint(
      day: DateTime(day.year, day.month, day.day),
      userId: map['user_id'] as String,
      seconds: (map['seconds'] as num).toInt(),
    );
  }
}

/// Sadece sunucunun finalized verified grup-günlerinden türetilen alfa sayısı.
/// Ham oturum veya başka grubun başarım ilerlemesi bu modelden taşınmaz.
class GroupAlphaScore {
  const GroupAlphaScore({required this.userId, required this.alphaWins});

  final String userId;
  final int alphaWins;

  factory GroupAlphaScore.fromMap(Map<String, dynamic> map) {
    return GroupAlphaScore(
      userId: map['user_id'] as String,
      alphaWins: (map['alpha_wins'] as num?)?.toInt() ?? 0,
    );
  }
}

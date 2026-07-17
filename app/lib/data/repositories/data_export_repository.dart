/// WP-152: kullanıcının kendi verisini dışa aktarma (GDPR portability).
enum DataExportRange { hot90, year, all }

class DataExportBundle {
  const DataExportBundle({
    required this.payload,
    required this.sessionCount,
  });

  final Map<String, dynamic> payload;
  final int sessionCount;

  bool get isEmpty =>
      sessionCount == 0 &&
      (payload['subjects'] as List?)?.isEmpty != false &&
      payload['profile'] == null;
}

abstract class DataExportRepository {
  /// Yalnız [userId] verisi. Başka kullanıcı satırı dönmez.
  Future<DataExportBundle> buildExport({
    required String userId,
    required DataExportRange range,
  });
}

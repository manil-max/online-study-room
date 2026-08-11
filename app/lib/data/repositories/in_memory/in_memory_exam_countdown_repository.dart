import '../../models/exam_countdown.dart';
import '../exam_countdown_repository.dart';

/// Bellek ici geri sayim deposu (demo/test).
///
/// Testte **sunucuyu** temsil eder: iki `ProviderContainer` (= iki cihaz) ayni
/// ornegi paylasir, boylece "ayni hesap, iki cihaz" iddiasi gercekten olculur.
class InMemoryExamCountdownRepository implements ExamCountdownRepository {
  InMemoryExamCountdownRepository({this.maxEntries = 3});

  final int maxEntries;
  final Map<String, List<ExamCountdown>> _store = {};

  /// Kac kez okundu/yazildi - testin kabuk degil govde olctugunu gormek icin.
  int loads = 0;
  int writes = 0;
  int deletes = 0;

  List<ExamCountdown> rowsOf(String userKey) =>
      List.unmodifiable(_store[userKey] ?? const []);

  @override
  Future<List<ExamCountdown>> load({required String userKey}) async {
    loads++;
    final rows = [...(_store[userKey] ?? const <ExamCountdown>[])]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return rows;
  }

  @override
  Future<void> upsert({
    required String userKey,
    required ExamCountdown entry,
  }) async {
    writes++;
    final rows = [...(_store[userKey] ?? const <ExamCountdown>[])];
    final index = rows.indexWhere((r) => r.id == entry.id);
    if (index < 0) {
      // Sunucu sinirini taklit eder: fazlasi SESSIZCE yutulmaz, hata atar.
      if (rows.length >= maxEntries) {
        throw StateError('exam_countdown_limit_reached');
      }
    } else if (rows[index].updatedAt.isAfter(entry.updatedAt)) {
      return; // LWW: bayat yazma yok sayilir.
    }
    if (entry.isPriority) {
      for (var i = 0; i < rows.length; i++) {
        if (rows[i].id != entry.id && rows[i].isPriority) {
          rows[i] = rows[i].copyWith(isPriority: false);
        }
      }
    }
    if (index < 0) {
      rows.add(entry);
    } else {
      rows[index] = entry;
    }
    _store[userKey] = rows;
  }

  @override
  Future<void> delete({required String userKey, required String id}) async {
    deletes++;
    final rows = [...(_store[userKey] ?? const <ExamCountdown>[])]
      ..removeWhere((r) => r.id == id);
    _store[userKey] = rows;
  }

  void clear() => _store.clear();
}

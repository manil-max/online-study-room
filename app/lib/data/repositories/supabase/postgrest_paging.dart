/// WP-936: PostgREST tek yanitta en fazla `max_rows` satir dondurur
/// (`supabase/config.toml` -> `[api] max_rows = 1000`; barindirilan Supabase
/// varsayilani da 1000). Sinir asildiginda hata YOKTUR — liste sessizce kisa
/// gelir. 1000'i asabilecek her liste bu yardimciyla sayfalanir.
///
/// Sayfa boyu sunucu `max_rows` degerinden BUYUK olmamalidir: aksi hâlde
/// kesilmis dolu sayfa "kisa sayfa" sanilir ve dongu erken biter.
const int kPostgrestPageSize = 1000;

/// Sonsuz donguye karsi ust sinir (50 x 1000 = 50.000 satir). Bir istatistik
/// donemi icin bunun uzerindeki veri gercekci degil; sinira ulasilirsa
/// eldeki satirlar dondurulur.
const int kPostgrestMaxPages = 50;

/// [fetchPage] `(from, to)` icin **kararli sirali** bir sorguyu
/// `.range(from, to)` ile calistirmalidir (siralama tekil bir anahtarla
/// bitmeli; esit degerlerde sayfa sinirinda tekrar/atlama olmasin).
/// Kisa sayfa gelene kadar ya da [maxPages] dolana kadar cekilir; kucuk
/// sonuclarda tek istek atilir.
Future<List<Map<String, dynamic>>> fetchAllPostgrestPages(
  Future<dynamic> Function(int from, int to) fetchPage, {
  int pageSize = kPostgrestPageSize,
  int maxPages = kPostgrestMaxPages,
}) async {
  final all = <Map<String, dynamic>>[];
  for (var page = 0; page < maxPages; page++) {
    final from = page * pageSize;
    final rows = await fetchPage(from, from + pageSize - 1) as List<dynamic>;
    for (final r in rows) {
      all.add(Map<String, dynamic>.from(r as Map));
    }
    if (rows.length < pageSize) break;
  }
  return all;
}

/// Kararsız (flaky) test önleyicileri.
///
/// **Neden var:** `v49` sürüm koşumu, kodla ilgisi olmayan üç sayaç testi
/// yüzünden kırıldı. Üçü de "yeterince beklemiştir" varsayımıyla yazılmıştı:
/// `await Future.delayed(20 ms)`, `pumpEventQueue(times: 20)`, tek `pump()`.
/// Bu süreler geliştirici makinesinde yetiyor ama GitHub koşucusu yük
/// altındayken yetmiyor — test rastgele düşüyor ve **her sürümü** kilitliyor.
///
/// Doğrusu süre beklemek değil **koşul** beklemektir: aşağıdaki yardımcılar
/// koşul sağlanana kadar olay kuyruğunu döndürür, sağlanmazsa açık bir
/// mesajla düşer. Hızlı makinede ilk turda döner, yavaş makinede sabreder.
library;

import 'package:flutter_test/flutter_test.dart';

/// [condition] doğru olana kadar olay kuyruğunu döndürür.
///
/// Sağlık zamanaşımı [timeout]; aşılırsa test **başarısız olur** (sessizce
/// devam etmez — sessiz geçiş, beklenen durumun hiç oluşmadığını gizler).
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'waitUntil zaman aşımına uğradı (${timeout.inSeconds} sn)'
        '${reason == null ? '' : ': $reason'}',
      );
    }
    await pumpEventQueue(times: 1);
  }
}

/// [count] kare ilerletir — **olumsuz** iddialar için.
///
/// "Şu sayı değişmemeli" gibi bir iddiada koşul beklenemez: beklenen şey
/// zaten hiçbir şeyin olmaması. Tek `pump()` ile yetinilirse olay henüz
/// işlenmemiş olabilir ve test **boş yere geçer** — yani hatayı kaçırır.
/// Birkaç kare ilerletmek olayın gerçekten işlendiğini garantiler.
Future<void> pumpFrames(WidgetTester tester, {int count = 5}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

/// [finder] eşleşene kadar kareleri ilerletir (widget testleri için).
///
/// Akış (`Stream`) tabanlı sağlayıcılarda tek `pump()` çoğu zaman yetiyor ama
/// **garanti değil**: olay + yeniden çizim iki ayrı tura düşebilir.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'pumpUntilFound zaman aşımına uğradı (${timeout.inSeconds} sn): '
        '$finder${reason == null ? '' : ' — $reason'}',
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
}

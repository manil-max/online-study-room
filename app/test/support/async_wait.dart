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

/// [condition] doğru olana kadar olay kuyruğunu döndürür — **düz `test`** için.
///
/// [waitUntil] ile aynı işi yapmaz: o, `pumpEventQueue` üzerinden çalışır ve
/// widget testleri için yazılmıştır. Bu varyant olay kuyruğunu doğrudan
/// `Future.delayed(Duration.zero)` ile döndürür, yani `testWidgets` dışında
/// kalan düz `test` gövdelerinde de aynı davranır. Zaman aşımı mesajı kaç TUR
/// harcandığını da yazar: "yavaş makine" ile "koşul hiç sağlanmıyor" ancak
/// böyle ayırt edilir (0'a yakın tur = koşul yanlış, binlerce tur = gerçekten
/// olmuyor).
Future<void> waitForCondition(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 15),
  String? reason,
}) async {
  final deadline = DateTime.now().add(timeout);
  var turns = 0;
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail(
        'waitForCondition zaman aşımına uğradı '
        '(${timeout.inSeconds} sn, $turns tur)'
        '${reason == null ? '' : ': $reason'}',
      );
    }
    await Future<void>.delayed(Duration.zero);
    turns++;
  }
}

/// Olay kuyruğunu tam [turns] **tur** döndürür — **olumsuz** iddialar için.
///
/// "Şu olay OLMAMALI" diyen bir testte koşul beklenemez: beklenen durum baştan
/// doğrudur, koşul beklemesi hiç beklemeden döner ve test ölçmek istediği şeyi
/// **ölçmez**. Sabit süre (`Future.delayed(20 ms)`) de yanlıştır ama ters
/// yönde: yük altında o süre içinde istenmeyen olay henüz işlenmemiş olabilir,
/// test **boş yere** yeşil geçer.
///
/// Tur sayısı makinenin hızından bağımsızdır — her tur, olay kuyruğunun bir kez
/// işlenmesidir. Bekleyen bir benimseme/kayıt varsa bu turların içinde mutlaka
/// gerçekleşir; hâlâ gerçekleşmiyorsa iddia gerçekten doğrudur.
Future<void> drainEventQueue({int turns = 256}) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

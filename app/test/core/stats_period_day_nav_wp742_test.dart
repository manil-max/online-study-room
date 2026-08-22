// WP-742: "Gün" dönemi gezinilebilir oldu + takvimden belirli bir güne atlama.
//
// Bu dosya ÜÇ sözleşmeyi ölçer:
//   1. `StatsPeriod.day` gezinilebilir; `all`/`custom` HÂLÂ değil.
//   2. Kaydırılmış gün KAPALIDIR: `from == to == o günün gün ANAHTARI`
//      (saat/dakika/saniye/ms = 0). WP-612 kapanış sözleşmesi gün için de
//      geçerli — "23:59:59.999" yazsaydık İstanbul çevrimi CI'da (UTC) günü
//      bir ileri kaydırırdı.
//   3. `jumpTo` dönem TÜRÜNÜ koruyup `offset`i yeniden hesaplar ve bunu
//      TAKVİM aritmetiğiyle yapar — `Duration.inDays` ile değil.
//
// Hiçbir vaka gerçek saate bağlı değil: `now` her yerde enjekte edilir.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';

/// Bir değerin gerçekten bir gün ANAHTARI olduğunu ölçer (WP-612 sözleşmesi).
void expectDayKey(DateTime value, {required String reason}) {
  expect(value.hour, 0, reason: '$reason — saat 0 değil');
  expect(value.minute, 0, reason: '$reason — dakika 0 değil');
  expect(value.second, 0, reason: '$reason — saniye 0 değil');
  expect(value.millisecond, 0, reason: '$reason — ms 0 değil');
  expect(value.microsecond, 0, reason: '$reason — µs 0 değil');
}

/// Dinleyicisi olan bir container. 🔴 Riverpod 3'te sağlayıcılar varsayılan
/// olarak auto-dispose'dur: dinleyicisiz `read` her çağrıda yeniden kurar,
/// `setPeriod`/`jumpTo` ile yazılan state sessizce kaybolur ve test hiçbir şey
/// ölçmez. Abonelik testin sonuna kadar açık tutulur.
ProviderContainer liveContainer() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final sub = container.listen(statsPeriodProvider, (_, _) {});
  addTearDown(sub.close);
  return container;
}

/// `jumpTo`yu izole bir container'da koşturup ortaya çıkan offset'i verir.
int offsetAfterJump(
  StatsPeriod period,
  DateTime date, {
  required DateTime now,
}) {
  final container = liveContainer();
  final notifier = container.read(statsPeriodProvider.notifier);
  notifier.setPeriod(period);
  notifier.jumpTo(date, now: now);
  return container.read(statsPeriodProvider).offset;
}

void main() {
  group('WP-742 #1: gün gezinilebilir', () {
    test('day gezinilebilir; all/custom değil', () {
      expect(
        const StatsPeriodSelection(period: StatsPeriod.day).supportsNavigation,
        isTrue,
      );
      for (final p in [StatsPeriod.all, StatsPeriod.custom]) {
        expect(
          StatsPeriodSelection(period: p).supportsNavigation,
          isFalse,
          reason: '${p.name} gezinilemez kalmalı',
        );
        expect(
          StatsPeriodSelection(period: p).shifted(-3).offset,
          0,
          reason: '${p.name} kaydırılamaz',
        );
      }
    });

    test('ileri ok yalnız geçmişteyken açık', () {
      const sel = StatsPeriodSelection(period: StatsPeriod.day);
      expect(sel.canGoForward, isFalse, reason: 'bugündeyiz, gelecek yok');
      expect(sel.canGoBack, isTrue);
      expect(sel.shifted(-1).canGoForward, isTrue);
      // Geleceğe taşma 0'da kırpılır.
      expect(sel.shifted(-1).shifted(5).offset, 0);
    });
  });

  group('WP-742 #2: gün aralığı', () {
    test('offset 0 → gün CANLI: (bugünün anahtarı, şimdi)', () {
      final now = DateTime(2026, 3, 11, 15, 30);
      final (from, to) = const StatsPeriodSelection(
        period: StatsPeriod.day,
      ).range(now: now);
      expect(from, dayOf(now));
      expect(to, now, reason: 'mevcut davranış korunmalı: üst uç "şimdi"');
    });

    test('offset -1 → dün, KAPALI gün: from == to == gün anahtarı', () {
      final now = DateTime(2026, 3, 11, 15, 30);
      final (from, to) = const StatsPeriodSelection(
        period: StatsPeriod.day,
      ).shifted(-1).range(now: now);
      expect(from, DateTime(2026, 3, 10));
      expect(to, DateTime(2026, 3, 10));
      expect(from, to, reason: 'tek günlük dönem: iki uç aynı gün');
      // 🔴 WP-612: kapanış "23:59:59.999" olsaydı `dayOf` onu İstanbul'a
      // çevirir ve UTC+3'ün batısındaki her cihazda (CI dâhil) gün bir ileri
      // kayardı — "dün" iki gün olurdu.
      expectDayKey(to, reason: 'kaydırılmış günün kapanışı');
      expectDayKey(from, reason: 'kaydırılmış günün açılışı');
    });

    test('ay sınırı: 1 Mart -1 → 28/29 Şubat (artık yıl dâhil)', () {
      // 2026 artık yıl DEĞİL: 1 Mart'ın dünü 28 Şubat.
      final (from2026, to2026) = const StatsPeriodSelection(
        period: StatsPeriod.day,
      ).shifted(-1).range(now: DateTime(2026, 3, 1, 9));
      expect(from2026, DateTime(2026, 2, 28));
      expect(to2026, DateTime(2026, 2, 28));

      // 2028 artık yıl: 1 Mart'ın dünü 29 Şubat.
      final (from2028, to2028) = const StatsPeriodSelection(
        period: StatsPeriod.day,
      ).shifted(-1).range(now: DateTime(2028, 3, 1, 9));
      expect(from2028, DateTime(2028, 2, 29));
      expect(to2028, DateTime(2028, 2, 29));
    });

    test('yıl sınırı: 1 Ocak -1 → 31 Aralık (önceki yıl)', () {
      final (from, to) = const StatsPeriodSelection(
        period: StatsPeriod.day,
      ).shifted(-1).range(now: DateTime(2026, 1, 1, 0, 30));
      expect(from, DateTime(2025, 12, 31));
      expect(to, DateTime(2025, 12, 31));
    });

    test('çok gün geriye: -40 gün ay sınırlarını doğru aşar', () {
      final (from, to) = const StatsPeriodSelection(
        period: StatsPeriod.day,
      ).copyWith(offset: -40).range(now: DateTime(2026, 3, 11, 15, 30));
      // 11 Mart - 40 gün: Mart'ta 10, Şubat 28, kalan 2 → 30 Ocak.
      expect(from, DateTime(2026, 1, 30));
      expect(to, DateTime(2026, 1, 30));
    });

    test('chartDays değişmedi (day = 7)', () {
      expect(StatsPeriod.day.chartDays(), 7);
    });
  });

  group('WP-742 #3: jumpTo', () {
    // Sabit "şimdi": 11 Mart 2026, Çarşamba.
    final now = DateTime(2026, 3, 11, 15, 30);

    test('day: gün farkı', () {
      expect(
        offsetAfterJump(StatsPeriod.day, DateTime(2026, 3, 11), now: now),
        0,
      );
      expect(
        offsetAfterJump(StatsPeriod.day, DateTime(2026, 3, 10), now: now),
        -1,
      );
      expect(
        offsetAfterJump(StatsPeriod.day, DateTime(2026, 1, 30), now: now),
        -40,
      );
    });

    test('week: hafta farkı (gün değil)', () {
      // 11 Mart Çarşamba → haftanın Pazartesisi 9 Mart.
      expect(
        offsetAfterJump(StatsPeriod.week, DateTime(2026, 3, 9), now: now),
        0,
      );
      expect(
        offsetAfterJump(StatsPeriod.week, DateTime(2026, 3, 8), now: now),
        -1,
        reason: '8 Mart Pazar = ÖNCEKİ hafta (Pazartesi başlangıçlı)',
      );
      expect(
        offsetAfterJump(StatsPeriod.week, DateTime(2026, 2, 24), now: now),
        -2,
      );
    });

    test('month: takvim ayı farkı, yıl sınırını aşar', () {
      expect(
        offsetAfterJump(StatsPeriod.month, DateTime(2026, 3, 31), now: now),
        0,
      );
      expect(
        offsetAfterJump(StatsPeriod.month, DateTime(2026, 2, 1), now: now),
        -1,
      );
      expect(
        offsetAfterJump(StatsPeriod.month, DateTime(2025, 12, 15), now: now),
        -3,
      );
    });

    test('year: yıl farkı', () {
      expect(
        offsetAfterJump(StatsPeriod.year, DateTime(2026, 12, 31), now: now),
        0,
      );
      expect(
        offsetAfterJump(StatsPeriod.year, DateTime(2024, 6, 1), now: now),
        -2,
      );
    });

    test('jumpTo sonrası aralık gerçekten o günü İÇERİR', () {
      final container = liveContainer();
      final notifier = container.read(statsPeriodProvider.notifier);
      notifier.setPeriod(StatsPeriod.day);
      notifier.jumpTo(DateTime(2025, 12, 31), now: now);

      final (from, to) = container.read(statsPeriodProvider).range(now: now);
      expect(from, DateTime(2025, 12, 31));
      expect(to, DateTime(2025, 12, 31));
      expect(
        container.read(statsPeriodProvider).period,
        StatsPeriod.day,
        reason: 'dönem TÜRÜ korunmalı',
      );
    });

    test('gelecek YOK: ileri tarih offset\'i 0\'a kırpılır', () {
      for (final p in [
        StatsPeriod.day,
        StatsPeriod.week,
        StatsPeriod.month,
        StatsPeriod.year,
      ]) {
        expect(
          offsetAfterJump(p, DateTime(2027, 7, 1), now: now),
          0,
          reason: '${p.name}: gelecek dönem açılamaz',
        );
      }
    });

    test('all/custom seçiliyken jumpTo sessiz no-op', () {
      for (final p in [StatsPeriod.all, StatsPeriod.custom]) {
        final container = liveContainer();
        final notifier = container.read(statsPeriodProvider.notifier);
        notifier.setPeriod(p);
        final before = container.read(statsPeriodProvider);
        notifier.jumpTo(DateTime(2024, 1, 1), now: now);
        final after = container.read(statsPeriodProvider);
        expect(after.period, before.period, reason: p.name);
        expect(after.offset, 0, reason: '${p.name}: offset değişmemeli');
        expect(
          after.range(now: now),
          before.range(now: now),
          reason: '${p.name}: aralık değişmemeli',
        );
      }
    });
  });

  // 🔴 ANLAR UTC ILE KURULUR, DUZ YEREL `DateTime` ILE DEGIL.
  //
  // Bu grup CI'da (UTC) kirmizi dustu, bu makinede (UTC+3) yesildi. Sebep
  // testin olctugu sey degil, olcum ANININ kendisiydi: `istanbul_calendar`
  // gun anahtari uretirken gece yarisi OLMAYAN bir `DateTime`i cihazin yerel
  // saatinden Istanbul'a CEVIRIR (`_dayKeyIn` -> `TZDateTime.from`). Yani
  // duz `DateTime(2026, 3, 10, 22)` UTC+3'te 10 Mart, UTC'de 11 Mart demek.
  //
  // `DateTime.utc(...)` mutlak bir andir; hangi makinede kosarsa kossun ayni
  // Istanbul gunune duser. Yorumlarda yazan saatler ISTANBUL saatidir
  // (Istanbul 2016'dan beri yil boyu UTC+3), UTC karsiligi yaninda verilir.
  //
  // Ayni sinif WP-612'de de yakalanmisti ve orada da yalnizca UTC+3'un
  // batisindaki makinelerde gorunuyordu.
  group('WP-742 #4: Duration.inDays tuzağı', () {
    // Istanbul 11 Mart 15:30
    final now = DateTime.utc(2026, 3, 11, 12, 30);

    // Nobetci: bu grubun anlari MUTLAK olmali. Biri duz yerel `DateTime`a
    // dondurulurse test yine bu makinede yesil kalir ve YALNIZ CI'da kirmizi
    // duser -- yani kusur gorunmez olur. Bu iddia onu ayni turda yakalar.
    test('olcum anlari saat diliminden BAGIMSIZ kurulmus', () {
      expect(now.isUtc, isTrue, reason: 'now duz yerel DateTime olmamali');
      expect(
        DateTime.utc(2026, 3, 10, 19).isUtc,
        isTrue,
        reason: 'gun ortasi an UTC ile kurulur',
      );
    });

    test('gün ORTASI bir an verilince inDays 0 der, doğrusu -1', () {
      // 🔴 Naif uygulama: `date.difference(now).inDays`.
      //    10 Mart 22:00 ile 11 Mart 15:30 arası -17sa 30dk; `inDays` sıfıra
      //    doğru kırptığı için 0 döner → kullanıcı "dün"e basıp BUGÜNde kalır.
      final date = DateTime.utc(2026, 3, 10, 19); // Istanbul 10 Mart 22:00
      expect(
        date.difference(now).inDays,
        0,
        reason: 'tuzağın kendisi: naif hesap kısmî günü yutuyor',
      );
      expect(
        offsetAfterJump(StatsPeriod.day, date, now: now),
        -1,
        reason: 'takvim aritmetiği gün ANAHTARLARINI kıyaslar',
      );
    });

    test('hafta: gün ortası an + hafta sınırı → inDays yine yanlış', () {
      // 8 Mart Pazar 20:00 → önceki hafta. Naif: (-2gün 19sa).inDays = -2,
      // `-2 ~/ 7 == 0` → kullanıcı bu haftada kalırdı.
      final date = DateTime.utc(2026, 3, 8, 17); // Istanbul 8 Mart 20:00
      expect(date.difference(now).inDays ~/ 7, 0, reason: 'naif hesap');
      expect(offsetAfterJump(StatsPeriod.week, date, now: now), -1);
    });

    test('Avrupa yaz saati geçiş günü (29 Mart 2026) doğru sayılır', () {
      // 29 Mart 2026 AB'de saatler ileri alınır: o gün YEREL olarak 23 saat
      // sürer. Gün farkını süreden türeten her hesap burada kayar.
      final dstNow = DateTime.utc(2026, 3, 30, 9); // Istanbul 30 Mart 12:00
      expect(
        offsetAfterJump(StatsPeriod.day, DateTime(2026, 3, 29), now: dstNow),
        -1,
      );
      expect(
        offsetAfterJump(StatsPeriod.day, DateTime(2026, 3, 28), now: dstNow),
        -2,
      );
      // Sonbahar geçişi (25 Ekim 2026, 25 saatlik gün) de aynı sözleşmede.
      final fallNow = DateTime.utc(2026, 10, 26, 9); // Istanbul 26 Ekim 12:00
      expect(
        offsetAfterJump(StatsPeriod.day, DateTime(2026, 10, 25), now: fallNow),
        -1,
      );
    });
  });
}

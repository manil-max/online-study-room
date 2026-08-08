// WP-571: "Bugün özeti" kartı günü CİHAZIN yerel tarihiyle seçiyordu.
//
// `today_summary_card.dart:37` şuydu:
//     sessions.where((s) => isSameDay(s.day, now))
// `s.day` bir İSTANBUL gün anahtarıdır (`istanbulDay(start)` ya da sunucunun
// damgaladığı `recordedDay`), `now` ise cihazın HAM yerel anı. `isSameDay` iki
// tarafın y/m/d alanlarını kıyasladığı için, cihazın yerel TARİHİ İstanbul
// TARİHİNDEN farklı olduğu her an kart YANLIŞ günü arar.
//
// Pencere genişliği = offset farkı:
//   * UTC cihaz (CI koşucusu dâhil): İstanbul 00:00–03:00 arası,
//   * New York (UTC−4): yerel 17:00'dan gece yarısına, yani HER GÜN 7 SAAT,
//   * UTC+4 ve doğusu: yerel gece yarısından İstanbul gece yarısına kadar kart
//     henüz var olmayan günü arar → "0 dk".
//
// 🔴 Kanıt tahmin değil: CI koşumu 31281652153 ("analyze + full test suite",
// Ubuntu/TZ=UTC) `today_summary_unbounded_wp515_test` içindeki dört testi
// `Found 0 widgets with text "Matematik"` ile düşürdü; aynı testler
// Europe/Istanbul makinede yeşildi. Yani hata testte değil ÜRÜNDE idi ve
// TR dışındaki her kullanıcıyı etkiliyordu.
//
// 🔴 Bu dosya KOŞUM MAKİNESİNDEN BAĞIMSIZDIR: anlar `DateTime.utc(...)` ile
// kurulur, dolayısıyla `.year/.month/.day` alanları UTC'dir ve İstanbul
// tarihinden bilerek ayrışır. Böylece hata, Türkiye'deki bir geliştirici
// makinesinde de kırmızı döner — eski kod bu dosyada HER makinede düşer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';

StudySession _session({
  required String id,
  required DateTime recordedDay,
  required int seconds,
  String? subjectId,
}) => StudySession(
  id: id,
  userId: 'u1',
  subjectId: subjectId,
  // Başlangıç/bitiş bilerek gün anahtarıyla tutarlı ama seçim onlara bakmaz:
  // sunucu damgası (`recordedDay`) varsa tek doğru kaynak odur.
  start: recordedDay,
  end: recordedDay.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
  recordedDay: recordedDay,
);

void main() {
  // 2026-08-08 22:30Z = İstanbul (UTC+3) 2026-08-09 01:30.
  // UTC alanları 8 Ağustos der, İstanbul günü 9 Ağustos'tur — hatanın tam
  // doğduğu aralık.
  final utcDeviceInsideWindow = DateTime.utc(2026, 8, 8, 22, 30);
  final istanbulToday = DateTime(2026, 8, 9);
  final istanbulYesterday = DateTime(2026, 8, 8);

  test('gün anahtarı cihazın yerel tarihiyle değil İSTANBUL günüyle eşleşir', () {
    // Ön koşul: senaryo gerçekten hatanın penceresinde mi? (Test kendi
    // kurulumunu doğrular; yoksa yarın "yeşil ama anlamsız" olurdu.)
    expect(
      dayOf(utcDeviceInsideWindow),
      istanbulToday,
      reason: 'Kurulum bozuk: seçilen an İstanbul 9 Ağustos gününe düşmüyor.',
    );
    expect(
      utcDeviceInsideWindow.day,
      isNot(istanbulToday.day),
      reason:
          'Kurulum bozuk: anın UTC tarihi İstanbul tarihiyle aynı, yani hata '
          'bu anda zaten oluşmaz.',
    );

    final bugun = _session(
      id: 'bugun',
      recordedDay: istanbulToday,
      seconds: 3600,
      subjectId: 'matematik',
    );
    final dun = _session(
      id: 'dun',
      recordedDay: istanbulYesterday,
      seconds: 1800,
      subjectId: 'fizik',
    );

    final secilen = sessionsOnDay([dun, bugun], utcDeviceInsideWindow);

    // Eski kod burada TAM TERSİNİ seçiyordu: `dun`u bugün sayıp `bugun`u
    // düşürüyordu. İki yönlü iddia, tek yönlü bir "boş değil" kontrolünün
    // kaçıracağı hatayı yakalar.
    expect(secilen.map((s) => s.id), ['bugun']);
    expect(totalSeconds(secilen), 3600);
  });

  test('gün anahtarı verildiğinde de aynı sonuç (dayOf idempotent)', () {
    final bugun = _session(
      id: 'bugun',
      recordedDay: istanbulToday,
      seconds: 900,
    );

    // Çağıran taraf ham an yerine gün anahtarı geçerse davranış değişmemeli;
    // aksi hâlde `sessionsOnDay` çağrı yerine göre farklı anlam taşırdı.
    expect(sessionsOnDay([bugun], istanbulToday).map((s) => s.id), ['bugun']);
    expect(
      sessionsOnDay([bugun], utcDeviceInsideWindow).map((s) => s.id),
      ['bugun'],
    );
  });

  test('pencere dışında da doğru: İstanbul öğleni tek günü seçer', () {
    // 09:00Z = İstanbul 12:00 — UTC tarihi ile İstanbul tarihi AYNI. Düzeltme
    // bu kolay durumu bozmamalı (regresyonun sessiz hâli budur).
    final ogle = DateTime.utc(2026, 8, 9, 9);
    final bugun = _session(id: 'b', recordedDay: istanbulToday, seconds: 60);
    final dun = _session(id: 'd', recordedDay: istanbulYesterday, seconds: 60);

    expect(sessionsOnDay([bugun, dun], ogle).map((s) => s.id), ['b']);
  });

  test('boş liste boş sonuç verir (çökme yok)', () {
    expect(sessionsOnDay(const <StudySession>[], utcDeviceInsideWindow), isEmpty);
  });

  test('kart seçimi tek kaynaktan geçer (kaynak sözleşmesi)', () {
    // 🔴 Yukarıdaki testler saf yardımcıyı ölçer; kartın ONU kullandığını
    // ölçmez. Kart `DateTime.now()` okuduğu için widget testinde saat enjekte
    // edilemez, bu yüzden bağ kaynak düzeyinde sabitlenir: eski satır geri
    // yazılırsa (ya da yeni bir `isSameDay(..., now)` doğarsa) bu iddia düşer.
    // Bu repoda "kural yazılıydı ama çağıran yoktu" hatası defalarca üretime
    // çıktı; ölçülmeyen bağ yok sayılır.
    final source = File(
      'lib/features/home/widgets/today_summary_card.dart',
    ).readAsStringSync();
    // Yorum satırları elenir: bu dosyadaki açıklama eski satırı ALINTILIYOR ve
    // ham metinde arama yapmak testi kendi belgesiyle düşürürdü.
    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code,
      contains('sessionsOnDay(sessions, now)'),
      reason: 'Kart günü artık ortak yardımcıdan seçmeli.',
    );
    expect(
      code,
      isNot(contains('isSameDay(s.day, now)')),
      reason:
          'Cihazın ham yerel anıyla gün karşılaştırması geri geldi — TR '
          'dışındaki kullanıcılarda "Bugün özeti" yanlış günü gösterir.',
    );
  });
}

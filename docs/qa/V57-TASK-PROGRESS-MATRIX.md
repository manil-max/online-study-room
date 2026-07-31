# V57 — Görev tarafı ilerleme kabul matrisi (WP-451)

Kapsam: tekrarlanan görev motorunun (WP-449) ve görev ekranının (WP-450) tek tek
değil **birbirine ve komşu kavramlara karşı** davranışı — takvim fazı, İstanbul
gün sınırı, çevrimdışı, undo, iki cihaz, silinen ders, ve görev tamamlamanın
çalışma süresi/başarım/grup ilerlemesine sızmaması.

Kanıt dosyaları:

| Uç | Dosya | Kapsam |
| --- | --- | --- |
| İstemci | `app/test/data/task_progress_matrix_wp451_test.dart` | 15 senaryo |
| Sunucu | `supabase/tests/034_user_task_recurrence_contract.test.sql` | 21 iddia (WP-472) |
| Şema | `supabase/migrations/0109_user_task_recurrence_interval.sql` | interval + anchor |

---

## 1. Matris

| # | Senaryo | Kabul | Durum |
| --- | --- | --- | --- |
| 1 | 1 günlük cadence | occurrence = anchor + k·1 | ✅ |
| 2 | 2 günlük cadence | ara gün occurrence üretmez | ✅ |
| 3 | 3 günlük cadence | 12 occurrence boyunca faz sabit | ✅ |
| 4 | 7 günlük cadence | 12 occurrence boyunca faz sabit | ✅ |
| 5 | Tamamlama kaydı faz hesabına girmez | `completionDay` girdi değil | ✅ |
| 6 | İstanbul gün sınırı 23:59 / 00:01 | farklı occurrence günleri | ✅ |
| 7 | Eski DST geçiş tarihleri | aralık tam N gün | ✅ |
| 8 | Çevrimdışı yazma hatası | occurrence tüketilmez, retry geçer | ✅ |
| 9 | Hızlı çift tap | başlangıç durumu, tek satır | ✅ |
| 10 | Undo → yeniden tamamlama | faz ve occurrence sayısı korunur | ✅ |
| 11 | Aynı `operationId` tekrarı | iş yapılmaz | ✅ |
| 12 | Çelişkili `operationId` tekrarı | `task_operation_conflict` | ✅ |
| 13 | İki cihaz | B reload'da A'nın tamamlamasını görür | ✅ |
| 14 | Silinen ders | görev ve tamamlanma durumu etkilenmez | ✅ |
| 15 | Görev tamamlama | çalışma süresi/oturum üretmez | ✅ |

Kabul kriterlerine karşılık:

* **cadence drift 0** → 1–5, 7
* **occurrence kaybı/çifti 0** → 8–13
* **undo sonrası ilerleme uzlaşması doğru** → 10
* **kavramlar arası yan etki** → 14, 15

---

## 2. Mutasyon turunda yakalanan **test zaafı**

Bu, kodda değil **testte** bulunan bir hata; not edilmeye değer çünkü sınıfı
tekrar edecek cinsten.

İlk yazdığım "geç tamamlama sonraki occurrence gününü kaydırmaz" testi, fazı
`completionDay`e kaydıran bir mutasyonu **yakalamadı**. Sebep yapısaldı:

> Tamamlama yalnız döngü günlerinde mümkün olduğu için (`taskOccurrenceDayForCompletion`
> döngü dışında `null` döner), `anchor = tamamlama günü` ile `anchor + k·N`
> **ileriye doğru aynı kafesi üretir**. İki farklı uygulama, gözlemlenebilir
> aynı sonucu veriyordu.

Yani test "doğru sonucu" ölçüyordu ama "doğru sebebi" ölçmüyordu — kartın
kabul kriteri olan *cadence drift 0* aslında hiç bağlanmamıştı.

Düzeltme: fark ancak **kafes dışında bir `completionDay`** varken görünür
(eski/bozuk kayıt, saat oynaması, elle düzeltme). Yeni test tam olarak o durumu
kuruyor ve şu değişmezi sabitliyor: **faz yalnız anchor'a bağlıdır.** Mutasyon
tekrar uygulandığında test kırmızıya döndü.

Genel ders: "bu mutasyonu neden yakalamadı" sorusunun cevabı çoğu zaman
"senaryo o farkı gözlemlenebilir kılmıyor" olur; çözüm iddiayı sertleştirmek
değil, **farkın görünür olduğu durumu kurmak**.

---

## 3. Neden bazı satırların sunucu eşi yok

* **İki cihaz / reload** — istemci yakınsama davranışı; sunucuda karşılığı
  `034`'teki replay iddialarıdır.
* **Silinen ders** — `user_tasks` şemasında `subject_id` **yok**. Satır bu
  ayrımın kazara bozulmadığını sabitler: ileride bir ders bağı eklenirse
  `on delete cascade` sessizce görev kaybına dönüşebilirdi.
* **Çalışma süresi izolasyonu** — başarım ve grup ilerlemesi yalnız
  `study_sessions`'tan beslenir; görev tablosu bu zincirin hiçbir yerinde
  okunmaz (migration taramasıyla doğrulandı).

## 4. WP-455 için fixture

WP-455 (seri ve bütün ilerleme matrisi) bu dosyadaki iki yardımcıyı doğrudan
okuyabilir:

* `_recurring({intervalDays, anchor, id})` — deterministik tekrarlanan görev.
* `_occurrenceRun(task, from, count)` — occurrence günlerini **motora
  sordurur**; sabit bir liste ile karşılaştırmak motoru değil testin kendi
  aritmetiğini doğrulamak olurdu.

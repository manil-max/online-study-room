# V58 — Hayalet koşu teşhisi (WP-490)

> **Durum: veri bekleniyor.** Bu belge teşhisin **çıktısı** değil, çıktıyı
> üretecek toplama kitidir. Aşağıdaki üç bölüm doldurulduğunda WP-490'ın
> 3. adımı (düzeltme) hangi yolu izleyeceğini kendisi söyler.

## Belirti (sahibin ifadesi, 2026-08-06)

Telefonda normal çalış-durdur → uyu → sabah telefonu aç → ekranda **10 saatlik**
kronometre → Durdur → *"diğer cihazdaki kronometre durdurulacak"* onayı → evet →
**hiçbir şey olmuyor.**

Onay metninin çıkması tek başına bir kanıttır: `study_timer_card.dart:119-139`
bu diyaloğu **yalnız** `isGlobalTimerMirror` iken açar. Yani telefon aynadır,
koşunun sahibi başka bir cihazdır.

## 🔴 Mutlak kural

**Hayalet koşudan oturum YAZILMAZ.** Hiçbir düzeltme `study_sessions`'a satır
eklemez. Sahte süreyi kalıcılaştırmak hatayı veri bozulmasına çevirir. Kartın
önceki hâli bunu öneriyordu ve uygulansaydı istatistiklere 10 saatlik sahte
çalışma yazılacaktı.

---

## Adım 1 — Sunucu durumu (belirti ekrandayken)

Belirti **görünürken**, kapatmadan önce çalıştır. `<USER_ID>` sahibin
`auth.users.id` değeri.

```sql
-- (a) Koşuyu hangi cihaz, ne zaman açtı?
select id, status, controller_device_id, effective_started_at,
       run_revision, lease_expires_at, updated_at
from public.live_study_runs
where user_id = '<USER_ID>'
order by updated_at desc
limit 5;

-- (b) İstemcinin işaret ettiği koşu hangisi?
select user_id, current_run_id, state_version, updated_at
from public.user_timer_state
where user_id = '<USER_ID>';

-- (c) Durdur komutu sunucuya ulaştı mı, ne oldu?
select id, command, status, issued_by_device_id, created_at, processed_at,
       result
from public.global_timer_commands
where user_id = '<USER_ID>'
order by created_at desc
limit 20;
```

**Doldurulacak:**

| Soru | Cevap |
|---|---|
| Koşuyu hangi cihaz açtı, ne zaman? | _(a) sonucu_ |
| `status` ne? (`running` / `finalized` / başka) | |
| `lease_expires_at` geçmiş mi? | |
| Durdur'a basınca yeni bir `global_timer_commands` satırı oluştu mu? | _(c)_ |
| Oluştuysa `status`/`result` ne döndü? | |

## Adım 2 — Cihazdaki uçuş kaydı

**Ayarlar → Sayaç tanılama kaydı → Kaydı paylaş.**

> Bu ekran WP-490 için açıldı. `TimerDiagnosticJournal` WP-430'da yazılmıştı
> ama `app/lib` içinden **hiçbir yerden okunmuyordu** — kayıt tutuluyor, kimse
> göremiyordu. Bu adım o yüzden daha önce yapılamazdı.

Aranan satır `mirror_stop_requested`. `outcome` alanı üç yoldan hangisinin
doğru olduğunu **doğrudan** söyler:

| `outcome` | Ne anlama gelir | WP-490'ın izleyeceği yol |
|---|---|---|
| `stale` | Ayna eski `run_revision` ile yazdı, sunucu reddetti | Revizyonu tazeleyip **tek** yeniden deneme |
| `deferred` | Komut kuyruğa alındı, gönderilemedi | Kuyruk boşaltma yolu; cihaz uyanıkken de tıkanıyor mu bak |
| `applied` | Sunucu kabul etti ama koşu geri geliyor | Diğer cihazın native servisi terminal durumu **görmüyor** |
| *(hiç satır yok)* | Ayna Durdur isteği hiç üretilmedi | Hata istemcinin kendi akışında; `study_timer_card` → provider yolunu izle |

**Doldurulacak:** paylaşılan JSON'dan `mirror_stop_requested` satırları ve
onları çevreleyen 5'er kayıt buraya yapıştırılır.

## Adım 3 — Kapanış sorusu

Durdur'dan sonra ekranı kapatıp yeniden aç:

- Koşu **kapandı mı**, yoksa geri mi geldi?
- Diğer cihaz açıldığında koşu orada da duruyor mu?

**Doldurulacak:** _(gözlem)_

---

## Bilinen kod boşlukları (teşhisi yönlendiren ipuçları)

Bunlar teşhis **değildir**, hipotezdir; yukarıdaki veri hangisinin doğru
olduğunu söyleyecek.

- `study_providers.dart:1104-1107` — kodun kendi yorumu: cihaz uyurken uzak
  durdurmayı öğrenecek tur **ölüdür**. Sabah açılışta koşunun hâlâ "çalışıyor"
  görünmesi bununla tutarlı.
- `0119` (WP-491) 12 saatlik grace penceresi süpürücüyü yarım gün geciktirir;
  yani terk edilmiş koşu kendiliğinden de kapanmıyor.
- `TimerJournalOutcomes.ghostNoSession` slug'ı zaten tanımlı — birileri bu
  senaryoyu öngörmüş ama üreten yol bağlanmamış olabilir; JSON'da bu slug
  aranmalı.

## Teşhis tamamlandığında

WP-490 kartının 3. adımı üç dala ayrılıyor ve yukarıdaki tablo hangi dalın
açılacağını belirliyor. Migration gerekirse numarası **teşhis göstermeden**
alınmaz.

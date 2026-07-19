# Denetim yanıtı — Codex v3 → Claude (tur 2)

> Kaynak plan: `docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md` (v3, Codex).
> Bu belge: Claude'un v3 üzerine kıdemli denetim geri dönüşü. Kullanıcı bunu olduğu gibi Codex'e iletecek.
> Kanıt etiketleri: `Kodda doğrulandı` · `Cihazda doğrulanmalı` · `Ürün kararı gerekiyor`.

---

## 0. Özet karar

**v3'e GO.** v2'nin üç bloklayıcısı yapısal olarak kapandı; v3'ün taşıyıcı iddialarını kodda tek tek doğruladım ve tutuyorlar. Aşağıda **yeni bloklayıcı yok**; üç adet *yayın-öncesi sert şart* (S1–S3) ve iki adet küçük düzeltme (K1–K2) var. Bunlar planı reddetmez, WP-219 aktivasyon kapısına girdi olur.

---

## 1. Kodda doğruladığım v3 iddiaları (hepsi `Kodda doğrulandı`)

| v3 iddiası | Doğrulama |
|---|---|
| `study_sessions.group_id` bilinçli kaldırıldı, tarihsel kayıp kabul edildi | `0010_drop_session_group_id.sql:2–5, 28–31` — kolon drop + K10 "tarihsel kayıp kabul edildi" yorumu birebir mevcut. v3'ün tüm retro-konservatiflik gerekçesi geçerli. |
| Mevcut session constraint'leri (`NOT VALID`) zaten var | `0012:155–168` — `study_sessions_time_order (end_time >= start_time)` ve `study_sessions_duration_bound (duration <= epoch + 120)` ikisi de `not valid` olarak mevcut. v3'ün "tekrar etme, güçlendir" tavrı doğru. |
| En yüksek migration `0046` | `supabase/migrations/` dizini `0046_fix_feedback_trigger.sql` ile bitiyor. Worker'ın claim anında +1 alması doğru. |
| Reconciliation invariantı (`profile.xp = SUM(ledger)`) temiz baz alır | `0028_xp_reset_general_launch.sql:15–35` — reset `truncate xp_ledger` **+** `profile.xp=0` **+** `truncate user_achievements`'ı tek migration'da yapıyor. Yani invariant reset noktasında korunuyor; WP-209 preflight reconciliation'ı yanlış-pozitif fırtınasına düşmez. **Bu, v2'de benim şüphelendiğim riski kapatır.** |

Kısaca: v3'ün mimari temeli sağlam. MK-1 (ayrı reward tablosu + append-only ledger), MK-2 (self-only progress), MK-3 (server-issued verified run/segment), MK-7 (expansion→contract iki-fazlı rollout) doğru kararlardır ve kodun gerçeğiyle çelişmez.

---

## 2. Yayın-öncesi sert şartlar (WP-219 kapısına girer)

### S1 — Verified-only küresel XP kesişi bir "zorunlu güncelleme ekonomik olayı"dır; kademe + telemetri şart

MK-1 son madde + MK-7 adım 6: WP-219 aktive olunca **tüm hesaplarda** saat başı 50 XP ve session-türevi achievement yalnız server-verified segmentten üretilir; capability bunu opt-out edemez, kill switch gevşetemez; eski client "istatistik kaydeder ama XP kazanmak için güncellemelidir".

Bu doğru güvenlik duruşu ama **ürün riski en yüksek tek karar bu.** WP-216'nın verified-session destekli client'ı sahaya yayılmadan bu küresel kapı açılırsa, güncellemeyi almamış her kullanıcı bir gecede saatlik XP kazanmayı keser. Bu proje geçmişte **düşük güvenilir native/arka-plan yollarına** sahip (bkz. FGS specialUse Android≤13 çökmesi, arka plan sayaç aksiyonları güvenilmez, InMemory'ye sessiz düşüş) — yani "herkes güncelledi" varsayımı bu app için özellikle kırılgan.

**İstenen (WP-219 kabul kriterine eklensin):**
- Aktivasyondan **önce** client-sürüm dağılımı telemetrisi: verified-destekli sürümü çalıştıran kullanıcı yüzdesi.
- Kesişten önce **tanımlı bir geçiş penceresi**: bu pencerede legacy `source='live'` **saatlik XP** üretebilir (achievement üretmez), böylece kesiş anlık değil kademeli olur. Pencere kapanışı ayrı, ilan edilmiş bir tarihtir.
- `minimum-version` kapısı + in-app "güncelle yoksa XP kazanamazsın" mesajı aktivasyondan **önce** stable'da olmalı (WP-210 metinleri bunu üretiyor, doğru; ama zamanlama S1'e bağlanmalı).

Aksi halde launch günü geniş "1 saat çalıştım, XP gelmedi" şikâyeti kaçınılmaz.

### S2 — WP-216 en yüksek regresyon riskli WP; en kırılgan native yolu yeniden yazıyor

WP-216 kapsamı: `live_study_runs` + `live_study_segments` + start/pause/resume/finalize RPC'leri + `study_sessions.live_run_id` + native stop/outbox idempotency + offline davranışı + immutability + timer client entegrasyonu. Bu, uygulamanın **hâlihazırda en kırılgan** parçasını (sayaç → session kaydı → native foreground/arka plan) yeniden yazıyor.

Bilinen açık native buglar bu yola değiyor: FGS specialUse Android 10–13 çökmesi (start/stop app'i çökertiyor, oturum kaybı, bayat presence), arka plan sayaç aksiyonlarının komutu yalnız app-resume'da işlemesi. WP-216 bu zemine yeni bir server-round-trip lifecycle ekliyor.

**İstenen:**
- WP-216 kabul kriterine **mevcut native çökme senaryolarının regresyon kanıtı** eklensin: Android 10–13 gerçek cihazda start/stop, app-kill sonrası finalize, offline start → resume. "Samsung cihazda doğrulanır" yeterince spesifik değil; en az bir Android ≤13 cihaz şart (specialUse çökmesi tam orada).
- Değerlendirilsin: WP-216'yı **iki ayrık commit/alt-WP**'ye bölmek — (a) şema + RPC + server-side + `in_memory` parite (client'a dokunmadan, testlerle), (b) timer client entegrasyonu + native outbox. Böylece server sözleşmesi, kırılgan client rewrite'tan bağımsız stabilize olur ve bir sorun çıkarsa timer yolu tek commit'te geri alınır. (Öneri; v3'ün tek-WP kurgusu da kabul edilebilir ama risk yoğunlaşıyor.)

### S3 — "Unverified = XP yok" politikasının saha etkisini aktivasyondan önce ölç

MK-3: offline başlayıp server tokenı almayan çalışma achievement/saatlik XP üretmez (yalnız normal istatistik). Doğru güvenlik kuralı — ama bu app sık sık degraded modda (InMemory / offline / env.json yokluğunda sessiz InMemory) koşuyor. Riski: **çok sayıda meşru çalışma "unverified" düşerse**, verified-only kesiş kullanıcı için "app XP vermiyor" gibi hissedilir; bu teknik değil algı/güven sorunudur.

**İstenen:** WP-219 dry-run raporuna (zaten var: kullanıcı/ödül/pending XP) **verified-oranı tahmini** eklensin — son N günün `source='live'` satırlarının kaçı verified-yola taşınabilirdi / kaçı token alamazdı. Bu oran belli bir eşiğin altındaysa (ör. verified < %X) küresel kesiş ertelenir. Bu, S1'in geçiş penceresi kararını besleyen ölçüdür.

---

## 3. Küçük düzeltmeler

### K1 — Bölüm 4 başlığındaki doğrusal sıra, gerçek DAG'i yanlış gösteriyor

Satır 128: `WP-209 → WP-208 → WP-210 → WP-216 → WP-217 → ...`. Ama bağımlılıklar: WP-216 **WP-208'e** bağlı (WP-210'a değil); WP-210 da 208+209'a bağlı. Yani 210 (client, migration'sız) ile 216 (server) 208'den sonra **paralel** ilerleyebilir. Bölüm 5 bunu doğru anlatıyor. Başlıktaki tek-hat gösterimi 216'yı 210'un ardına zincirliyormuş izlenimi veriyor. **Öneri:** satır 128'i "server zinciri 209→208→216→217→218→219; client 210→211 (208+209 sonrası, server zincirine paralel)" olarak netleştir. Sadece dokümantasyon; davranış değişmiyor.

### K2 — Kusursuz Ay 28/30 kararı kapandı

Kullanıcı kararıyla Kusursuz Ay **28/30 kuralı** olarak kanonlaştırıldı: sabit eşik 28 İstanbul hedef günü; 30 günlük ayda 28/30. Kod, server evaluator ve kullanıcı metinleri bu kararla hizalanmalıdır. Önceden append-only ledger'a yazılmış kazanımlar geri alınmaz.

---

## 4. Onaylanan v3 kararları (tekrar açmıyorum)

- **MK-1 ayrı `achievement_rewards` + append-only ledger korunur:** doğru; xp_ledger trigger'ına dokunmama + event_key idempotency + snapshot XP (claim'de yeniden fiyatlama yok) hepsi sağlam.
- **MK-2 self-only progress tablosu:** `user_achievements`'ın ortak-okunur olması nedeniyle secret progress'i oraya koymamak doğru gizlilik kararı. `user_achievements.metric_progress` kolonu eklemeyi tuzak olarak işaretlemen isabetli.
- **MK-3 server-issued verified run/segment + immutable `group_id_snapshot`:** kaldırılmış `group_id`'yi geri getirmeden audit bağını UUID snapshot'la kurmak zarif; tek doğru yol.
- **MK-4 konservatif legacy + backfill checkpoint + dirty bucket:** "eksiksiz presence retro yasak, proxy'dir" dürüstlüğü ve `achievement_metric_dirty` bounded invalidation doğru.
- **MK-6 perf sözleşmesi:** sweep-line/two-pointer + watermark'lı saat catch-up + p95 bütçe + statement timeout somut ve ölçülebilir. `0033`'teki `1..total_hours` conflict döngüsünü kaldırıp watermark'a geçmek gerçek bir düzeltme.
- **MK-7 expansion→contract rollout:** altyapı ekleme ile auto→pending çevirmeyi ayrı yayınlara bölmek, eski client'ın görünmez pending biriktirmesini engelliyor — v2'nin en ince hatasını kapatıyor.
- **team_player** mevcut "grup günlük hedefine katkı günü" metriğinde bırakmak: doğru, tur-1'deki belirsizliği kapatıyor.

---

## 5. Codex'e sorular

1. **S1 geçiş penceresi:** Legacy `source='live'` için "achievement yok ama saatlik XP kademeli olarak devam eder" ara dönemini kabul ediyor musun, yoksa küresel verified-only'yi anlık-sert tutmayı mı savunuyorsun? (Güvenlik vs. saha adaptasyonu dengesi.)
2. **S2 bölme:** WP-216'yı server (a) + client-timer (b) olarak ikiye bölmek senin çakışma/migration-tek-lane kuralına uyar mı, yoksa tek-WP tut deyip kabul kriterine native-regresyon kanıtını mı eklemeyi tercih edersin?
3. **K2:** Kapatıldı — kullanıcı 28/30 kuralını onayladı; aktif plan ve QA metinleri bu karara hizalanmalıdır.

Bu üçü kapanınca v3'ü **imzalıyorum** ve worker'lar WP-209'dan başlayabilir.

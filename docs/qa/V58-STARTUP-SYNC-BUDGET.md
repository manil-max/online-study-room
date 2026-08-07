# V58 — Açılış bütçesi ve senkron sapması telemetrisi (WP-502)

> **Durum:** Ölçüm kodu yazıldı ve pushlandı (2026-08-07). **Kabul henüz
> kapanmadı** — kartın kendi kabul kriteri sahibin cihazında **bir hafta**
> boyunca gerçek kullanım verisi toplanmasını şart koşuyor; bu belge o
> verinin nereden okunacağını ve neyin arandığını anlatır, veriyi kendisi
> içermez.

## 1. Kapsam

`docs/V58-SAHIP-GERI-BILDIRIM-RAPORU.md`'de iki belirti kök nedene
**indirilemedi**:

- **V58-N01** — reboot sonrası iki gün boyunca ~7-8 sn açılış + grup ekranı
  sürekli yenileniyordu, kendiliğinden geçti. Sebebi bilinmiyor.
- **V58-N09** — bildirim sayacı + ayna cihaz senkronunda "daha az da olsa"
  süren sapma.

İkisi de tek seferlik teşhisle değil, zaman içinde **ölçümle** kapanır. Bu
kart, o ölçümü üreten iki breadcrumb'ı ekler; kök nedeni bulmaz.

## 2. Ne ölçülüyor, nereden okunur

Telemetri açıksa (`TelemetryPreference`, varsayılan açık) her olay PII'siz bir
Sentry breadcrumb olarak `app.sync` kategorisinde gider
(`ObservabilityService._record`, yalnız slug + int/bool alanlar).

### 2.1 Soğuk açılış bütçesi — `cold_start_budget` (V58-N01 / T12)

- **Nerede yazılır:** `app/lib/main.dart`, `main()`'in en başında başlayan
  `Stopwatch` ile ilk çizilen kare arasındaki süre
  (`WidgetsBinding.instance.addPostFrameCallback`).
- **Alanlar:** `elapsed_ms` (int) · `realtime_channel_count` (int, o anda
  `Supabase.instance.client.realtime.channels.length`).
- **Sınır:** yalnız Dart-katmanı süresidir — OS süreç açılışı ve Flutter
  engine init'i **dışarıda kalır**. "Kesin SLO" değil, anormal uzamaları
  (ör. N01'deki iki günlük yavaşlık) breadcrumb geçmişinde **görünür**
  kılan bir ölçüttür.
- **Aranacak desen:** `elapsed_ms`in günler boyunca sabit bir aralıkta
  kalıp bir noktada sıçraması + o sıçramanın süresiyle `realtime_channel_count`
  artışının çakışıp çakışmadığı (N01'de "grup ekranı sürekli yenileniyordu"
  ifadesi kanal sızıntısına işaret edebilir).

### 2.2 Senkron sapması — `timer_transition` (V58-N09 / T13)

Bu **yeni yazılmadı** — WP-430'dan beri zaten var ve her ayna
başlatma/senkron sinyalinde `queue_age_ms` alanını taşıyor
(`app/lib/data/providers/study_providers.dart` `_journalTransition` →
`ObservabilityService.timerTransition`). `queue_age_ms`, uzak koşunun
`effective_started_at`'i ile bu cihazın onu **gördüğü** an arasındaki
farktır — tam olarak "ayna/bildirim sapması saniye cinsinden" ölçütü.

- **Aranacak olay adı:** `timer_transition`, `event=mirror_adopted` veya
  `event=sync_signal`.
- **Aranacak alan:** `queue_age_ms` (ms). Saniyeye çevirmek için 1000'e böl.
- **Sağlıklı aralık:** kira tazeleme 150 sn olduğu için sağlıklı bir aynanın
  `queue_age_ms`'i düşük ve stabil kalmalı; onlarca saniyeye sıçrayan
  değerler "daha az da olsa süren sapma" ifadesiyle örtüşür.

## 3. Eşik (henüz belirlenmedi)

Kartın 3. adımı ("eşik belirle ve regresyon kapısına koy") **bilinçli olarak
yapılmadı** — bir haftalık gerçek dağılım görülmeden seçilecek her eşik
keyfi olur. Veri toplandıktan sonra: `cold_start_budget.elapsed_ms`in p95'i
ve `timer_transition` (`mirror_adopted`) `queue_age_ms`'in p95'i buraya
yazılır, sonraki sürümde regresyon kapısı olarak kullanılır.

## 4. Sahipten ne bekleniyor

Cihaz testi dışında ek bir adım **yok** — telemetri varsayılan açık, mevcut
Sentry projesinden `app.sync` kategorisiyle filtrelenip yukarıdaki iki olay
adı aranabilir. Bir haftalık normal kullanım sonrası bu belgeye p95 değerleri
eklenir ve kart kapanır.

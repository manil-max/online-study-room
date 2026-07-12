# Odak Kampı — Teknik & Mimari Plan

> ⚠️ **Bu belge [KALITE-PROGRAMI.md](./KALITE-PROGRAMI.md)'ye taşındı.** Güncel ve kanonik plan orasıdır; bu dosya arşiv/kaynak olarak kalır.
>
> Tarih: 2026-07-12 · Durum: **Plan, kod değişikliği yok**
> Sunum (etkileşimli): https://claude.ai/code/artifact/d6047722-025b-43a4-bbda-45f3f0faa321
> Ürün karşılığı: [YOL-HARITASI.md](./YOL-HARITASI.md)

## Mimari felsefe: yıkma, güçlendir

Mevcut temel sağlam (Flutter + Riverpod 3 + Supabase + çift repository + RLS +
offline-first). Atılmaz. Pro seviyesi, bu temelin üstüne eksik katmanları
eklemekle gelir: arka plan yürütme, gözlemlenebilirlik, sunucu-tarafı hesaplama,
gerçek tema motoru. Riskli/native/AI işleri feature-flag arkasında izole edilir.

## Altyapı denetimi (tut / ekle / değiştir)

| Katman | Bugün | Pro hedef | Karar | Neden |
|---|---|---|---|---|
| Durum yönetimi | Riverpod 3.3 (elle) | + `riverpod_generator` (ops.) | tut | Tip güvenliği, az boilerplate |
| Arka plan yürütme | **Yok** | `flutter_foreground_task` + Kotlin foreground service + WorkManager | **ekle** | İstek 1/2/5: app kapalıyken canlı sayaç + widget besleme |
| Bildirim | flutter_local_notifications | + chronometer + full-screen intent | ekle | Canlı HH:MM:SS + alarm çalar ekranı |
| Home widget | home_widget + 3 native provider | + arka plan besleme pipeline (isolate/WorkManager) | ekle | Stats/leaderboard gerçek veriyle beslensin |
| Yerel veri | shared_preferences + özel cache | **drift (SQLite)** | **değiştir** | Sorgulanabilir sağlam yerel depo; offline-first güçlenir |
| Hata/çökme izleme | **Yok** | `sentry_flutter` (crash + perf) | **ekle** | Pro olmazsa olmazı |
| Ürün analitiği | **Yok** | PostHog / Firebase Analytics (gizlilik odaklı) | ekle | Kullanımı ölç, kararı veriyle ver |
| Feature flag / config | **Yok** | Supabase config tablosu / Remote Config | ekle | Kademeli yayın, acil kapatma |
| Sunucu mantığı | RPC agregasyon | + Edge Functions + `pg_cron` + trigger | ekle | Başarım/seri hesabı sunucuda → tutarlı, hilesiz |
| Test | unit + widget | + `integration_test` + golden (tema) + CI kapısı | ekle | Regresyonu üründen önce yakala |
| CI/CD | Release workflow | + PR'da analyze/test/golden kapısı + Play Internal | ekle | Her değişiklik doğrulansın |
| Animasyon/asset | Vektör fallback | rive / Lottie | ekle | Saat, kamp ateşi, seri alevi |
| Tema | Elle `AppTheme` | **Token tabanlı `ThemeExtension` motoru** | **değiştir** | Zemin/yüzey/gradyan/şekil/tipografi değişsin |
| i18n | Sabit TR string | flutter_localizations + arb (ops.) | ekle | İleride çoklu dil |

## Android native gerçeği (AndroidManifest.xml okundu)

**Var:** `INTERNET`, `POST_NOTIFICATIONS`, `REQUEST_INSTALL_PACKAGES`; 3 widget
provider (Timer/Stats/Leaderboard) + `TimerActionReceiver` (native iskelet mevcut).

**Eklenecek (v9/v10):** `FOREGROUND_SERVICE` (+ tipi), `WAKE_LOCK`,
`SCHEDULE_EXACT_ALARM`/`USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`,
`RECEIVE_BOOT_COMPLETED`, foreground `<service>` tanımı.

**Risk:** OEM (Samsung/Xiaomi) agresif pil kısıtı foreground service'i öldürebilir → cihaz matrisinde ayrı test.

## AI teknolojileri (sunucu tarafı, graceful)

Çekirdek AI **Supabase Edge Function → Claude API** ile çalışır. Anahtar asla
istemcide değil; yalnız **agregat** veri gider (PII yok); AI kapalıysa çekirdek
aynen çalışır; yanıtlar önbelleklenir + hız sınırı.

- **AI Çalışma Koçu:** istatistik özetinden kişiselleştirilmiş içgörü/öneri.
- **Adaptif hedef & bildirim:** hedefi geçmişe göre ayarla; dürtme/hatırlatıcı metnini bağlama göre yaz.
- **Grup haftalık AI özeti:** grubun haftasını doğal dille özetle/kutla/öner.
- **Akıllı tema/rozet önerisi:** çalışma ritmine göre tema + öne çıkan rozet.
- (Ops.) **Anomali/anti-hile:** anormal çalışma süresi tespiti.

## Büyük alanların teknik yaklaşımı

- **v9 Canlı Sayaç:** foreground service sayacı süreçten bağımsız yürütür;
  `startedAt` tek gerçek kaynak → chronometer bildirimi + widget snapshot aynı
  andan beslenir; boot receiver restore; komut kuyruğu `timer_external_command_store` üstüne.
- **v10 Saat:** AlarmManager exact + tam ekran çalar activity + boot restore;
  dünya saati `timezone` db; kronometre/zamanlayıcı foreground service paylaşır;
  mevcut `alarm_rule`/`timer_preset`/`local_alarm_repository` üstüne; Rive.
- **v11 Tema Motoru:** `ThemeSpec` (zemin/yüzey/gradyan/şekil/tipografi/ışık) →
  `ThemeExtension`; tema başına arka plan painter; tüm `Theme.of` denetimi; her
  tema golden test; `paletId` → yeni spec migration.
- **v12 Başarım/Sosyal Profil:** tek motor; hesap sunucuda (Edge Function +
  `pg_cron` gece + on-write trigger); şema `achievements/badges/xp/crown`;
  herkese açık profil RLS (grup üyeliği); realtime taç; seri alevi (Rive).

## Teknik Bitiş Tanımı (ürün DoD'sine ek)

- Sentry ile crash-free oranı ölçülür.
- Yeni mantık birim + integration testle örtülür.
- Tema/görsel golden test yeşil.
- Arka plan davranışı gerçek cihazda kanıtlı (kayıt).
- İstemcide sır yok; AI/anahtar sunucuda.
- Migration + geri alma planı hazır.
- Riskli özellik feature-flag arkasında.

## Riskler

- OEM pil kısıtı (foreground service ölümü) → cihaz matrisi testi.
- Android 13+ exact alarm izni + Play politikası (foreground service tipi gerekçesi).
- AI maliyet/gecikme/gizlilik → önbellek + hız sınırı + agregat veri.
- drift geçişinde veri taşıma.
- Tema refactor geniş yüzey → golden testler şart.

## Not
- Aynı prompt Codex'e de verildi (paralel). Çıktı görülünce paket sınırları ve
  teknoloji seçimleri hizalanır; çakışma lane disipliniyle önlenir.

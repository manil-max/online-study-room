# KALITE-PROGRAMI — Tarihsel Bölümler (Arşiv)

> `docs/KALITE-PROGRAMI.md`'den **2026-07-19'da ayrıldı** (token optimizasyonu).
> Buradaki bölümler **tamamlanmış program dilimlerinin tarihsel kapsam/tanı detayıdır** — güncel karar kaynağı değildir. Canlı yönetişim (çalışma sistemi, kalite kapıları, eşzamanlılık kuralı, açık Play programı, açık kararlar) ana `../KALITE-PROGRAMI.md`'de kaldı.
> İçerik: §0 Yönetici Özeti, §1 Ürün Vizyonu, §3 Kod Kanıtlı Durum Denetimi (B1–B10), §5.1 Yığın Denetimi, §6 AI Katmanı, §8.1–8.7 tamamlanmış program kapsamları (V8-A/B/C, Saat, Tema, Başarım 3.0, Windows), §10 Faz 0 teslimleri, §12 Uzlaştırma Notları.

---

## 0. Yönetici Özeti (tarihsel — 2026-07-12)

Kullanıcının talebi **daha fazla özellik değil, ürün geliştirme kültürünün değişmesidir.** Sorun ekip hızı değil; "kodlandı" durumunun "bitti" sayılmasıdır. Bu yüzden iş, klasik bir özellik yol haritası değil, bir **kalite programıdır.** Doğru cevap: daha çok WP açmak değil "tamamlandı"yı zorlaştırmak; native davranışı gerçek cihazda kanıtlamak; görünümü semantic token'lara taşımak; Saat'i bağımsız ürün gibi tasarlamak; başarıyı server-authoritative yapmak; stable'ı kalite kapısına bağlamak. (v7 özellik sürümü olarak yayında; ilk kalite-kapılı stable v8 "Güven Sürümü" oldu.)

## 1. Ürün Vizyonu ve Konsept (tarihsel — kullanıcının istediği son hâl)

Ölçüt: "çalışsın" değil **profesyonel kalite**. Benchmark, kopya değil — Apple/Google/Samsung'u referans al, Odak Kampı kimliğiyle özgün tasarla. Beş sekme: **Ana Sayfa · Saat · Gruplar · İstatistikler · Profil.**
- **Saat:** bağımsız saat uygulaması gibi — Dünya Saati, Alarm, Kronometre, Zamanlayıcı, Odak, StandBy.
- **Bildirim/sayaç:** yalnız `HH:MM:SS` + Başlat/Durdur; app açmadan yönetim; widget app açmadan çalışır.
- **Senkron:** app içi saatler ↔ widget istatistik gecikmesi giderilsin.
- **Tema:** yazı rengi değil, uygulamanın **havası**; 10 palet %99 aynı olmasın.
- **Başarım & Profil:** ayarlardan çıksın → Çalışma kayıtlarım / Başarımlar / Ayarlar; Clash tarzı kademeli liste, XP, taç her yerde; herkese açık profil + seri alevi.
- **Gruplar & İstatistik:** boş kalmasın. **Küçük düzenler:** sıralamayı grup günlük trendinin üstüne al; kamp ateşini en üste taşı, animasyonu kısalt.

## 3. Kod Kanıtlı Durum Denetimi (tarihsel tanı — B1–B10, hepsi ele alındı)

| # | Alan | Bulgu |
|---|---|---|
| B1 | Tema | 10 palet ortak `_bg`/`_card` kullanıyordu; hepsi aynı görünüyordu. |
| B2 | Saat | Saat sekmesi = büyük saat + `StudyTimerCard`; bağımsız deneyim yoktu. |
| B3 | Başarım | İki motor paralel (`gamification.dart` + `achievement_engine.dart`); streak/perfectWeeks=0; XP istemcide. |
| B4 | Widget/senkron | Yalnız `AndroidWidgetSnapshot.timer` besleniyordu; stats/leaderboard gerçek veri almıyordu; FGS yok. |
| B5 | Sayaç lifecycle | Durdur/Başlat lifecycle'a aşırı bağımlı; canlı akan saat yok. |
| B6 | Bilgi mimarisi | "Başarı Yolculuğum" Ayarlar>Hesap içinde gömülüydü. |
| B7 | Güvenlik/RLS | `0022`'de gamification/achievements tüm authenticated'a açıktı. |
| B8 | Migration/ops | Yerel dosya = canlı deploy kanıtı değil. |
| B9 | Test kapsamı | ~245–254 test geçse de native/arka plan/OEM/uçtan uca kapsanmıyordu. |
| B10 | Doküman gerçeği | progress/backlog/project birbirini tam yansıtmıyordu. |

## 5.1 Yığın Denetimi (tarihsel karar tablosu)

Çekirdek (Flutter + Riverpod 3 + Supabase + çift repository + RLS + offline-first) korundu; felsefe "yıkma, güçlendir". Eklenenler: foreground service (`flutter_foreground_task` + Kotlin), chronometer bildirim, widget arka plan besleme, drift (SQLite), Sentry, analitik (ops.), feature flag, Edge Functions + pg_cron, integration/golden test + CI kapısı, rive/Lottie, token tabanlı `ThemeExtension`, flutter_localizations + arb.

## 6. AI Katmanı (gelecek — henüz başlamadı)

Supabase Edge Function → Claude API. İlkeler: anahtar istemcide değil; yalnız agregat veri; AI kapalıyken çekirdek aynen çalışır; önbellek + hız sınırı; maliyet/gecikme ölçülür. Fikirler: AI Çalışma Koçu, adaptif hedef/bildirim metni, grup haftalık özet, akıllı tema/rozet önerisi, (ops.) anomali/anti-hile. **Güven sürümü ve server-authoritative altyapı oturduktan sonra devreye alınır.**

---

## 8.1 Sayaç–Bildirim–Widget Tek Doğruluk Kaynağı (V8-A · tamamlandı)

Hedef: bütün yüzeyler aynı native timer state'ini okur (Flutter ekran · kalıcı bildirim · ana ekran widget · oturum tamamlama). State: `mode · status · startedAt · accumulatedSeconds · targetSeconds · currentPhase · cycle · subjectId · commandSequence/version · lastUpdatedAt`. Bildirim: dar `HH:MM:SS`+Başlat/Durdur, geniş +Sıfırla/+1dk; butonlar Flutter'ı açmadan. Widget: sistem `Chronometer` canlı süre, olay bazlı stats. Kabul: app kapalı 20 ardışık Başlat/Durdur; çift session yok; 8 saatte ≤±1 sn; Samsung+Pixel video.

## 8.2 Genel Senkronizasyon Denetimi (V8-B · tamamlandı)

`study_sessions → repository stream → canonical stats projection → UI/profile/group/widgets`. Aynı metrik farklı ekranda farklı hesaplanmaz. `Europe/Istanbul` tek yardımcıdan; insert/update/delete sonrası provider invalidation standardı; offline outbox + realtime reconciliation; idempotency; çoklu cihaz conflict; widget snapshot canonical projection. Kabul: aynı veri her ekranda aynı toplam; app ≤1 sn, widget ≤5 sn; offline session bir kez yazılır; 23:59–00:01 sınır testi.

## 8.3 Küçük ama Görünür IA Düzenlemeleri (V8-C · tamamlandı)

**İstatistik sırası:** Grup hedefi → Özet → Sıralama → Grup günlük trendi → Uzun dönem → Tüm zamanlar → Karşılaştırma. **Gruplar sırası:** Kamp ateşi → Grup hedefi → Sıralama → Trend → Bilgi/yönetim. Davet kodu/grup değiştirme kompakt başlığa. **Kamp ateşi animasyonu:** ilk sahne ≤300 ms, tam yerleşim ≤700 ms, reduce-motion.

## 8.4 Saat Ürünü (tamamlandı — WP-58/59/60)

- **Saat 1 (motor):** tek zaman kaynağı · alarm/timer/kronometre/pomodoro/world-clock modeli · local persistence · native scheduling · reboot + clock/timezone recovery · exact alarm.
- **Saat 2 (IA):** Dünya Saatleri · Alarm · Kronometre · Timer · Odak · StandBy — her biri bağımsız state.
- **Saat 3 (alarm):** tekrar günleri · etiket · ses · kademeli ses · snooze · schedule recovery.
- **Saat 4:** kronometre lap/paylaş/arka plan; çoklu timer etiket/renk/preset/+1dk/güvenilir alarm.
- **Saat 5 (StandBy/widget):** yatay masa saati · AMOLED/burn-in · büyük tipografi · saat/alarm/timer/odak widget'ları.
- **Kalite kapısı:** Android matris · Samsung batarya · reboot · DST · alarm aynı dakikada iki kez çalmaz · process death recovery · 24 saat soak.

## 8.5 Tema Stüdyosu (tamamlandı — WP-54/55 + 15 aile)

Katmanlar: **Renk** (app/elevated bg, surface 1–5, primary/secondary/tertiary, container, outline, text, success/warning/error/info, chart serileri, heatmap, campfire, widget, notification accent) · **Tipografi** · **Şekil** · **Derinlik** · **Atmosfer** (gradient/doku/kamp ateşi/parçacık/glow) · **Hareket** (motion + reduce-motion). Aileler: Campfire Night · Deep AMOLED · Nordic Snow · Forest Study · Ocean Glass · Coffee Library · Retro Terminal · Neon Focus · Paper & Ink · Pastel Day · Royal Academy · Dynamic Material You. Editör: tema→mood→ana renk→token→önizleme→kontrast→kaydet. Kapısı: ≥12 farklı tema, ana UI ≥%95 token, WCAG AA, restart yok, bozuk tema güvenli varsayılana döner.

## 8.6 Başarım ve Sosyal Profil 3.0 (tamamlandı — WP-56/57)

Tek kanonik server-authoritative sistem: `Session/Nudge/Group Event → server progression evaluator → achievement progress → XP ledger (append-only) → crown/rank → profile+groups+leaderboard`. **Append-only XP ledger:** `event id · user id · achievement id · tier · XP · reason · created_at · unique event key` (çift ödül/hile engeli). Kategoriler: Çalışma · Seri/düzen · Grup · Sosyal (spam'e karşı cooldown/benzersiz günlük kullanıcı) · Eğlenceli/gizli. Profil IA: Çalışma kayıtlarım · Başarımlar · Ayarlar. Sosyal profil: avatar+isim · taç · XP · seri alevi · 3 rozet · ortak grup · gizlilik. Güvenlik: yalnız ortak aktif grup üyesi; e-posta gizli; admin otomatik genişletmez; rozet gerçekten açık olmalı; XP/tier istemciden yazılamaz.

> **Not (2026-07-19):** Bu programın canlı sisteminde 4 ölü başarı (alpha_wolf/campfire_hours/locomotive/secret_break_enemy `then 0`) + claim/topla eksikliği tespit edildi; düzeltme WP-208–211 (`docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`).

## 8.7 Windows Masaüstü Ürünü (tamamlandı — WP-27/52/53/28/70/71)

Flutter/Riverpod/Supabase çekirdeği korunur; ayrı desktop shell. `<640` minimal / `640–1007` kompakt / `≥1008` geniş rail; max 1440 px içerik; dashboard 6/8/12/16 sütun profilleri; Compact Focus ayrı yüzey; klavye/mouse/Narrator/high-contrast/çoklu monitör birinci sınıf; MSIX + Microsoft Store; yalnız Windows 11. Kanonik: `docs/WINDOWS-URUN-PLANI.md`. Kalite kapısı: gerçek release build · 1366×768/1080p/1440p · %100–200 ölçek · klavye-only · Narrator · multi-monitor + sleep/resume · temiz install/update/uninstall · P0=0.

---

## 10. Faz 0 Teslimleri (tarihsel liste)

1. Özellik kalite envanteri · 2. P0/P1/P2 bug listesi · 3. V8 blocker listesi · 4. Migration/Edge canlı durum matrisi · 5. Sayaç/native state mimari şeması · 6. Widget veri akışı şeması · 7. Tema token sözlüğü · 8. Saat özellik matrisi · 9. Başarım event + XP ledger tasarımı · 10. Cihaz QA matrisi · 11. Her faz DoD · 12. Rollback/release planı.

## 12. Uzlaştırma Notları (tarihsel)

- v7 zaten yayında (git `d7729f4 release: v7 (1.0.6+7)`); Codex "V6" varsaymıştı → kalite sürümü bir *sonraki* stable (v8) oldu.
- İlk sunumdaki v8–v12 özellik yol haritası, kalite programıyla birleşip **Faz 0 + Güven Sürümü + sıralı büyük programlar** oldu.
- "Copy Apple/Samsung/Google" → benchmark + güvenilirlik + özgün kimlik (IP-güvenli) olarak düzeltildi.
- Platform sınırları (bildirim OEM'e bağlı, widget <15 dk garanti yok, native Chronometer, olay bazlı stats) belgelendi.

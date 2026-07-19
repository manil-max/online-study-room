# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik `docs/KALITE-PROGRAMI.md` faz sırasına tabidir.** Kaynak: KALITE-PROGRAMI + `progress.md` + `project.md` açık sorular.
> **Yalnız açık (`[~]`/`[ ]`) maddeler burada.** Tamamlanmış (`[x]`) tarihsel backlog git geçmişinde + `progress.md` arşivinde (`docs/archive/progress-tarihsel-2026-07.md`). 2026-07-19'da sadeleştirildi.

---

## 🔴 Yüksek Öncelik

- [~] **Başarım canlı ilerleme + topla-ödül + ölü başarı fix + günlük görev + grup PP** — **WP-208–220 planlandı; Claude tur-2 saha denetimi sonrası plan v3.1** (2026-07-19)
  - Claim = ayrı `achievement_rewards`; `xp_ledger` literal append-only. Expansion önce iner, auto→pending yalnız claim-capable client + hesap capability'si sonrası WP-219'da aktive edilir; 50 XP/saat ambient kalır ama contract sonrası yalnız server-verified süre üretir.
  - Gerçek progress self-only projection'dadır; ortak-okunur `user_achievements` secret progress taşımaz. `study_sessions.group_id` 0010'da kaldırıldığı için grup başarıları ileriye dönük server-issued live segment + immutable tek grup context ile hesaplanır. WP-216 server/data expansion, WP-220 timer/native köprü + shadow saha kapısıdır.
  - Alfa/Kamp/Lokomotif ve Mola Düşmanı WP-217/218; kayıp tarihsel grup bağlamı yalnız konservatif legacy proxy + audit/dry-run ile retro, belirsiz satır XP üretmez.
  - **Ürün kararı kilitli:** Kusursuz Ay, bir takvim ayında 30 İstanbul günü hedefe ulaşmaktır. WP-208 server+Dart evaluator'ı 30'a hizalar; önceki append-only XP/rozet geri alınmaz.
  - Günlük görev cloud modeli toggle/undo + tombstone + server-arrival LWW + Europe/Istanbul günüyle WP-212/213.
  - Grup avatarı private bucket + RLS + signed URL/versioned path (WP-214). Tap-to-top, WP-211 kanonik tab indeksleri ve gerçek scroll dosyalarıyla WP-215.
  - Verified-only XP, WP-220'de ≥7 günlük ölçüm ve benimseme/başarı eşikleri sağlanmadan WP-219'da açılmaz; post-cut unverified saat-XP istisnası yoktur. Saf-native start, güvenli server tokenı yoksa stat-only kalır.
  - Kanon plan v3.1 + WP kartları + denetçi bölümü: `docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`. Denetim yanıtları tarihsel referanstır: `docs/features/DENETIM-YANIT-CODEX-01.md`, `docs/features/DENETIM-YANIT-CODEX-02.md`.

- [~] **Google Play production hazırlığı** — **WP-110–124 ayrıntılı planlandı; mevcut karar NO-GO**
  - Politika bloklayıcıları: Play/sideload kanal ayrımı, GitHub APK updater izolasyonu, gizlilik/koşullar/topluluk kuralları, uygulama içi + web hesap silme ve UGC raporla/engelle/moderasyon.
  - Teknik/operasyon kapıları: Android kısıtlı izin–FGS–alarm uygunluğu, Data Safety kanıt paketi, production migration/Edge/RLS doğrulaması, target API 36 imzalı AAB ve gerçek cihaz QA.
  - Yayın kapısı: Internal/uygunsa Closed test, soak, pre-launch raporu ve açık ürün sahibi GO kararı olmadan production submission/rollout yapılmaz.
  - Kanonik kapsam/dalga: `progress.md` WP-110–124; özet: `docs/KALITE-PROGRAMI.md`; bulgu: `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`; sahip aksiyonları: `docs/play/OWNER-ACTION-CHECKLIST.md`.

- [~] **Hesap silme ve veri saklama politikası** — **WP-66 karar dokümanı hazır; WP-112–114 kod tamam**
  - Retention/export/mesaj kaderi/audit kararı: `docs/HESAP-SILME-RETENTION-KARARI.md`. Kalan: WP-113/127 purge-accounts **Edge deploy + CRON** (canlı ops).

## 🟡 Orta / Kalan uçlar

- [~] **Küresel l10n (en varsayılan, tr ikinci dil)** — temel (en/tr) + katalog **teslim**; kalan: WP-87/89 entegrasyon/cihaz QA ve ar/de + RTL (WP-155 park). Sözleşme: sistem dili `tr` → Türkçe, diğer her locale İngilizce; üretilen l10n elle düzenlenmez.
- [~] **Global açık/özel gruplar (keşfet/katıl/klan)** — WP-92/93 **tamamlandı** (2026-07-17); ileri "klan" fikirleri açık kalırsa buraya yazılır.
- [~] **Yeni grafik türleri** — WP-67 brief hazır; **implementasyon için ürün onayı bekliyor** (onay gelince kod WP'si açılır).

## ❓ Açık Sorular / Ürün Kararları

- Çoklu sınıf özelliği aktif kullanılıyor mu, yoksa tek sınıfa mı odaklanılmalı?
- WP-69 aylık rapor: DNS + Resend API key (canlıya alınacak mı?).
- Windows release boşta RAM (300–400 MB iddiası): WP-70 tabanı p95 85.9 MB ölçtü, iddia temiz release'te üretilmedi; bulgu çıkarsa ayrı düzeltme WP'si.

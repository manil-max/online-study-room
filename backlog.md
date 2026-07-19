# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik `docs/KALITE-PROGRAMI.md` faz sırasına tabidir.** Kaynak: KALITE-PROGRAMI + `progress.md` + `project.md` açık sorular.
> **Yalnız açık (`[~]`/`[ ]`) maddeler burada.** Tamamlanmış (`[x]`) tarihsel backlog git geçmişinde + `progress.md` arşivinde (`docs/archive/progress-tarihsel-2026-07.md`). 2026-07-19'da sadeleştirildi.

---

## 🔴 Yüksek Öncelik

- [~] **Başarım canlı ilerleme + topla-ödül + ölü başarı fix + günlük görev + grup PP** — **WP-208–215 planlandı** (kullanıcı isteği 2026-07-19)
  - Başarı ilerlemesini canlı göster (26/30 + rozet + streak); "topla-ödülü-al" (pending + claim, battle-pass, ilerlemeyi durdurmaz, **claim=C onaylandı**); 4 ölü başarı fix (Alfa Kurt/Kamp Ateşi/Lokomotif retroaktif + Mola Düşmanı = 5h'te ≥4.5h); açıklama netleştirme (Kusursuz Ay=28+ gün); başarı/taç bildirimi (Clash banner + Brawl Stars nav-nokta); "az kaldı" minimal şerit.
  - Günlük yenilenen görev tipi **buluta** taşınır (şablon + gün-damgalı tamamlama, 00:00 İstanbul yenileme, streak); mevcut görev sistemi aynı kalır.
  - Grup profil fotoğrafı (`groups.avatar_url` + `group-avatars` bucket, admin-yazma RLS). + Tap-to-top tüm sekmeler (WP-215).
  - Kanon plan + WP kartları + denetçi bölümü: `docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`. Açık ürün kararı kalmadı (claim=C, Mola Düşmanı tanımı, retroaktif=evet çözüldü).

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

# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik `docs/KALITE-PROGRAMI.md` faz sırasına tabidir.** Kaynak: KALITE-PROGRAMI + `progress.md` + `project.md` açık sorular.
> **Yalnız açık (`[~]`/`[ ]`) maddeler burada.** Tamamlanmış (`[x]`) tarihsel backlog git geçmişinde + `progress.md` arşivinde (`docs/archive/progress-tarihsel-2026-07.md`). 2026-07-19'da sadeleştirildi.

---

## 🔴 Yüksek Öncelik

- [~] **Bildirim güveni + Android canlı sayaç — WP-265–267**
  - **Kod durumu (2026-07-22):** WP-265 rapor, WP-266 push çekirdeği ve WP-267 standard/promoted sayaç tamamlandı. Açık kalan iş yalnız Firebase/staging aktivasyonu + gerçek remote push ve Samsung/Pixel cihaz kabulüdür; production ayrıca somut GO ister.
  - Adli inceleme kesin teşhisi: dürtme/güncelleme/duyuru için kapalı sürece ulaşan push transport yok; Android izin/yerel notification tek başına bunu sağlamaz.
  - Hedef: FCM + Supabase transactional outbox/Edge dispatcher + token yaşam döngüsü + Bildirim Sağlığı/≤10 sn remote self-test.
  - Sayaçta custom `RemoteViews` Android Live Update şartlarına aykırıdır; standard/promoted ongoing chronometer'a geçilir, Samsung Now Bar OEM best-effort kalır.
  - Production deploy/release bu işin örtük parçası değildir; local→staging→fiziksel cihaz→soak→somut kullanıcı GO kapıları korunur.
  - Kanonik rapor ve WP'ler: [`docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md`](docs/NOTIFICATION-SYSTEM-AUDIT-2026-07.md), `progress.md` WP-265–267.

- [~] **Proje kurtarma + stable/beta/Supabase izolasyonu — WP-225–232 (en yüksek öncelik, production freeze)**
  - Canlı DB salt-okunur baseline ve veri invariant raporu; `0063` production'a uygulanmaz.
  - Pinli Supabase CLI + Docker local replay; SQL Editor ile elle uygulanmış `0001–0062` geçmişi şema kanıtıyla uzlaştırılır.
  - Beta ayrı staging Supabase/flavor/env'e, stable production'a bağlanır; ortam uyuşmazlığı fail-closed olur.
  - Local/staging test ve deploy otomatik; production backup+dry-run+cihaz+soak+somut kullanıcı GO kapılıdır.
  - Eşit süre kaynağı sözleşmesi, reward zinciri, 6 kademe/20k ekonomi, XP barı, istatistik refresh ve açık dönem etiketleri onarılır.
  - Kanonik plan: `docs/KALITE-PROGRAMI.md §8.7`; operasyon sözleşmesi: `docs/ORTAM-MIGRATION-YONETISIMI.md`; WP kartları: `progress.md`.

- [~] **Başarım canlı ilerleme + topla-ödül + ölü başarı fix + günlük görev + grup PP** — **WP-208–220 planlandı; Claude tur-2 saha denetimi sonrası plan v3.1** (2026-07-19)
  - Claim = ayrı `achievement_rewards`; `xp_ledger` literal append-only. 50 XP/saat, kişisel başarımlar ve grup başarımları için **manuel giriş, uygulama içi sayaç ve native sayaç eşittir**; süre kaynağı kullanıcı kazanımını değiştirmez. Mevcut `0063` bu hedefin kabul edilmiş uygulaması değildir.
  - Gerçek progress self-only projection'dadır; ortak-okunur `user_achievements` secret progress taşımaz. `study_sessions.group_id` 0010'da kaldırıldığı için grup hesapları üyelik penceresindeki tüm `study_sessions` üzerinden yapılır; eski live-run tabloları yalnız denetim geçmişidir.
  - Alfa/Kamp/Lokomotif, Lider Kurt ve Mola Düşmanı tüm çalışma oturumlarından hesaplanır. Geçmiş çalışma satırları, ledger, rozet ve pending ödüller silinmez.
  - **Ürün kararı kilitli:** Kusursuz Ay **28/30** kuralıdır: takvim ayında en az 28 İstanbul günü hedefe ulaşmak gerekir (30 günlük ayda 28/30; sabit eşik 28). WP-208 server+Dart evaluator'ı bu kurala hizalar; önceki append-only XP/rozet geri alınmaz.
  - Günlük görev cloud modeli toggle/undo + tombstone + server-arrival LWW + Europe/Istanbul günüyle WP-212/213.
  - Grup avatarı private bucket + RLS + signed URL/versioned path (WP-214). Tap-to-top, WP-211 kanonik tab indeksleri ve gerçek scroll dosyalarıyla WP-215.
  - Eski WP-219 verified-only XP/canary kapısı **iptal edildi**. Kaynak eşitliği WP-229'da güvenli migration/reconciliation ile uygulanacak; native/widget başlangıcı da normal oturumdur.
  - Kanon plan v3.1 + WP kartları + denetçi bölümü: `docs/features/BASARIM-GOREV-GRUPPP-PLAN-2026-07.md`. Denetim yanıtları tarihsel referanstır: `docs/features/DENETIM-YANIT-CODEX-01.md`, `docs/features/DENETIM-YANIT-CODEX-02.md`.
  - **Freeze:** Bu dalganın production terfisi WP-225–232 kabul edilene kadar durur; mevcut `0063` doğrudan uygulanmaz.

- [~] **Google Play production hazırlığı** — **WP-110–124 ayrıntılı planlandı; mevcut karar NO-GO**
  - Politika bloklayıcıları: Play/sideload kanal ayrımı, GitHub APK updater izolasyonu, gizlilik/koşullar/topluluk kuralları, uygulama içi + web hesap silme ve UGC raporla/engelle/moderasyon.
  - Teknik/operasyon kapıları: Android kısıtlı izin–FGS–alarm uygunluğu, Data Safety kanıt paketi, production migration/Edge/RLS doğrulaması, target API 36 imzalı AAB ve gerçek cihaz QA.
  - Yayın kapısı: Internal/uygunsa Closed test, soak, pre-launch raporu ve açık ürün sahibi GO kararı olmadan production submission/rollout yapılmaz.
  - Kanonik kapsam/dalga: `progress.md` WP-110–124; özet: `docs/KALITE-PROGRAMI.md`; bulgu: `docs/PLAY-STORE-HAZIRLIK-TARAMASI.md`; sahip aksiyonları: `docs/play/OWNER-ACTION-CHECKLIST.md`.

- [~] **Hesap silme ve veri saklama politikası** — **WP-66 karar dokümanı hazır; WP-112–114 kod tamam**
  - Retention/export/mesaj kaderi/audit kararı: `docs/HESAP-SILME-RETENTION-KARARI.md`. Kalan: WP-113/127 purge-accounts **Edge deploy + CRON** (canlı ops).

## 🟡 Orta / Kalan uçlar

- [~] **Windows Store hazırlığı ve kontrollü yayın — WP-259–262**
  - Stable kanal Microsoft Store MSIX; GitHub Releases yalnız beta/QA ve kaynak dağıtımıdır. Store MSIX'i Microsoft imzalar, ücretli kod imzalama sertifikası alınmaz.
  - Önce Windows Sandbox/VM'de staging test hesabıyla temiz kurulum → iki sürüm arası update → uninstall; mevcut test-imzalı yerel paket korunur, test ortamı izoledir.
  - Sonra Store'da Private Audience ile yalnız seçilen Microsoft hesaplarına görünür pilot; public listing/rollout yalnız WP-262 kanıtları ve somut kullanıcı GO sonrası.
  - Ayrıntılı sıra ve kabul kapıları: `docs/WINDOWS-STORE-PLAN.md`.

- [~] **Küresel l10n (en varsayılan, tr ikinci dil)** — temel (en/tr) + katalog **teslim**; kalan: WP-87/89 entegrasyon/cihaz QA ve ar/de + RTL (WP-155 park). Sözleşme: sistem dili `tr` → Türkçe, diğer her locale İngilizce; üretilen l10n elle düzenlenmez.
- [~] **Global açık/özel gruplar (keşfet/katıl/klan)** — WP-92/93 **tamamlandı** (2026-07-17); ileri "klan" fikirleri açık kalırsa buraya yazılır.
- [~] **Yeni grafik türleri** — WP-67 brief hazır; **implementasyon için ürün onayı bekliyor** (onay gelince kod WP'si açılır).
- [ ] **Taç XP çubuğu — toplam eşik üzerinden gösterim**
  - Bir sonraki taç eşiği `75k` ve kullanıcının toplam XP'si `25k` ise metin `25k / 75k XP`, doluluk da `25 / 75` olmalı. Kademe içi/kalan XP (`0 / 55k`, “55k kaldı”) temel alınmaz.
  - Kapsam yalnız profil/başarım ekranındaki görsel ilerleme ve erişilebilirlik metnidir; XP ekonomisi, taç eşikleri ve sunucu taraflı ilerleme hesabı değişmez.
  - Kabul: her taçta etiket, semantik açıklama ve bar aynı mutlak hedefi kullanır; son/sonsuz kademe davranışı uygulama öncesi netleştirilir.

## ❓ Açık Sorular / Ürün Kararları

- Çoklu sınıf özelliği aktif kullanılıyor mu, yoksa tek sınıfa mı odaklanılmalı?
- WP-69 aylık rapor: DNS + Resend API key (canlıya alınacak mı?).
- Windows release boşta RAM (300–400 MB iddiası): WP-70 tabanı p95 85.9 MB ölçtü, iddia temiz release'te üretilmedi; bulgu çıkarsa ayrı düzeltme WP'si.

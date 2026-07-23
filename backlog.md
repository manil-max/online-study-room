# backlog.md — Yapılacaklar (Öncelik Sıralı)

> Üstteki en öncelikli. Yeni fikir en alta eklenir, birlikte sıralanır.
> Bir işe başlayınca buradan alınır → `progress.md`'ye WP olarak geçer.
> **Öncelik `docs/KALITE-PROGRAMI.md` faz sırasına tabidir.** Kaynak: KALITE-PROGRAMI + `progress.md` + `project.md` açık sorular.
> **Yalnız açık (`[~]`/`[ ]`) maddeler burada.** Tamamlanmış (`[x]`) tarihsel backlog git geçmişinde + `progress.md` arşivinde (`docs/archive/progress-tarihsel-2026-07.md`). 2026-07-19'da sadeleştirildi.

---

## 🔴 Yüksek Öncelik

- [~] **Post-v43 kurtarma: release sadeleştirme + bildirim güveni + sayaç kontratı — WP-269–273**
  - **Gerçek durum (2026-07-23):** Stable `v43/fa771ce` production `0065`te korunur. Beta deney tabanı `beta-v4303/3bdf8bb`, staging `0068`dir; Android APK yayımlandı, Windows artefaktı eksiktir.
  - WP-266/267/268'in kod, staging ve beta yayın adımları yapılmıştır; ancak zamanlanmış retry worker, salt-okunur health, gerçek FCM cihaz kabulü ve sayaç paneli ürün kabulü eksiktir. Bu yüzden bu WP'ler “tamamlandı” sayılmaz ve yeniden claim edilmez.
  - Sıra: WP-269 release/Database Gates sadeleştirme + WP-270 retry/health → WP-271 tek cihaz staging kabulü; WP-272 v43 custom panel/fallback kontratı paralel native lane; WP-273 Windows deterministik release.
  - Production deploy/release bu işin örtük parçası değildir; HOLD ancak staging kabulü + soak + backup/dry-run + somut kullanıcı GO ile kalkar.
  - Kanonik güncel rapor ve WP'ler: [`docs/KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md`](docs/KURTARMA-ON-INCELEME-RAPORU-2026-07-23.md), `progress.md` WP-269–273.

- [~] **Başarım, görev ve grup ilerlemesi — kod/migration tarihsel, güncel kabul borcu WP-277**
  - Append-only ledger, pending reward/claim, görev, grup avatarı ve süre kaynağı eşitliği için tarihsel implementasyonlar vardır; bunlar yeniden geliştirme kuyruğu değildir.
  - Açık gerçek iş: beş süre kaynağı, iki cihaz, pending claim, görev toggle/undo, private grup/RLS ve İstanbul gün sınırını tek staging+cihaz matrisinde kanıtlamak. Bu WP-277'dir; bug bulunursa ayrı debug WP açılır.
  - Production terfisi HOLD'dur; eski `0063` doğrudan uygulanmaz.

- [ ] **Google Play production hazırlığı — NO-GO / bilinçli park**
  - Play flavor/updater izolasyonu ve bazı hesap/UGC kodları repoda bulunur; bunları “yapılmadı” diye yeniden claim etmek yanlıştır. Eksikler canlı HTTPS legal kimliği, Console/Data Safety, production Edge/cron kanıtı, izin matrisi, AAB/cihaz/closed-test ve açık GO'dur.
  - Program yalnız kullanıcı Play girişimini açıkça başlattığında canlanır. Ayrıntılı WP-110–124 kartları: `docs/archive/progress-tarihsel-2026-07.md`; kanonik sıra: `docs/KALITE-PROGRAMI.md §8.8`; sahip aksiyonları: `docs/play/OWNER-ACTION-CHECKLIST.md`.
  - Stable/production HOLD altında Play submission/rollout yapılmaz.

- [~] **Hesap silme ve veri saklama — staging ops kabulü WP-276**
  - `0037` RPC'leri, Flutter istek/iptal UI'ı, `purge-accounts` Edge ve retry terminal mantığı kodda var. Eksik olan staging Edge/cron/secret zinciri ile sentetik hesap üzerinden gerçek request→cancel→purge kanıtıdır.
  - Retention kararı: `docs/HESAP-SILME-RETENTION-KARARI.md`. Production purge ayrı backup/dry-run + somut kullanıcı GO gerektirir.

## 🟡 Orta / Kalan uçlar

- [~] **Windows Store hazırlığı ve kontrollü yayın — WP-259–262**
  - Stable kanal Microsoft Store MSIX; GitHub Releases yalnız beta/QA ve kaynak dağıtımıdır. Store MSIX'i Microsoft imzalar, ücretli kod imzalama sertifikası alınmaz.
  - Önce Windows Sandbox/VM'de staging test hesabıyla temiz kurulum → iki sürüm arası update → uninstall; mevcut test-imzalı yerel paket korunur, test ortamı izoledir.
  - Sonra Store'da Private Audience ile yalnız seçilen Microsoft hesaplarına görünür pilot; public listing/rollout yalnız WP-262 kanıtları ve somut kullanıcı GO sonrası.
  - WP-259 yerel smoke kanıtı aldı ama temiz VM/ikinci PC kabulü açık; WP-260–262 Partner Center/Private Audience ve kullanıcı GO bekler.
  - Ayrıntılı sıra ve kabul kapıları: `docs/WINDOWS-STORE-PLAN.md`; Windows release flake'i önce WP-273 ile kapanır.

- [ ] **AR/DE dil desteği ve RTL** — WP-278 ürün kararı gerekir
  - EN/TR l10n WP-87/89 ile cihaz/ürün kabulü aldı; AR/DE tabanı vardır ancak insan çevirisi/RTL cihaz kapsamı onaylanmış ürün işi değildir.
- [ ] **Yeni grafik türleri** — WP-67 brief hazır; kullanıcı türleri/onayı vermeden kod WP'si açılmaz.
- [ ] **Taç XP çubuğu — mutlak hedef gösterimi** — WP-275
  - 25k XP / sonraki taç 75k ise etiket ve doluluk mutlak `25k / 75k` olacaktır; ekonomi/server hesabı değişmez.

## ❓ Açık Sorular / Ürün Kararları

- Çoklu sınıf özelliği aktif kullanılıyor mu, yoksa tek sınıfa mı odaklanılmalı? Karar gelince ayrı WP açılır.
- WP-69 aylık rapor: DNS + Resend API key ile canlıya alınacak mı? Karar/ops preflight: WP-279.
- Windows release boşta RAM (300–400 MB iddiası): WP-70 tabanı p95 85.9 MB ölçtü, iddia temiz release'te üretilmedi; bulgu çıkarsa ayrı düzeltme WP'si.

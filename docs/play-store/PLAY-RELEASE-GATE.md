# Play Release Gate (WP-124)

| Gate | Status template |
|---|---|
| WP-110 Play installer isolation | [ ] |
| WP-111 Privacy URL live HTTPS | [ ] |
| WP-112–114 Account deletion in-app + web | [ ] |
| WP-115–117 UGC report/moderation | [ ] |
| WP-118 Restricted permissions declared | [ ] |
| WP-119 Data Safety submitted | [ ] |
| WP-120 Listing + content rating | [ ] |
| WP-121 Prod migrations 0034–0038 + Edge | [ ] |
| WP-122 AAB target API + versionCode>29 | [ ] |
| WP-123 Device QA matrix P0=0 | [ ] |
| Signing backup | [ ] |
| Rollback forward-fix plan | [ ] |

**GO requires all checked + product owner signature.**  
Staged rollout: 10% → 25% → 50% → 100% (min 24h/stage unless halt).

### TODO — kullanıcı / Console doğrulama (WP-132)

> Kod envanteri: `docs/play-store/DATA-SAFETY.md` (WP-132). Aşağıdakiler **otomatik kapanmaz**.

- [ ] Play Console → Data safety formunu `DATA-SAFETY.md` tablosuyla satır satır doldur ve kaydet
- [ ] Privacy policy + Terms canlı **HTTPS** URL’lerini forma yapıştır (`LEGAL_BASE_URL` / WP-111)
- [ ] Data deletion: in-app hesap silme + 14 gün grace + purge-accounts’un prod’da çalıştığını doğrula (0037/113)
- [ ] UGC beyanı: rapor + engel + engellenenler listesi (WP-125–129) cihaz smoke
- [ ] Telemetri: Legal Center’da Sentry anahtarını kapat/aç; default **açık** olduğunu kabul et veya ürün kararıyla default’u değiştir
- [ ] Location / ads: forma “No” (envanterle uyumlu)
- [ ] Content rating anketi + store listing görselleri (WP-120)
- [ ] Production migration 0034–0038 + Edge secret/deploy checklist (WP-121)

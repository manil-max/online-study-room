# Release Gate (WP-269 + WP-282)

## Güvenli varsayılan

`tooling/release/deploy-contract.json` production için `deploy_enabled` ve
`release_enabled` değerlerini kapalı tutar. Bu değerler normal bir release için
değiştirilmez. Stable akışı yalnız protected `production` Environment içinde,
tam commit SHA + migration head + project-ref'e bağlı tek kullanımlık şu GO ile
ilerler:

`PRODUCTION RELEASE GO:<sha>:<head>:<project-ref>`

Bu GO'ya staging kabulü, cihaz QA, soak ve rollback kanıtının konumu ayrıca
workflow inputu olarak verilir. Yanlış SHA/head/channel preflight'ta reddedilir.

## Owner checklist (repo dışı)

1. GitHub `production` Environment'a en az bir required reviewer ve deployment
   protection rule ekle; self-review kapalı olsun.
2. `staging` ve `production` project-ref/secret'larının farklı olduğunu kontrol
   et. Secret veya `env.json` değerini issue, input, artefakt ya da loga yazma.
3. Stable öncesi staging migration, cihaz QA ve en az üç günlük beta soak
   kanıtını kaydet; backup/rollback kaydını hazırla.
4. Stable workflow yalnız bu somut SHA/head/project-ref için reviewer onayı ve
   exact GO ile çalıştırılır. Yeni commit/head için yeni GO gerekir.

## Artefakt gerçeği

Release orchestrator Android ve Windows üretimlerini ayrı job'larda toplar.
`release-status-manifest.json` her çalışmada `partial`, `complete` veya `failed`
durumunu ve iki job sonucunu yazar.

- **Beta:** Android cihaz güncellemesi ana üründür. Preflight+Android başarılı
  olduğunda prerelease, APK, hash ve Android manifesti hemen yayımlanır; Windows
  job'ı beklenmez. Windows başarılı olursa MSIX/ZIP ve iki-platform complete
  manifesti aynı prerelease'e sonradan eklenir. Windows hatası yayımlanmış beta
  APK'yı geri çekmez.
- **Stable:** Android ve Windows zorunludur; iki platform da `success` olmadan
  stable release finalize edilmez.

Release asset listesi explicit tutulur; iki platformun aynı adlı iç
`platform-manifest.json` dosyaları doğrudan yüklenmez. Kullanıcıya açık birleşik
kanıt `release-manifest.json` dosyasıdır.

## Geri alma

Bu WP veri veya migration değiştirmez. Geri alma yalnız bu workflow/tooling
commit'ini geri almaktır; production HOLD korunur.

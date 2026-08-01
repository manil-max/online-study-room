# v57 Stable Release Hazırlık ve Sahip Muafiyeti

> Tarih: 2026-08-01 (Europe/Istanbul)
> Aday: `v57` · `1.0.57+57` · migration head `0116`
> Durum: **Yerel hazırlık tamamlanıyor; production apply/tag/release GO bekliyor.**

## 1. Kapsam

Bu paket `v56..HEAD` aralığındaki PLAN 5 güven turunu, test sistemi
sertleştirmelerini, WP-475 profil ünvanını ve WP-476 dürtme odak korumasını
stable v57 adayı olarak tekilleştirir.

Sürüm SHA'sı kaynak dosyada kendisine referans veremez. Kanonik aday SHA,
hazırlık commit'inden sonra `git rev-parse HEAD` ile alınır ve Database Gates
ile Release workflow girdilerinde aynı değer olarak pinlenir.

## 2. Ürün sahibinin tek seferlik kararı

Ürün sahibi 2026-08-01 tarihinde v57 için şu zinciri açıkça iptal etti:

`beta-v5701 → fiziksel cihaz QA → 3 gün beta soak`

Bu karar:

- yalnız **v57** içindir; sonraki sürümlere kalıcı politika olarak taşınmaz;
- beta APK/tag üretimini ve fiziksel Samsung/ikinci-cihaz kabulini zorunlu
  release önkoşulu olmaktan çıkarır;
- production migration, stable tag/release veya Store gönderimi için otomatik
  yetki değildir;
- ölçülmeyen OEM, gerçek cihaz, bildirim teslimi ve uzun süreli kullanım
  risklerinin v57 için ürün sahibi tarafından bilinçli kabulüdür.

## 3. Kanıtlanan otomatik kapılar

2026-08-01 yerel `python scripts/test_all.py --full` sonucu:

| Ölçüm | Sonuç |
| --- | --- |
| Toplam kapı | 15 |
| Geçen | 12 |
| Kırmızı | 0 |
| Atlanan / ölçülmeyen | 3 |
| Toplam süre | 356 sn |
| Flutter analyze | Geçti · 14 sn |
| Flutter package + coverage | Geçti · 136 sn |
| Golden | Geçti · 158 sn |
| Windows kritik entegrasyon | Geçti · 46 sn |
| Deploy guard / release-preflight testleri | Geçti |
| Stable manifest gate | Geçti · `stable`/`production`, v57, head `0116` |
| Android stable release compile | Geçti · package `com.manilmax.online_study_room`, version `1.0.57`/`57`, APK Signature v2 doğrulandı |

Yerelde ölçülmeyenler yeşil sayılmaz:

- Deno tip denetimi — hostta Deno yok; CI işi zorunlu.
- Deno davranış testleri — hostta Deno yok; CI işi zorunlu.
- pgTAP sıfırdan replay — Docker motoru yok; Database Gates CI işi zorunlu.

Sürüm metadata/workflow değişikliklerinden sonraki son varsayılan regresyon:
**12 kapı · 10 geçti · 0 kırmızı · 2 Deno kapısı atlandı · 290 sn**.
Flutter package + coverage 202 sn, analyze 86 sn; guard ve preflight testleri
yeniden geçti.

Yerel stable APK yalnız production-biçimli **örnek** manifestle derleme kanıtı
almak için üretildi. SHA-256:
`35eda88267662165f2b054b1debfae22ebd38d0a27fe74b3c6eb06b1b35f8556`.
Gerçek production backend secret'larını taşımadığı için yayınlanabilir artefakt
değildir; kimlik/imza doğrulamasından sonra workspace dışındaki geçici alana
`online-study-room-v57-example-not-for-release.apk` adıyla karantinaya
taşınmıştır. GO sonrası Release workflow aynı flavor'ı production-scoped
secret'larla sıfırdan derler.

## 4. Ortam gerçeği

| Kaynak | Head | Durum |
| --- | --- | --- |
| Repo/local | `0116` | Kod ve statik head kapıları hazır |
| Staging | `0114` | `0115–0116` uygulanmadı |
| Production | `0100` | HOLD; `0101–0116` uygulanmadı |

Stable uygulama `0116` sunucu davranışını gerektirir. Uygulama artefaktı,
production post-check `0116` göstermeden yayımlanamaz.

## 5. GO öncesi fail-closed durum

- `staging.deploy_enabled=false`
- `staging.release_enabled=false`
- `production.deploy_enabled=false`
- `production.release_enabled=false`
- Çalışma dalı `main`; hazırlık başlangıcında `origin/main` karşısında üç yerel
  commit öndeydi.
- Stable tag yok; release workflow çalıştırılmadı.

## 6. GO geldiğinde yürütülecek sıra

1. Hazırlık commit'ini push et; CI, Deno ve Database Gates sonucunu aynı SHA'da
   doğrula.
2. Staging'e yalnız `0115–0116` dry-run/apply yap; post-check head `0116` al ve
   staging deploy kapısını yeniden kilitle. Beta artefakt/cihaz/soak yok.
3. Production için `0101–0116` dry-run çıktısı, proje hedefi ve mevcut
   backup-waiver/no-rollback gerçeğini raporla.
4. Aynı SHA/head için somut production apply GO ile migration'ları uygula;
   veri/RLS/ledger post-check'lerini tamamla ve kapıyı yeniden kilitle.
5. Ayrı somut stable release GO ile `v57` tag/release workflow'unu çalıştır;
   `app-release.apk` ve Windows artefakt sonuçlarını doğrula.

## 7. Geri alma ve kalan risk

Production free plan ortamında günlük backup/PITR yoktur; deploy contract'ta
önceden kaydedilmiş sahip muafiyeti ve `rollback_path: none` geçerlidir.
Migration dosyalarında ileri düzeltme/işlevsel rollback notları bulunur, fakat
canlı veri için zaman noktasına geri dönüş yoktur.

Fiziksel cihaz QA ve soak sahibi kararıyla kaldırıldığı için şu riskler release
öncesi ölçülmeyecektir: Samsung/Pixel OEM farkları, iki fiziksel cihazdaki
bildirim gecikmesi, force-stop/reboot davranışı ve üç günlük saha regresyonu.
Otomatik kapılar bunların tamamının yerine geçtiği iddiasında değildir.

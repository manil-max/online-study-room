# v80 yayın kanıtı — 2026-09-05

## Yetki ve kapsam

Sahip, Claude'un limiti dolduktan sonra kalan işi devralıp yayını tamamlamamızı
açıkça istedi. Kapsam: GitHub stable v80 ve mevcut Google Play `alpha` kapalı
testi. Google Play production veya Microsoft Store submission yok.

## Sabit aday

- Tag: `v80`
- Git SHA: `3d08f02445afeb4baf16dc7336e8671dbda959b9`
- Uygulama: `1.0.80+80`; Windows paket sürümü: `1.0.80.0`
- Kanal/ortam: stable / production
- Beklenen migration head: `0138`
- Release workflow: [33981277911](https://github.com/manil-max/online-study-room/actions/runs/33981277911)
- Durum: **YAYIMLANDI** — release run başarılı, GitHub Release `v80` 2026-09-05T17:55:08Z'de yayında; sahip güncellemeyi cihazında aldı (2026-09-05, sözlü teyit).

## Devirde doğrulananlar

- Son uygulama kaynak CI: [33980155808](https://github.com/manil-max/online-study-room/actions/runs/33980155808),
  `81a9936e2e08c5d15548d9078817af84f85f8610`, 7/7 başarılı.
  Linux tam test/kapsam, Windows golden + kritik akış integration,
  Android API 30/33 sayaç smoke, Edge tip/test ve Dart/Edge–SQL sözleşmesi.
- Release metadata commit CI: [33981259073](https://github.com/manil-max/online-study-room/actions/runs/33981259073), sonuç bekleniyor.
- Yerel `flutter analyze`: 0 sorun.
- Yerel `release_notes_test.dart`: 11/11 geçti.
- Release preflight testleri: 13/13; sürüm notu sözleşme testleri: 2/2.
- Gerçek v80 girdisiyle `release-preflight.ps1 -ValidateOnly` geçti.
- `release_body.py --self-test`: 8/8; Play not üreteci self-test geçti.
- `git diff --check`: temiz.

## Sunucu terfisi

Migration tekrar uygulanmadı. Önceden tamamlanan zincir:

1. Staging kuru koşu: `33976795633` başarılı.
2. Staging apply: `33977602736`, head `0138`.
3. Production apply: `33977837446`, head `0138`.

Devirde kalan gerçek operasyon: `d82bf74e`, `ticket_message_attachments`
bucket'ını purge kapsamına ekliyordu; kayıtlı son purge deployment'ları bu
değişiklikten eskiydi. Mevcut korumalı activation workflow'larıyla güncel
`81a9936e` kodu sırayla dağıtıldı:

1. [Staging purge 33981030034](https://github.com/manil-max/online-study-room/actions/runs/33981030034): başarılı.
2. [Production purge 33981190557](https://github.com/manil-max/online-study-room/actions/runs/33981190557): başarılı.

Her iki ortam: `configuration_status=configured`; due/processing/stale/failed
sayıları 0. Worker denemesi `dry_run=true`, `processed=0`, `no due jobs`.
Doğrulama hiçbir hesap silmedi; gerçek süresi dolmuş hesap temizliği sınanmış
sayılmaz. Workflow, purge ve iki admin fonksiyonunu dağıtır; purge'a özel
kimliği günceller ve özel runtime yapılandırmasını eşler.

## Play hedefi

[Verify 33981031948](https://github.com/manil-max/online-study-room/actions/runs/33981031948)
başarılı: `alpha=79`, production/beta/internal boş. Hedef tahmin edilmedi.
v80 AAB yüklemesi (devirden sonra, lider tarafından): [Play Upload 33984240093](https://github.com/manil-max/online-study-room/actions/runs/33984240093)
başarılı — `alpha` izi, **`draft`** durumu (`iz guncellendi: alpha (draft)`).
Yükleme sonrası [Verify 33984653538](https://github.com/manil-max/online-study-room/actions/runs/33984653538):
`alpha = 80, 79`; production/beta/internal boş. 🔴 `draft` demek: testçilere
**henüz açılmadı**; Console'da "Sürümü tamamla" sahibin kararıdır.

## Ölçülmeyenler

- Gerçek galeri/storage ile iki yönlü destek fotoğrafı akışı.
- Cihazda admin profil yaptırımları ve vaka bağlantıları.
- Samsung canlı bildirim görünümü ve yüzen şerit kabulü.
- Yeni beta soak veya yeni backup/PITR kanıtı yok. Sahip yayın emriyle
  ilerleniyor; bunlar geçmiş kabul edilmiş gibi gösterilmez.
- Mevcut 2026-07-27 yedeksiz production muafiyeti geçerli; SQL rollback
  yolu yok. Gelecekteki sorunlar ayrı, ileri düzeltme gerektirir.

## Yayın sonrası

- Release run [33981277911](https://github.com/manil-max/online-study-room/actions/runs/33981277911):
  `preflight`, `android`, `windows / build`, `finalize_android`,
  `finalize_complete`, `release_status` — **6/6 başarılı**.
- GitHub Release `v80` → `3d08f02445afeb4baf16dc7336e8671dbda959b9`, yayın
  2026-09-05T17:55:08Z. Varlıklar: `app-release.apk` (80.9 MB) + sha256,
  `app-play-release.aab` (75.6 MB) + sha256, `app-stable-release.apk.sha1`,
  `odak-kampi-windows-stable.zip` (19.7 MB) + sha256, `release-manifest.json`.
- Play: `alpha` izinde `80` **draft** (yukarıda).
- Sahip cihaz geri bildirimi (2026-09-05, v80 kurulu): (1) admin kuyruğunda
  "resolved" işaretlenen vaka listeden gitmiyor → WP-792; (2) bildirim
  panelinde kronometre küçük → WP-793. İkisi de bir sonraki sürüme.

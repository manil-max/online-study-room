# v82 yayın kanıtı — 2026-09-07

## Yetki ve kapsam

Sahip GO (2026-09-07): *"kapı yeşilse push et ve v82 çıkar ve play store a not
yazarak gönderebiliyorsan oraya da gönder."* Kapsam: GitHub stable `v82` +
Google Play `alpha` kapalı testi. Google Play production ve Microsoft Store
submission **yok**.

## Sabit aday

- Tag: `v82`
- Git SHA: `03a1e179de96c52573c9307c8a73c2966b6ec6b4`
- Uygulama: `1.0.82+82`; Windows paket sürümü: `1.0.82.0`
- Kanal/ortam: stable / production
- Beklenen migration head: `0138` (veritabanı **değişmedi**)
- Release workflow: [34113711763](https://github.com/manil-max/online-study-room/actions/runs/34113711763) — **6/6 başarılı**
- GitHub Release `v82`: 2026-09-07T11:14:14Z

## İçerik

- **WP-794** (`606fa75f`) — kuyrukta Bekleyen/Arşiv segmentleri + sayılar;
  **arşivlenmiş biletler Arşiv'e katıldı** (önceden hiçbir görünümden
  erişilemiyordu — sahibin "kaybolmasın" dediği asıl açık); En eski/En yeni
  sıralama; **İncelemeye al** (`in_review`, `0104`'ten beri yazılamayan
  durum); **Geri aç** / **Arşivden çıkar**.
- **WP-795** (`ca8a56fe`) — vaka iç notları, ayna bilet altyapısı, migration
  yok.
- **WP-796** (`4eb68ab2`, `12f0e048`, `2ee17e08`) — vaka zaman çizelgesi.
  🔴 Planlanan `0139` **gereksiz çıktı**: `moderation_audit_events` (`0106`)
  zinciri olayları 2026-08'den beri yazıyordu, istemci hiç okumamıştı.

## Yayın öncesi doğrulananlar

- Yerel tam kapı: **20 kapı, 0 kırmızı, 2 atlandı** (`deno` bu makinede yok;
  CI'da koşar — **atlanan kapı yeşil değildir**).
- `flutter test test/features/admin` **273** geçti; `flutter analyze` 0;
  `l10n_audit` OK (1861 anahtar, EN/TR eşit).
- Sürüm notları: `release_notes` + `release_body_contract` +
  `release_notes_remote` **18/18**; `release_body.py --self-test` 8/8;
  `play_publish.py self-test` geçti.
- `release-preflight.ps1 -ValidateOnly` gerçek v82 girdisiyle geçti.

🔴 **WP-794'ün alt ajanı gece limitle kesildi ve kendi sabotaj turunu
koşturamadı.** Beş sabotaj lider tarafından uygulandı, **beşi de kırmızı
döndü**, dosyalar sha256 ile bit-bit geri konuldu: segment filtresi,
arşivli bilet okuma, sıralama yönü, İncelemeye al, Arşivden çıkar.
Zaman çizelgesi dikişi de ayrıca sabote edildi → kırmızı.

## Sunucu

Migration uygulanmadı. Head her iki ortamda `0138` (staging `33977602736`,
production `33977837446`). Mevcut 2026-07-27 yedeksiz muafiyet geçerli;
SQL rollback yolu yok.

## Play

- Upload [34117748127](https://github.com/manil-max/online-study-room/actions/runs/34117748127):
  `alpha`, **completed** (`iz guncellendi: alpha (completed)`, AAB 72.2 MB,
  sha256 eşleşti).
- Verify [34117874475](https://github.com/manil-max/online-study-room/actions/runs/34117874475):
  `alpha = 82`; production/beta/internal boş.
- Mağaza notu `app/assets/release_notes.json`'dan türetildi (TR 359 / EN 358
  karakter, sınır 500) ve yüklemeyle birlikte gönderildi.

## Varlıklar

`app-release.apk` (81.0 MB) + sha256, `app-play-release.aab` (75.7 MB) +
sha256, `app-stable-release.apk.sha1`, `odak-kampi-windows-stable.zip`
(19.8 MB) + sha256, `release-manifest.json`.

## Ölçülmeyenler

- Arşiv segmentinin gerçek telefonda kullanımı.
- İç not yazma akışı (gerçek Supabase).
- Zaman çizelgesinin **gerçek** `moderation_audit_events` satırlarıyla
  dolması — bellek içi tohumlu depo ile ölçüldü, sunucudan okunuşu
  ölçülmedi.
- Yeni beta soak yok; sahip yayın emriyle ilerlendi.

# v81 yayın kanıtı — 2026-09-05

## Yetki ve kapsam

Sahip GO (2026-09-05, kendi sözleriyle): *"neyse v81'i çıkar … google play'e
de atar mısın."* Kapsam: GitHub stable `v81` + Google Play `alpha` kapalı
testi. Google Play production ve Microsoft Store submission **yok**.

Çerçeve sahibin isteği: *"kullanıcıdan dönütler konusunda iyileştirmeler."*
Sürüm notları buna göre yazıldı (TR/EN), Play notu aynı dosyadan türer.

## Sabit aday

- Tag: `v81`
- Git SHA: `1732724920f92b33da8b3ba2863779330474d6bd`
- Uygulama: `1.0.81+81`; Windows paket sürümü: `1.0.81.0`
- Kanal/ortam: stable / production
- Beklenen migration head: `0138` (veritabanı **değişmedi**)
- Release workflow: [33988535747](https://github.com/manil-max/online-study-room/actions/runs/33988535747)
- Durum: **YAYIMLANDI** — release run 6/6 başarılı (`preflight`, `android`, `windows / build`, `finalize_android`, `release_status`, `finalize_complete`), 19:54:58Z → 20:38:15Z; GitHub Release `v81` 2026-09-05T20:16:59Z.

## İçerik

- **WP-792** — çözülen/reddedilen iş kuyruktan gider; Kapananlar çipi sabit
  (`25998e74`, `9298c886`). Sahip şikâyeti: *"resolved işaretliyorum ama
  gitmiyor."* Kök neden kasıtlı bir karardı: kuyruk kapananları yalnız dibe
  indiriyordu.
- **WP-793** — genişletilmiş bildirimde 56sp saat, daraltılmışta 32sp
  (`10afe589`). 🔴 Sahip **Live Update modunda**: orada özel görünüm yasak,
  başlık boyutunu sistem çizer — bu değişiklik onun gölgesinde görünmez ve
  notlarda açıkça yazılı. Varsayılan paneldeki kullanıcılar için geçerli.

## Yayın öncesi doğrulananlar

- Kaynak CI [33985681179](https://github.com/manil-max/online-study-room/actions/runs/33985681179)
  (`9298c886`): 7/7 başarılı.
- Yerel: admin test paketi 248/248; timer JVM testleri exit 0
  (`TimerNotificationBigPanelWp793Test` 6, sabotaj A kırmızı döndü);
  `flutter analyze` 0; `l10n_audit` OK (2 yeni anahtar, EN/TR eşit).
- Sürüm notları: `release_notes_test` + `release_body_contract` +
  `release_notes_remote` 18/18; `release_body.py --self-test` 8/8;
  `play_publish.py self-test` geçti (500 karakter sınırı).
- `release-preflight.ps1 -ValidateOnly` gerçek v81 girdisiyle geçti;
  preflight testleri 13/13; notes-contract 2/2.
- Tam yerel kapı (`test_all.py`) WP-792/2 öncesi 1 kırmızı verdi
  (arşivlenmiş bilet testi — beklenen, iddia çevrildi); düzeltme sonrası
  admin paketi ve CI yeşil.

## Sunucu

Migration uygulanmadı. Head her iki ortamda `0138` (staging `33977602736`,
production `33977837446`). Purge dağıtımı v80'de güncellendi
(`33981030034`, `33981190557`). Mevcut 2026-07-27 yedeksiz muafiyet geçerli;
SQL rollback yolu yok.

## Play

- v80: `alpha` izinde **draft** olarak yüklüydü (`33984240093`).
- v81: [Play Upload 33990740683](https://github.com/manil-max/online-study-room/actions/runs/33990740683) başarılı — `alpha`, **completed** (`iz guncellendi: alpha (completed)`, AAB 72.1 MB, sha256 eşleşti). Sahip GO: *"bitince play e completed at"*.
- Yükleme sonrası [Verify 33990826649](https://github.com/manil-max/online-study-room/actions/runs/33990826649): `alpha = 81`; production/beta/internal boş. v80 draft'ı beklendiği gibi yerini v81'e bıraktı.

## Ölçülmeyenler

- 56sp genişletilmiş saatin One UI'da kırpılmadan çizilmesi.
- Kapananlar çipinin gerçek telefonda dokunulabilirliği (test 390dp'de ölçtü).
- Sahibin Live Update modunda **hiçbir görsel fark beklenmez**; bu bir kusur
  değil, o yolun sınırı.

## Yayın sonrası

- Varlıklar: `app-release.apk` (80.9 MB) + sha256, `app-play-release.aab` (75.6 MB) + sha256, `app-stable-release.apk.sha1`, `odak-kampi-windows-stable.zip` (19.7 MB) + sha256, `release-manifest.json`.
- Play: `alpha = 81` **completed** — kapalı test kullanıcılarına açık.
- Deploy kontratı: `release_enabled` açık kaldı (sahibin sık yayın temposu; her tag taze GO ister), `deploy_enabled` kilitli; gerekçe kontratta yazılı.
- Sahibe push bildirimi gönderildi ("haber ver" isteği).

# Sürüm Listesi

Bu dosya ürün tarafındaki okunur sürüm indeksidir. Ayrıntılı değişiklikler için
`CHANGELOG.md`, uygulama içi veri için `app/assets/release_notes.json` kullanılır.

| Kanal | Tag | Uygulama sürümü | Durum | Kısa not |
|---|---:|---:|---|---|
| geliştirme | — | 1.0.29+29 | `v29` tag'inden ileride · Play NO-GO | `main`, WP-105–109'u içeriyor fakat build numarası hâlâ 29; bir sonraki dağıtımda versionCode artmalı |
| stable | v29 | 1.0.29+29 | Yerel Git etiketi WP-104 commitinde | Tag `ff369e3`; mevcut `main` ile aynı kod değildir, tag taşınmaz/üzerine yazılmaz |
| beta | beta-v29 | 1.0.29+29 | Yerel Git etiketi WP-104 commitinde | `v29` ile aynı commit; sonraki beta yeni build numarası kullanır |
| stable | v28 | 1.0.28+28 | Git etiketi mevcut | v28 / beta-v28 sürüm numarası |
| stable | v27 | 1.0.27+27 | Git etiketi mevcut | Saat başına XP ve EN/TR sürüm notları |
| stable | v22 | 1.0.22+22 | Git etiketi mevcut | Cihaz QA bekleyen yayın hattı |
| stable | v21 | 1.0.21+21 | Yayınlanıyor | Global açık/özel grup keşfi ve EN/TR yüzeyi |
| beta | beta-v20 | 1.0.20+20 | Yayında · cihaz testi | Bildirim teslimi + dinamik panel uygunluk düzeltmeleri |
| beta | beta-v19 | 1.0.19+19 | Test için hazırlanıyor | Dinamik panel + izinleri geri alma rehberi |
| stable | v8 | 1.0.18+8 | Yayında | Güven Sürümü: native sayaç, Saat Merkezi, başarımlar/taç, 15 tema |
| beta | beta-v18 | 1.0.18+18 | Süperseed | v8’e gömüldü |
| beta | beta-v17 | 1.0.17+17 | Test arşiv | Alarm app-kapalı + widget sekmesi |
| stable | v7 | — | Önceki | v7 özellik hattı |
| stable | v6 | 1.0.5+6 | Önceki | Bildirim/grup/dürtme düzeltmeleri |
| stable | v5 | 1.0.4+5 | Yayında | V5 release notes, ikon/branding ve Android dış yüzey hazırlığı |
| stable | v4 | 1.0.3+4 | Yayında | Odak Kampı adı, V4 temel deneyim ve grup/sayaç hazırlıkları |
| stable | v3 | 1.0.2+3 | Yayında | Bildirim, dürtme ve canlı sayaç altyapısı |
| stable | v2 | 1.0.1+2 | Yayında | Ana sayfa, çalışma odası ve temel responsive iyileştirmeler |
| stable | v1 | 1.0.0+1 | Yayında | İlk yayın |
| beta | beta-v1 | 1.0.0-beta+1 | Test | İlk beta release kanalı |

## Release notes kuralı

1. Kullanıcıya görünen metin önce `CHANGELOG.md` içinde hazırlanır.
2. Uygulama içi geçmiş için aynı içerik `app/assets/release_notes.json` içine
   yapılandırılmış veri olarak eklenir.
3. GitHub Release oluşturulurken ilgili changelog bölümü release body olarak
   kullanılmalıdır.
4. Uygulama yeni build numarasıyla açıldığında kullanıcı “Yenilikler” penceresini
   sadece bir kez görür.

## Bildirim sınırı

Güncelleme bildirimi FCM/push değildir. Sideload kanalında uygulama açılışında
GitHub Releases kontrol edilebilir ve yeni APK için uygulama içi pencere gösterilebilir.
**Play kanalında GitHub APK indirme/kurma tamamen kapalıdır**; güncelleme Play Store
üzerinden yapılır (WP-110). Android sistem bildirimine dönüştürülmez.

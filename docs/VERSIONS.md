# Sürüm Listesi

Bu dosya ürün tarafındaki okunur sürüm indeksidir. Ayrıntılı değişiklikler için
`CHANGELOG.md`, uygulama içi veri için `app/assets/release_notes.json` kullanılır.

| Kanal | Tag | Uygulama sürümü | Durum | Kısa not |
|---|---:|---:|---|---|
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

Güncelleme bildirimi FCM/push değildir. Uygulama açılışında GitHub Releases
kontrol edilir; yeni APK bulunursa ve Android bildirim izni varsa yerel bildirim
gösterilir. İzin yoksa dialog fallback akışı devam eder.

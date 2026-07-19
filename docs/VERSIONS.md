# Sürüm Listesi

Bu dosya ürün tarafındaki okunur sürüm indeksidir. Ayrıntılı değişiklikler için
`CHANGELOG.md`, uygulama içi veri için `app/assets/release_notes.json` kullanılır.

| Kanal | Tag | Uygulama sürümü | Durum | Kısa not |
|---|---:|---:|---|---|
| beta | beta-v41 (hazırlanıyor) | 1.0.41+41 | Paket hazır · APK build + cihaz QA bekliyor | beta-v40 üzerine 3 düzeltme (WP-221 avatar / WP-222 saat etiketi / WP-223 poll+pull-refresh); canlıda `0054` gerekir; kademe/XP/Alpha revizyonu sonraki betada |
| beta | beta-v40 | 1.0.40+40 | Yerel imzalı APK · saha testi yapıldı (10 bulgu) | v39 sonrası WP-209–218/220; beta-v41 bu bulguların ilk 3'ünü düzeltir |
| stable | v39 | 1.0.39+39 | Yerel Git etiketi mevcut | `c6843a5`; beta-v40'ın karşılaştırma tabanı |
| geliştirme | — | 1.0.41+41 | `main` beta-v41 ara düzeltme | WP-219 aktive edilmez; ekonomi/kademe revizyonu sonraki betada; XP shadow |
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

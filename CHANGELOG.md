# Odak Kampı Changelog

Sürüm notlarının kullanıcıya görünen ana kaynağı burasıdır. Uygulama içindeki
`app/assets/release_notes.json`, GitHub Release body ve Ayarlar > Güncelleme
notları ekranı bu metinle aynı kararları yansıtmalıdır.

## [v6 / 1.0.5+6] - 2026-07-11

### Düzeltmeler

- Sayaç bildirimindeki başlıkta artık takılı kalan “0 sn” yerine canlı ilerleyen
  saat (HH:MM:SS) gösterilir.
- Grup adı, hedefi veya davet kodu değiştirildiğinde liste anında tazelenir;
  değişikliği görmek için uygulamayı kapatıp açmak gerekmez.
- Kimse dürtmese bile tekrar tekrar gelen sahte “... seni dürttü” bildirimi
  giderildi; her dürtme yalnızca bir kez bildirilir.
- Bildirim ya da ana ekran widget'ındaki Durdur/Başlat komutu, uygulama kapalıyken
  basıldıysa artık uygulama açılışında da işlenir (önceden yalnız arka plandan öne
  gelişte çalışıyordu).

### Notlar

- Uygulama tamamen kapalıyken Durdur/Başlat'ın ve widget canlı saatinin anında
  çalışması için bir foreground service gerekir; bu ayrı bir iş paketi olarak
  cihaz üzerinde test edilerek eklenecektir.

## [v5 / 1.0.4+5] - 2026-07-11

### Öne çıkanlar

- Android saat, bildirim ve widget deneyimi sadeleştiriliyor.
- Sürüm geçmişi, tek seferlik “Yenilikler” penceresi ve Ayarlar içinden geçmiş
  güncelleme notları eklendi.
- Yeni ikon/branding, tema paleti ve V5 release hazırlıkları ayrı iş paketleriyle
  takip ediliyor.

### Düzeltmeler

- GitHub Release, repo dokümanı ve uygulama içi notlar için tek kaynak prensibi
  kuruldu.

### Notlar

- Push/FCM yoktur. Güncelleme bildirimi uygulama açıldığında yapılan yerel
  GitHub release kontrolüyle best-effort çalışır.

## [v4 / 1.0.3+4] - 2026-07-11

### Öne çıkanlar

- Görünen uygulama adı Odak Kampı olarak netleştirildi.
- Canlı sayaç yüzeyleri, sade bildirim akışı ve grup ekranı hiyerarşisi V4
  hazırlığına alındı.
- Grup sohbeti ve grup ayarlarına erişim daha anlaşılır hale getirildi.

### Düzeltmeler

- Gamification profili yokken başarılar kartı güvenli varsayılan veriyle
  görünür kalır.
- Ana ekrandan yönetilen sayaç ayarlarının ayarlarda tekrarlanması sadeleştirildi.

## [v3 / 1.0.2+3] - 2026-07-10

### Öne çıkanlar

- Kalıcı Android sayaç bildirimi ve bildirim izni altyapısı eklendi.
- Dürtme bildirimleri ve bildirim tercihleri ayarlara bağlandı.
- Grup/presence ve canlı çalışma yüzeyleri daha güvenilir hale getirildi.

### Düzeltmeler

- Uygulama yeniden açıldığında aktif sayaç durumunun wall-clock süreyle toparlanması
  iyileştirildi.
- Demo/offline akışlar için repository davranışları güçlendirildi.

## [v2 / 1.0.1+2] - 2026-06-27

### Öne çıkanlar

- Ana sayfa kart düzeni ve çalışma odası deneyimi geliştirildi.
- Odak/pomodoro sayaç davranışları daha okunur hale getirildi.
- İstatistik ve grup hedefi yüzeyleri sonraki sürümlere zemin olacak şekilde
  toparlandı.

### Düzeltmeler

- Kart taşmaları ve temel responsive düzen sorunları azaltıldı.
- Provider/repository sınırları test edilebilirlik için netleştirildi.

## [v1 / 1.0.0+1] - 2026-06-21

### Öne çıkanlar

- İlk Odak Kampı yayını.
- Odak oturumu başlatma, durdurma ve temel çalışma takibi yayınlandı.
- Profil, grup ve temel istatistik ekranları eklendi.
- Supabase bağlı ve Supabase'siz demo kullanım için temel mimari kuruldu.

## [beta-v1 / 1.0.0-beta+1] - 2026-07-11

### Öne çıkanlar

- Stable ve beta release kanalları ayrıldı.
- Beta APK adı ve GitHub prerelease akışı ayrı takip edilmeye başladı.

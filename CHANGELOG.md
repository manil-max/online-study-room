# Odak Kampı Changelog

Sürüm notlarının kullanıcıya görünen ana kaynağı burasıdır. Uygulama içindeki
`app/assets/release_notes.json`, GitHub Release body ve Ayarlar > Güncelleme
notları ekranı bu metinle aynı kararları yansıtmalıdır.

## [beta-v12 / 1.0.11+12] - 2026-07-13

> ⚠️ **Beta test sürümü.** Sayaç bildirimi ve ana ekran widget'ı **native** altyapıya taşındı; beta-v11'in R1/R2 düzeltmelerini de içerir.

### Yenilikler / Düzeltmeler

- **Ana ekran widget'ı ve bildirim artık uygulama tamamen kapalıyken de çalışıyor:**
  Sayaç bildirimi ve widget artık native bir Android servisiyle yönetiliyor. Widget'taki
  **Başlat/Durdur** ve bildirimdeki buton, uygulamayı hiç açmadan çalışır. Süre bildirimde
  ve widget'ta native olarak akar (saniyede bir uygulama güncellemesi yok → pil dostu).
- **Oturum kaydı güvende:** Uygulama kapalıyken yaptığın Başlat/Durdur'lar bir kuyruğa
  yazılır; uygulamayı açtığında her çalışma aralığı sunucuya doğru biçimde kaydedilir
  (arka arkaya durdur/başlat oturum sayımını bozmaz).
- **beta-v11 dahil:** Bildirimde gövde yazısı yok + Durdur↔Başlat kalıcı toggle.

### Bilinen / sıradaki

- Native bildirimin cihazın **dinamik paneline** (HyperOS "Live notifications" / Samsung
  "Now Bar") terfisi OEM'e bağlıdır; desteklenmeyen cihazda düz ama temiz canlı bildirime düşer.

## [beta-v11 / 1.0.10+11] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v10 cihaz geri bildirimine göre sayaç bildirimi iki noktada elden geçirildi.

### Düzeltmeler

- **Bildirimde gövde yazısı kalktı (saat uygulaması gibi):** Sayaç bildiriminde artık
  "Odak Kampı çalışıyor" alt satırı yok; yalnız akan `HH:MM:SS` süre ve buton görünür.
- **Durdur↔Başlat kalıcı toggle:** Bildirimdeki **Durdur**'a basınca bildirim artık
  kaybolmaz; süre kaydedilir ve buton **Başlat**'a döner (`00:00:00`). Uygulamayı hiç
  açmadan **Başlat** ile yeni bir oturuma devam edebilirsin; her Durdur ayrı bir oturum
  olarak doğru kaydedilir (arka arkaya durdur/başlat oturum sayımını bozmaz).

### Bilinen / sıradaki

- Bildirimin cihazın **dinamik paneline** (HyperOS "Live notifications" / Samsung "Now Bar")
  native kronometre gibi terfi etmesi ayrı bir adımda ele alınacak (WP-51).
- **Ana ekran widget'ı** ve widget üzerindeki Başlat/Durdur bir sonraki beta'da aynı
  mantıkla elden geçirilecek (WP-42).

## [beta-v10 / 1.0.9+10] - 2026-07-13

> ⚠️ **Beta test sürümü.** Sayaç bildirimi tamamen yeniden yapıldı.

### Düzeltmeler

- **Artık TEK bildirim, canlı akan saat ve Durdur butonu:** Sayaç çalışırken tek bir
  bildirim çıkar; başlığında saniye saniye akan `HH:MM:SS` süre ve altında **Durdur**
  butonu bulunur. Önceki çift bildirim (biri düz "arka planda korunuyor", biri ayrı
  kronometre) kaldırıldı — tek, temiz, saat uygulaması gibi.
- **Durdur uygulama tamamen kapalıyken de çalışır:** Bildirimdeki Durdur'a basınca
  sayaç, uygulamayı açmadan durur; oturum gerçek durdurma anıyla kaydedilir (uygulamayı
  sonra açsan bile aradaki süre yanlış eklenmez).

### Bilinen / sıradaki

- **Ana ekran widget'ı** ve widget üzerindeki Başlat/Durdur bir sonraki beta'da
  aynı mantıkla elden geçirilecek (WP-42).

## [beta-v9 / 1.0.8+9] - 2026-07-13

> ⚠️ **Beta test sürümü.** beta-v8 cihaz geri bildirimine göre düzeltmeler.

### Düzeltmeler

- **Sayaç bildirimi artık tek ve canlı:** Sayaç çalışırken bildirimde saniye saniye
  akan `HH:MM:SS` kronometre baskın olarak görünür. Önceden servisin düz "arka planda
  korunuyor" bildirimi öne çıkıp canlı bildirimi gizliyordu; artık düz servis
  bildirimi en dibe alındı, üstte tek canlı kronometreli bildirim kalıyor (sessiz).
- **Kamp ateşi sahnesi kısaldı:** Gruplar sekmesindeki kamp ateşi çok uzundu ve
  üstte/altta gereksiz boşluk kaplıyordu; sahne kısaltıldı.

### Bilinen / sıradaki

- Bildirim ve widget'taki **Başlat/Durdur butonlarının uygulama tamamen kapalıyken**
  işlenmesi bir sonraki beta'da (arka plan komut işleme). Şu an bu butonlar uygulama
  açık/açılırken çalışır.

## [beta-v8 / 1.0.7+8] - 2026-07-12

> ⚠️ **Beta test sürümü.** "Odak Kampı Beta" olarak ayrı kurulur. Bu sürümdeki
> native arka plan sayaç, bildirim ve widget davranışı gerçek cihazlarda test
> ediliyor; cihaz/OEM'e göre değişebilir. Geri bildirim bekleniyor.

### Öne çıkanlar

- **Güvenilir arka plan sayacı (V8-A):** Uygulama kapalıyken de çalışan native
  zamanlayıcı ve foreground service; cihaz yeniden başlasa bile aktif sayaç
  geri yüklenir.
- **Canlı bildirim:** Kalıcı bildirimde akan `HH:MM:SS` kronometre ve uygulamayı
  açmadan **Başlat/Durdur**.
- **Widget paritesi:** Ana ekran widget'ında canlı kronometre, olay bazlı
  istatistik/sıralama beslemesi, açık/koyu tema ve Android 12+ dynamic color.
- **Senkronizasyon denetimi (V8-B):** Aynı toplam artık her ekranda tutarlı;
  çevrimdışı açılan oturum tekrar bağlanınca **bir kez** yazılır; gün sınırı
  (Europe/Istanbul) tek kaynaktan.
- **İstatistik sırası:** Sıralama (leaderboard) artık grup günlük trendinin
  **üstünde**, özet kartlarının hemen altında.
- **Gruplar sekmesi:** Kamp ateşi en üstte; davet kodu alttaki açılır "Grup
  bilgileri" paneline taşındı; kamp ateşi yerleşme animasyonu hızlandı ve
  sistemdeki **"animasyonları azalt"** ayarına uyar (batarya dostu).

### Notlar

- Native arka plan sayacı, bildirim aksiyonları ve widget davranışı cihaz pil
  optimizasyonuna ve OEM kısıtlarına bağlıdır; force-stop sonrası garanti değildir.
- Yeni sunucu migration'ı yoktur; v7 ile aynı şema (0020–0023) yeterlidir.

## [v7 / 1.0.6+7] - 2026-07-12

### Öne çıkanlar

- **Bildirim Merkezi:** Dürtme, çalışma hatırlatıcıları, alarm/zamanlayıcı, duyuru,
  güncelleme ve sessiz saatler artık tek ekrandan yönetiliyor.
- **Çalışma hatırlatıcıları:** Seçtiğin saat ve günlerde yerel bildirimle hatırlatma
  kurabilirsin.
- **Sessiz saatler:** Belirlediğin aralıkta dürtme ve hatırlatıcı bildirimleri susturulur.
- **Sosyal Profil 2.0 ve Başarı Yolculuğu:** Kademeli başarılar, XP ve taç vitrini.
- Beş sekmeli yapı netleşti (Ana Sayfa / Saat / Gruplar / İstatistik / Profil);
  Ayarlar'daki tekrar eden "Ana Sayfa" grubu kaldırıldı.

### Düzeltmeler

- Duyurular Bildirim Merkezi'nde okundu takibiyle listelenir.
- Bildirim türleri ve cihaz izin durumu tek yerde açıkça görünür.

### Notlar

- Hatırlatıcı ve alarmlar Android'de yerel bildirimdir; cihaz izni gerekir ve uygulama
  tamamen kapalıyken tam-zamanlı teslim garanti edilmez.
- Bildirim Merkezi'nin sunucu tarafı özellikleri (hatırlatıcı ve duyuru okundu kaydı)
  için `0023_notification_center.sql` ve önceki `0020–0022` migration'ları canlı
  Supabase şemasına uygulanmalıdır.

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

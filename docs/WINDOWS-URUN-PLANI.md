# Odak Kampı Windows Ürün Planı

> Tarih: 2026-07-13 · Durum: Araştırma ve teknik tasarım · Kod değişikliği yok
>
> Amaç, mobil uygulamanın büyütülmüş kopyasını değil; klavye, fare, geniş ekran,
> pencere yönetimi ve güvenilir dağıtımı gerçekten masaüstü gibi kullanan bir
> Odak Kampı deneyimi üretmektir.

## 1. Mevcut durum denetimi

`Kodda doğrulandı`:

- Flutter 3.44.2, Visual Studio 2022 ve Windows SDK 10.0.26100 bu makinede hazır.
  `app/windows/DAGITIM.md` içindeki “Visual Studio yok / build doğrulanmadı” notu
  artık güncel değil; ilk worker adımı gerçek Windows build + launch kanıtıdır.
- `HomeShell` her genişlikte mobil `NavigationBar` kullanıyor. Geniş pencerede
  sol navigasyon, komut alanı veya masaüstü bilgi yoğunluğu yok.
- Ana sayfadaki 6 sütunlu matris pencere genişliğiyle sınırsız büyüyor; desktop
  içerik genişliği, kolon/panel stratejisi ve fare davranışı tanımlı değil.
- Mevcut mini mod tüm uygulamayı 320×184'e küçültüyor. Ayrı bir focus surface
  olmadığı için navigasyon ve tam ekranlar küçük pencereye sıkışabilir.
- Pencere boyutu/konumu, maximize ve mini mod oturumlar arasında geri yüklenmiyor.
- Windows runner metadata'sında ürün adı hâlâ `online_study_room`; Windows release
  CI, installer, kod imzası ve Windows updater yok.
- Android release workflow Linux runner'da yalnız APK üretir; Windows artefaktı
  ve kurulum/güncelleme testi bulunmaz.

## 2. Ürün yönü ve referans sentezi

### Önerilen kimlik

Flutter ve mevcut Riverpod/Supabase katmanı korunur. Windows için ayrı bir
**desktop presentation shell** eklenir; veri modeli ve repository katmanı
çatallanmaz. Fluent davranış ilkeleri alınır ancak uygulama WinUI'ya yeniden
yazılmaz ve Microsoft Clock kopyalanmaz.

Microsoft Clock/Windows Focus'tan alınan ders: focus deneyimi tek büyük sayaçtan
ibaret değildir; süre, mola, göreve bağlanma, dikkat dağıtıcıları azaltma ve
oturum bitiş geri bildirimi tek akıştır. Odak Kampı bunu grup/istatistik kimliğiyle
özgünleştirir; Windows “Rahatsız etmeyin” entegrasyonu ilk dilimde zorunlu değil,
ayrı izinli geliştirme olarak değerlendirilir.

### Masaüstü bilgi mimarisi

| Pencere genişliği | Navigasyon | İçerik davranışı |
|---|---|---|
| `< 640` | Minimal/ikon odaklı rail veya açılır pane | Tek kolon; taşma yok; mini mod ayrı yüzey |
| `640–1007` | Sabit kompakt sol rail | İçerik 1–2 panel; başlık/komutlar içerikte |
| `≥ 1008` | Etiketli geniş sol rail | Ana içerik + ikincil bağlam paneli; max 1440 px |

Bu eşikler Windows `NavigationView` varsayılan davranışlarıyla hizalıdır. Mobilde
mevcut alt navigasyon aynen kalır; desktop shell yalnız Windows'ta seçilir.

### Ana pencere iskeleti

```
Sistem title bar
┌──────────────┬─────────────────────────────────────────────┐
│ Odak Kampı   │ Sayfa başlığı       bağlamsal komutlar     │
│              ├──────────────────────────────┬──────────────┤
│ Ana Sayfa    │ Ana çalışma alanı            │ Opsiyonel    │
│ Saat         │ kartlar / tablo / grafik     │ detay paneli │
│ Gruplar      │                              │              │
│ İstatistik   │                              │              │
│ Profil       │                              │              │
│              ├──────────────────────────────┴──────────────┤
│ Ayarlar      │ bağlantı/senkron durum satırı (gerektiğinde)│
└──────────────┴─────────────────────────────────────────────┘
```

- İlk sürüm standart sistem title bar'ını korur. Caption, drag, Snap Layouts,
  yüksek kontrast ve DPI davranışı kanıtlanmadan özel Mica title bar yapılmaz.
- Geniş rail `≥1008`, kompakt rail `640–1007`, minimal düzen `<640` olur.
- Sayfa başlıkları ve eylemler bağlamsaldır; mobil AppBar kopyaları desktop'ta
  üst üste iki başlık üretmez.
- Ana sayfa içerik genişliği sınırlandırılır; telefon/tablet/Windows aynı grid
  motorunun cihaz-yerel 6/8/12/16 profillerini kullanır (WP-52). Desktop için
  ikinci veri modeli kurulmaz; mevcut mobil düzen göçte kaybolmaz.

### Compact Focus penceresi

Mevcut “bütün uygulamayı küçült” yaklaşımı değiştirilir. Compact mod yalnız:

- süre / mod / aktif ders,
- Başlat–Duraklat–Durdur,
- üstte tut ve tam pencereye dön,
- bağlantı/ kayıt hatası için kısa durum

gösterir. Hedef normal boyut yaklaşık 360×220; içerik 320×180'e kadar taşmadan
çalışır. Compact'a geçerken normal pencere bounds/maximize durumu saklanır;
dönüşte aynı monitörde güvenli alana geri gelir. Compact oturum-içi geçici
moddur; uygulama cold-start'ta gri/boş ilk frame riskini önlemek için her zaman
güvenli normal pencerede açılır.

### Klavye ve fare sözleşmesi

| Komut | Davranış |
|---|---|
| `Ctrl+1…5` | Ana Sayfa / Saat / Gruplar / İstatistik / Profil |
| `Ctrl+Shift+M` | Compact Focus aç/kapat |
| `Ctrl+Shift+P` | Her zaman üstte tut aç/kapat |
| `Space` | Yalnız sayaç kapsamındayken ve metin alanı odakta değilken başlat/duraklat |
| `Esc` | Dialog/menü/düzenleme modundan güvenli çıkış |
| `F5` | Aktif sayfanın desteklediği veriyi yenile |

- Kısayollar tooltip/yardım yüzeyinde keşfedilebilir olur.
- Tab sırası görsel sırayla aynıdır; görünür focus ring zorunludur.
- Kartlarda hover ve sağ tık yalnız mevcut eylemlerin masaüstü erişim yoludur;
  dokunmatik/mobil davranış kaldırılmaz.
- Dashboard drag/resize fareyle hassas; klavyeyle taşıma/yeniden boyutlandırma
  için erişilebilir alternatif komut sunulur.

## 3. Pencere, erişilebilirlik ve performans standardı

### Pencere yaşam döngüsü

- Normal bounds, maximize, son monitör ve pin yerelde tutulur; compact cold-start
  modu olarak geri yüklenmez.
- Kayıtlı monitör yoksa pencere görünür çalışma alanına clamp edilir.
- Sleep/resume, ekran çıkarma, DPI değişimi ve çoklu monitör geçişi test edilir.
- “Kapatınca tray'e küçült” varsayılan yapılmaz; kullanıcı kararı olmadan arka
  planda gizli süreç bırakılmaz.

### Erişilebilirlik

- Klavye ile ana yolculuk %100 tamamlanır; mouse zorunlu eylem kalmaz.
- Narrator için anlamlı Semantics label/state/value sağlanır.
- Windows yüksek kontrast, dark/light ve %100/%125/%150/%200 ölçek test edilir.
- Primary hedefler ≥40 etkili px, ikincil desktop kontrolleri ≥32 etkili px olur.
- Hareket azaltma tercihi compact ve dashboard animasyonlarında korunur.

### Ölçülebilir kalite hedefleri

- Release build ilk anlamlı pencere: referans makinede ≤2.5 sn.
- Sekme değişimi: kullanıcı girdisinden yeni yüzeyin görünmesine ≤150 ms.
- Pencere resize: 10 sn sürekli sürüklemede overflow/kırmızı ekran 0; hedef ≥55 fps.
- Compact ↔ normal geçiş: ≤300 ms ve pencere ekran dışında kalmaz.
- 1366×768, 1920×1080, 2560×1440; %100/%125/%150/%200 ölçekte taşma 0.
- Offline → online dönüşünde session/stat reconciliation mevcut ortak kuralları
  korur; Windows'a özel ikinci veri doğruluğu kaynağı oluşturulmaz.

## 4. Dağıtım ve güncelleme mimarisi

### Kanal önerisi

1. **Geliştirme/QA:** release klasörü ZIP; yalnız ekip içi.
2. **Beta:** imzalı MSIX veya güvenilen test sertifikalı MSIX; kurulum kanıtı.
3. **Stable:** Microsoft Store MSIX önerilir. Store paket imzasını ve güncelleme
   dağıtımını yönetir. Store kullanılmayacaksa güvenilir kod imzası + App Installer
   güncelleme akışı gerekir.

MSIX; uygulama dosyalarını korunan alana kurar, state'i binary'den ayırır ve
temiz uninstall/güvenilir update sağlar. Portable ZIP stable'ın ana kanalı olmaz.

### Kimlik ve metadata

- ProductName/FileDescription: `Odak Kampı`
- InternalName/OriginalFilename: kararlı teknik kimlik
- Publisher/package identity: dağıtım kararıyla bir kez sabitlenir
- Çok boyutlu ikon, Start menüsü, Ayarlar > Uygulamalar metadata'sı
- Sürüm/tag/build ilişkisi Android'den bağımsız ama tek release kaynağından türetilir

### CI ve artefakt kapısı

Windows runner üzerinde:

1. `flutter pub get`
2. `flutter analyze`
3. Windows ilgili testleri + tam test paketi
4. `flutter build windows --release --dart-define-from-file=...`
5. MSIX/Store paketi üretimi ve imza
6. temiz VM'de install → launch → update → uninstall smoke
7. Windows App Certification Kit / paket doğrulama
8. SHA-256, release notu, sembol/Sentry release eşlemesi

Sertifika/PFX, Store/Azure kimliği ve Supabase değerleri yalnız secret store'da
kalır; repoya veya artefakt loguna yazılmaz.

## 5. Windows QA matrisi

| Alan | Minimum matris |
|---|---|
| OS | Windows 11 24H2 + 25H2; Windows 10 kapsam dışı |
| Ekran | 1366×768, 1920×1080, 2560×1440; tek + çoklu monitör |
| Ölçek | %100, %125, %150, %200 |
| Girdi | mouse, touchpad, yalnız klavye, touch varsa temel smoke |
| Tema | light, dark, high contrast, reduce motion |
| Yaşam döngüsü | cold start, minimize/restore, maximize, sleep/resume, monitor çıkarma |
| Veri | offline login/cache, bağlantı dönüşü, Android+Windows aynı hesap |
| Dağıtım | temiz kurulum, üstüne update, rollback/forward-fix, uninstall |

## 6. İş paketleri

### WP-27 — Desktop Shell, Etkileşim ve Compact Focus

Önce gerçek Windows build/launch baseline alınır; sonra adaptif sol navigasyon,
desktop içerik iskeleti, klavye/fare davranışları, compact focus, window state ve
erişilebilirlik tek desktop presentation diliminde uygulanır. Mobil navigasyon ve
veri katmanı korunur.

### WP-52 — Adaptif Dashboard Grid ve Cihaz Yoğunluğu

Dashboard'un sabit 6×N modeli cihaz-yerel **6/8/12/16** sütun profillerine
dönüşür. Telefon, tablet ve Windows aynı kart motorunu kullanır; layout profilleri
cihazda ayrı saklanır ve yoğunluklar arasında tekrar geçişte yuvarlama drift'i veya
kart kaybı oluşmaz. WP-52, gerçek desktop iç tasarımından önce tamamlanır.

### WP-53 — Windows Desktop Design 2.0

WP-27'nin shell/pencere temelinin üstünde beş ekranın iç bilgi mimarisi masaüstüne
özgü hale getirilir: command bar, master-detail, çok panelli analiz ve bağlamsal
eylemler. Mobil widget/provider ağacı veri doğruluğu için korunur; fakat `≥1008`
genişlikte ana deneyim büyütülmüş mobil AppBar/tek-kolon liste olmaz.

### WP-28 — Windows Paketleme, Güncelleme ve Release QA

WP-52 ve WP-53 cihaz/ürün kabulünden sonra runner metadata/ikon, MSIX kimliği,
imza stratejisi, Windows CI, update kanalı, installer testleri ve Windows release
gate uygulanır. Sıra: `WP-27 base → WP-52 → WP-53 → WP-28`.

## 7. Ürün kararları

1. **Stable kanal:** Microsoft Store MSIX (önerilen) mı, doğrudan imzalı
   MSIX + App Installer mı?
2. **İşletim sistemi:** Ürün kararı yalnız Windows 11'dir. Windows 10 geliştirme,
   uyumluluk ve QA matrisinin tamamı kapsam dışıdır.
3. **Kapatma davranışı:** normal çıkış (önerilen) mı, isteğe bağlı system tray mi?
4. **Focus entegrasyonu:** Windows Rahatsız Etmeyin entegrasyonu ilk sürümde mi,
   sonraki izinli WP'de mi? Öneri: sonraki WP.

## 8. Araştırma kaynakları

- Microsoft Windows Focus: https://support.microsoft.com/en-US/Windows/Experience/focus-stay-on-task-without-distractions-in-windows
- Windows NavigationView ve eşikler: https://learn.microsoft.com/en-us/windows/apps/develop/ui/controls/navigationview
- Windows responsive layout: https://learn.microsoft.com/en-us/windows/apps/design/layout/
- Windows klavye etkileşimleri: https://learn.microsoft.com/en-us/windows/apps/develop/input/keyboard-interactions
- Windows erişilebilirlik: https://learn.microsoft.com/en-us/windows/apps/design/accessibility/accessibility-overview
- Windows title bar: https://learn.microsoft.com/en-us/windows/apps/design/basics/titlebar-design
- Flutter desktop: https://docs.flutter.dev/platform-integration/desktop
- Flutter Windows release: https://docs.flutter.dev/deployment/windows
- MSIX imzalama: https://learn.microsoft.com/en-us/windows/msix/package/sign-msix-package-guide
- MSIX container/update modeli: https://learn.microsoft.com/en-us/windows/msix/msix-containerization-overview


## 8. WP-53 R2 uygulama notu (2026-07-14)

`Kodda doğrulandı`:

- Ortak chrome: `DesktopDensity`, `DesktopMasterDetail`, `DesktopSectionList`, `DesktopContextPanel`.
- Profil: ≥1008 master-detail (Genel / Kayıtlar / Ayarlar gömülü).
- İstatistik, Saat, Ana Sayfa, Gruplar: ≥1008 ikincil bağlamsal panel veya master-detail.
- Mobil AppBar/tek kolon branch korundu; `isDesktopWindow` dışı değişmedi.
- Klavye: mevcut shell Ctrl+1…5, Compact Focus, F5.
- Cihaz golden/resize matrisi ve ürün kabulü hâlâ `Cihazda doğrulanmalı`.

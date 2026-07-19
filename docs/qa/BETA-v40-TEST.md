# beta-v40 — v39 sonrası tam cihaz test listesi

| Alan | Değer |
|---|---|
| Karşılaştırma tabanı | **stable v39** (`c6843a5`) |
| Test paketi | **beta-v40** · `1.0.40+40` · cihazda `1.0.40-beta` |
| Kanal | GitHub beta / ayrı `.beta` paket kimliği |
| Kapsam | `v39..HEAD`: WP-209–218 ve WP-220; yalnız plan/dokümantasyon commitleri kapsam dışıdır |
| Kritik güvenlik durumu | **WP-219 aktif değildir.** XP ekonomisi değiştirilmez; bu listede onu etkinleştirme adımı yoktur. |

> Her satırda sonucu yaz: **Geçti / Kaldı / Atlandı**, cihaz modeli-Android sürümü ve kısa kanıt (ekran görüntüsü, saat, hata metni). Bir P0/P1 hata varken GO verme.

---

## 0. Başlatma, build ve veri kapısı

| # | Önkoşul / adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 0.1 | Mevcut stable v39'u silmeden beta APK'yı kur; giriş yap, uygulamayı kapat/aç. | Launcher adı **Odak Kampı BETA TEST**; stable ve beta yan yana durur; beta sürümü `1.0.40-beta` / build 40 görünür; oturum kalır. | ☐ |
| 0.2 | Supabase Dashboard migration geçmişini kontrol et. | `0047`–`0053` uygulanmış; 0053 hata vermeden tamamlanmış. | ☐ |
| 0.3 | Wi-Fi ve mobil veri ile açılış; ardından uçak modu açıp tekrar aç. | Crash yok; bağlantı hatası anlaşılır, bağlantı dönünce yenileme çalışır. | ☐ |
| 0.4 | Açık/koyu tema ve yaklaşık %130 yazı boyutunda beş ana sekmeyi dolaş. | Kritik taşma, kesik dokunma alanı veya İngilizce ham hata yok. | ☐ |

## 1. Ödül inbox ve gerçek başarı ilerlemesi — WP-209, 208, 210, 211

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 1.1 | Profil → Başarımlar; ilerlemesi olan ve olmayan başarıları incele. | Kartlar gerçek sayaçla görünür (`x/y`, sonraki kademe); sahte dolu tier yok. | ☐ |
| 1.2 | Kusursuz Ay açıklamasını ve ilerlemesini kontrol et. | Metin **bir takvim ayında 30 gün** der; Şubat/29 günlük ay Kusursuz Ay sayılmaz. Geçmiş rozet/XP kaybolmaz. | ☐ |
| 1.3 | Test hesabında bekleyen ödül üretildiyse Profil'den **Topla** yap. Aynı anda ikinci kez bas veya ağ dönüşünde tekrar dene. | Başarılı sonuç yalnız bir kez XP/rozet yansıtır; tekrar claim çift XP üretmez; hata varsa ödül kaybolmaz. | ☐ |
| 1.4 | Birden fazla bekleyen ödülle **Tümünü topla** kullan; sonra profili yenile. | Sınır içindeki ödüller toplanır, kalan sayısı/badge doğru güncellenir; kısmi hata net bildirilir. | ☐ |
| 1.5 | Ödül varken ana kabuğu ve Profil'i dolaş; banner/badge'e, sonra aksiyonuna dokun. | Doğru sayfa açılır; sayı claim sonrası kaybolur/azalır; uygulama yeniden açılınca bayat sayı geri gelmez. | ☐ |
| 1.6 | Aynı hesapla ikinci cihazda 1.3 veya 1.4 sırasında Profil'i açık tut. | İki cihaz sonunda aynı XP, rozet ve bekleyen ödül sayısını gösterir. | ☐ |
| 1.7 | Ödül yok hesabında Başarımlar/Profil'i aç. | Boş durum düzgün; Topla düğmesi veya banner yanlış görünmez. | ☐ |

## 2. Günlük görevler ve çoklu cihaz — WP-212, 213

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 2.1 | Araçlar → Görevler'den bugüne iki günlük görev ekle. | Görevler kalıcıdır; Ana Sayfa Görevler kartında da görünür. | ☐ |
| 2.2 | Bir görevi tamamla, geri al; uygulamayı öldürüp aç. | Durum doğru kalır; tamamlanmış görev aktif listede çift görünmez. | ☐ |
| 2.3 | Aynı hesabı ikinci cihazda aç; ekle/tamamla/geri al yap. | Diğer cihaz yenileme veya yeniden girişten sonra aynı sırayı ve durumu gösterir. | ☐ |
| 2.4 | İstanbul 00:00 sınırında (veya test saatiyle) açık uygulamayı arka plana alıp geri dön. | Yeni günün görevleri tekrar aktiftir; eski gün tamamlaması yanlış taşınmaz. | ☐ |
| 2.5 | Uçak modunda toggle dene, sonra ağı aç. | Kullanıcıya hata/retry durumu nettir; bağlantı sonrası çift kayıt veya veri kaybı olmaz. | ☐ |
| 2.6 | 360 px genişlik ve klavye açıkken görev ekle/düzenle. | Kaydet/iptal erişilebilir, taşma yok. | ☐ |

## 3. Özel grup avatarı — WP-214

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 3.1 | Grup yöneticisi olarak fotoğraf seç/yükle/değiştir/sil. | Küçük önizleme ve grup ekranları güncellenir; yükleme/hata durumu anlaşılır. | ☐ |
| 3.2 | Üye hesabı ve gruba üye olmayan hesapla aynı grubu incele. | Üye gerekli signed görüntüyü görür; üye olmayan private dosyaya erişemez. | ☐ |
| 3.3 | Fotoğraf izni reddedilmiş veya geçersiz dosyayla dene. | Uygulama çökmez; kullanıcıya Türkçe, eyleme dönük hata gösterir. | ☐ |

## 4. Ana sekmede yeniden dokunma — WP-215

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 4.1 | Saat, Gruplar, İstatistikler ve Profil'de listeyi aşağı kaydır; seçili sekmeye tekrar bas. | Liste yaklaşık 300 ms içinde başa döner. | ☐ |
| 4.2 | İstatistikler'de hem Kişisel hem Grup görünümünü dene. | Her iki gerçek liste doğru şekilde başa döner. | ☐ |
| 4.3 | Zaten baştayken, boş yükleme durumunda ve grup kartı içi jestlerde tekrar dene. | No-op güvenli; Home davranışı ve nested kaydırma/regüler dokunma bozulmaz. | ☐ |

## 5. Doğrulanmış canlı oturum ve native shadow — WP-216, 220

> Bu bölüm beta için en kritik cihaz testidir. **Shadow modunda XP veya başarıma hak ediş değişmemelidir.** Saf native başlangıç (widget/bildirim) normal istatistiğe sayılır; XP/başarım için doğrulanmış sayıldığı iddia edilmez.

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 5.1 | Uygulama içinden odak sayacını başlat → duraklat → devam → durdur. | Tek oturum kaydı; süre/istatistik doğru; ağ gecikmesi uygulamayı kilitlemez. | ☐ |
| 5.2 | Uygulama içinden başlat → uygulamayı son uygulamalardan kapat → native bildirimden Durdur. | Dönüşte tek oturum görünür; aynı süre için çift kayıt yok. | ☐ |
| 5.3 | 5.2 sırasında ağ kes → Durdur → ağ geri gelince uygulamayı aç. | Retry/outbox en fazla bir finalize üretir; kullanıcı verisi kaybolmaz. | ☐ |
| 5.4 | Bildirimden ve ana ekran widget'ından uygulama tamamen kapalıyken başlat/durdur. | Sayaç ve normal istatistik çalışır; kullanıcıya uygun "istatistiğe sayılır" geri bildirimi verilir; XP ekonomisi değişmez. | ☐ |
| 5.5 | Başlat/durdur/duraklat komutlarını hızlı ve tekrarlı uygula; sonra uygulamayı yeniden aç. | Çift oturum, negatif süre, takılı bildirim veya çökme yok. | ☐ |
| 5.6 | Cihazı yeniden başlat ve force-stop sonrası sayaç/bildirim akışını dene. | Platformun izin verdiği akış net davranır; uygulama açılışında bozuk durum/çift kayıt yok. | ☐ |
| 5.7 | Sürüm güncelleme/readiness mesajı çıkıyorsa incele. | Sadece desteklenen minimum build bilgisini doğru anlatır; döngü veya yanlış zorunlu güncelleme yok. | ☐ |

### 5.A Zorunlu cihaz matrisi

| Cihaz sınıfı | Minimum senaryo | Sonuç |
|---|---|---|
| Samsung / One UI, Android 8–13 | 5.1–5.6; bildirimde `00:MM:SS`, Başlat/Durdur ve app-kapalı akış | ☐ |
| Android 14+ | 5.1–5.6; FGS, bildirim ve widget izinleri | ☐ |
| İkinci fiziksel cihaz | 5.2–5.5 ve aynı hesap eşitlemesi | ☐ |

## 6. Verified başarı metrikleri — WP-217, 218

> Bu metrikler server/staging doğrulaması ister. Üretimde backfill veya ödül aktivasyonu çalıştırma. Test verisiyle, mümkünse ayrı staging grubu kullan.

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 6.1 | Mola Düşmanı için toplam **tam 270 dk** nitelikli segment oluştur; 269:59 ve 270:00 sınırını ayrı dene. | Eşik yalnız doğru sınırda gerçekleşir; gece yarısı/çakışan segmentler iki kez sayılmaz. | ☐ |
| 6.2 | Aynı metric projector/backfill kontrolünü yeniden çalıştırılabilir staging akışında tekrarla. | Duplicate candidate/ödül oluşmaz; timeout sonrası cursor yanlış ilerlemez. | ☐ |
| 6.3 | Alfa: aynı İstanbul gününde grubun en yüksek verified katkısını; eşitlik durumunu da test et. | Lider seçimi deterministik; eşitlikte dokümante edilen bağ kuralı korunur. | ☐ |
| 6.4 | Kamp Ateşi: aynı gün üç etkin üye; Lokomotif: takipçi üyede 15 dk verified katkı senaryosu kur. | Uygun grup metric snapshot'ları bir kez oluşur; üyelikten ayrılma/yeniden katılma veriyi bozmaz. | ☐ |
| 6.5 | Grup silme veya üyelik değişimi sonrası eski verified oturumu incele. | Sunucu snapshot'ı immutable kalır; yetkisiz kullanıcı metrik/oturum yazamaz. | ☐ |

## 7. Sunucu yetkisi ve regresyon — WP-216–218

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 7.1 | Staging'de istemci yetkisiyle doğrudan `live_run_id` yazmayı veya verified oturumu değiştirmeyi dene. | RLS/RPC sözleşmesi reddeder; kullanıcı başka hesabın/grubun kaydına erişemez. | ☐ |
| 7.2 | Aynı hesapla iki cihazdan eşzamanlı canlı oturum başlatmayı dene. | Tek aktif run kuralı korunur; kullanıcıya anlaşılır sonuç döner. | ☐ |
| 7.3 | Eski v39/stable istemci ile normal çalışma ekle; beta ile istatistikleri karşılaştır. | Normal eski oturumlar görünmeye devam eder; shadow döneminde eski XP davranışı kırılmaz. | ☐ |
| 7.4 | Bir saatlik eski/normal çalışma ile XP ve başarı durumunu v39 tabanına karşılaştır. | **WP-219 yok:** beta, yalnız verified XP kesişimi veya pending cohort aktivasyonu yapmaz. | ☐ |

## 8. v39 regresyon smoke

| # | Adım | Beklenen | Sonuç / kanıt |
|---|---|---|---|
| 8.1 | Grup İstatistikleri'nde küçük ve 10+'lı grupta donut ile liderlik geçmişini aç. | Aynı üye iki grafikte aynı, üyeler birbirinden farklı renkte; sıralama değişince renk değişmez. | ☐ |
| 8.2 | Samsung bildirim panelinde sayaç başlat/durdur; uygulama kapalıyken de dene. | Tek satır `00:MM:SS` ve doğrudan Başlat/Durdur; takılı/çift bildirim yok. | ☐ |
| 8.3 | Ana Sayfa / Saat / Gruplar / İstatistikler / Profil temel dolaşımı. | Crash, kalıcı yükleniyor durumu veya veri kaybı yok. | ☐ |

## Sonuç ve hata kaydı

| Alan | Doldur |
|---|---|
| Cihaz / Android / One UI | |
| Beta APK SHA-256 | `292B4C9FB13FA391CF0D2C6DFE826B2E8C1E8E2844151D9CC2A994987505051A` |
| Test hesabı / staging mi canlı mı | |
| P0 (çökme, veri/XP kaybı, yetki açığı) | |
| P1 (ana akış çalışmıyor) | |
| P2/P3 ve ekran görüntüleri | |
| Genel karar | ☐ GO · ☐ GO (notlarla) · ☐ NO-GO |
| Tarih / test eden | |

### GO şartı

- 0–5 ve 8 bölümlerinde P0/P1 kalmamalı.
- 6–7 staging kanıtı olmadan WP-219 için GO çıkarılmaz; bu beta yalnız shadow/ölçüm paketidir.
- WP-219 için ayrıca planın zorunlu 7 ardışık gün saha eşiği gerekir; bu liste o aktivasyonun yerine geçmez.

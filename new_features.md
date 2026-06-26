# Yeni Özellik Planları & Kullanıcı Geri Bildirimleri

Bu dosya, ilk kullanıcılardan gelen geri bildirimler (21 madde) doğrultusunda projeye eklenecek yeni özellikleri, düzeltmeleri ve oyunlaştırma (gamification) fikirlerini barındırır.
> **AI İçin Önemli Not:** Bu dosyadaki fikirler (özellikle animasyonlar, başarımlar, grafik türleri) kesin kurallar değildir. Geliştirme aşamasında AI, listelenen bu maddeleri genişletmekte, kendi yaratıcı, rekabetçi ve eğlenceli fikirlerini (vb. diyerek belirtilen yerlerde) koda dökmekte tamamen özgür ve esnektir.

## Öncelikli Özellikler: E-posta ve Şifre Güvenliği

### E-posta Doğrulama (Email Confirmation)
* **Amaç:** Kullanıcıların sahte e-postalarla kayıt olmasını engellemek ve hesap kurtarma adımlarında güvenliği garanti altına almak.
* **Gereksinimler:**
  * Supabase panelinden `Confirm email` aktif edilecek.
  * Kayıt olunca "Lütfen e-postanıza gelen onay linkine tıklayın" uyarısı gösterilecek.
  * Doğrulanmamış girişte hata verilecek. Mevcut eski kullanıcılar etkilenmeyecek.

### Şifre Sıfırlama (Password Reset)
* **Amaç:** Şifresini unutanların e-posta ile yeni şifre belirleyebilmesi.
* **Gereksinimler:**
  * Giriş sayfasına "Şifremi Unuttum" eklenecek.
  * `resetPasswordForEmail` ile link yollanacak.
  * Gelen link tıklandığında uygulamanın şifre yenileme ekranı açılacak.

---

## 1. Kritik Düzeltmeler ve Mimari Değişiklikler (Bugs & Arch)
* **Grup Hedefi Belirlenemiyor:** (Madde 1) Supabase'deki `0006_group_goal.sql` migration'ı çalıştırılarak grup hedeflerinin kaydedilmesi sağlanacak.
* **Sayaç Sorunları ve Çoklu Grup Senkronizasyonu:** (Madde 2, 3, 11) 
  * *Sorun:* Çalışmalar istatistiklere yansımıyor ve sadece tek bir gruba süre yazılıyor.
  * *Çözüm:* `study_sessions` (çalışma kayıtları) tablosundaki `group_id` bağımlılığı kaldırılacak. Kullanıcı "Çalış" dediğinde bu genel profilin kaydı olacak ve üyesi olduğu **TÜM gruplardaki** istatistiklerine anında yansıyacak. 
* **Silinen Kullanıcı Adı:** (Madde 5) Gruptan çıkan veya silinen üyelerin kayıtlarında "İsimsiz" yerine "Eski Grup Üyesi" yazacak (Veritabanı ilişkisi korunacak).

## 2. Arayüz ve Ana Ekran (UI & Dashboard)
* **Ana Ekran Serbest Izgara (Free-form Grid) Mantığı:** (Madde 7 ve 19)
  * Ana ekran tamamen esnek bir ızgara yapısına geçecek. Izgaranın hücre boyutu (kaç x kaç olacağı) şimdilik belirsizdir, kodlama aşamasında en optimal oran deneme-yanılma ile bulunacaktır.
  * **Doğal Sürükle ve Bırak:** Mevcut sistemdeki gibi sadece belirli bir kısımdan (tutma yerinden) sürükleme zorunluluğu kalkacak. Kullanıcı widget'ın **doğrudan üstüne basılı tutarak** ızgara üzerinde istediği yere taşıyabilecek.
  * **Akışkan Kayma Animasyonları (Android Ana Ekran Deneyimi):** Tıpkı Android işletim sisteminin kendi ana ekranında olduğu gibi; bir widget'ı alıp ızgarada diğer widget'ların arasına veya üstüne sürüklediğinizde, oradaki diğer widget'lar pürüzsüz ve tatlı bir animasyonla alta veya yana doğru kayarak yeni widget'a yer açacak.
  * **Akıcı ve Sınırsız Boyutlandırma:** Artık widget'lar sabit ön ayarlı boyutlarda (küçük/orta/büyük) olmayacak. Kullanıcı, tıpkı bilgisayar pencerelerinde olduğu gibi widget'ın köşesinden/kenarından tutup çekerek istediği forma **serbestçe** büyütebilecek veya küçültebilecek. Bu boyutlandırma işlemi son derece akıcı (fluid) çalışacak.
  * **Kusursuz İçerik Esnekliği:** Widget'lar serbest formda (dikdörtgen, kare, dikey vb.) boyutlandırıldığında, içindeki yazılar, saat göstergeleri veya grafikler **asla birbirine girmeyecek ve bozulmayacak**. İçerik, o anki forma ve orana kusursuz adapte olup akıllıca (responsive) yeniden şekillenecek.
  * **Düzenleme Modu Odağı (Kritik):** Kullanıcı bir widget'a basılı tutup düzenleme moduna geçtiğinde, ekran anlamsızca en başa/ilk widget'a kaymayacak (zıplamayacak). Kullanıcı **hangi widget'a basılı tuttuysa, ekran tam olarak orada kalacak** ve oradan düzenlemeye devam edecek.
* **Kamp Ateşi Konsepti (Canlı Çalışma Ekranı):** (Madde 6) Canlı çalışanların sıkıcı bir liste yerine dinamik bir alanda gösterilmesi kararlaştırıldı. Ekranın ortasında yanan tatlı bir "Kamp Ateşi" animasyonu olacak. O an çalışan kullanıcıların avatarları ateşin etrafında toplanacak, mola verenler karanlığa çekilecek vb. (AI bu alanda farklı hava durumları, animasyonlar veya etkileşimler eklemekte serbesttir).
* **Eksiksiz Bir Saat/Zamanlayıcı Uygulaması:** (Madde 9) 
  * **Önemli:** Bu uygulama özünde bir "Saat/Kronometre" uygulamasıdır. Bu nedenle bir kullanıcının standart bir saat uygulamasından bekleyebileceği **HER ŞEYİ** kusursuz sunmalıdır.
  * Kronometreye ek olarak Geri Sayım, Pomodoro (25/5), ayarlanabilir hazır çalışma planları vb. tüm modern zaman yönetimi teknikleri ve estetik saat stilleri sisteme dahil edilmelidir. (AI yeni zaman yönetimi teknikleri üretebilir).
* **Ayarların Düzenlenmesi:** (Madde 18) Uygulama "her şeyin en ince ayrıntısına kadar özelleştirilebildiği" bir menüye sahip olacak. Bildirim sistemi son derece gelişmiş ve esnek olacak; her bildirim türü, tarzı ve önceliği detaylıca ayarlanabilecek. Ana ekran sıfırlama butonu ana ayarlarda değil, doğrudan "ana ekran düzenleme" menüsünün içinde yer alacak.

## 3. İstatistikler ve Grafikler (Stats)
* **Çizgisel Grup Grafiği:** (Madde 12) Tarihe bağlı olarak grubun çalışma ivmesini gösteren çizgi grafik.
* **Grup İçi Tüm Zamanlar İstatistiği:** (Madde 14) Sadece bugün/bu hafta değil, tüm zamanlar rekorlarının detaylı görünümü.
* **Yeni Özelleştirilebilir Grafikler:** (Madde 15) Daire, pasta, radar vb. yeni grafik seçenekleri (AI istatistikleri daha havalı kılacak farklı grafik türleri ve animasyonlar eklemekte esnektir).

## 4. Oyunlaştırma ve Eğlence (Gamification)
* **Pause (Mola) Günü Hakkı:** (Madde 8) Chess.com / Duolingo benzeri "Streak Freeze" (Seri dondurma / Telafi) hakkı. Kullanıcı gün içinde hedefe ulaşamadığında kişisel ve grup serisinin bozulmasını engellemek için telafi hakkı olacak.
* **Gün / Hafta Birincilerine Görsel Efektler:** (Madde 13) Günün birincisinin profilinin/avatarının üstünde bir taç 👑 ile belirtilmesi. Geçen haftanın birincisine ekranda parlayan özel bir rozet / efekt verilmesi vb.
* **Grubun Enleri ve Trophy (Başarımlar) Sistemi:** (Madde 16, 17) 
  * "Gece Kuşu" (En çok gece çalışan), "Maratoncu" (En uzun seans), "Dürtücü" vb.
  * Profil sekmesi bu başarımların (Trophy) toplandığı zengin bir alana dönüşecek.
  * *Not:* Bu liste kesin değildir. AI, grubun dinamiğini artıracak çok daha komik, rekabetçi ve eğlenceli yeni başarımlar/ödüller (trophy) icat edip sisteme eklemelidir.

## 5. İletişim, Bildirim ve Widget Sistemleri (Social, Widgets & Notifications)
* **Android Ana Ekran Widget Sistemi:** (Madde 4)
  * Telefonun ana ekranına eklenebilecek, uygulamanın ruhunu yansıtan **çok çeşitli ve detaylı** bir widget sistemi inşa edilecek.
  * Tek bir standart widget yerine; küçük sayaçlar, büyük günlük/haftalık istatistik panoları, grup liderlik (leaderboard) tabloları gibi zengin çeşitlilikte harici widget'lar eklenecek.
  * Kullanıcı uygulamayı hiç açmadan, telefonunun ana ekranından güncel çalışma süresini görebilecek ve sayacı (kronometreyi) ana ekrandan doğrudan başlatıp/durdurabilecek.
* **Kapsamlı Bildirim ve Durum Çubuğu Sistemi:** (Madde 10 ve Ek)
  * **Genel Bildirimler:** İsteğe bağlı açılıp kapatılabilen, kişiye özel çalışma hatırlatıcıları.
  * **Dürtme (Nudge):** (Madde 8 - Minik Kuş) Grup üyelerine çalışma daveti mesajı atabilme.
  * **Zengin Kronometre Bildirimi (Kritik):** Sayaç çalışırken bildirim çubuğunda "kalıcı bildirim" (persistent notification) görünecek. Bu bildirim sadece süreyi göstermekle kalmayacak; durdurma, başlatma, mola verme gibi pek çok eylemi barındıran gelişmiş ve çeşitli bir kontrol paneli olacak.
  * **Dinamik Durum Çubuğu Baloncuğu (Live Activities):** Yeni nesil Android cihazlardaki sol üstte beliren "dinamik buton/hap" entegrasyonu. Uygulama arka plandayken durum çubuğunda minik bir gösterge kalacak, üzerine tıklandığında tıpkı bir baloncuk gibi üstten şık bir kontrol paneli açılarak kullanıcıya kolaylık sağlayacak.
* **Sistem Modları (Samsung Modes & Routines) Entegrasyonu:**
  * Cihazın işletim sistemiyle derin entegrasyon sağlanacak. Örneğin, Samsung cihazlarda telefon "Ders Çalışma Modu"na alındığında uygulama bunu algılayabilecek; arayüzünü değiştirebilecek, otomatik olarak odak ekranına geçebilecek veya bildirim ekranında özel bir pencere/aksiyon çıkartabilecek.
* **Otomatik E-posta Raporları:** (Madde 21) Ay sonlarında kullanıcılara otomatik özet maillerinin atılması.

## 6. Geliştirici, Test ve Yönetim Ekosistemi (Dev & Admin)
* **İzole Test Uygulaması (Beta/Staging Track):**
  * Güncellemeleri genel kullanıcıya ("Production") dağıtmadan önce geliştiricinin kendi telefonunda yeni özellikleri güvenle deneyebileceği ayrı bir "Test Uygulaması" ortamı oluşturulacak.
  * Bu uygulamanın paket adı (Package ID) farklı olacak (örneğin `.beta` uzantılı), böylece ana uygulamayla yan yana durabilecek.
  * *Beta Güncelleme Kanalı:* Uygulama içi güncelleme sistemi iki kanallı (Stable ve Beta) çalışacak.
  * **Önemli Esneklik Notu:** AI, bu test uygulamasının içerisine gizli geliştirici menüleri (developer options), hızlı log izleme (debug) ekranları, performans ölçüm panelleri vb. faydalı göreceği her türlü test aracını kendi inisiyatifiyle tasarlayıp eklemekte tamamen özgürdür.
* **Özel Admin Paneli (Admin App):**
  * Sadece proje sahibine/geliştiricisine özel ayrı bir yönetim uygulaması inşa edilecek (veya ana uygulama içinde gizli bir süper-admin arayüzü olacak).
  * **Özellikler:**
    * Sistemdeki kullanıcı, grup yönetimi ve veritabanı denetimi.
    * Supabase kullanım istatistiklerinin (kota ve limit doluluk oranlarının) ekrandan takip edilebilmesi.
    * **Geri Bildirim / Hata (Bug) Raporu Merkezi:** Kullanıcıların ana uygulamadan gönderdiği tüm mesajlar ve hata raporları bu panele düşecek.
    * **Önemli Esneklik Notu:** Bu özellikler sadece bir temeldir. AI, Admin panelini zenginleştirecek detaylı veri analizi grafikleri, kitle yönetimi (toplu duyuru/bildirim atma) araçları, otomatik yapay zeka analizleri vb. yeni ve yaratıcı özellikleri kendi vizyonuyla panele entegre etmekte son derece esnektir.

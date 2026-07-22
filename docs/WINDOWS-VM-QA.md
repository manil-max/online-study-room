# Windows Temiz Kurulum ve Güncelleme QA Prosedürü

> Kapsam: WP-259 · Yalnız local/staging QA. Store public yayını, production
> backend veya ana bilgisayardaki mevcut test paketi bu prosedürün dışındadır.

## Amaç

İki artan QA MSIX paketi arasında gerçek kurulum ve güncelleme davranışını
kanıtlamak:

`N temiz kurulum → giriş/demo → yerel tercih → N+1 güncelleme → veri korunumu → kaldırma`

ZIP artefaktı bu kanıtın yerine geçmez; ZIP yalnız taşınabilir çalıştırma
senaryosudur.

## Test hedefi seçimi

Bu bilgisayar Windows 11 Home kullanıyor. Windows Sandbox yalnız desteklenen
Pro/Enterprise/Education sürümlerinde kullanılabildiği için burada Sandbox
etkinleştirme denenmez. Aşağıdaki seçeneklerden **yalnız biri** seçilir:

1. Windows 11 Pro/Enterprise/Education cihazında Windows Sandbox.
2. Temiz Windows 11 x64 sanal makinesi (VirtualBox, VMware veya kurumsal VM).
3. Yalnız QA için ayrılmış ikinci Windows bilgisayar.

Ana bilgisayardaki `CN=Msix Testing` paketini kaldırmak veya onunla Store
kimliğini karıştırmak yasaktır.

## Testten önce

- [ ] Hedef Windows temiz/izole; önceki `OdakKampi.App` paketi yok.
- [ ] Hedefte test için ayrı Microsoft/Supabase hesabı hazır; gerçek kullanıcı
      e-postası, tokenı veya üretim verisi kullanılmaz.
- [ ] Aynı QA identity/publisher ile imzalanmış iki MSIX var: `N` ve `N+1`.
- [ ] `N+1` sürüm numarası `N`den yüksektir; iki paket de SHA-256 dosyasına
      sahiptir.
- [ ] Paket manifesti staging/test backend tuple'ını taşır; production endpoint
      veya Store public kimliği taşımaz.
- [ ] Ekran kaydında e-posta, erişim tokenı, özel grup adı ve kişisel veri yok.

## Koşum

1. Hedefte yüklü paket olmadığını doğrula; başlangıç ekranının görüntüsünü al.
2. `N` paketinin SHA-256 değerini doğrula ve MSIX'i kur.
3. Uygulamayı aç; giriş veya InMemory demo yolunu tamamla.
4. Bir zararsız yerel tercih oluştur (ör. tema) ve kısa bir test oturumu başlatıp
   bitir; kanıt için ekran görüntüsü al.
5. Uygulamayı tamamen kapatıp `N+1` MSIX'i kur. Aynı publisher/identity değilse
   burada dur: bu update kanıtı değildir.
6. `N+1`i aç; oturum, yerel tercih ve kullanıcı durumunu `N` ile karşılaştır.
7. Uygulamayı bir kez kapat/aç. Ardından offline → online geçişi ve yeniden
   başlatmayı kontrol et.
8. Uygulamayı kaldır; Paketli Uygulamalar/Start menüde kalıntı olmadığını doğrula.
9. Aynı oturumda taşınabilir ZIP'i tüm Release klasörüyle çalıştır; bunu ayrı
   `W-06` sonucu olarak yaz, update sonucuna dahil etme.

## Kanıt kaydı

| ID | Kanıt | Sonuç |
|---|---|---|
| W-01 | Temiz hedef + `N` kurulum ekranı | PASS/FAIL |
| W-02 | İlk açılış | PASS/FAIL |
| W-03 | `N → N+1` ve korunmuş tercih/oturum | PASS/FAIL |
| W-04 | Kaldırma sonrası kalıntı kontrolü | PASS/FAIL |
| W-06 | ZIP ile taşınabilir açılış | PASS/FAIL |
| W-10/11/12 | 100% / 125% / 150% DPI ekranları | PASS/FAIL |
| W-13 | Sleep/resume | PASS/FAIL |
| W-15 | Offline → online | PASS/FAIL |

Her satır için paket sürümü, SHA-256'nın ilk 12 karakteri, Windows sürümü ve
redacted ekran görüntüsü/video bağlantısı kaydedilir. Secret veya tam hash
değeri kanıt metnine yazılmaz.

## Başarı ve geri dönüş

Başarı için W-01…W-06 ile hedef platform/DPI kontrolleri PASS, `N → N+1`
sonrasında veri kaybı 0 ve P0/P1 hata 0 olmalıdır. Sorunda VM snapshot'ına veya
temiz hedefe dönülür; ana bilgisayardaki pakete, Store'a veya production'a işlem
yapılmaz.

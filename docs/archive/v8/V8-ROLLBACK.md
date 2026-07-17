# V8 Rollback Planı

> Durum: **Hazırlık taslağı.** Gerçek sürüm/build/artefakt bilgileri release
> gate PASS olduktan sonra doldurulur. Rollback kararı ürün sahibi ve yayın
> sorumlusu tarafından verilir.

## Hangi durumda dağıtım durur?

- P0 çökme, veri kaybı veya hesap/güvenlik sorunu.
- Uygulama kapalıyken bildirim veya widget eyleminin çalışmaması.
- Timer state/oturum sayısında çift yazım ya da kullanıcıyı etkileyen sapma.
- Beta cihazlarında tekrarlanabilir P1 olup güvenli workaround bulunmaması.

## Yayından önce hazır olacaklar

| Artefakt | Zorunlu kayıt |
|---|---|
| Aday APK/AAB | Git commit, SHA-256, sürüm adı/build numarası, paket kimliği |
| Geri-dönüş paketi | Aynı imza, **daha yüksek** Android build numarası, SHA-256 |
| Önceki bilinen iyi kaynak | Tag/commit ve imzalı artefakt yolu |
| Sunucu değişiklikleri | Migration/Edge Function listesi ve geri alma/forward-fix notu |
| İletişim taslağı | Dağıtımın durduğu, etki ve sonraki güncelleme zamanı |

## Uygulama adımları

1. Beta/stable dağıtımını durdur; etkilenen sürüm, kanal ve zaman damgasını kayda al.
2. Sentry/cihaz kanıtlarını redakte ederek olayı P0/P1 olarak kaydet; rastgele
   log, token veya kullanıcı e-postası paylaşma.
3. Sorun yalnız istemciyse önceki bilinen iyi koddan **ileri build numaralı**
   imzalı forward-fix paketi üret ve aynı kanala yükle.
4. Sorun sunucu/migration kaynaklıysa geri alma SQL'ini staging'de doğrula;
   veri kaybı riski varsa destructive rollback yapma, ileri düzeltme uygula.
5. Samsung ve Pixel üzerinde kritik yolu yeniden çalıştır; kanıtlar
   `QA-V8-ANDROID.md` içine eklenmeden dağıtımı açma.
6. Release gate'i NO-GO/PASS durumuyla güncelle, kullanıcıya etkisini ve
   güncelleme yolunu duyur.

## Android sürüm kuralı

Android, aynı paket imzasıyla daha düşük `versionCode` taşıyan APK'nın mevcut
kurulumun üstüne yüklenmesine izin vermez. Bu nedenle “eski APK'yı geri yükle”
planı çoğu kullanıcı için güvenilir değildir. Geri dönüş paketi, bilinen iyi
davranışı içeren ama **daha yüksek build numaralı** yeni bir imzalı pakettir.
Kullanıcıdan uygulamayı kaldırmasını istemek veri kaybı yaratabileceği için
son çaredir ve açık onay gerektirir.

## Olay kaydı

| Alan | Değer |
|---|---|
| Etkilenen sürüm/build | — |
| Tespit zamanı / kişi | — |
| Etki / P0-P1 | — |
| Dağıtımın durdurulması | — |
| Forward-fix sürümü / SHA-256 | — |
| Samsung + Pixel yeniden doğrulama | — |
| Kapanış onayı | — |

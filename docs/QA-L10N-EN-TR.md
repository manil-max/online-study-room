# EN/TR cihaz kalite kapısı

Bu liste WP-89 için gerçek cihaz ve ürün kabulü kanıtıdır. Otomatik testlerin
yeşil olması bunu ikame etmez.

## Otomatik kanıt

- `python scripts/l10n_audit.py` — Flutter katalog anahtarları/placeholder'ları,
  görünür Flutter Türkçe literalları ve Android EN/TR kaynak paritesi.
- `flutter analyze --no-pub`
- `flutter test --dart-define-from-file=env.json`
- `flutter build apk --release --dart-define-from-file=env.json`
- `flutter build windows --release --dart-define-from-file=env.json`

## Cihaz matrisi

Her satır için cihaz modeli, işletim sistemi, uygulama build numarası, sistem
dili ve ekran görüntüsü/video bağlantısı kaydedilir. Bir hata varsa yeni debug
WP açılır; bu kart “tamamlandı”ya taşınmaz.

| Yüzey | EN sistem dili | TR sistem dili | Kanıt |
|---|---|---|---|
| Samsung (Android 14+) | Giriş, Ana Sayfa, Gruplar, İstatistik, Profil; uzun İngilizce taşması yok | Aynı yolculuk, Türkçe metinler | Bekliyor |
| Pixel (Android 14+) | Widget preview, kısayol, alarm/timer bildirimi | Aynısı; uygulama kapalıyken alarm/widget | Bekliyor |
| Windows | Cold-start, masaüstü gezinme, saat/StandBy | Aynı yolculuk, pencere başlığı ve hata yüzeyi | Bekliyor |

## Kritik senaryolar

1. Uygulamayı tamamen kapat, sistem dilini değiştir, tekrar aç. `tr` yalnızca
   Türkçeyi; `en`, `de` ve desteklenmeyen tüm dilleri İngilizceyi göstermeli.
2. Girişsiz, boş grup, ağ hatası ve çevrimdışı durumlarında ham hata/exception
   metni görünmemeli.
3. Sayaç başlat; uygulamayı görev listesinden kapat; bildirimdeki eylem,
   widget ve alarm yüzeyleri sistem dilinde kalmalı.
4. 360 dp Android ve dar Windows penceresinde uzun İngilizce etiketler
   taşmamalı; temel dokunma hedefleri erişilebilir kalmalı.
5. TalkBack/Narrator ile ana sekmeler, alarm/timer eylemleri ve widget
   açıklamaları anlaşılır olmalı.

## Kabul eşiği

Samsung, Pixel ve Windows için iki dilde kanıt olmadan WP-89 yalnızca
“Otomatik test geçti” durumunda kalır. Ürün sahibi kabulünden sonra ilgili
WP-84–89 kartları tamamlananlar bölümüne taşınabilir.

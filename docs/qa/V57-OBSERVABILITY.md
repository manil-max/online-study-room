# V57 — Çökme ve sessiz hata gözlemlenebilirliği

## Kapsam

Uygulama, yerel tercih okunduktan sonra Flutter framework hatalarını ve
`PlatformDispatcher` asenkron hatalarını tek bir güvenli kapıdan geçirir.
Kapı; ham hata metni yerine yalnız hata türünü, kapalı sözlükten operasyon ve
sonuç sınıfını ve PII redaksiyonundan geçmiş en fazla 40 stack satırını işler.

Kullanıcı eylemleri şu kapalı operasyon sözlüğünü kullanır: `timer`, `feedback`,
`group_leave` ve `moderation`. Eylemi başlatan yüzey bir correlation ID alır;
aynı ID ile başarı, başarısızlık, iptal, çevrimdışı veya zaman aşımı sonucu
kaydedilir. Başarı UI'da gösterilmeden önce `succeeded`, hata UI'da gösterilirken
`failed` (veya daha özel sonuç) kaydedilmelidir. Böylece başarısız bir eylem
telemetride başarı gibi görünemez.

## Gizlilik ve yerel tampon

- Telemetri tercihi kapalıysa uzak sağlayıcıya veri gitmez, yerel tampon da
  tutulmaz. Tercihi kapatma mevcut tamponu hemen siler.
- Sağlayıcı yapılandırılmamış ya da çevrimdışıysa, kullanıcı izin vermişse en
  fazla 64 yapılandırılmış olay sadece bellekte tutulur. Disk, SharedPreferences
  veya dosyaya yazılmaz; uygulama kapanınca kaybolur.
- Olay adları, alan anahtarları, operasyonlar ve sonuçlar kapalı sözlüktür.
  Serbest metin, e-posta, kullanıcı/grup kimliği, token, parola, authorization
  değeri ve mesaj gövdesi kabul edilmez.
- Stack izindeki e-posta, yerel kullanıcı yolu ve token/secret/password/
  authorization atamaları redakte edilir. Uzak hata nesnesi sabit metin ile
  yalnız güvenli hata türünü taşır.

## Sağlayıcı kapısı

Sentry yalnız aşağıdaki derleme ayarlarının tamamı verildiğinde başlar:

- `SENTRY_ENABLED=true`
- `SENTRY_DSN=<sağlayıcı DSN'i>`
- İsteğe bağlı: `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`

DSN veya diğer credential'lar `env.json` gibi commit dışı ortam dosyalarında
kalır. Sağlayıcı hazır değilse uygulama açılmaya devam eder ve yukarıdaki sınırlı
yerel structured log davranışı kullanılır. Native process crash kapsaması,
sağlayıcının ilgili platform yapılandırması ile etkinleştirildiğinde gelir;
uygulama kodu bu hazırlık yokken de güvenli fallback'e sahiptir.

## QA kanıtı

Hedefli otomatik test:

```text
flutter test --dart-define-from-file=env.json \
  test/core/observability/observability_service_test.dart
```

Testler kontrollü hata yakalama, timer/feedback/group leave/moderation için
correlation ID ve sonuç sınıfı, token/e-posta/yerel yol redaksiyonu, opt-out
sonrası tampon silinmesi ve 64 olay sınırını doğrular.

Manuel cihaz doğrulamasında, test ortamında geçici sağlayıcı ayarıyla kontrollü
bir Flutter ve asenkron hata üretilir; kullanıcıya başarı mesajı gösterilmediği,
olayın yalnız güvenli alanlarla ulaştığı ve telemetri kapatılınca yeni olay
oluşmadığı doğrulanır. Bu geçici ayarlar repoya eklenmez.

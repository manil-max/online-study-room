# V8 Gözlemlenebilirlik ve Sentry Kontrol Listesi

WP-47, çökme ve senkron teşhisini kullanıcı davranış analitiğinden ayırır.
Yalnız `app.sync` breadcrumb'ları gönderilir; e-posta, kullanıcı kimliği, token,
ham oturum verisi, ders adı ve serbest metin gönderilmez.

## Ortam ayarları

`app/env.json` (commit edilmez) için beta/stable örneği:

```json
{
  "SENTRY_DSN": "https://public@example.ingest.sentry.io/0",
  "SENTRY_ENABLED": true,
  "SENTRY_ENVIRONMENT": "beta",
  "SENTRY_RELEASE": "odak-kampi@1.0.7+8"
}
```

`SENTRY_DSN` eksikse veya `SENTRY_ENABLED` false ise SDK hiç başlatılmaz. Yerel
opt-out anahtarı `observability.telemetry_enabled=false` olduğunda da hiçbir
olay gönderilmez. DSN publiktir; yine de gerçek `env.json` repoya eklenmez.

## Gönderilen breadcrumb'lar

| Olay | Veri |
|---|---|
| `timer_restore` | Aktif timer vardı/yoktu |
| `outbox_flush` | Bekleyen, uygulanan, kalan mutation sayıları ve süre |
| `realtime_snapshot` | Oturum sayısı, bekleyen outbox sayısı ve süre |
| `realtime_fallback` | Yerel cache bulundu/bulunmadı |

## Beta doğrulaması

1. Beta `env.json` ile imzalı paketi kur; Sentry'de environment=`beta` ve
   release değerinin doğru olduğunu doğrula.
2. Uygulamayı çalışan timer ile kapat/aç; `timer_restore` breadcrumb'ını gör.
3. Ağı kesip bir oturum ekle, ağı aç; `outbox_flush` ve `realtime_snapshot`
   breadcrumb'larını gör. Kimlik/token/oturum içeriği olmadığını denetle.
4. Yerel tercihi `observability.telemetry_enabled=false` yapıp yeniden aç;
   yeni event gitmediğini doğrula.
5. Bilinen hata kontrolü yalnız test/prova ortamında yapılır; hata metninde
   e-posta/token görünmemelidir. Sonra test olayı Sentry'den silinir.

Geri alma: `SENTRY_ENABLED=false` ile yeni paket yayınla; gerekirse
`sentry_flutter` bağımlılığını sonraki bakım paketinde kaldır. Telemetri kesilse
bile timer, offline outbox ve uygulama açılışı çalışmaya devam eder.

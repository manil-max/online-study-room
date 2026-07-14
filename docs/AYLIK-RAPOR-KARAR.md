# Aylık Çalışma Raporu — E-posta Sağlayıcısı ve Teslim Mimarisi Kararı

> **WP-65** · Tarih: 2026-07-14 · Durum: `Ürün kararı gerekiyor`
> Bu belge implementasyon **yapmaz**; sağlayıcı, gönderen, izin, içerik, zamanlama ve hata politikası kararlarını ürün sahibine sunar.
> Onaylanan seçeneklerle ayrı bir uygulama WP'si açılır.

---

## 0. Yönetici Özeti

Kullanıcılara aylık çalışma özeti e-postası göndermek istiyoruz. Mevcut durumda:

- **Hiçbir e-posta altyapısı yok** — Supabase'in yerleşik e-postası yalnız auth (şifre sıfırlama vb.) için, saat 4 mail limiti var ve özel e-posta desteklemiyor.
- **Edge Function kalıbı mevcut** — `admin-operations` ve `admin-user-actions` Deno tabanlı çalışıyor; aynı kalıp e-posta gönderimi için uygun.
- **İstatistik verisi zengin** — `study_stats.dart`'ta toplam süre, günlük ortalama, seri, ders dağılımı, saatlik dağılım, zirve gün gibi çok sayıda metrik var.
- **Supabase Free Tier** — `pg_cron` + Edge Function + harici e-posta API birleşimi ile yapılabilir.
- **WP-66 ile tutarlılık** — rapordaki verilerin saklama politikasıyla uyumlu olması gerekiyor.

Bu belge beş ana karar alanını kapsar: **Sağlayıcı · Gönderen · İzin · İçerik · Mimari**.

---

## 1. Mevcut Durum Envanteri

### 1.1 E-posta Altyapısı

| Bileşen | Durum |
|---|---|
| Supabase yerleşik e-posta | ✅ Yalnız auth (şifre sıfırlama/doğrulama); 4/saat limiti |
| Özel SMTP yapılandırması | ❌ Yok |
| E-posta SDK/paketi (Flutter) | ❌ Yok |
| E-posta gönderim kodu | ❌ Yok |
| Harici e-posta sağlayıcı hesabı | ❌ Yok |

### 1.2 Mevcut Edge Function Kalıbı

```
Deno serve() → CORS → Authorization header → Supabase service-role client
→ İş mantığı → JSON yanıt
```

İki fonksiyon canlı: `admin-operations`, `admin-user-actions`. Aynı kalıp e-posta Edge Function'ı için kullanılabilir. `Kodda doğrulandı`

### 1.3 Mevcut İstatistik Verileri

Raporda kullanılabilecek metrikler (`study_stats.dart` saf fonksiyonları):

| Metrik | Fonksiyon | Açıklama |
|---|---|---|
| Toplam çalışma süresi | `totalSeconds()` | Tüm oturumların toplamı |
| Günlük ortalama | `dailyAverageSeconds()` | Takvim günü başına ortalama |
| Günlük seri | `currentStreak()` / `longestStudyStreak()` | Hedef bazlı ve en uzun |
| Ders dağılımı | `subjectBreakdown()` | Derse göre süre, sıralı |
| Saatlik dağılım | `hourlyTotals()` | 24 saatlik çalışma kalıbı |
| Hafta içi/sonu | `weekdayWeekendSplit()` | Hafta içi vs hafta sonu |
| Zirve gün | `peakDay()` | En verimli gün |
| Aktif gün sayısı | `activeDayCount()` | Çalışılan toplam gün |

### 1.4 Supabase Tier Bilgisi

| Özellik | Free Tier | Pro Tier |
|---|---|---|
| Edge Function çağrı | 500.000/ay | 2.000.000/ay |
| Compute | 250.000 GB-sn | 500.000 GB-sn |
| Maks. çalışma süresi | 150 sn | 400 sn |
| CPU süresi/istek | 200 ms | 200 ms |
| Secret sayısı | 100 | 100 |
| `pg_cron` | ✅ Tüm planlarda | ✅ |
| Proje uyku (inaktivite) | ⚠️ 1 hafta sonra duraklar | Duraklamaz |

---

## 2. E-posta Sağlayıcı Karşılaştırması

### 2.1 Karşılaştırma Tablosu

| Kriter | **Resend** | **Brevo** | **Amazon SES** | **Postmark** | **Mailgun** | **SendGrid** |
|---|---|---|---|---|---|---|
| **Ücretsiz limit** | 3.000/ay (100/gün) | ~9.000/ay (300/gün) | Yeni hesap kredisi | 100/ay | ~3.000/ay (100/gün) | ❌ Yok |
| **1.000 mail maliyeti** | ~$0,90 | Starter $9/ay 5K | **$0,10** | $1,50 | $2,00 | $0,40 |
| **İlk ücretli plan** | $20/ay (50K) | $9/ay (5K) | Kullandıkça öde | $15/ay (10K) | $15/ay | $19,95/ay (50K) |
| **Deno uyumu** | ⭐ Mükemmel (`fetch`) | ✅ İyi (`fetch`) | ⚠️ AWS SDK | ✅ İyi (`fetch`) | ✅ İyi (`fetch`) | ✅ İyi (`fetch`) |
| **Teslim oranı** | İyi (SES altyapı) | Orta | İyi | ⭐ En iyi | İyi | İyi |
| **DNS doğrulama** | SPF+DKIM+DMARC | SPF+DKIM+DMARC | SPF+DKIM+DMARC+sandbox çıkış | SPF+DKIM+DMARC | SPF+DKIM+DMARC | CNAME |
| **Abonelik yönetimi** | ✅ List-Unsubscribe | ✅ Yerleşik | ❌ Manuel | ✅ Stream ayrımı | ✅ Yerleşik | ✅ Yerleşik |
| **Ücretsiz marka izi** | Yok | ⚠️ "Sent by Brevo" | Yok | Yok | Yok | — |
| **Kurulum karmaşıklığı** | ⭐ Çok düşük | Orta | ⚠️ Yüksek (IAM) | Düşük | Düşük | Orta |

### 2.2 Önerilen İlk Üç

#### 🥇 Resend — Önerilen

**Neden:**
- Supabase Edge Function ile en basit entegrasyon (tek `fetch` çağrısı)
- Resmi Supabase dokümantasyonunda Resend entegrasyon örnekleri var
- 3.000/ay ücretsiz (uygulamamız için yeterli başlangıç)
- Marka izi (watermark) yok
- Modern, geliştirici dostu API
- Tek API anahtarı → Supabase secret olarak saklanır

**Sınırlar:**
- Ücretsiz katmanda **100/gün** sınırı — 500 kullanıcıya ayda tek seferde gönderim için ücretli gerekir
- Türkiye'den domain doğrulama + DNS kaydı yönetimi gerekir

**Örnek Edge Function entegrasyonu:**
```typescript
const res = await fetch("https://api.resend.com/emails", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
    "Content-Type": "application/json",
  },
  body: JSON.stringify({
    from: "Odak Kampı <rapor@odakkampi.com>",
    to: userEmail,
    subject: "Temmuz 2026 — Aylık Çalışma Raporun",
    html: reportHtml,
    headers: { "List-Unsubscribe": "<mailto:unsubscribe@odakkampi.com>" },
  }),
});
```

#### 🥈 Brevo — En yüksek ücretsiz hacim

**Neden:** 300/gün = ~9.000/ay ücretsiz, süresi dolmaz.
**Dezavantaj:** Ücretsiz katmanda "Sent by Brevo" damgası; pazarlama ve işlemsel e-posta aynı altyapıyı paylaşır (teslim riski).

#### 🥉 Amazon SES — Ölçekte en ucuz

**Neden:** $0,10/1.000 mail ile en düşük birim maliyet.
**Dezavantaj:** AWS IAM kurulumu + SDK bağımlılığı + sandbox çıkışı; küçük proje için aşırı karmaşık.

### 2.3 Önerilmeyen

| Sağlayıcı | Neden |
|---|---|
| **SendGrid** | Ücretsiz katman kaldırıldı (2025); küçük proje için pahalı |
| **Postmark** | Ücretsiz 100/ay yetersiz; maliyet yüksek |
| **Mailgun** | Flex fiyatı 2025'te iki katına çıktı; Resend her boyutta daha iyi |

---

## 3. Gönderen Kimliği

### 3.1 Seçenekler

| Seçenek | Gönderen Adresi | DNS Gereksinimi | Güven/Teslim |
|---|---|---|---|
| **A — Özel domain** | `rapor@odakkampi.com` | SPF+DKIM+DMARC (domain kontrolü gerekir) | ⭐ En yüksek |
| **B — Alt domain** | `rapor@mail.odakkampi.com` | SPF+DKIM alt domain'de | Yüksek (ana domain korunur) |
| **C — Sağlayıcı paylaşımlı** | `noreply@resend.dev` vb. | Yok | ⚠️ Düşük (spam riski) |

> **Öneri:** Seçenek **B** (alt domain) — ana domain'in e-posta itibarını korur; kurulum bir kez yapılır.

### 3.2 DNS Kayıtları (bir kez)

Seçilen sağlayıcı (ör. Resend) doğrulama sırasında şu kayıtları verir:
1. **SPF** — `TXT` kaydı, gönderme yetkisi
2. **DKIM** — `TXT` veya `CNAME`, dijital imza
3. **DMARC** — `TXT`, kimlik doğrulama politikası (önerilir: `p=quarantine`)

> `Ürün kararı gerekiyor` — Domain adı ve DNS erişimi var mı? Alan adı `odakkampi.com` mı yoksa başka mı?

---

## 4. Kullanıcı İzni ve Abonelik

### 4.1 Hukuki Çerçeve

| Kural | Gereklilik |
|---|---|
| **CAN-SPAM (ABD)** | Opt-out yeterli; her mailde iptal linki + fiziksel adres |
| **GDPR (AB)** | Opt-in gerekli; açık onay + geri çekme hakkı |
| **KVKK (Türkiye)** | GDPR benzeri; açık rıza + bilgilendirme |
| **Apple/Google politikaları** | Uygulama içi e-posta izni bilgilendirmesi |

### 4.2 Seçenekler

| Seçenek | Varsayılan | Açıklama | Risk |
|---|---|---|---|
| **A — Opt-in** | Kapalı → kullanıcı açar | Ayarlar'da "Aylık rapor al" toggle'ı; kayıtta da gösterilebilir | Düşük katılım |
| **B — Soft opt-in** | Açık → kullanıcı kapatabilir | Kayıt sonrası bilgilendirme; ayarlardan kapatma; ilk mailden önce bildirim | Daha yüksek katılım |
| **C — Zorunlu** | Her zaman gönder | İptal yok | ❌ KVKK/GDPR ihlali |

> **Öneri:** Seçenek **B** (soft opt-in) — yeni kullanıcılarda varsayılan açık, Ayarlar'dan kapatılabilir, her mailde tek tıkla iptal linki. Kayıt ekranında kısa bilgilendirme metni.

### 4.3 Veritabanı Etkisi (sonraki uygulama WP'sinde)

```sql
-- profiles tablosuna eklenecek alan
ALTER TABLE profiles ADD COLUMN monthly_report_opt_in BOOLEAN DEFAULT true;
-- İptal linki için token tablosu
CREATE TABLE email_unsubscribe_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  used_at TIMESTAMPTZ
);
```

> Bu migration WP-65'te **yapılmaz** — onay sonrası uygulama WP'sinde.

### 4.4 Her E-postada Zorunlu Öğeler

- `List-Unsubscribe` HTTP başlığı (tek tıkla iptal)
- E-posta gövdesinde görünür iptal linki
- Gönderen bilgisi (uygulama adı + iletişim)
- E-postanın neden gönderildiği açıklaması

---

## 5. Rapor İçeriği

### 5.1 Önerilen Rapor Alanları

Mevcut istatistik fonksiyonlarından türetilebilecek içerik:

| Bölüm | İçerik | Veri Kaynağı | Hassasiyet |
|---|---|---|---|
| **Başlık** | "Temmuz 2026 — Aylık Çalışma Raporun" | Tarih | Düşük |
| **Toplam süre** | "Bu ay 42 saat 15 dakika çalıştın" | `totalSeconds()` (aylık filtre) | Orta |
| **Günlük ortalama** | "Günlük ortalaman: 1 saat 22 dakika" | `dailyAverageSeconds()` | Orta |
| **Aktif gün** | "31 günün 25'inde çalıştın" | `activeDayCount()` | Orta |
| **En verimli gün** | "En çok 5 Temmuz'da çalıştın: 4 saat 10 dk" | `peakDay()` | Orta |
| **Günlük seri** | "Mevcut serin: 12 gün 🔥" | `currentStreak()` | Orta |
| **Ders dağılımı** | İlk 3 ders + süre | `subjectBreakdown()` | Orta |
| **Önceki aya göre değişim** | "Geçen aya göre %15 artış ↑" | İki ayın karşılaştırması | Orta |
| **Haftanın en aktif günü** | "En çok Çarşamba günleri çalışıyorsun" | `weekdayWeekendSplit()` | Düşük |
| **Motivasyon mesajı** | Veriye göre kişiselleştirilmiş kısa metin | Basit kural tabanlı | Düşük |

### 5.2 Raporda Yer Almaması Gerekenler

| Veri | Neden |
|---|---|
| E-posta adresi (gövdede tekrar) | Gereksiz PII tekrarı |
| Diğer kullanıcıların verileri | Gizlilik ihlali |
| Grup sıralaması detayı | Sosyal baskı riski; yalnız kendi verisi |
| Ham oturum listesi | Çok uzun; gizlilik |
| XP/başarım detayı | Server-authoritative yapı oturuncaya kadar e-postada yer almaz |

### 5.3 Veri Minimizasyonu (WP-66 Uyumu)

- Raporda yalnız **toplu/aggregate** veriler kullanılır (ham oturum değil)
- E-posta gövdesinde `user_id` veya teknik kimlik yer almaz
- Rapor verisi geçici olarak hesaplanır, kalıcı "rapor" tablosu **oluşturulmaz**
- WP-66'da belirlenen saklama süresinden eski veriler rapora dahil edilmez

> `Ürün kararı gerekiyor` — Hangi alanlar kesinlikle olsun? Hangileri fazla?

---

## 6. Zamanlama ve Teslim Mimarisi

### 6.1 Önerilen Mimari (3 katmanlı)

```
┌─────────────┐     ┌──────────────────────┐     ┌─────────────────┐
│  pg_cron     │────▶│ Edge Function:       │────▶│ Edge Function:  │
│  (zamanlayıcı)│     │ "collect-reports"    │     │ "send-report"   │
│  Ayın 1'i    │     │ Kullanıcıları kuyruğa│     │ Batch gönderim  │
│  09:00 UTC+3 │     │ yaz                  │     │ (50-100/çağrı)  │
└─────────────┘     └──────────────────────┘     └─────────────────┘
                              │                          │
                              ▼                          ▼
                    ┌──────────────────┐       ┌──────────────────┐
                    │ email_job_queue  │       │ Resend / Brevo   │
                    │ (Supabase tablo) │       │ API              │
                    └──────────────────┘       └──────────────────┘
```

### 6.2 Akış Detayı

**Adım 1 — Toplayıcı** (`pg_cron` → Edge Function `collect-reports`)
- Her ayın 1'i, saat 09:00 (Europe/Istanbul) tetiklenir
- `profiles` tablosundan `monthly_report_opt_in = true` ve `email_bounced IS NOT true` olan kullanıcıları çeker
- Her kullanıcı için `email_job_queue` tablosuna satır ekler: `user_id`, `status: 'pending'`, `report_month`, `created_at`

**Adım 2 — Göndericiler** (`email_job_queue` → Edge Function `send-report`)
- Toplayıcı bitince veya ayrı bir `pg_cron` ile 5 dakikada bir tetiklenir
- `status = 'pending'` olan ilk 50-100 kaydı alır
- Her kullanıcı için:
  1. `study_sessions` tablosundan ilgili ayın oturumlarını çeker
  2. İstatistikleri hesaplar (sunucu tarafında, saf SQL/RPC)
  3. HTML şablonunu doldurur
  4. E-posta API'sine gönderir
  5. Başarılıysa `status: 'sent'`, `processed_at: now()` günceller
  6. Başarısızsa `status: 'failed'`, `error: <mesaj>`, `retry_count + 1` günceller

**Adım 3 — Yeniden deneme**
- `status = 'failed'` ve `retry_count < 3` olanlar sonraki turda tekrar denenir
- 3 başarısız denemeden sonra `status: 'abandoned'` olur, log kaydı tutulur

### 6.3 Zamanlama Seçenekleri

| Seçenek | Zaman | Avantaj | Dezavantaj |
|---|---|---|---|
| **A — Ayın 1'i** | Her ayın 1., 09:00 İstanbul | Doğal ay sonu özeti | Uzun ay (31 gün) vs kısa ay (28) farkı |
| **B — Ayın 2'si** | Her ayın 2., 09:00 İstanbul | Ay sonu oturumları kesinleşir (offline sync) | 1 gün gecikme hissi |
| **C — Her 4 hafta** | Her 28 günde bir | Eşit aralık | Takvim ayıyla uyuşmaz |

> **Öneri:** Seçenek **B** (ayın 2'si) — ayın son günü yapılan çalışmaların sync olması için 1 gün tampon.

### 6.4 `pg_cron` + `pg_net` Tetikleme (referans)

```sql
-- Toplayıcı Edge Function'ı tetikle (uygulama WP'sinde kurulur)
SELECT cron.schedule(
  'monthly-report-collector',
  '0 6 2 * *',  -- Ayın 2'si, 06:00 UTC (09:00 İstanbul)
  $$
  SELECT net.http_post(
    url := 'https://YOUR-PROJECT.supabase.co/functions/v1/collect-reports',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object('month', to_char(now() - interval '1 day', 'YYYY-MM'))
  );
  $$
);
```

### 6.5 Free Tier Dikkat Noktaları

| Kısıt | Etki | Çözüm |
|---|---|---|
| Resend 100/gün | 500 kullanıcıda 5 gün sürer | Ücretli plana geçiş veya Brevo (300/gün) |
| Supabase proje uyku | 1 hafta inaktivitede `pg_cron` durur | Harici ping (ör. UptimeRobot) veya Pro plan |
| Edge Function CPU 200ms | İstatistik hesaplama I/O değil | SQL/RPC ile hesapla, Edge Function yalnız göndersin |
| Edge Function 150s duvar | Tek çağrıda 500 mail gönderilmez | Batch (50-100) + kuyruk tablosu |

---

## 7. Hata ve Yeniden Deneme Politikası

### 7.1 Başarısız Teslim Türleri

| Tür | Açıklama | Eylem |
|---|---|---|
| **Soft bounce** | Posta kutusu dolu, geçici hata | 3 kez yeniden dene (6-12-24 saat aralıklı) |
| **Hard bounce** | Adres yok, domain yok | Kullanıcı kaydında `email_bounced = true` işaretle; gelecek gönderimlerde atla |
| **Spam şikayeti** | Kullanıcı spam olarak işaretledi | Otomatik opt-out; `monthly_report_opt_in = false` |
| **API hatası** | Sağlayıcı geçici hata (429/500) | Kuyrukta tut, üstel geri çekilme ile yeniden dene |
| **Rate limit** | Sağlayıcı günlük/dakikalık limit | Sonraki batch turuna ertele |

### 7.2 Webhook Akışı (sağlayıcıdan geri bildirim)

```
Resend/Brevo webhook → Edge Function "email-webhook"
  → bounce: email_bounced = true
  → complaint: monthly_report_opt_in = false
  → delivered: log kaydı (opsiyonel)
```

> Webhook imzası doğrulanmalı (güvenlik).

### 7.3 İzleme ve Uyarı

| Metrik | Eşik | Eylem |
|---|---|---|
| Aylık teslim oranı | < %95 | Uyarı → DNS/itibar kontrolü |
| Bounce oranı | > %5 | Uyarı → liste temizliği |
| Şikayet oranı | > %0,1 | ⚠️ Acil → içerik/sıklık gözden geçir |
| Kuyrukta kalan iş | > 48 saat | Uyarı → batch boyutunu/sıklığını kontrol et |

---

## 8. Maliyet Tahmini

### 8.1 Kullanıcı Sayısına Göre Aylık Maliyet

| Kullanıcı Sayısı | Resend | Brevo | Amazon SES |
|---|---|---|---|
| **≤ 100** | $0 (ücretsiz) | $0 (ücretsiz) | $0 (kredi dahili) |
| **100–300** | $0 (ücretsiz) | $0 (ücretsiz) | $0,03 |
| **300–3.000** | $0 (ücretsiz*) | $0 (ücretsiz) | $0,30 |
| **3.000–5.000** | $20/ay | $9/ay | $0,50 |
| **5.000–50.000** | $20/ay | $25/ay | $5 |

\* Resend ücretsiz 100/gün limiti nedeniyle 3.000 kullanıcıya gönderim 30 gün alır; pratikte 300+ kullanıcıda ücretli gerekir.

### 8.2 Ek Maliyetler

| Kalem | Tahmini Maliyet |
|---|---|
| Domain/DNS (zaten varsa) | $0 |
| Supabase Pro (proje uyku önleme) | $25/ay (başka nedenlerle de gerekebilir) |
| Sağlayıcı ücretli plan (≤3K kullanıcı) | $0–$20/ay |
| **Toplam (≤3K kullanıcı, free tier)** | **$0/ay** |

---

## 9. Güvenlik Değerlendirmesi

### 9.1 Sır (Secret) Yönetimi

| Sır | Nerede Saklanır | Repoya Girer mi? |
|---|---|---|
| E-posta API anahtarı | Supabase Secrets (`RESEND_API_KEY` vb.) | ❌ ASLA |
| Service role key | Supabase Secrets (zaten var) | ❌ ASLA |
| Webhook imza anahtarı | Supabase Secrets | ❌ ASLA |

### 9.2 Veri Güvenliği

- E-posta gövdesinde yalnız **toplu istatistik** — ham oturum verisi yok
- `user_id`, API anahtarı veya teknik kimlik e-posta gövdesine konmaz
- E-posta adresi **yalnız sunucu tarafında** (Edge Function) kullanılır; istemciye hiç inmez
- Gönderim işlemi `service_role` ile yapılır; kullanıcı kendi e-postasını tetikleyemez (spam koruması)
- Başka kullanıcının e-postasını tetikleme yolu yoktur (API yalnız sunucu tarafı)

### 9.3 RLS Uyumu

- Rapor verisi `service_role` ile çekilir (Edge Function); RLS atlanır
- Bu kabul edilebilir çünkü kullanıcıya **yalnız kendi verisi** gönderilir
- Edge Function, `user_id` filtresi ile tek kullanıcının verisini çeker
- Grup/başkasının verisi **asla** dahil edilmez

---

## 10. Geri Alma (Rollback) Planı

| Bileşen | Geri Alma |
|---|---|
| Edge Function | `supabase functions delete <fonksiyon-adı>` |
| `pg_cron` işi | `SELECT cron.unschedule('monthly-report-collector')` |
| `email_job_queue` tablosu | `DROP TABLE email_job_queue` |
| `profiles.monthly_report_opt_in` | `ALTER TABLE profiles DROP COLUMN monthly_report_opt_in` |
| Sağlayıcı hesabı | Dashboard'dan kapat/dondur |
| DNS kayıtları | SPF/DKIM/DMARC kayıtlarını sil |

Tüm bileşenler bağımsız geri alınabilir; birini kaldırmak diğerini bozmaz.

---

## 11. WP-66 (Hesap Silme/Retention) ile Eşleştirme

| WP-65 Kararı | WP-66 Etkisi |
|---|---|
| Rapor verileri geçici hesaplanır, saklanmaz | Retention politikası rapor verisini etkilemez |
| Kullanıcı opt-out yaparsa e-posta durur | Hesap silindiğinde e-posta tercihi de silinir |
| `email_job_queue` kayıtları 90 gün sonra temizlenir | Retention süresine uyumlu |
| Bounce/şikayet kaydı profille birlikte silinir | Silme akışına dahil edilir |
| Raporda yalnız mevcut ayın verisi var | Eski veri purge edilse bile rapor etkilenmez |

> Uygulama WP'si, WP-66 kararları kesinleşince retention sürelerini bu tabloya bağlar.

---

## 12. Uygulama WP'si Taslağı (onay sonrası açılır)

Aşağıdaki WP, bu belgedeki kararlar onaylandıktan sonra planlama kuyruğuna eklenir:

**WP-6X: Aylık Çalışma Raporu — E-posta Gönderim Altyapısı**
- [ ] Sağlayıcı hesabı aç + DNS doğrula + API key'i Supabase Secret'a ekle
- [ ] `profiles` tablosuna `monthly_report_opt_in` kolonu migration
- [ ] Ayarlar ekranına "Aylık rapor al" toggle'ı + çift repo (supabase/in_memory)
- [ ] `email_job_queue` tablosu migration (+ RLS: yalnız service_role erişir)
- [ ] Edge Function: `collect-reports` (toplayıcı)
- [ ] Edge Function: `send-report` (batch göndericisi)
- [ ] HTML e-posta şablonu (Türkçe, responsive, koyu/açık)
- [ ] `pg_cron` + `pg_net` zamanlayıcı kurulumu
- [ ] Webhook Edge Function: bounce/şikayet işleme
- [ ] İptal linki + token mekanizması
- [ ] Birim testleri (istatistik hesaplama, kuyruk işleme)
- [ ] Cihaz QA: gerçek test hesabına e-posta gönderim kanıtı

---

## 13. Ürün Kararları Özeti

> **Aşağıdaki her madde için ürün sahibinin yazılı seçimi gereklidir.**

### Karar 1 — E-posta Sağlayıcısı
| Seçenek | Öneri |
|---|---|
| **A — Resend** | ⭐ Önerilen (basit, ücretsiz, Supabase uyumlu) |
| B — Brevo | Alternatif (daha yüksek ücretsiz hacim, marka izi) |
| C — Amazon SES | Yalnız ölçek gerekirse |

### Karar 2 — Gönderen Adresi
| Seçenek | Öneri |
|---|---|
| A — `rapor@odakkampi.com` (ana domain) | Profesyonel |
| **B — `rapor@mail.odakkampi.com` (alt domain)** | ⭐ Önerilen (ana domain korunur) |
| C — Paylaşımlı (sağlayıcı domain) | Önerilmez |

> **Ön koşul:** Domain adı nedir? DNS erişimi var mı?

### Karar 3 — Kullanıcı İzni
| Seçenek | Öneri |
|---|---|
| A — Opt-in (kapalı başlar) | Düşük katılım riski |
| **B — Soft opt-in (açık başlar, kapatılabilir)** | ⭐ Önerilen |
| C — Zorunlu | ❌ Hukuka aykırı |

### Karar 4 — Rapor İçeriği
> Bölüm 5.1'deki alanlardan hangilerini istiyorsun? Eklemek/çıkarmak istediğin var mı?

### Karar 5 — Gönderim Zamanı
| Seçenek | Öneri |
|---|---|
| A — Ayın 1'i, 09:00 İstanbul | Hızlı |
| **B — Ayın 2'si, 09:00 İstanbul** | ⭐ Önerilen (sync tamponu) |
| C — Her 4 hafta | Takvimle uyumsuz |

### Karar 6 — Başarısız Teslim Limiti
| Seçenek | Öneri |
|---|---|
| **A — 3 deneme, sonra terk** | ⭐ Önerilen |
| B — 5 deneme | Daha dayanıklı ama yavaş |
| C — Sınırsız | ❌ Kaynak israfı |

### Karar 7 — Maliyet Bütçesi
> Aylık e-posta harcaması için üst limit nedir? (Başlangıç önerisi: $0 — ücretsiz tier yeter)

---

## 14. Sonraki Adımlar

1. ✅ Bu belge oluşturuldu
2. ⏳ Ürün sahibi 7 kararı onaylar
3. ⏳ Uygulama WP'si (WP-6X) planlanır ve kuyruğa alınır
4. ⏳ WP-66 retention kararları ile eşleştirme yapılır
5. ⏳ Implementasyon başlar

---

> **Kanıt etiketi:** `Ürün kararı gerekiyor` — tüm belge ürün sahibi kararlarına bağlıdır.
> **Son güncelleme:** 2026-07-14 · **Ajan:** Claude · **WP:** 65

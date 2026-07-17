# Gizlilik Politikası — Odak Kampı

**Sürüm:** 2026-07-17 · **Uygulama:** Odak Kampı (`com.manilmax.online_study_room`)  
**İşleyici:** Uygulama geliştiricisi (iletişim: uygulama içi “Geri bildirim” ve mağaza geliştirici e-postası)

Bu metin bilgilendirme amaçlıdır; avukat onaylı hukuki görüş yerine geçmez.

## 1. Topladığımız veriler

| Tür | Örnek | Amaç |
|---|---|---|
| Hesap | e-posta, kimlik doğrulama | Giriş, güvenlik |
| Profil | görünen ad, avatar, kamp hayvanı | Sosyal vitrin, sınıf |
| Çalışma | oturum süreleri, ders, hedefler | İstatistik, XP, grup |
| Sosyal | grup üyeliği, sohbet, dürtme | Birlikte çalışma |
| Destek | geri bildirim, ekler | Destek |
| Cihaz/tercih | dil, tema, bildirim, telemetri tercihi | Deneyim |
| Telemetri (isteğe bağlı) | çökme türü, senkron olay sayıları | Kalite (Sentry); e-posta/token gönderilmez |

## 2. İşleyiciler

- **Supabase** (AB/EU bölgesi tercihi): Auth, veritabanı, depolama, edge functions  
- **Sentry** (yalnız build’de açık ve kullanıcı telemetrisi açıkken): hata izleme  
- **GitHub Releases** (Play dışı sideload kanalları): güncelleme paketleri  

## 3. Saklama ve silme

Hesap silme isteği (uygulama içi) → **geri alma penceresi** → planlı kalıcı silme.  
Ayrıntılı takvim: `DATA-RETENTION-SCHEDULE.md`. Pipeline tamamlanana kadar metin “istek + geri alma + planlı silme” modelini tarif eder.

## 4. Çocuklar

Uygulama 13+ / genel kitle içindir; bilerek 13 yaş altı çocuklara yönelik değildir.

## 5. Haklarınız

Erişim, düzeltme, silme talebi, telemetri kapatma (Ayarlar → Gizlilik ve yasal).  
Talepler için uygulama içi geri bildirim veya mağaza iletişim kanalı.

## 6. Değişiklikler

Politika sürüm/tarihi güncellenir. Önemli değişikliklerde uygulama içi yasal merkezde yeni sürüm gösterilir.

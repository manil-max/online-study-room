# Şifre Sıfırlama — Supabase Panel Runbook (WP-287)

> **Durum (2026-07-25): staging otomatik olarak yapılandırıldı.** Elle panel adımı
> gerekmiyor; `.github/workflows/supabase-auth-config.yml` Management API ile yalnız
> `site_url` + `uri_allow_list` alanlarını yamalıyor (run 30164160511). Aşağıdaki panel
> adımları referans/production içindir.
>
> ⚠️ **Free tier sınırı:** varsayılan e-posta sağlayıcısını kullanan ücretsiz projelerde
> Supabase, kurtarma **e-posta şablonunun değiştirilmesini hem API'den hem panelden
> reddediyor** ("Email template modification is not available for free tier projects").
> Yani `{{ .Token }}` eklenemiyor → **Windows/masaüstündeki 6 haneli kod yolu, özel bir
> SMTP sağlayıcısı (veya ücretli plan) bağlanana kadar çalışmaz.** Android derin bağlantı
> yolu çalışır. Şablon adımı workflow'da otomatik denenir, bu hatada uyarıyla geçilir.
>
> Kod tarafı tamamlandı; aşağıdaki adımlar **Supabase panelinden** de yapılabilir.
> Kod bu adımlar olmadan da merge edilir ama **kullanıcı için düzelmiş olmaz.**
>
> `supabase config push` **kullanılmaz**: repodaki `supabase/config.toml` yerel
> geliştirmeye göre yazılmıştır (`site_url = http://127.0.0.1:3000`) ve uzak projeye
> basılırsa Site URL'i localhost'a çevirip redirect listesini siler.
>
> 🔴 **Bu WP yalnız STAGING panelini kapsar.** Production panel değişikliği ayrı bir
> ops/release kapısıdır ve somut GO ister (`.agents/AGENTS.md §2`, plan ADR-5 / K-6).

## Kök neden (kısa)

`resetPasswordForEmail` `redirectTo` olmadan çağrılıyordu → Supabase e-postadaki linki
projenin **Site URL**'ine (`localhost:3000`) yönlendiriyordu → tarayıcı "check your internet
connection" hatası veriyordu. Kod artık Android'de flavor'a uygun derin bağlantıyı geçiyor;
Windows/masaüstünde ise kullanıcı e-postadaki **6 haneli kodu** girerek sıfırlıyor.

## Yapılacaklar — STAGING projesi

Supabase Dashboard → ilgili **staging** projesi → **Authentication → URL Configuration**:

1. **Redirect URLs** listesine ekle (her flavor için ayrı scheme):
   - `com.manilmax.onlinestudyroom://login-callback` (stable/play)
   - `com.manilmax.onlinestudyroom.beta://login-callback` (beta)
   - `com.manilmax.onlinestudyroom.local://login-callback` (local geliştirme — opsiyonel)
   > ⚠️ Scheme, applicationId'nin aynısı **değildir** — alt çizgisizdir
   > (`onlinestudyroom`, `online_study_room` değil). `AndroidManifest.xml:64`'teki
   > `${authCallbackScheme}` placeholder'ı ile birebir aynıdır.

2. **Site URL** `localhost:3000` ise gerçek bir değere çek (ör. uygulamanın bir web
   karşılama sayfası veya en azından derin bağlantı scheme'lerinden biri).

3. **Authentication → Email Templates → Reset Password** şablonuna **`{{ .Token }}`**
   alanını ekle (Windows/kod yolu için — yoksa kullanıcıya 6 haneli kod hiç gitmez):
   ```
   Şifreni sıfırlamak için kodun: {{ .Token }}
   veya bu bağlantıya dokun: {{ .ConfirmationURL }}
   ```

## Güvenlik notları

- Redirect allowlist'e **yalnız** yukarıdaki uygulama scheme'leri eklenir; joker (`*`)
  veya üçüncü taraf domain **eklenmez** (open-redirect riski).
- Kod/e-posta var/yok bilgisi kullanıcıya sızdırılmaz: uygulama, hesap kayıtlı olsun
  olmasın aynı nötr mesajı gösterir (user-enumeration koruması).

## Kabul (cihazda doğrulanmalı — staging)

1. **Android:** Şifremi unuttum → e-posta → linke dokun → uygulama açılır →
   yeni şifre → yeni şifreyle giriş başarılı.
2. **Windows / yedek:** "Bunun yerine kodu gir" → e-postadaki 6 haneli kod + yeni şifre →
   giriş başarılı.
3. Kayıtlı olmayan e-postada da aynı nötr "gönderildi" mesajı görünür.

## Production (AYRI KAPI — bu WP'de yapılmaz)

Aynı üç adım production projesinde de gerekir; ancak bu bir **production auth
yapılandırması**dır ve `progress.md` Proje Gerçekleri'ndeki freeze/GO kuralına tabidir.
Ayrı ops/release turunda, somut kullanıcı GO ile uygulanır.

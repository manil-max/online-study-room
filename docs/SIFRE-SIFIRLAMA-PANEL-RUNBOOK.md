# Şifre Sıfırlama — Supabase Panel Runbook (WP-287)

> Kod tarafı tamamlandı; bu adımlar **sahip tarafından Supabase panelinden** yapılır.
> Kod bu adımlar olmadan da merge edilir ama **kullanıcı için düzelmiş olmaz.**
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

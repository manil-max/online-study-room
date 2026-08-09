import 'package:flutter/foundation.dart';

/// WP-616: e-postadaki şifre sıfırlama **bağlantısını açabilen** platform.
///
/// 🔴 Ölçülen gerçek (`docs/denetim/DENETIM-auth.md` KANAMA-1). Windows'ta
/// sıfırlamanın çalışan **hiçbir** ucu yoktu, ekran yine de "bağlantı e-postana
/// gönderildi" diyordu. Zincirin her halkası kapalı:
///
/// 1. `resolveRecoveryRedirect()` (`data/providers/auth_providers.dart`)
///    Android değilse `null` döner → `resetPasswordForEmail` `redirectTo`suz
///    gider → Supabase bağlantıyı proje **Site URL**'ine düşürür; o da
///    `com.manilmax.onlinestudyroom://login-callback`, yani **Android'e özel**
///    bir scheme. Windows'ta bu scheme'i kaydeden bir şey yok
///    (`app/windows/runner/main.cpp` + `app/lib/main.dart` argüman bile almaz).
/// 2. Yedek olan 6 haneli kod ekranı (`ResetWithCodeScreen`) çalışmıyor:
///    Supabase ücretsiz katmanı kurtarma e-posta şablonunun değiştirilmesini
///    reddediyor, şablona `{{ .Token }}` eklenemiyor, yani kullanıcıya kod hiç
///    gitmiyor (`docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md` free-tier notu,
///    `.github/workflows/supabase-auth-config.yml` bu hatayı uyarıyla geçiyor).
/// 3. Postayı telefonda açmak da kurtarmıyor: akış PKCE ve kod doğrulayıcı
///    isteği **başlatan** cihazda kalıyor; Windows'tan başlatılan sıfırlama
///    başka cihazda tamamlanamaz.
///
/// Bu yüzden masaüstünde e-posta **gönderilmez**: çalışmayan bir akışı
/// "gönderildi" diye sunmak, hiç sunmamaktan kötüdür. Kullanıcıya gerçekten
/// çalışan yol (telefondaki uygulamadan sıfırlama) söylenir.
///
/// Özel SMTP (veya ücretli plan) bağlanıp şablona `{{ .Token }}` eklenirse
/// masaüstü kod yolu geri açılır; o gün burası da `kResetWithCodeEnabled` ile
/// birlikte gözden geçirilir.
///
/// [platform] verilmezse `defaultTargetPlatform` okunur; testler bunu
/// `debugDefaultTargetPlatformOverride` ile enjekte eder (gerçek platforma
/// bağlı test yazılmaz).
bool passwordResetLinkOpensHere({TargetPlatform? platform, bool isWeb = kIsWeb}) {
  if (isWeb) return false;
  return (platform ?? defaultTargetPlatform) == TargetPlatform.android;
}

import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';
import '../../l10n/app_localizations.dart';

/// 🔴 WP-834 — şifre yazan üç ekranın **ortak** hata sözlüğü ve kural metni.
///
/// Sahip v85'te (gerçek cihaz, production) sıfırlama bağlantısından gelip yeni
/// şifresini yazdı ve "Beklenmeyen bir hata oluştu." gördü; **tek harf**
/// değiştirince aynı şifre kabul edildi. Yani sunucu somut bir sebep söyledi,
/// arayüz onu yuttu ve kullanıcıya neyi düzelteceğini söylemedi.
///
/// Sebep üç ekranda birden vardı ve üçü de **farklı** davranıyordu:
/// `recovery_screen.dart` dört kodu tanıyordu, `reset_with_code_screen.dart`
/// depo katmanının ham mesajını basıyordu, ayarlardaki şifre değiştirme
/// diyaloğu ise kendi beşli listesini taşıyordu. Aynı sunucu reddi ekrandan
/// ekrana başka cümle veriyordu. Eşleme bu yüzden tek yerde.
///
/// WP-539 sözleşmesi korunur: **depo kod atar, ekran cümleyi kurar.** Burada
/// Türkçe cümle yoktur, yalnız katalog anahtarı seçilir.
String passwordErrorMessage(
  AppLocalizations l10n,
  Object error, {
  /// Kurtarma akışında (sıfırlama bağlantısı / e-posta kodu) oturumun düşmesi
  /// "bağlantının süresi doldu" demektir ve çözümü yeni e-posta istemektir.
  /// Ayarlar ekranında aynı kod "yeniden giriş yap" demektir. Tek fark budur;
  /// bu yüzden ayrı bir fonksiyon değil tek bayrak.
  bool recovery = false,
}) {
  if (error is! AuthException) return l10n.authBeklenmeyenBirHataOlustu;
  return switch (error.code) {
    AuthErrorCode.weakPasswordLength => l10n.authSifreCokKisa,
    AuthErrorCode.weakPasswordCharacters =>
      l10n.authSifreKarakterCesidiYetersiz,
    AuthErrorCode.weakPasswordPwned => l10n.authSifreVeriSizintisindaGorulmus,
    AuthErrorCode.weakPassword => l10n.authSifreEnAz6SifreEnAz6KarakterOlmal,
    AuthErrorCode.samePassword => l10n.authYeniSifrenEskisiyleAyniOlamaz,
    AuthErrorCode.invalidCurrentPassword ||
    AuthErrorCode.invalidCredentials => l10n.profileMevcutSifreHatali,
    AuthErrorCode.otpExpired => l10n.authKodGecersizVeyaSuresiDolmus,
    AuthErrorCode.noSession => recovery
        ? l10n.authSifirlamaBaglantisiGecersiz
        : l10n.profileOturumBulunamadiGirisYap,
    AuthErrorCode.rateLimited => l10n.profileCokFazlaDeneme,
    // WP-536: ağ hatası şifre hakkında hüküm vermez.
    AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
    _ => l10n.authBeklenmeyenBirHataOlustu,
  };
}

/// Üç ekranda da aynı anahtar: test "kural satırı hatadan **önce** görünüyor
/// mu" sorusunu tek bir bulucuyla sorabilsin.
const Key passwordRulesKey = Key('passwordRulesText');

/// WP-834: yeni şifre alanının altındaki **kalıcı** kural satırı.
///
/// Kalıcı olması kabul kriteridir: kural yalnız hatadan sonra görünürse
/// kullanıcı önce reddedilmek zorunda kalır. Metin sunucunun gerçekten
/// dayattığı kuralı söyler (`supabase/config.toml` → `minimum_password_length
/// = 6`; "eskisiyle aynı olamaz" `same_password` reddidir).
class PasswordRulesText extends StatelessWidget {
  const PasswordRulesText() : super(key: passwordRulesKey);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        AppLocalizations.of(context).authSifreKurallari,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

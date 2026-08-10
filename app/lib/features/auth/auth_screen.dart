import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/validation/name_limits.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/app_localizations.dart';
import '../support/faq_screen.dart';
import 'entry_desktop_layout.dart';
import 'password_reset_platform.dart';
import 'reset_with_code_screen.dart';

/// 🔴 WP-539: e-postadaki 6 haneli kod yolu **derleme zamanı kapalıdır**.
///
/// Neden: `docs/SIFRE-SIFIRLAMA-PANEL-RUNBOOK.md:9-14` — Supabase ücretsiz plan
/// kurtarma e-posta şablonunun değiştirilmesini reddediyor, yani şablona
/// `{{ .Token }}` eklenemiyor ve kullanıcıya **6 haneli kod hiç gitmiyor**.
/// Düğme yine de açıktı ve şu kapalı döngüyü üretiyordu: kod yok → ne girilse
/// "Kod geçersiz veya süresi dolmuş." → yeni kod iste → yine gelmiyor.
/// Kullanıcının şifre sıfırlamak için çıkışı kalmıyordu.
///
/// Aynı karar hesap ayarlarında zaten verilmişti
/// (`account_settings_screen.dart` `_sendPasswordReset` notu: "Kod alanı açmak
/// tam da bu WP'nin kapattığı ölü anahtar deseni olurdu"); giriş ekranı o
/// kararı uygulamamıştı.
///
/// Ekran **silinmedi**, erişilemez yapıldı: özel SMTP (veya ücretli plan)
/// bağlanıp şablona `{{ .Token }}` eklenince yol tek bayrakla geri açılır:
/// `--dart-define=RESET_WITH_CODE_ENABLED=true`.
const bool kResetWithCodeEnabled = bool.fromEnvironment(
  'RESET_WITH_CODE_ENABLED',
);

/// Giriş ve kayıt ekranı (e-posta + şifre). Tek ekranda iki mod arası geçiş yapılır.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  String? _error;
  String? _info;

  /// WP-587: hesap **var** ama e-postası doğrulanmamış.
  ///
  /// Bu duruma iki yoldan gelinir ve ikisi de aynı çıkmazdır: kayıt
  /// oturum döndürmedi (doğrulama bekleniyor) ya da giriş
  /// [AuthErrorCode.emailNotConfirmed] ile düştü. Yeniden gönder düğmesi
  /// **yalnız** burada çizilir; koşulsuz çizilirse kullanıcı hiç
  /// gelmeyecek bir postayı beklemeye davet edilmiş olur.
  bool _emailNotConfirmed = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
      _emailNotConfirmed = false;
    });

    final auth = ref.read(authRepositoryProvider);
    // WP-530: kayıt sonucunun onay metni. Hesap kurulduğu **her iki** uçta da
    // (oturum açıldı / e-posta doğrulaması bekleniyor) doluyor; modal, istek
    // bittikten sonra gösterilir.
    String? accountCreated;
    var signedIn = false;
    try {
      if (_isRegister) {
        await auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
        accountCreated = l10n.authHesabinHazir;
        signedIn = true;
      } else {
        await auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
        signedIn = true;
      }
    } on AuthException catch (e) {
      final verifiedEmailNotice = e.message.contains('e-postana gönderilen');
      // Hesap **oluştu**, yalnız doğrulama bekliyor. Eskiden tek satırlık bir
      // bilgi yazıp modu sessizce giriş'e çeviriyorduk; sahibin gördüğü "bir
      // anda sign in kısmına atıyor" davranışı buydu.
      if (verifiedEmailNotice) {
        accountCreated = l10n.authEpostaDogrulamaGonderildi;
      }
      setState(() {
        // WP-587: iki uç da aynı gerçeği anlatır — hesap oluştu, e-posta
        // doğrulanmadı. Kayıt ucu kodsuz gelir (depo cümleyi taşır),
        // giriş ucu kodla gelir; ikisini de tek duruma indiriyoruz.
        _emailNotConfirmed =
            verifiedEmailNotice || e.code == AuthErrorCode.emailNotConfirmed;
        if (verifiedEmailNotice) {
          _info = l10n.commonEpostaDogrulamasiGerekiyor;
          _isRegister = false;
          _passwordController.clear();
        } else {
          _error = _localizedAuthError(l10n, e);
        }
      });
    } catch (e) {
      setState(() => _error = l10n.authBeklenmeyenBirHataOlustu);
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (accountCreated != null && mounted) {
      await _showAccountCreatedDialog(l10n, accountCreated);
    }
    // Başarılıysa AuthGate otomatik olarak ana uygulamaya geçer.
    if (signedIn && mounted) ref.invalidate(authStateProvider);
  }

  /// WP-530: kayıt sonucunun **kaçırılamaz** onayı.
  ///
  /// Satır içi `_info` metni yetmiyordu: doğrulama gerekmeyen kurulumda ekran
  /// zaten değişiyor, gerekende ise mod giriş'e dönüyor ve kullanıcı hesabının
  /// oluşup oluşmadığını anlayamıyordu.
  Future<void> _showAccountCreatedDialog(
    AppLocalizations l10n,
    String message,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        key: const Key('signup-confirmation'),
        icon: const Icon(Icons.check_circle_outline),
        title: Text(l10n.authHesabinOlusturuldu),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.authDevam),
          ),
        ],
      ),
    );
  }

  /// WP-587: doğrulama e-postası gelmediyse kullanıcının tek çıkışı.
  ///
  /// [_emailNotConfirmed] burada **sıfırlanmaz**: hız sınırına takılınca
  /// düğme kaybolsaydı kullanıcı yine çıkışsız kalırdı.
  Future<void> _resendVerificationEmail() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .resendVerificationEmail(_emailController.text);
      setState(() => _info = l10n.authDogrulamaPostasiYenidenGonderildi);
    } on AuthException catch (e) {
      setState(() => _error = _localizedAuthError(l10n, e));
    } catch (_) {
      setState(() => _error = l10n.authBeklenmeyenBirHataOlustu);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// WP-616: masaüstünde sıfırlamanın **çalışan ucu yok** — o yüzden
  /// çalışıyormuş gibi davranmıyoruz.
  ///
  /// 🔴 Eskiden buradaki tek dal her platformda `sendPasswordResetEmail`
  /// çağırıp "Şifre sıfırlama bağlantısı e-postana gönderildi." yazıyordu.
  /// Windows'ta o bağlantı Android'e özel bir scheme'e çıkıyor ve açılmıyor;
  /// yedek kod ekranı da ücretsiz katmanda kapalı (gerekçe:
  /// `password_reset_platform.dart`). Sonuç: kullanıcı hesabını kaybediyor,
  /// ekran ona "gönderildi" diyordu. Artık masaüstünde e-posta gönderilmez,
  /// kullanıcıya **gerçekten çalışan yol** söylenir.
  Future<void> _showDesktopResetUnavailable(AppLocalizations l10n) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('auth-reset-desktop-unavailable'),
        icon: const Icon(Icons.phonelink_erase_outlined),
        title: Text(l10n.authSifirlamaMasaustundeCalismiyorBaslik),
        content: SingleChildScrollView(
          child: Text(
            l10n.authSifirlamaMasaustundeCalismiyorGovde,
            key: const Key('auth-reset-desktop-body'),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.authAnladim),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    // 🔴 WP-616: gönderimden ÖNCE. Masaüstünde istek sunucuya hiç gitmez;
    // gitseydi kullanıcı açılamayan bir bağlantı bekleyecekti.
    if (!passwordResetLinkOpensHere()) {
      setState(() {
        _error = null;
        _info = null;
        _emailNotConfirmed = false;
      });
      await _showDesktopResetUnavailable(l10n);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      setState(() {
        _info = l10n.authSifreSifirlamaBaglantisiEpostana;
      });
      // 🔴 WP-539: burada da `_localizedAuthError` çağrılıyor ama eskiden yalnız
      // dört Türkçe alt dize tanındığı için hız sınırı ("Çok sık denedin…")
      // generic'e düşüyordu — kullanıcı biraz bekleyip yeniden denemesi
      // gerektiğini öğrenemiyordu.
    } on AuthException catch (e) {
      setState(() => _error = _localizedAuthError(l10n, e));
    } catch (_) {
      setState(() => _error = l10n.authBeklenmeyenBirHataOlustu);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    // 🔴 WP-680 / SPEC §3 A3 uyarisi + §7 — ekran IKI bagimsiz blok tasir.
    //
    // OLCUM (bu WP'nin testi, `devicePixelRatio = 1`): 1920 px pencerede form
    // sutunu **380 px** boyaniyordu, yani pencerenin %20'si; 2560 px'te yine
    // 380 px. Kalan her sey bos zemindi ve kullanicinin ILK gordugu ekran
    // buydu. Kusur "form dar" degil, **ikinci blogun yok sayilmasi**: kimlik
    // bloku (ikon + uygulama adi + mod alt basligi) formun tepesine
    // yigilmisti, oysa masaustunde kendi panosuna sigar.
    //
    // Asagida blok **tasinir**, uretilmez: [brand] ve [fields] listelerinin
    // icerigi WP-680 oncesiyle BIREBIR aynidir, mobil dal ikisini eskisi gibi
    // tek sutunda arka arkaya dizer (SPEC §7: islev degismez, mobil dal
    // degismez).
    final brand = <Widget>[
      Icon(
        Icons.groups,
        size: 64,
        color: theme.colorScheme.primary,
      ),
      const SizedBox(height: 16),
      Text(
        l10n.commonOdakKampi,
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall,
      ),
      const SizedBox(height: 4),
      Text(
        _isRegister
            ? l10n.authYeniHesapOlustur
            : l10n.authHesabnaGirisYap,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ];

    final fields = <Widget>[
      if (_isRegister) ...[
        TextFormField(
          controller: _nameController,
          textInputAction: TextInputAction.next,
          // WP-517: sunucu karşılığı `0122_name_length_limits.sql`.
          maxLength: kDisplayNameMaxLength,
          decoration: InputDecoration(
            labelText: l10n.authGorunenAd,
            prefixIcon: const Icon(Icons.person_outline),
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.authGorunenAdGirin
              : null,
        ),
        const SizedBox(height: 12),
      ],
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: l10n.authEposta,
          prefixIcon: const Icon(Icons.mail_outline),
        ),
        validator: (v) => (v == null || !v.contains('@'))
            ? l10n.authGecerliBirEpostaGirin
            : null,
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _passwordController,
        obscureText: true,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.authSifre,
          prefixIcon: const Icon(Icons.lock_outline),
        ),
        validator: (v) => (v == null || v.length < 6)
            ? l10n.authSifreEnAz6
            : null,
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: TextStyle(color: theme.colorScheme.error),
        ),
      ],
      if (_info != null) ...[
        const SizedBox(height: 12),
        Text(
          _info!,
          style: TextStyle(color: theme.colorScheme.primary),
        ),
      ],
      // 🔴 WP-587: kayıt doğrulama postası gelmediğinde
      // kullanıcının çıkışı YOKTU. Ne yapacağını söyleyen
      // satır ve yeniden gönderme düğmesi yalnız bu durumda
      // çizilir.
      if (_emailNotConfirmed) ...[
        const SizedBox(height: 12),
        Text(
          l10n.authDogrulamaPostasiGelenKutusuSpam,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton.icon(
          key: const Key('auth-resend-verification'),
          onPressed: _loading ? null : _resendVerificationEmail,
          icon: const Icon(Icons.forward_to_inbox_outlined),
          label: Text(l10n.authDogrulamaPostasiniYenidenGonder),
        ),
      ],
      const SizedBox(height: 20),
      FilledButton(
        onPressed: _loading ? null : _submit,
        child: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                _isRegister ? l10n.authKaytOl : l10n.authGirisYap,
              ),
      ),
      const SizedBox(height: 8),
      if (!_isRegister) ...[
        TextButton.icon(
          onPressed: _loading ? null : _sendPasswordReset,
          icon: const Icon(Icons.mark_email_read_outlined),
          label: Text(l10n.authSifremiUnuttum),
        ),
        // 🔴 WP-539: `kResetWithCodeEnabled` false olduğu sürece
        // bu düğme **hiç çizilmez** (bayrağın gerekçesi dosyanın
        // başında). Ekranın kendisi silinmedi; SMTP bağlanınca
        // `--dart-define=RESET_WITH_CODE_ENABLED=true` ile geri
        // açılır. Kullanıcının çalışan yolu üstteki "Şifremi
        // unuttum" — e-postadaki **bağlantı**.
        if (kResetWithCodeEnabled)
          TextButton.icon(
            key: const Key('auth-reset-with-code'),
            onPressed: _loading
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ResetWithCodeScreen(
                        initialEmail: _emailController.text
                            .trim(),
                      ),
                    ),
                  ),
            icon: const Icon(Icons.password_outlined),
            label: Text(l10n.authKoduGir),
          ),
      ],
      TextButton(
        onPressed: _loading
            ? null
            : () => setState(() {
                _isRegister = !_isRegister;
                _error = null;
                _info = null;
                _emailNotConfirmed = false;
              }),
        child: Text(
          _isRegister
              ? l10n.authZatenHesabinVarMi
              : l10n.authHesabinYokMuKayit,
        ),
      ),
      // WP-422: SSS bağlantısı kayıt geçişinin **altında, en
      // sonda** durur. Eskiden üç yardımcı bağlantının başındaydı
      // ve yalnız giriş modunda çıkıyordu; kayıt olmaya çalışan
      // kullanıcı yardıma hiç ulaşamıyordu. Oturum açmadan SSS
      // erişimi v55 kazanımıdır, iki modda da korunur.
      TextButton.icon(
        key: const Key('auth-faq-link'),
        onPressed: _loading
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FaqScreen(),
                ),
              ),
        icon: const Icon(Icons.help_outline),
        label: Text(l10n.faqLoginLink),
      ),
    ];

    if (entryUsesDesktopSplit(context)) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: EntryDesktopSplit(
                hero: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: brand,
                ),
                // Form yalniz ALANLARI sarar; kimlik blogunda dogrulanacak
                // hicbir alan yok, dolayisiyla `_formKey.currentState.validate`
                // ayni kumeyi dogrular.
                form: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: fields,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...brand,
                    const SizedBox(height: 24),
                    ...fields,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Hatanın **nedenini** kullanıcı metnine çevirir.
  ///
  /// 🔴 WP-539: eskiden burası `message.contains('…')` üçlemesiydi ve yalnız
  /// dört Türkçe alt dizeyi tanıyordu; tanımadığı her şey "Beklenmeyen bir hata
  /// oluştu."ya düşüyordu. Ölçülen sonuç: depo doğru cümleyi
  /// ("E-posta doğrulaması gerekiyor.") üretiyor, ekran generic gösteriyordu.
  /// Alt dize eşleştirmesi ayrıca ağ hatasını ve hız sınırını da yutuyordu.
  /// Artık eşleme [AuthErrorCode] üzerinden yapılır: depo nedeni **kodla**
  /// taşır, metni ekran katalogdan üretir.
  String _localizedAuthError(AppLocalizations l10n, AuthException error) {
    return switch (error.code) {
      AuthErrorCode.emailNotConfirmed => l10n.commonEpostaDogrulamasiGerekiyor,
      AuthErrorCode.invalidCredentials => l10n.commonEpostaVeyaSifreHatali,
      AuthErrorCode.emailAlreadyInUse => l10n.commonBuEpostaZatenKayitli,
      AuthErrorCode.invalidEmail => l10n.authGecerliBirEpostaGirin,
      AuthErrorCode.weakPassword => l10n.authSifreEnAz6,
      AuthErrorCode.rateLimited => l10n.profileCokFazlaDeneme,
      AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
      _ => l10n.authBeklenmeyenBirHataOlustu,
    };
  }
}

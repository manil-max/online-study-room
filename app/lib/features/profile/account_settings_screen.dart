import 'dart:async';

import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/safe_screen_padding.dart';
import '../../data/models/account_deletion_status.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth/password_reset_platform.dart';
// WP-679: ortak masaustu olculeri (`ProfileDesktopBody`) Ayarlar'da durur.
import 'settings_screen.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isLoading = false;

  /// Silme durumu sorgusu **bir kez** kurulur.
  ///
  /// 🔴 WP-539: `FutureBuilder`ın `future:`ı doğrudan `build` içinde
  /// çağrılıyordu; ekranın her yeniden çiziminde (snackbar, `setState`, auth
  /// akışı tiki) yeni bir RPC açılıyor ve gösterge sıfırdan yükleniyordu.
  late Future<AccountDeletionStatus> _deletionStatus;

  @override
  void initState() {
    super.initState();
    _deletionStatus = _queryDeletionStatus();
  }

  /// Durum gerçekten değiştiğinde (istek/iptal) veya kullanıcı yeniden
  /// denediğinde sorguyu tazeler.
  void _refreshDeletionStatus() {
    // Gövde bloklu: `=>` biçimi atama ifadesinin değerini (bir `Future`)
    // döndürür ve `setState` bunu "async callback" sanıp assert atar.
    setState(() {
      _deletionStatus = _queryDeletionStatus();
    });
  }

  Future<AccountDeletionStatus> _queryDeletionStatus() {
    final query = ref.read(authRepositoryProvider).fetchAccountDeletionStatus();
    // `FutureBuilder` bu Future'a ancak **bir sonraki çizimde** abone olur.
    // Sorgu o ana kadar hatayla biterse Dart onu "işlenmemiş" sayar ve hata
    // yakalanabilir bir UI durumu yerine zone hatası olarak patlar — yani tam
    // da görünür kılmaya çalıştığımız durum ekranı düşürür. Buradaki dinleyici
    // hatayı yalnız **işlenmiş** işaretler; Future tamamlandıktan sonra abone
    // olan `FutureBuilder` aynı hatayı yine görür.
    unawaited(query.then((_) {}, onError: (Object _, StackTrace _) {}));
    return query;
  }

  Future<void> _changeEmail() async {
    final outcome = await showDialog<EmailChangeOutcome>(
      context: context,
      builder: (_) => const _ChangeEmailDialog(),
    );
    if (!mounted || outcome == null) return;
    if (outcome == EmailChangeOutcome.confirmed) {
      setState(() {});
    }

    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          outcome == EmailChangeOutcome.verificationPending
              ? l10n.profileEpostaDogrulamaBekliyor
              : l10n.profileEpostaDegistirildi,
        ),
        duration: outcome == EmailChangeOutcome.verificationPending
            ? const Duration(seconds: 10)
            : const Duration(seconds: 4),
      ),
    );
  }

  /// WP-319: şifre değiştirme.
  ///
  /// 🔴 **Önceki hâli ölü anahtardı:** diyalog yalnız "yeni şifre" soruyor,
  /// doğrudan `updatePassword` çağırıyordu — Supabase `updateUser(password:)`
  /// eski şifreyi **doğrulamaz**. Yani açık bırakılmış bir oturumu eline geçiren
  /// biri şifreyi tek ekranda değiştirebiliyordu. Artık doğrulama repository
  /// sözleşmesinde ([AuthRepository.changePassword]); bu ekran onu atlayamaz.
  Future<void> _changePassword() async {
    final outcome = await showDialog<_PasswordDialogOutcome>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (!mounted || outcome == null) return;

    if (outcome == _PasswordDialogOutcome.forgot) {
      await _sendPasswordReset();
      return;
    }

    // WP-319-G: "şifre güncellendi" tek başına eksik bir cümle — kullanıcının
    // asıl sorduğu şey diğer cihazların hâlâ içeride olup olmadığı. İptal
    // başarısızsa bunu **söylüyoruz**; sessizce başarı göstermek, şifre
    // değiştirmenin koruduğu izlenimini verir ki tam da bu WP'nin kapattığı
    // yanlış güvence desenidir.
    final l10n = AppLocalizations.of(context);
    final kept = outcome == _PasswordDialogOutcome.changedOtherSessionsKept;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kept
              ? l10n.profileDigerCihazlarKapatilamadi
              : l10n.profileDigerCihazlarKapatildi,
        ),
        duration: kept
            ? const Duration(seconds: 8)
            : const Duration(seconds: 4),
        backgroundColor: kept ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  /// "Şifremi unuttum" — oturumdaki adrese sıfırlama e-postası gönderir.
  ///
  /// Bilerek **kod girme ekranına yönlendirmiyor**: Supabase free tier
  /// varsayılan e-posta sağlayıcısıyla kurtarma şablonunu kilitliyor, şablona
  /// `{{ .Token }}` eklenemiyor, yani e-postada 6 haneli kod **yok**. Kod alanı
  /// açmak tam da bu WP'nin kapattığı ölü anahtar deseni olurdu. Özel SMTP
  /// bağlanınca buraya kod yolu eklenebilir.
  Future<void> _sendPasswordReset() async {
    final l10n = AppLocalizations.of(context);

    // 🔴 WP-620: gönderimden **önce**. WP-616 giriş ekranındaki aynı düğmeyi
    // kapattı ama oturum **içindeki** "Şifremi unuttum" kolu açık kaldı:
    // Windows'ta e-posta gidiyor, ekran "gönderildi" diyor, kullanıcı gelen
    // bağlantıyı bu bilgisayarda açamıyor (bkz. [passwordResetLinkOpensHere]
    // dokümantasyonu — scheme kayıtlı değil, kod yolu free tier'da kapalı,
    // PKCE doğrulayıcısı başlatan cihazda kalıyor). Karar WP-616'nındır;
    // burada yalnız **kullanılır**, yeniden üretilmez.
    if (!passwordResetLinkOpensHere()) {
      await _showDesktopResetUnavailable(l10n);
      return;
    }

    final email = ref.read(authRepositoryProvider).currentUserEmail;
    if (email == null || email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profileOturumBulunamadiGirisYap),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.profileSifreSifirlamaGonderildi)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is AuthException && e.code == AuthErrorCode.rateLimited
                  ? l10n.profileCokFazlaDeneme
                  : l10n.profileBeklenmeyenBirHataOlustu,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Masaüstünde sıfırlamanın neden çalışmadığını ve **çalışan yolu** anlatır.
  /// Metin WP-616 kataloğundan gelir; burada ikinci bir sürüm yazılmaz.
  Future<void> _showDesktopResetUnavailable(AppLocalizations l10n) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('account-reset-desktop-unavailable'),
        icon: const Icon(Icons.phonelink_erase_outlined),
        title: Text(l10n.authSifirlamaMasaustundeCalismiyorBaslik),
        content: SingleChildScrollView(
          child: Text(
            l10n.authSifirlamaMasaustundeCalismiyorGovde,
            key: const Key('account-reset-desktop-body'),
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

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).profileGuvenliCikis),
          content: Text(
            AppLocalizations.of(
              context,
            ).profileHesabinizdanCikisYapmakIstediginize,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context).profileIptal),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(AppLocalizations.of(context).profileCikisYap),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final l10n = AppLocalizations.of(context);
    // Snackbar'ı ekrandan **önce** yakala: `popUntil` bu ekranı ağaçtan
    // düşürünce `context` ölür ve mesaj hiç görünmez.
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isLoading = true);
    // 🔴 WP-620: burası eskiden hatayı "çıkış yapılamadı" diye gösteriyor ve
    // kullanıcıyı ekranda tutuyordu. Oysa gotrue **önce** yerel oturumu siler,
    // **sonra** sunucuya haber verir; ağ o ikinci adımda düşerse kullanıcı
    // çoktan çıkmıştır. Ekranda kalmak "hâlâ içerideyim" yanılgısı veriyor,
    // kullanıcı tekrar tekrar basıyor ve hiçbiri "başarılı" olmuyordu.
    //
    // Doğrusu: çıkışı **olmuş say** (yereldeki oturum gitti), ama sessizce
    // "her şey yolunda" da deme — kapatılamayan şey diğer cihazlardaki
    // oturumdur ve kullanıcı bunu bilmeli.
    var serverNotified = true;
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (_) {
      serverNotified = false;
    }

    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (!serverNotified) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.profileCikisYapildiSunucuyaUlasilamadi),
          duration: const Duration(seconds: 8),
        ),
      );
    }
    if (mounted) setState(() => _isLoading = false);
  }

  /// WP-114: silme isteği — şifre yeniden doğrulama + 14 gün grace (sunucu).
  ///
  /// 🔴 WP-294: bu ekran eskiden `languageCode == 'tr'` üçlemesiyle elle iki dil
  /// tutuyordu; katalogu tamamen atlıyordu, yani **DE/AR kullanıcısı İngilizce
  /// görüyordu**. Artık tüm metinler `AppLocalizations` üzerinden geliyor.
  Future<void> _requestAccountDeletion() async {
    final l10n = AppLocalizations.of(context);
    // 🔴 WP-539: şifre alanının denetleyicisi **burada** kuruluyor ve diyalog
    // kapanır kapanmaz `dispose()` ediliyordu. Kapanma animasyonu sürerken
    // widget bir kez daha çiziliyor, bu da "A TextEditingController was used
    // after being disposed" istisnasını atıyordu; istisna asenkron akışı
    // kesiyor ve hata snackbar'ı **hiç görünmüyordu**. Denetleyici artık
    // diyalogun kendi `State`'inde yaşıyor ve orada dispose ediliyor.
    final password = await showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (password == null || !mounted) return;

    final email = ref.read(authRepositoryProvider).currentUserEmail;
    if (email == null) return;

    setState(() => _isLoading = true);
    try {
      // Yeniden doğrulama: aynı e-posta + şifre ile sign-in denemesi.
      await ref
          .read(authRepositoryProvider)
          .signIn(email: email, password: password);
      final status = await ref
          .read(authRepositoryProvider)
          .requestAccountDeletion();
      if (!mounted) return;
      final until = status.purgeAfter?.toLocal().toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.accountSilmePlanlandiTarih(until))),
      );
      _refreshDeletionStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // 🔴 WP-539: burası tek bir `catch (e)` idi ve **her** sebep
            // "Beklenmeyen bir hata oluştu."ya düşüyordu — yanlış şifre dahil.
            // Aynı ekranın şifre/e-posta diyalogları zaten koda göre eşliyordu;
            // silme yolu o eşlemenin dışında kalmıştı. Ham `e.toString()` yine
            // gösterilmiyor: yerelleştirilemez ve sunucu metnini sızdırır
            // (WP-294).
            content: Text(_deletionErrorFor(l10n, e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Silme yolundaki hatanın nedenini kullanıcı metnine çevirir.
  String _deletionErrorFor(AppLocalizations l10n, Object error) {
    if (error is! AuthException) return l10n.profileBeklenmeyenBirHataOlustu;
    return switch (error.code) {
      // Giriş denemesi başarısız: kullanıcı **kendi** şifresini yazıyor, bu
      // yüzden mesaj "e-posta veya şifre" değil doğrudan şifre hakkındadır.
      AuthErrorCode.invalidCredentials => l10n.profileMevcutSifreHatali,
      AuthErrorCode.invalidCurrentPassword => l10n.profileMevcutSifreHatali,
      AuthErrorCode.rateLimited => l10n.profileCokFazlaDeneme,
      AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
      AuthErrorCode.noSession => l10n.profileOturumBulunamadiGirisYap,
      _ => l10n.profileBeklenmeyenBirHataOlustu,
    };
  }

  /// İptal yolundaki hatayı kullanıcı cümlesine çevirir.
  ///
  /// 🔴 WP-620: burada tek bir "Beklenmeyen bir hata oluştu." vardı. Oysa
  /// sunucunun **en olası** cevabı bu değil: `cancel_account_deletion`
  /// (`supabase/migrations/0037_account_deletion_core.sql`) bekleyen istek
  /// yoksa `no_active_request`, 14 günlük pencere dolmuşsa `too_late`
  /// fırlatır. İkisi de kullanıcıya bambaşka şey söyler ve ikisi de
  /// "beklenmeyen" değildir.
  ///
  /// Depo katmanı bu iki neden için henüz [AuthErrorCode] taşımıyor ve o
  /// katman bu WP'nin dışında; bu yüzden önce kod, kod yoksa sunucu etiketi
  /// okunur. Depo bir gün kod eklerse bu dal kendiliğinden ona geçer.
  String _cancelDeletionErrorFor(AppLocalizations l10n, Object error) {
    if (error is! AuthException) return l10n.authBeklenmeyenBirHataOlustu;
    final code = error.code ?? '';
    final message = error.message.toLowerCase();
    bool says(String marker) => code == marker || message.contains(marker);

    // Yalnız sunucunun **makine** etiketine bakılır; Türkçe mesaj metnine
    // `contains` uygulamak bu deponun tekrar eden kırılganlığıdır (WP-319).
    if (says('no_active_request')) return l10n.accountSilmeBekleyenIstekYok;
    if (says('too_late')) return l10n.accountSilmeIptalPenceresiKapandi;
    return switch (error.code) {
      AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
      AuthErrorCode.noSession => l10n.profileOturumBulunamadiGirisYap,
      _ => l10n.authBeklenmeyenBirHataOlustu,
    };
  }

  Future<void> _cancelAccountDeletion() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).cancelAccountDeletion();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.accountSilmeIptalEdildi)));
        _refreshDeletionStatus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_cancelDeletionErrorFor(l10n, e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Üçüncü hâl: silme durumu **okunamadı**.
  ///
  /// 🔴 WP-620: eskiden bu hâl "aktif" sayılıyordu
  /// (`final active = failed || snap.data?.active == true;`). Sonucu iki
  /// yönlü zarardı: (a) silmeyi hiç istememiş kullanıcı, ağ kötüyken Hesabım'a
  /// girdiğinde kırmızı "Silme planlandı — iptal et" kartını görüp paniğe
  /// kapılıyor, dokununca da sunucudan `no_active_request` yiyordu;
  /// (b) gerçekten silmek isteyen kullanıcı ise "Hesabı sil" düğmesine hiç
  /// ulaşamıyordu. Bilinmeyen bir durumu iki hâlden birine yuvarlamak yerine
  /// **bilinmediğini söylüyoruz** ve her iki kapıyı da açık bırakıyoruz.
  Widget _deletionStatusUnknownCard(ThemeData theme, AppLocalizations l10n) {
    return Card(
      key: const Key('accountDeletionStatusUnknown'),
      elevation: 0,
      // Kırmızı **değil**: kırmızı "hesabın gidiyor" demektir, oysa burada
      // bilinen tek şey durumun bilinmediğidir.
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(
              Icons.help_outline,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(l10n.accountSilmeDurumuOkunamadiBaslik),
            subtitle: Text(l10n.accountSilmeDurumuOkunamadi),
            trailing: IconButton(
              key: const Key('accountDeletionStatusRetry'),
              icon: const Icon(Icons.refresh),
              tooltip: l10n.authTekrarDene,
              onPressed: _refreshDeletionStatus,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              children: [
                TextButton(
                  key: const Key('accountDeletionCancelPending'),
                  onPressed: _cancelAccountDeletion,
                  child: Text(l10n.accountBekleyenSilmeyiIptalEt),
                ),
                TextButton(
                  key: const Key('accountDeletionRequestAnyway'),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: _requestAccountDeletion,
                  child: Text(l10n.accountHesabiSil),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // E-posta doğrulama bağlantısı uygulamaya döndüğünde Supabase
    // `userUpdated` yayar. Repository nesnesi değişmez; auth akışını izlemek,
    // confirmed durumda görünen adresin restart beklemeden yenilenmesini sağlar.
    ref.watch(authStateProvider);
    final email = ref.watch(authRepositoryProvider).currentUserEmail;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).profileHesabim)),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView(
              padding: getSafePadding(
                context,
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              ),
              children: [
                // 🔴 WP-679 — bu ekranin hicbir genislik siniri YOKTU. Olcum
                // (2026-08-10, `WP679 | HESABIM`): kart 1920 px pencerede
                // **1888 px**, 2560 px'te **2528 px** cizildi; icindeki en
                // uzun metin bir e-posta adresi. SPEC §2.3 form/ayar sutunu
                // tavani 760. Hesap silme, sifre/e-posta degistirme ve guvenli
                // cikis akislarinin HICBIRI degismedi — yalniz kap daraldi.
                ProfileDesktopBody.form(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppLocalizations.of(context).profileHesapBilgileri,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.4),
                        child: Column(
                          children: [
                            ListTile(
                              leading: Icon(Icons.email_outlined),
                              title: Text(
                                AppLocalizations.of(
                                  context,
                                ).profileEpostaAdresi,
                              ),
                              subtitle: Text(
                                email ??
                                    AppLocalizations.of(
                                      context,
                                    ).profileBilinmiyor,
                              ),
                              trailing: TextButton(
                                onPressed: _changeEmail,
                                child: Text(
                                  AppLocalizations.of(context).profileDegistir,
                                ),
                              ),
                            ),
                            Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.lock_outline),
                              title: Text(
                                AppLocalizations.of(context).profileSifre,
                              ),
                              subtitle: Text('••••••••'),
                              trailing: TextButton(
                                onPressed: _changePassword,
                                child: Text(
                                  AppLocalizations.of(context).profileDegistir,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),
                      Text(
                        AppLocalizations.of(context).profileGuvenlik,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Card(
                        elevation: 0,
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.logout,
                            color: theme.colorScheme.error,
                          ),
                          title: Text(
                            AppLocalizations.of(context).profileGuvenliCikis,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          subtitle: Text(
                            AppLocalizations.of(
                              context,
                            ).profileCihazdakiOturumuSonlandir,
                            style: TextStyle(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.8,
                              ),
                            ),
                          ),
                          onTap: _signOut,
                        ),
                      ),
                      SizedBox(height: 12),
                      // WP-114: hesap silme
                      FutureBuilder(
                        future: _deletionStatus,
                        builder: (context, snap) {
                          final l10n = AppLocalizations.of(context);
                          // WP-539 `snap.hasError`ı görünür kıldı ama üç durumu
                          // ikiye sıkıştırdı: okunamayan durum "aktif" sayılıyordu.
                          // WP-620 üçüncü hâli ayırdı — ayrıntı ve ölçüm
                          // [_deletionStatusUnknownCard] belgesinde.
                          if (snap.hasError) {
                            return _deletionStatusUnknownCard(theme, l10n);
                          }
                          final active = snap.data?.active == true;
                          return Card(
                            elevation: 0,
                            color: theme.colorScheme.errorContainer.withValues(
                              alpha: 0.25,
                            ),
                            child: ListTile(
                              leading: Icon(
                                Icons.delete_forever,
                                color: theme.colorScheme.error,
                              ),
                              title: Text(
                                active
                                    ? l10n.accountSilmePlanlandiIptalEt
                                    : l10n.accountHesabiSil,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              subtitle: Text(
                                active
                                    ? l10n.accountSilmeSonTarih(
                                        '${snap.data?.purgeAfter?.toLocal()}',
                                      )
                                    : l10n.accountSilmeGeriAlmaPenceresi,
                              ),
                              onTap: active
                                  ? _cancelAccountDeletion
                                  : _requestAccountDeletion,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// WP-539: hesap silme onayı — şifre alanı **kendi** `State`'inde yaşar.
///
/// İki ayrı hatayı birden kapatır:
/// 1. 🔴 **Sessiz düğme.** Alanda hiç doğrulayıcı yoktu ve üst ekran boş şifreyi
///    `if (password.isEmpty) return;` ile yutuyordu: "Silmeyi planla"ya basmak
///    hiçbir şey yapmıyordu (ölçüm: `signInCalls=0 requestCalls=0 snackBar=0
///    dialog=0`). Artık form doğrulaması diyalogu **açık tutuyor** ve nedeni
///    yazıyor.
/// 2. 🔴 **Dispose edilmiş denetleyici.** Denetleyici üst ekranda kuruluyor ve
///    diyalog kapanma animasyonu sürerken senkron `dispose()` ediliyordu.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    Navigator.pop(context, _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.accountHesabiSil),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.accountSilmeOnayGovdesi),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('deleteAccountPassword'),
              controller: _passwordController,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: l10n.authSifre),
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.profileMevcutSifreniGir;
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.profileIptal),
        ),
        FilledButton(
          key: const Key('deleteAccountSubmit'),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: _submit,
          child: Text(l10n.accountSilmeyiPlanla),
        ),
      ],
    );
  }
}

/// WP-458: e-posta değişikliği mevcut şifreyi aynı güvenlik sınırında doğrular.
///
/// Hata diyaloğun içinde kalır; yanlış şifrede yeni adres silinmez. Supabase
/// doğrulama bekletiyorsa diyalog kapanır ve üst ekran pending durumunu açıkça
/// anlatır. Bağlantı/OTP mantığı burada taklit edilmez.
class _ChangeEmailDialog extends ConsumerStatefulWidget {
  const _ChangeEmailDialog();

  @override
  ConsumerState<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends ConsumerState<_ChangeEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newEmailController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }

  String _messageFor(AppLocalizations l10n, Object error) {
    if (error is! AuthException) return l10n.profileBeklenmeyenBirHataOlustu;
    return switch (error.code) {
      AuthErrorCode.invalidCurrentPassword => l10n.profileMevcutSifreHatali,
      AuthErrorCode.invalidEmail => l10n.profileGecerliBirEpostaGirin,
      AuthErrorCode.sameEmail => l10n.profileEpostaAyniOlamaz,
      AuthErrorCode.emailAlreadyInUse => l10n.profileEpostaKullanilamiyor,
      AuthErrorCode.rateLimited => l10n.profileCokFazlaDeneme,
      // WP-536: ag hatasi sifre hakkinda hukum vermez.
      AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
      AuthErrorCode.noSession => l10n.profileOturumBulunamadiGirisYap,
      _ => l10n.profileBeklenmeyenBirHataOlustu,
    };
  }

  Future<void> _submit() async {
    if (_busy || _formKey.currentState?.validate() != true) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .changeEmail(
            currentPassword: _currentPasswordController.text,
            newEmail: _newEmailController.text,
          );
      if (mounted) Navigator.pop(context, outcome);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFor(l10n, error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentEmail = ref.read(authRepositoryProvider).currentUserEmail;

    return AlertDialog(
      title: Text(l10n.profileEpostaDegistir),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.profileEpostaDogrulamaAciklama),
              if (currentEmail != null && currentEmail.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  currentEmail,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('changeEmailCurrentPassword'),
                controller: _currentPasswordController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.profileMevcutSifre,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return l10n.profileMevcutSifreniGir;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('changeEmailNewEmail'),
                controller: _newEmailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.newUsername],
                decoration: InputDecoration(
                  labelText: l10n.profileYeniEposta,
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  final email = value?.trim();
                  if (email == null || email.isEmpty || !email.contains('@')) {
                    return l10n.profileGecerliBirEpostaGirin;
                  }
                  if (email.toLowerCase() == currentEmail?.toLowerCase()) {
                    return l10n.profileEpostaAyniOlamaz;
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.profileIptal),
        ),
        FilledButton(
          key: const Key('changeEmailSubmit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.profileKaydet),
        ),
      ],
    );
  }
}

/// Diyalogdan çıkan sonuç: şifre değişti mi, yoksa kullanıcı "şifremi unuttum"
/// yoluna mı geçti?
enum _PasswordDialogOutcome {
  /// Şifre değişti ve diğer cihazların oturumu kapatıldı (WP-319-G).
  changed,

  /// Şifre değişti ama diğer oturumlar kapatılamadı — kullanıcıya **söylenir**.
  changedOtherSessionsKept,

  /// Kullanıcı "şifremi unuttum" yoluna geçti.
  forgot,
}

/// WP-319: üç alanlı şifre değiştirme diyaloğu.
///
/// Hata **diyaloğun içinde** gösterilir, snackbar'da değil: yanlış mevcut şifre
/// en olası sonuç ve kullanıcının diğer iki alanı yeniden yazması gerekmemeli.
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Sunucudan gelen nedeni yerelleştirir. Mesaj metnine bakmak yerine
  /// [AuthErrorCode] kullanılır — mesaj düzenlenince dal sessizce kaymasın.
  String _messageFor(AppLocalizations l10n, Object error) {
    if (error is! AuthException) return l10n.profileBeklenmeyenBirHataOlustu;
    return switch (error.code) {
      AuthErrorCode.invalidCurrentPassword => l10n.profileMevcutSifreHatali,
      AuthErrorCode.weakPassword => l10n.profileSifreEnAz6,
      AuthErrorCode.samePassword => l10n.profileYeniSifreEskisiyleAyni,
      AuthErrorCode.rateLimited => l10n.profileCokFazlaDeneme,
      // WP-536: ag hatasi sifre hakkinda hukum vermez.
      AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
      AuthErrorCode.noSession => l10n.profileOturumBulunamadiGirisYap,
      _ => l10n.profileBeklenmeyenBirHataOlustu,
    };
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_formKey.currentState?.validate() != true) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .changePassword(
            currentPassword: _currentController.text,
            newPassword: _newController.text,
          );
      if (mounted) {
        Navigator.pop(
          context,
          outcome == PasswordChangeOutcome.done
              ? _PasswordDialogOutcome.changed
              : _PasswordDialogOutcome.changedOtherSessionsKept,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageFor(l10n, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.profileSifreDegistir),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                key: const Key('changePasswordCurrent'),
                controller: _currentController,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: l10n.profileMevcutSifre,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return l10n.profileMevcutSifreniGir;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('changePasswordNew'),
                controller: _newController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.profileYeniSifre,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.length < 6) {
                    return l10n.profileSifreEnAz6;
                  }
                  if (val == _currentController.text) {
                    return l10n.profileYeniSifreEskisiyleAyni;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('changePasswordConfirm'),
                controller: _confirmController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.profileYeniSifreTekrar,
                  border: const OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val != _newController.text) {
                    return l10n.profileSifrelerEslesmiyor;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const Key('changePasswordForgot'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.pop(
                          context,
                          _PasswordDialogOutcome.forgot,
                        ),
                  child: Text(l10n.profileSifremiUnuttum),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(l10n.profileIptal),
        ),
        FilledButton(
          key: const Key('changePasswordSubmit'),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.profileKaydet),
        ),
      ],
    );
  }
}

import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/safe_screen_padding.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _isLoading = false;

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

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileCikisYapilirkenBirHata,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  /// WP-114: silme isteği — şifre yeniden doğrulama + 14 gün grace (sunucu).
  ///
  /// 🔴 WP-294: bu ekran eskiden `languageCode == 'tr'` üçlemesiyle elle iki dil
  /// tutuyordu; katalogu tamamen atlıyordu, yani **DE/AR kullanıcısı İngilizce
  /// görüyordu**. Artık tüm metinler `AppLocalizations` üzerinden geliyor.
  Future<void> _requestAccountDeletion() async {
    final l10n = AppLocalizations.of(context);
    final passwordController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.accountHesabiSil),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.accountSilmeOnayGovdesi),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.authSifre),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.profileIptal),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.accountSilmeyiPlanla),
            ),
          ],
        );
      },
    );
    if (confirm != true || !mounted) {
      passwordController.dispose();
      return;
    }

    final email = ref.read(authRepositoryProvider).currentUserEmail;
    final password = passwordController.text;
    passwordController.dispose();
    if (email == null || password.isEmpty) return;

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
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // Ham `e.toString()` gösterilmiyordu: içeriği yerelleştirilemez ve
            // sunucu/istisna metnini kullanıcıya sızdırıyor (WP-294).
            content: Text(l10n.authBeklenmeyenBirHataOlustu),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelAccountDeletion() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).cancelAccountDeletion();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).accountSilmeIptalEdildi),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).authBeklenmeyenBirHataOlustu,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.email_outlined),
                        title: Text(
                          AppLocalizations.of(context).profileEpostaAdresi,
                        ),
                        subtitle: Text(
                          email ??
                              AppLocalizations.of(context).profileBilinmiyor,
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
                        title: Text(AppLocalizations.of(context).profileSifre),
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
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    title: Text(
                      AppLocalizations.of(context).profileGuvenliCikis,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: Text(
                      AppLocalizations.of(
                        context,
                      ).profileCihazdakiOturumuSonlandir,
                      style: TextStyle(
                        color: theme.colorScheme.error.withValues(alpha: 0.8),
                      ),
                    ),
                    onTap: _signOut,
                  ),
                ),
                SizedBox(height: 12),
                // WP-114: hesap silme
                FutureBuilder(
                  future: ref
                      .read(authRepositoryProvider)
                      .fetchAccountDeletionStatus(),
                  builder: (context, snap) {
                    final l10n = AppLocalizations.of(context);
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
                          style: TextStyle(color: theme.colorScheme.error),
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

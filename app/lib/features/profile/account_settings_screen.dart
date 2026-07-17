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
    final currentEmail = ref.read(authRepositoryProvider).currentUserEmail;
    final controller = TextEditingController(text: currentEmail);
    final formKey = GlobalKey<FormState>();

    final newEmail = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).profileEpostaDegistir),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).profileYeniEposta,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                final text = val?.trim();
                if (text == null || text.isEmpty || !text.contains('@')) {
                  return AppLocalizations.of(
                    context,
                  ).profileGecerliBirEpostaGirin;
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).profileIptal),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: Text(AppLocalizations.of(context).profileKaydet),
            ),
          ],
        );
      },
    );

    if (newEmail == null || newEmail.isEmpty || newEmail == currentEmail) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updateEmail(newEmail);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                context,
              ).profileEpostaBasariylaGuncellendiYeni,
            ),
          ),
        );
      }
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileBeklenmeyenBirHataOlustu,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileBeklenmeyenBirHataOlustu,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changePassword() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final newPassword = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).profileSifreDegistir),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).profileYeniSifre,
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (val) {
                if (val == null || val.length < 6) {
                  return AppLocalizations.of(context).profileSifreEnAz6;
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).profileIptal),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: Text(AppLocalizations.of(context).profileKaydet),
            ),
          ],
        );
      },
    );

    if (newPassword == null || newPassword.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(newPassword);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileSifreBasariylaGuncellendi,
            ),
          ),
        );
      }
    } on AuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileBeklenmeyenBirHataOlustu,
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).profileBeklenmeyenBirHataOlustu,
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
  Future<void> _requestAccountDeletion() async {
    final tr = Localizations.localeOf(context).languageCode == 'tr';
    final passwordController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(tr ? 'Hesabı sil' : 'Delete account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr
                    ? 'Hesabın 14 gün içinde kalıcı silinmek üzere planlanır. Bu süre içinde iptal edebilirsin. Devam için şifreni gir.'
                    : 'Your account will be scheduled for permanent deletion in 14 days. You can cancel during that window. Enter your password to continue.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: tr ? 'Şifre' : 'Password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context).profileIptal),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr ? 'Silmeyi planla' : 'Schedule deletion'),
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
        SnackBar(
          content: Text(
            tr
                ? 'Silme planlandı. Son tarih: $until'
                : 'Deletion scheduled. Deadline: $until',
          ),
        ),
      );
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
        final tr = Localizations.localeOf(context).languageCode == 'tr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr ? 'Silme isteği iptal edildi.' : 'Deletion request canceled.',
            ),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
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
                    final tr =
                        Localizations.localeOf(context).languageCode == 'tr';
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
                              ? (tr
                                    ? 'Silme planlandı — iptal et'
                                    : 'Deletion scheduled — cancel')
                              : (tr ? 'Hesabı sil' : 'Delete account'),
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                        subtitle: Text(
                          active
                              ? (tr
                                    ? 'Son tarih: ${snap.data?.purgeAfter?.toLocal()}'
                                    : 'Deadline: ${snap.data?.purgeAfter?.toLocal()}')
                              : (tr
                                    ? '14 gün geri alma; ardından kalıcı silme'
                                    : '14-day cooling-off, then permanent delete'),
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

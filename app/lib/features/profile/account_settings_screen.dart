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
              ],
            ),
    );
  }
}

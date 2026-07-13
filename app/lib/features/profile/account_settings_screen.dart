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
          title: const Text('E-posta Değiştir'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Yeni E-posta',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (val) {
                final text = val?.trim();
                if (text == null || text.isEmpty || !text.contains('@')) {
                  return 'Geçerli bir e-posta girin.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context, controller.text.trim());
                }
              },
              child: const Text('Kaydet'),
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
          const SnackBar(content: Text('E-posta başarıyla güncellendi. Yeni e-postanıza bir doğrulama maili gönderilmiş olabilir.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Beklenmeyen bir hata oluştu.'), backgroundColor: Theme.of(context).colorScheme.error),
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
          title: const Text('Şifre Değiştir'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Yeni Şifre',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              validator: (val) {
                if (val == null || val.length < 6) {
                  return 'Şifre en az 6 karakter olmalı.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  Navigator.pop(context, controller.text);
                }
              },
              child: const Text('Kaydet'),
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
          const SnackBar(content: Text('Şifre başarıyla güncellendi.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Beklenmeyen bir hata oluştu.'), backgroundColor: Theme.of(context).colorScheme.error),
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
          title: const Text('Güvenli Çıkış'),
          content: const Text('Hesabınızdan çıkış yapmak istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Çıkış Yap'),
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
          SnackBar(content: const Text('Çıkış yapılırken bir hata oluştu.'), backgroundColor: Theme.of(context).colorScheme.error),
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
      appBar: AppBar(title: const Text('Hesabım')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: getSafePadding(
                  context, const EdgeInsets.symmetric(horizontal: 16, vertical: 24)),
              children: [
                Text('Hesap Bilgileri',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('E-posta Adresi'),
                        subtitle: Text(email ?? 'Bilinmiyor'),
                        trailing: TextButton(
                          onPressed: _changeEmail,
                          child: const Text('Değiştir'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Şifre'),
                        subtitle: const Text('••••••••'),
                        trailing: TextButton(
                          onPressed: _changePassword,
                          child: const Text('Değiştir'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Text('Güvenlik',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                  child: ListTile(
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    title: Text(
                      'Güvenli Çıkış',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                    subtitle: Text(
                      'Cihazdaki oturumu sonlandır',
                      style: TextStyle(
                          color: theme.colorScheme.error.withValues(alpha: 0.8)),
                    ),
                    onTap: _signOut,
                  ),
                ),
              ],
            ),
    );
  }
}

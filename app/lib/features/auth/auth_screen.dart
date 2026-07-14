import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../l10n/app_localizations.dart';

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
    });

    final auth = ref.read(authRepositoryProvider);
    try {
      if (_isRegister) {
        await auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
        );
      } else {
        await auth.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      ref.invalidate(authStateProvider);
      // Başarılıysa AuthGate otomatik olarak ana uygulamaya geçer.
    } on AuthException catch (e) {
      final verifiedEmailNotice = e.message.contains('e-postana gönderilen');
      setState(() {
        if (verifiedEmailNotice) {
          _info = l10n.commonEpostaDogrulamasiGerekiyor;
          _isRegister = false;
          _passwordController.clear();
        } else {
          _error = _localizedAuthError(l10n, e.message);
        }
      });
    } catch (e) {
      setState(() => _error = l10n.authBeklenmeyenBirHataOlustu);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
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
    } on AuthException catch (e) {
      setState(() => _error = _localizedAuthError(l10n, e.message));
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
                    const SizedBox(height: 24),
                    if (_isRegister) ...[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
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
                    if (!_isRegister)
                      TextButton.icon(
                        onPressed: _loading ? null : _sendPasswordReset,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: Text(l10n.authSifremiUnuttum),
                      ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                              _isRegister = !_isRegister;
                              _error = null;
                              _info = null;
                            }),
                      child: Text(
                        _isRegister
                            ? l10n.authZatenHesabinVarMi
                            : l10n.authHesabinYokMuKayit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _localizedAuthError(AppLocalizations l10n, String message) {
    if (message.contains('Geçerli bir e-posta')) {
      return l10n.authGecerliBirEpostaGirin;
    }
    if (message.contains('Şifre en az 6 karakter')) {
      return l10n.authSifreEnAz6;
    }
    if (message.contains('Bu e-posta zaten kayıtlı')) {
      return l10n.commonBuEpostaZatenKayitli;
    }
    if (message.contains('E-posta veya şifre hatalı')) {
      return l10n.commonEpostaVeyaSifreHatali;
    }
    return l10n.authBeklenmeyenBirHataOlustu;
  }
}

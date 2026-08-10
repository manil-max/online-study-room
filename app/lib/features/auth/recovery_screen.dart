import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../l10n/app_localizations.dart';
import 'entry_desktop_layout.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({super.key});

  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.authSifrenizBasariylaSifirlandi)),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _error = _messageFor(l10n, e));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.authBeklenmeyenBirHataOlustu);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Hatanın nedenini kullanıcı metnine çevirir.
  ///
  /// 🔴 WP-539: burası eskiden `on AuthException {` idi — istisna **hiç
  /// bağlanmıyordu**, yani içine bakılmadan üç farklı sebep (süresi dolmuş
  /// sıfırlama oturumu, zayıf şifre, ağ hatası) tek bir "Beklenmeyen bir hata
  /// oluştu." cümlesine düşüyordu. Kullanıcı hangisini düzelteceğini
  /// bilemediği için ekranda takılı kalıyordu.
  String _messageFor(AppLocalizations l10n, AuthException error) {
    return switch (error.code) {
      AuthErrorCode.weakPassword => l10n.authSifreEnAz6SifreEnAz6KarakterOlmal,
      AuthErrorCode.noSession => l10n.authSifirlamaBaglantisiGecersiz,
      AuthErrorCode.rateLimited => l10n.profileCokFazlaDeneme,
      AuthErrorCode.network => l10n.profileSunucuyaUlasilamadi,
      _ => l10n.authBeklenmeyenBirHataOlustu,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.authYeniSifreBelirle)),
      // 🔴 WP-680 / SPEC §2.3 — bu ekranin HIC genislik tavani yoktu.
      // OLCUM (WP-680 testi, dpr=1): 1920 px pencerede en genis cizilen kutu
      // **1872 px**, 2560 px'te **2512 px**. 1872 / 7.5 = 250 karakter; WCAG
      // 2.1 SC 1.4.8 tavani 80 karakter = 600 px (SPEC §2.1). Sifresini
      // kurtarmaya calisan kullanici ekrani bastan basa kat eden tek bir
      // sifre alani goruyordu. Tavan: form sutunu **760 px**
      // ([DesktopBreakpoints.maxFormWidth]). Mobilde etkisiz — 390 px
      // pencerede kullanilabilir genislik zaten 342 px.
      body: Center(
        child: SingleChildScrollView(
          padding: getSafePadding(context, const EdgeInsets.all(24)),
          child: EntryFormColumn(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_reset,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l10n.authGuvenliginizIcinYeniBir,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: l10n.authYeniSifre,
                      border: const OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.length < 6) {
                        return l10n.authSifreEnAz6SifreEnAz6KarakterOlmal;
                      }
                      return null;
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.authSifreyiKaydetVeGiris),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

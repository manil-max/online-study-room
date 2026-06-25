import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../core/navigation/home_shell.dart';
import '../updater/updater_dialog.dart';
import 'auth_screen.dart';

/// Oturum durumuna göre giriş ekranını veya ana uygulamayı gösterir.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Uygulama açılışında bir kez güncelleme kontrolü (sadece Android'de iş yapar).
    // Sessizdir: güncelleme yoksa veya hata olursa kullanıcı hiçbir şey görmez.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowUpdateDialog(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (profile) =>
          profile == null ? const AuthScreen() : const HomeShell(),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        body: Center(child: Text('Bir hata oluştu: $error')),
      ),
    );
  }
}

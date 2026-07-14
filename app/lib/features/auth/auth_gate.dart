import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/auth_providers.dart';
import '../../core/navigation/home_shell.dart';
import '../updater/release_notes_screen.dart';
import '../updater/updater_dialog.dart';
import 'auth_screen.dart';
import 'recovery_screen.dart';

/// Oturum durumuna göre giriş ekranını veya ana uygulamayı gösterir.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  late final StreamSubscription<void> _recoverySub;

  @override
  void initState() {
    super.initState();
    // Uygulama açılışında bir kez güncelleme kontrolü (sadece Android'de iş yapar).
    // Sessizdir: güncelleme yoksa veya hata olursa kullanıcı hiçbir şey görmez.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await maybeShowWhatsNewDialog(context);
      if (mounted) await maybeShowUpdateDialog(context);
    });

    _recoverySub = ref
        .read(authRepositoryProvider)
        .passwordRecoveryEvents
        .listen((_) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RecoveryScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _recoverySub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (profile) =>
          profile == null ? const AuthScreen() : const HomeShell(),
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Yükleniyor…',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Bir hata oluştu: $error', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

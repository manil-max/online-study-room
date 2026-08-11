import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'shell/admin_shell.dart';

/// Yonetim paneli — yetki kapisi + kabuk.
///
/// 🔴 WP-A (`docs/design/ADMIN-PANEL-PLAN.md` §5): bu dosya eskiden
/// `DefaultTabController(length: 7)` + `TabBar(isScrollable: true)` idi ve
/// besinci sekmenin adi koda gomulu ham `'UGC'` dizesiydi. Yedi sekme uc
/// yuzeye indi ve duzen [AdminShell]e tasindi; burada yalniz yetki karari
/// kaldi.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(adminIsSuperAdminProvider);
    final l10n = AppLocalizations.of(context);

    return isAdmin.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.adminYonetim)),
        body: _AdminError(message: l10n.authBeklenmeyenBirHataOlustu),
      ),
      data: (allowed) {
        if (!allowed) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.adminYonetim)),
            body: _AdminError(
              icon: Icons.lock_outline,
              message: l10n.adminBuAlanYalnizcaSuperadmin,
            ),
          );
        }
        return const AdminShell();
      },
    );
  }
}

class _AdminError extends StatelessWidget {
  const _AdminError({required this.message, this.icon = Icons.error_outline});

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

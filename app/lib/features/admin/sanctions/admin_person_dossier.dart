import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'admin_active_restriction_card.dart';
import 'admin_sanction_actions.dart';
import 'admin_sanction_dialogs.dart';
import 'sanction_ladder.dart';

// WP-809: aktif kisit karti ile geri alma anahtari ortak widget'a tasindi;
// bu dosyayi import eden yuzeyler anahtari buradan gormeye devam etsin.
export 'admin_active_restriction_card.dart' show kAdminSanctionRevokeKey;

/// Kisi dosyasinin govdesi.
const Key kAdminPersonDossierKey = Key('admin-person-dossier');

/// Ceza gecmisi bloku (PLAN §1.3(b): saglayici vardi, hic cizilmiyordu).
const Key kAdminSanctionHistoryKey = Key('admin-sanction-history');

/// Basamak secme dugmesi.
const Key kAdminSanctionApplyMenuKey = Key('admin-sanction-apply-menu');

/// Hesabi silme — geri alinamaz, sert teyit ister.
const Key kAdminPersonDeleteKey = Key('admin-person-delete');

/// Vakadan ya da listeden gelen tek dokunusu karsilayan sayfa.
///
/// PLAN §2.3: bugun vakadan kisiye kopru yok — UUID panoya kopyalanip
/// aramasiz listede gozle araniyor. Bu sayfa o koprunin varis noktasi.
Future<void> openAdminPersonDossier(
  BuildContext context, {
  required String targetUserId,
  String? targetEmail,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AdminPersonDossierPage(
        targetUserId: targetUserId,
        targetEmail: targetEmail,
      ),
    ),
  );
}

class AdminPersonDossierPage extends StatelessWidget {
  const AdminPersonDossierPage({
    super.key,
    required this.targetUserId,
    this.targetEmail,
  });

  final String targetUserId;
  final String? targetEmail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminSanctionDossierTitle)),
      body: SafeArea(
        child: AdminPersonDossier(
          targetUserId: targetUserId,
          targetEmail: targetEmail,
        ),
      ),
    );
  }
}

/// Hedefin dosyasi: kimlik, **aktif kisit**, ceza gecmisi ve yaptirim yolu.
///
/// Ekranin tamami tek saglayiciyi `ref.watch` eder: yaptirim uygulandiginda ya
/// da geri alindiginda liste kendiliginden tazelenir. Bugun (WP-C oncesi)
/// `moderationSanctionsProvider` yalniz `invalidate` ediliyordu ve hicbir
/// dinleyicisi yoktu — yani gecmis hicbir ekranda cizilmiyordu.
class AdminPersonDossier extends ConsumerWidget {
  const AdminPersonDossier({
    super.key,
    required this.targetUserId,
    this.targetEmail,
  });

  final String targetUserId;
  final String? targetEmail;

  /// Sert teyitte yazdirilacak metin: e-posta bilinmiyorsa kimlik.
  ///
  /// 🔴 WP-771: burada `ref.read` vardi. `adminUsersProvider` **autoDispose**
  /// (`data/providers/admin_providers.dart:131`); dinleyicisi olmayan bir
  /// `read` Riverpod 3'te `AsyncLoading` (deger `null`) doner, yani e-posta
  /// HIC cozulmuyordu. Vakadan acilan dosyada — kopru e-postayi tasimaz
  /// (`widgets/moderation_queue_card.dart:90`) — "Kalici yasak"/"Hesabi sil"
  /// teyidi 36 karakterlik UUID yazdiriyordu. `watch` hem saglayiciyi ayakta
  /// tutar hem de cevap gelince ekrani tazeler. Sozlesme degismedi: e-posta
  /// yazilmadan geri alinamaz eylem uygulanmaz.
  String _confirmationPhrase(WidgetRef ref) {
    final known = targetEmail?.trim();
    if (known != null && known.isNotEmpty) return known;
    final users = ref.watch(adminUsersProvider).value;
    if (users != null) {
      for (final user in users) {
        if (user.id == targetUserId) return user.email;
      }
    }
    return targetUserId;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sanctions = ref.watch(moderationSanctionsProvider(targetUserId));
    final phrase = _confirmationPhrase(ref);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        // SPEC §3: form sutunu tavani 760.
        constraints: const BoxConstraints(
          maxWidth: DesktopBreakpoints.maxFormWidth,
        ),
        child: ListView(
          key: kAdminPersonDossierKey,
          padding: const EdgeInsets.all(16),
          children: [
            SelectableText(phrase, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l10n.adminIdGroupid(targetUserId),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            sanctions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(l10n.authBeklenmeyenBirHataOlustu),
              data: (items) => _SanctionBlock(
                targetUserId: targetUserId,
                confirmationPhrase: phrase,
                sanctions: items,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.adminSanctionAccountActions,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _performUserAction(
                    context,
                    ref,
                    action: 'send_password_reset',
                    title: l10n.adminSifreSifirlamaEpostasiGonder,
                    hardConfirm: false,
                    confirmationPhrase: phrase,
                  ),
                  icon: const Icon(Icons.lock_reset, size: 20),
                  label: Text(l10n.adminSifreSifirla),
                ),
                OutlinedButton.icon(
                  key: kAdminPersonDeleteKey,
                  onPressed: () => _performUserAction(
                    context,
                    ref,
                    action: 'soft_delete_user',
                    title: l10n.adminKullaniciyiSoftDeleteYap,
                    // 🔴 Geri alinamaz: e-posta yazdirilir (PLAN §4.3).
                    hardConfirm: true,
                    confirmationPhrase: phrase,
                  ),
                  icon: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: theme.colorScheme.error,
                  ),
                  label: Text(
                    l10n.adminSil,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performUserAction(
    BuildContext context,
    WidgetRef ref, {
    required String action,
    required String title,
    required bool hardConfirm,
    required String confirmationPhrase,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = await askAdminReason(context, title);
    if (raw == null) return;
    final reason = raw.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
      );
      return;
    }
    if (hardConfirm) {
      if (!context.mounted) return;
      final confirmed = await showAdminHardConfirm(
        context,
        title: title,
        expected: confirmationPhrase,
      );
      if (!confirmed) return;
    }
    try {
      await ref
          .read(adminRepositoryProvider)
          .performUserAction(
            action: action,
            targetUserId: targetUserId,
            reason: reason,
          );
    } on AdminException catch (e) {
      // 🔴 WP-771: sunucunun gercek mesaji burada yutuluyordu.
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    ref.invalidate(adminUsersProvider);
    messenger.showSnackBar(SnackBar(content: Text(l10n.adminIslemBasarili)));
  }
}

class _SanctionBlock extends ConsumerWidget {
  const _SanctionBlock({
    required this.targetUserId,
    required this.confirmationPhrase,
    required this.sanctions,
  });

  final String targetUserId;
  final String confirmationPhrase;
  final List<ModerationSanction> sanctions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // WP-809: aktif kisit + kaldirma yolu artik ortak widget. Vakadan
        // acilan moderasyon profili ayni karti cizer; iki yuzey ayrilamaz.
        AdminActiveRestrictionCard(sanctions: sanctions),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: kAdminSanctionApplyMenuKey,
          onPressed: () => AdminSanctionActions.chooseAndApply(
            context,
            ref,
            targetUserId: targetUserId,
            confirmationPhrase: confirmationPhrase,
          ),
          icon: const Icon(Icons.gavel_outlined, size: 20),
          label: Text(l10n.adminSanctionApplyRestriction),
        ),
        const SizedBox(height: 16),
        Text(l10n.adminSanctionHistoryTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        if (sanctions.isEmpty)
          Text(
            l10n.adminSanctionHistoryEmpty,
            key: kAdminSanctionHistoryKey,
            style: theme.textTheme.bodySmall,
          )
        else
          Column(
            key: kAdminSanctionHistoryKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final sanction in sanctions)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  // SPEC §4: liste ikonu 32.
                  leading: Icon(
                    sanction.state == ModerationSanctionState.revoked
                        ? Icons.undo
                        : Icons.gavel_outlined,
                    size: 20,
                  ),
                  title: Text(adminSanctionLabel(l10n, sanction.action)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Durum **kendi** metnidir: testin ve gozun okudugu sey
                      // birlestirilmis bir dize degil.
                      Text(adminSanctionStateLabel(l10n, sanction.state)),
                      Text(
                        sanction.appliedAt == null
                            ? sanction.reason
                            : '${adminSanctionStamp(sanction.appliedAt!)} · ${sanction.reason}',
                      ),
                    ],
                  ),
                  isThreeLine: true,
                ),
            ],
          ),
      ],
    );
  }
}

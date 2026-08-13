import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'admin_sanction_dialogs.dart';
import 'sanction_ladder.dart';

/// 10 sn "Geri al" seridi (PLAN §4.4/2).
const Key kAdminSanctionUndoKey = Key('admin-sanction-undo');

/// Geri alma seridinin omru. Sahip karari: geri alinabilir yaptirim teyit
/// istemez, bunun yerine bu serit cikar.
const Duration kAdminSanctionUndoWindow = Duration(seconds: 10);

/// Basamak secme sayfasindaki satirlarin anahtari — Kullanicilar sekmesi ile
/// kisi dosyasi **ayni** anahtari kullanir; iki yuzey tek yuzeydir.
Key adminSanctionLadderKey(ModerationAction action) =>
    Key('admin-suspend-${action.wire}');

/// WP-C: yaptirim uygulama / geri alma akisinin **tek** uygulamasi.
///
/// Ayni akis hem Kullanicilar listesindeki karttan hem de kisi dosyasindan
/// cagrilir; boylece "banlama farkli yere gidiyorum" sikayetinin kaynagi olan
/// iki ayri boru hatti tek hatta iner.
class AdminSanctionActions {
  const AdminSanctionActions._();

  /// Basamak secim sayfasi. Secilen basamak dogrudan [apply]'a gider.
  static Future<void> chooseAndApply(
    BuildContext context,
    WidgetRef ref, {
    required String targetUserId,
    required String confirmationPhrase,
    List<ModerationAction>? ladder,
    String? caseId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final steps = ladder ?? kAdminAccountRestrictionLadder;
    final selected = await showModalBottomSheet<ModerationAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              title: Text(
                l10n.adminKullaniciyiAskiyaAl,
                style: Theme.of(sheetContext).textTheme.titleSmall,
              ),
            ),
            for (final action in steps)
              ListTile(
                key: adminSanctionLadderKey(action),
                title: Text(adminSanctionLabel(l10n, action)),
                // 🔴 PLAN §4.4/5: kalici yasak ayirici altinda, `error`
                // renginde. Ayni menude durur ama ayni sey gibi gorunmez.
                titleTextStyle: adminSanctionNeedsHardConfirm(action)
                    ? Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(sheetContext).colorScheme.error,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(action),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !context.mounted) return;
    await apply(
      context,
      ref,
      targetUserId: targetUserId,
      confirmationPhrase: confirmationPhrase,
      action: selected,
      caseId: caseId,
    );
  }

  /// Tek yaptirim uygulama yolu.
  ///
  /// Ayrim (sahip karari, PLAN §6 S3):
  /// * suresi olan basamak → teyit **yok**, 10 sn "Geri al" seridi **var**;
  /// * kalici yasak → hedefin e-postasini yazdiran sert teyit.
  static Future<void> apply(
    BuildContext context,
    WidgetRef ref, {
    required String targetUserId,
    required String confirmationPhrase,
    required ModerationAction action,
    String? caseId,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final label = adminSanctionLabel(l10n, action);

    final raw = await askAdminReason(context, label);
    if (raw == null) return;
    final reason = raw.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
      );
      return;
    }

    if (adminSanctionNeedsHardConfirm(action)) {
      if (!context.mounted) return;
      final confirmed = await showAdminHardConfirm(
        context,
        title: label,
        expected: confirmationPhrase,
      );
      if (!confirmed) return;
    }

    final request = ModerationSanctionRequest(
      targetUserId: targetUserId,
      action: action,
      reason: reason,
      caseId: caseId,
      idempotencyKey:
          'admin-sanction-$targetUserId-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (!context.mounted) return;
    await _submit(context, ref, request);
  }

  /// Inceleme panosunun topladigi gerekce ve vaka kimligini ayni guvenli
  /// yaptirim hattina sokar. Boylece kalici yasak sert teyidi ve geri
  /// alinabilir basamaklarin 10 saniyelik seridi kuyrukta da kaybolmaz.
  static Future<void> applyPrepared(
    BuildContext context,
    WidgetRef ref, {
    required ModerationSanctionRequest request,
    required String confirmationPhrase,
  }) async {
    final l10n = AppLocalizations.of(context);
    if (adminSanctionNeedsHardConfirm(request.action)) {
      final confirmed = await showAdminHardConfirm(
        context,
        title: adminSanctionLabel(l10n, request.action),
        expected: confirmationPhrase,
      );
      if (!confirmed || !context.mounted) return;
    }
    await _submit(context, ref, request);
  }

  static Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    ModerationSanctionRequest request,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ModerationSanction sanction;
    try {
      sanction = await ref
          .read(adminModerationRepositoryProvider)
          .applySanction(request);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _refresh(ref, request.targetUserId);

    if (adminSanctionNeedsHardConfirm(request.action)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminModerationSanctionApplied)),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        duration: kAdminSanctionUndoWindow,
        content: Text(l10n.adminModerationSanctionApplied),
        action: SnackBarAction(
          key: kAdminSanctionUndoKey,
          label: l10n.adminSanctionUndo,
          onPressed: () async {
            try {
              await ref
                  .read(adminModerationRepositoryProvider)
                  .revokeSanction(
                    sanctionId: sanction.id,
                    reason: l10n.adminSanctionUndoReason,
                  );
            } on ModerationException catch (e) {
              messenger.showSnackBar(SnackBar(content: Text(e.message)));
              return;
            }
            _refresh(ref, request.targetUserId);
            messenger.showSnackBar(
              SnackBar(content: Text(l10n.adminModerationSanctionRevoked)),
            );
          },
        ),
      ),
    );
  }

  /// 🔴 PLAN §1.3(a): `revokeSanction` sunucuda hazirdi, testi yesildi ve
  /// `app/lib/features/**` icinde **sifir** cagri yeri vardi. Burasi o cagri
  /// yeridir: serit kaybolduktan sonra da yol acik kalir.
  static Future<void> revoke(
    BuildContext context,
    WidgetRef ref, {
    required ModerationSanction sanction,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final raw = await askAdminReason(
      context,
      l10n.adminSanctionLiftRestriction,
    );
    if (raw == null) return;
    final reason = raw.trim();
    if (reason.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.adminGerekceBelirtilmelidir)),
      );
      return;
    }
    try {
      await ref
          .read(adminModerationRepositoryProvider)
          .revokeSanction(sanctionId: sanction.id, reason: reason);
    } on ModerationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      return;
    }
    _refresh(ref, sanction.targetUserId);
    messenger.showSnackBar(
      SnackBar(content: Text(l10n.adminModerationSanctionRevoked)),
    );
  }

  /// Yazma sonrasi tazeleme. Gecmis saglayicisi artik **izleniyor**, bu yuzden
  /// `invalidate` gercekten yeniden okutur (dinleyicisiz `family` saglayiciyi
  /// invalidate etmek Riverpod 3'te islemsizdi — PLAN §1.3(b)).
  static void _refresh(WidgetRef ref, String targetUserId) {
    ref.invalidate(adminUsersProvider);
    ref.invalidate(moderationQueueProvider);
    ref.invalidate(moderationSanctionsProvider(targetUserId));
  }
}

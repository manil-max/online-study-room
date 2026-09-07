import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import 'admin_sanction_actions.dart';
import 'sanction_ladder.dart';

/// Aktif kisitin yanindaki kalici geri alma yolu (PLAN §4.4/4).
///
/// WP-809: anahtar `admin_person_dossier.dart`ten buraya tasindi. Degeri
/// **degismedi** — eski yuzeyi olcen `admin_sanction_surface_test.dart` ayni
/// anahtari tapmaya devam eder.
const Key kAdminSanctionRevokeKey = Key('admin-sanction-revoke');

/// Depoda kayitli desen: tarih bicimi tek satirda, gomulu metin yok.
String adminSanctionStamp(DateTime value) =>
    value.toLocal().toString().substring(0, 16);

/// Hedefin **su an yururlukteki** kisiti ve onu kaldirma yolu.
///
/// 🔴 WP-809 olcumu: bu blok yalniz kisi dosyasinda
/// (`sanctions/admin_person_dossier.dart`) duruyordu ve o sayfaya SADECE
/// Kullanicilar sekmesinden (`tabs/admin_users_tab.dart:223`) gidiliyordu.
/// Vakadan acilan moderasyon profili (`detail/admin_user_profile_page.dart`,
/// `detail/admin_case_detail_page.dart:884`ten tek dokunusla) kisit
/// UYGULUYOR ama kaldiramiyordu: yikici yon vakadan tek dokunus, kurtarma
/// yonu baska sekmede. Ortak widget o asimetriyi kapatir — iki yuzey ayni
/// kodu cizer, yani biri duzelince digeri de duzelir.
class AdminActiveRestrictionCard extends ConsumerWidget {
  const AdminActiveRestrictionCard({super.key, required this.sanctions});

  /// Hedefin **tum** yaptirim gecmisi; aktifi bu listeden secilir.
  ///
  /// 🔴 Liste disaridan verilir, iceride `ref.read` ile okunmaz: dinleyicisiz
  /// bir `family` saglayiciyi `read` etmek Riverpod 3'te sonsuza kadar
  /// `AsyncLoading` dondurur ve dugme SESSIZCE hicbir sey yapmaz (depoda
  /// kayitli tuzak; `detail/admin_case_detail_page.dart:183-189` anlatiyor).
  /// Cagiran iki yuzey de `moderationSanctionsProvider`i `watch` eder.
  final List<ModerationSanction> sanctions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    ModerationSanction? found;
    for (final sanction in sanctions) {
      if (sanction.isActive(now)) {
        found = sanction;
        break;
      }
    }
    final active = found;

    // `pending` satir ve suresi dolmus kisit AKTIF SAYILMAZ
    // (`ModerationSanction.isActive`): yarim kalan islem kullaniciyi cezali
    // birakmaz, dolan kisit kendiliginden kalkar. Ikisinde de kaldirilacak
    // bir sey yoktur, o yuzden dugme de yoktur.
    if (active == null) {
      return Text(
        l10n.adminSanctionNoActiveRestriction,
        style: theme.textTheme.bodyMedium,
      );
    }

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminModerationSanctionActive(
                adminSanctionLabel(l10n, active.action),
              ),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              active.expiresAt == null
                  ? l10n.adminSanctionNoExpiry
                  : l10n.adminSanctionExpiresAt(
                      adminSanctionStamp(active.expiresAt!),
                    ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: kAdminSanctionRevokeKey,
              onPressed: () =>
                  AdminSanctionActions.revoke(context, ref, sanction: active),
              icon: const Icon(Icons.undo, size: 20),
              label: Text(l10n.adminSanctionLiftRestriction),
            ),
          ],
        ),
      ),
    );
  }
}

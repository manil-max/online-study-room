import 'package:flutter/material.dart';

import 'package:online_study_room/l10n/app_localizations.dart';

import 'admin_person_dossier.dart';

/// Vakadan hedefin dosyasina giden **tek dokunus**.
const Key kAdminCaseTargetLinkKey = Key('admin-case-target-link');

/// 🔴 PLAN §2.3: bugun vakadan kisiye kopru yok. Tek yardim uc noktadaki
/// "Kopyala" — UUID'yi panoya aliyorsun, sekme degistiriyorsun, listede arama
/// kutusu olmadigi icin gozle ariyorsun.
///
/// Bu dugme o yolu tek dokunusa indirir: sikayet edilen kisinin dosyasi (aktif
/// kisit, ceza gecmisi, kisit kaldirma) dogrudan acilir.
///
/// Yalniz-ikon oldugunda etiketi `Tooltip` tasir (PLAN §4.6 son madde).
class AdminCaseTargetLink extends StatelessWidget {
  const AdminCaseTargetLink({
    super.key,
    required this.targetUserId,
    this.targetEmail,
    this.compact = false,
  });

  final String targetUserId;
  final String? targetEmail;

  /// Kart icinde yer darsa yalniz-ikon cizilir; etiket tooltip'e duser.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = l10n.adminSanctionTargetDossier;
    void open() => openAdminPersonDossier(
      context,
      targetUserId: targetUserId,
      targetEmail: targetEmail,
    );

    if (compact) {
      return IconButton(
        key: kAdminCaseTargetLinkKey,
        tooltip: label,
        onPressed: open,
        icon: const Icon(Icons.badge_outlined, size: 20),
      );
    }
    return OutlinedButton.icon(
      key: kAdminCaseTargetLinkKey,
      onPressed: open,
      icon: const Icon(Icons.badge_outlined, size: 20),
      label: Text(label),
    );
  }
}

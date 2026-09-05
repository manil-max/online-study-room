import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_sanction.dart';

/// WP-B (`docs/design/ADMIN-PANEL-PLAN.md` §5) — inceleme akisinin **paylasilan**
/// diyaloglari.
///
/// Neden burada: vaka sayfasi (`detail/admin_case_detail_page.dart`) ve itiraz
/// sayfasi (`detail/admin_appeal_detail_page.dart`) ayni gerekce diyalogunu ve
/// ayni basamak etiketini kullanir. Anahtarlar korunur:
/// `moderation-reason-field`, `moderation-reason-confirm`.
///
/// WP-768: eski `ModerationSanctionSheet` buradan kaldirildi — tek cagri yeri
/// silinen inceleme bolmesiydi; yaptirim artik tek hattan uygulanir
/// (`sanctions/admin_sanction_actions.dart`).

/// Yaptirim basamaginin kullaniciya gorunen adi.
///
/// 🔴 Tek kaynak: eskiden bu esleme `_SanctionSheetState` icinde private bir
/// `switch`ti, bu yuzden itiraz karti **hangi cezaya** itiraz edildigini
/// yazamiyordu (`ADMIN-PANEL-PLAN.md` §2.1: "admin kor onay veriyor").
String moderationActionLabel(AppLocalizations l10n, ModerationAction action) =>
    switch (action) {
      ModerationAction.noAction => l10n.adminModerationSanctionNoAction,
      ModerationAction.warn => l10n.adminModerationSanctionWarn,
      ModerationAction.nameReset => l10n.adminModerationSanctionNameReset,
      ModerationAction.mute24h => l10n.adminModerationSanctionMute24h,
      ModerationAction.suspend24h => l10n.adminModerationSanctionSuspend24h,
      ModerationAction.suspend7d => l10n.adminModerationSanctionSuspend7d,
      ModerationAction.suspend14d => l10n.adminModerationSanctionSuspend14d,
      ModerationAction.suspend30d => l10n.adminModerationSanctionSuspend30d,
      ModerationAction.banPermanent => l10n.adminModerationSanctionBan,
    };

/// Gerekce zorunludur; bos gerekce sessizce "gerekce belirtilmedi"ye
/// cevrilmez, islem hic yapilmaz.
Future<String?> askModerationReason(BuildContext context, String title) async {
  final reason = await showDialog<String>(
    context: context,
    builder: (_) => _ReasonDialog(title: title),
  );
  if (reason == null || reason.trim().isEmpty) return null;
  return reason.trim();
}

/// Gerekce soran diyalog.
///
/// Controller'i diyalogun kendisi tutar: cagiran tarafta `dispose` etmek,
/// diyalog kapanis animasyonu surerken denetleyiciyi oldurup cerceveyi
/// dusuruyordu.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title});

  final String title;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('moderation-reason-field'),
        controller: _controller,
        decoration: InputDecoration(
          labelText: l10n.adminGerekceZorunlu,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
        FilledButton(
          key: const Key('moderation-reason-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.adminOnayla),
        ),
      ],
    );
  }
}

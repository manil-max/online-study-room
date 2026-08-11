import 'package:flutter/material.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../data/models/moderation_sanction.dart';

/// WP-B (`docs/design/ADMIN-PANEL-PLAN.md` §5) — inceleme akisinin **paylasilan**
/// diyaloglari.
///
/// Neden burada: karar seridi (`moderation_review_view.dart`), vaka kartinin
/// uc noktasi ve itiraz karti ayni gerekce diyalogunu ve ayni yaptirim
/// sayfasini kullanir. Bunlar `admin_moderation_tab.dart` icinde **private**
/// durdugu icin yeni inceleme yuzeyi onlari cagiramiyordu; tasindilar, davranis
/// birebir korundu (anahtarlar dahil: `moderation-reason-field`,
/// `moderation-sanction-submit`).

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

/// WP-441: Basamakli yaptirim sayfasi.
///
/// Basamaklar **sunucudaki sirayla** listelenir; gerekce boşken uygula dugmesi
/// calismaz. Idempotency anahtari sayfa acilisinda bir kez uretilir, boylece
/// ayni sayfadan yapilan yeniden deneme ikinci yaptirim acmaz.
///
/// WP-B eklemesi: [initialReason]. Karar seridindeki **tek** gerekce alani
/// buraya tasinir; yonetici ayni vakaya ayni gerekceyi ikinci kez yazmaz
/// (`ADMIN-PANEL-PLAN.md` §2.2 "iki ayri gerekce alani").
class ModerationSanctionSheet extends StatefulWidget {
  const ModerationSanctionSheet({
    super.key,
    required this.targetUserId,
    this.caseId,
    this.initialReason = '',
  });

  final String targetUserId;
  final String? caseId;
  final String initialReason;

  @override
  State<ModerationSanctionSheet> createState() =>
      _ModerationSanctionSheetState();
}

class _ModerationSanctionSheetState extends State<ModerationSanctionSheet> {
  late final TextEditingController _reason = TextEditingController(
    text: widget.initialReason,
  );
  late final String _idempotencyKey =
      'sanction-${widget.targetUserId}-${DateTime.now().microsecondsSinceEpoch}';
  ModerationAction _action = ModerationAction.warn;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.adminModerationSanctionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ModerationAction>(
              key: const Key('moderation-sanction-action'),
              initialValue: _action,
              items: [
                for (final action in ModerationAction.values)
                  DropdownMenuItem(
                    value: action,
                    child: Text(moderationActionLabel(l10n, action)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _action = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('moderation-sanction-reason'),
              controller: _reason,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.adminGerekceZorunlu,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('moderation-sanction-submit'),
              onPressed: _reason.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                      ModerationSanctionRequest(
                        targetUserId: widget.targetUserId,
                        action: _action,
                        reason: _reason.text.trim(),
                        idempotencyKey: _idempotencyKey,
                        caseId: widget.caseId,
                      ),
                    ),
              child: Text(l10n.adminOnayla),
            ),
          ],
        ),
      ),
    );
  }
}

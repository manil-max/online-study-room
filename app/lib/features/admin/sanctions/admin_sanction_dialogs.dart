import 'package:flutter/material.dart';

import 'package:online_study_room/l10n/app_localizations.dart';

/// Gerekce alaninin anahtari. WP-625'ten beri ayni: yaptirim yolunu olcen
/// testler bu anahtari tapiyor, yuzey birlesirken anahtar **degismedi**.
const Key kAdminReasonFieldKey = Key('admin-user-reason-field');
const Key kAdminReasonConfirmKey = Key('admin-user-reason-confirm');

/// Sert teyit (geri alinamaz eylem) anahtarlari.
const Key kAdminHardConfirmKey = Key('admin-sanction-hard-confirm');
const Key kAdminHardConfirmEmailKey = Key('admin-sanction-hard-email');
const Key kAdminHardConfirmSubmitKey = Key('admin-sanction-hard-submit');

/// Gerekce sorar. `null` = iptal; bos dize = onaylandi ama gerekce yazilmadi.
///
/// PLAN §4.4/3: gerekce **her zaman** zorunlu ama **bir kez** sorulur.
Future<String?> askAdminReason(BuildContext context, String title) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AdminReasonDialog(title: title),
  );
}

class _AdminReasonDialog extends StatefulWidget {
  const _AdminReasonDialog({required this.title});

  final String title;

  @override
  State<_AdminReasonDialog> createState() => _AdminReasonDialogState();
}

class _AdminReasonDialogState extends State<_AdminReasonDialog> {
  /// Denetleyiciyi diyalogun kendisi tutar: cagiran tarafta `dispose` etmek
  /// kapanis animasyonu surerken cerceveyi dusuruyordu.
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
        key: kAdminReasonFieldKey,
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
          key: kAdminReasonConfirmKey,
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(l10n.adminOnayla),
        ),
      ],
    );
  }
}

/// 🔴 PLAN §4.4/1 — geri alinamaz eylemin kapisi.
///
/// Silme ve kalici yasak, hedefin e-postasini (e-posta bilinmiyorsa kimligini)
/// **yazdirmadan** uygulanmaz. Tek dokunusla yikim yok.
///
/// Dugme bilerek **etkin** birakildi: kilitli bir dugme "neden calismiyor"
/// sorusunu doguruyor (sahibin 3. sikayeti — "tus neyi ne oldugu belli
/// degil"). Eslesmeyen metinde diyalog kapanmaz ve nedenini yazar.
Future<bool> showAdminHardConfirm(
  BuildContext context, {
  required String title,
  required String expected,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _AdminHardConfirmDialog(title: title, expected: expected),
  );
  return result ?? false;
}

class _AdminHardConfirmDialog extends StatefulWidget {
  const _AdminHardConfirmDialog({required this.title, required this.expected});

  final String title;
  final String expected;

  @override
  State<_AdminHardConfirmDialog> createState() =>
      _AdminHardConfirmDialogState();
}

class _AdminHardConfirmDialogState extends State<_AdminHardConfirmDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _mismatch = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final typed = _controller.text.trim().toLowerCase();
    if (typed != widget.expected.trim().toLowerCase()) {
      setState(() => _mismatch = true);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      key: kAdminHardConfirmKey,
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminSanctionHardConfirmPrompt(widget.expected),
            style: theme.textTheme.bodyMedium,
          ),
          // SPEC §1.4: etiket ile kontrol arasi 12.
          const SizedBox(height: 12),
          TextField(
            key: kAdminHardConfirmEmailKey,
            controller: _controller,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.adminSanctionHardConfirmField,
              border: const OutlineInputBorder(),
              errorText: _mismatch
                  ? l10n.adminSanctionHardConfirmMismatch
                  : null,
            ),
            onChanged: (_) {
              if (_mismatch) setState(() => _mismatch = false);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.adminIptal),
        ),
        FilledButton(
          key: kAdminHardConfirmSubmitKey,
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
          ),
          onPressed: _submit,
          child: Text(l10n.adminOnayla),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/observability_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/widgets/safe_screen_padding.dart';
import '../../l10n/app_localizations.dart';
import 'legal_documents.dart';

/// WP-111: Gizlilik, koşullar, topluluk kuralları ve telemetri tercihi.
class LegalCenterScreen extends ConsumerStatefulWidget {
  const LegalCenterScreen({super.key});

  @override
  ConsumerState<LegalCenterScreen> createState() => _LegalCenterScreenState();
}

class _LegalCenterScreenState extends ConsumerState<LegalCenterScreen> {
  bool? _telemetryOverride;
  bool _savingTelemetry = false;

  bool get _turkish {
    final code = Localizations.localeOf(context).languageCode;
    return code == 'tr';
  }

  Future<void> _setTelemetry(bool value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    setState(() {
      _telemetryOverride = value;
      _savingTelemetry = true;
    });
    try {
      await ObservabilityService.instance.setTelemetryEnabled(prefs, value);
    } finally {
      if (mounted) setState(() => _savingTelemetry = false);
    }
  }

  void _openDocument(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _LegalDocumentScreen(title: title, body: body),
      ),
    );
  }

  Future<void> _copyPublicUrl(String? url) async {
    final l10n = AppLocalizations.of(context);
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.legalPublicUrlNotConfigured)),
      );
      return;
    }
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.legalPublicUrlCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prefs = ref.watch(sharedPreferencesProvider);
    final telemetryOn =
        _telemetryOverride ?? TelemetryPreference.isEnabled(prefs);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.legalCenterTitle)),
      body: ListView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
        children: [
          Text(
            l10n.legalPolicyVersion(LegalDocuments.policyVersion),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: Text(l10n.legalPrivacyPolicy),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDocument(
                    l10n.legalPrivacyPolicy,
                    LegalDocuments.privacy(turkish: _turkish),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: Text(l10n.legalTermsOfUse),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDocument(
                    l10n.legalTermsOfUse,
                    LegalDocuments.terms(turkish: _turkish),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(l10n.legalCommunityGuidelines),
                  subtitle: Text(
                    l10n.legalCommunityVersion(LegalDocuments.communityVersion),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDocument(
                    l10n.legalCommunityGuidelines,
                    LegalDocuments.community(turkish: _turkish),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.bug_report_outlined),
              title: Text(l10n.legalTelemetryTitle),
              subtitle: Text(l10n.legalTelemetrySubtitle),
              value: telemetryOn,
              onChanged: _savingTelemetry
                  ? null
                  : (v) => _setTelemetry(v),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.legalCopyPublicPrivacyUrl),
              subtitle: Text(
                LegalDocuments.hasPublicLegalSite
                    ? (LegalDocuments.publicUrl(
                          _turkish
                              ? 'legal/privacy-tr.html'
                              : 'legal/privacy-en.html',
                        ) ??
                        '')
                    : l10n.legalPublicUrlNotConfigured,
              ),
              onTap: () => _copyPublicUrl(
                LegalDocuments.publicUrl(
                  _turkish ? 'legal/privacy-tr.html' : 'legal/privacy-en.html',
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.legalDeletionNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: getSafePadding(
          context,
          const EdgeInsets.fromLTRB(16, 12, 16, 24),
        ),
        child: SelectableText(
          body,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

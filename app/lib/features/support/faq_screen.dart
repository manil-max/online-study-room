import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_locale.dart';
import '../../data/models/faq_entry.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/support_providers.dart';
import '../../data/repositories/in_memory/in_memory_support_repository.dart';
import '../../l10n/app_localizations.dart';

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(faqEntriesProvider);
    final isSignedIn = ref.watch(authStateProvider).value != null;
    final locale = ref.watch(appLanguageProvider) == AppLanguage.english
        ? 'en'
        : 'tr';
    final serverEntries = switch (entries) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final fallback = entries.hasError;
    final visible = _filter(
      serverEntries ??
          kFallbackFaq.where((entry) => entry.locale == locale).toList(),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: l10n.faqSearch,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (fallback)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.faqOfflineFallback,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: entries.isLoading && serverEntries == null
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(child: Text(l10n.faqNoResults))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final entry = visible[index];
                      return Card(
                        child: ExpansionTile(
                          title: Text(entry.question),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(entry.answer),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton.icon(
              onPressed: () =>
                  isSignedIn ? _askQuestion() : _showLoginRequired(),
              icon: const Icon(Icons.question_answer_outlined),
              label: Text(l10n.faqAskQuestion),
            ),
          ),
        ],
      ),
    );
  }

  List<FaqEntry> _filter(List<FaqEntry> entries) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return entries;
    return entries
        .where(
          (entry) =>
              '${entry.question} ${entry.answer}'.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _showLoginRequired() async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.faqLoginRequired)));
  }

  Future<void> _askQuestion() async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    final question = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.faqAskQuestion),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 1200,
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(hintText: l10n.faqAskQuestionHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gönder'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (question == null || question.isEmpty || !mounted) return;
    try {
      await ref.read(submitFaqQuestionProvider)(question);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.faqQuestionSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.faqQuestionFailed)));
      }
    }
  }
}

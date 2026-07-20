import 'package:flutter/material.dart';

import '../../core/config/app_build_manifest.dart';
import '../../core/config/build_identity_card.dart';
import '../../l10n/app_localizations.dart';
import 'release_notes_service.dart';

Future<void> maybeShowWhatsNewDialog(BuildContext context) async {
  final service = ReleaseNotesService();
  final state = await service.currentReleaseState();
  if (!context.mounted) return;

  final shouldShow = await service.shouldShowWhatsNew(
    currentBuildNumber: state.buildNumber,
  );
  if (!shouldShow) return;

  await service.markBuildSeen(state.buildNumber);
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => WhatsNewDialog(
      note: state.note,
      fallbackVersion:
          '${state.versionName}+${state.buildNumber} ${state.channel}',
    ),
  );
}

class ReleaseNotesScreen extends StatefulWidget {
  const ReleaseNotesScreen({super.key, this.service, this.buildManifest});

  final ReleaseNotesService? service;
  final AppBuildManifest? buildManifest;

  @override
  State<ReleaseNotesScreen> createState() => _ReleaseNotesScreenState();
}

class _ReleaseNotesScreenState extends State<ReleaseNotesScreen> {
  // Future build() içinde yeniden yaratılırsa CircularProgressIndicator
  // her karede FutureBuilder'ı sıfırlar → pumpAndSettle sonsuza gider.
  late final Future<List<ReleaseNote>> _notesFuture =
      (widget.service ?? ReleaseNotesService()).loadBundledNotes();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.updaterGuncellemeNotlari)),
      body: FutureBuilder<List<ReleaseNote>>(
        future: _notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                BuildIdentityCard(
                  manifest:
                      widget.buildManifest ?? AppBuildManifest.currentOrNull,
                ),
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ],
            );
          }

          final notes = snapshot.data ?? const [];
          if (notes.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                BuildIdentityCard(
                  manifest:
                      widget.buildManifest ?? AppBuildManifest.currentOrNull,
                ),
                const SizedBox(height: 24),
                Center(child: Text(l10n.updaterHenuzGosterilecekSurumNotu)),
              ],
            );
          }

          final locale = Localizations.localeOf(context);
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notes.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return BuildIdentityCard(
                  manifest:
                      widget.buildManifest ?? AppBuildManifest.currentOrNull,
                );
              }
              return ReleaseNoteCard(note: notes[index - 1].forLocale(locale));
            },
          );
        },
      ),
    );
  }
}

class WhatsNewDialog extends StatelessWidget {
  const WhatsNewDialog({
    super.key,
    required this.note,
    required this.fallbackVersion,
  });

  final ReleaseNote? note;
  final String fallbackVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final shownNote = note?.forLocale(locale);
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shownNote == null
                  ? l10n.updaterYenilikler
                  : '${l10n.updaterYenilikler}: ${shownNote.versionName}',
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: shownNote == null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(fallbackVersion),
                  const SizedBox(height: 8),
                  Text(l10n.updaterBuSurumIcinDetayli),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(shownNote.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _ReleaseNoteSection(
                    title: l10n.updaterOneCikanlar,
                    items: shownNote.highlights,
                  ),
                  _ReleaseNoteSection(
                    title: l10n.updaterDuzeltmeler,
                    items: shownNote.fixes,
                  ),
                  _ReleaseNoteSection(
                    title: l10n.updaterNotlar,
                    items: shownNote.notes,
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.updaterTamam),
        ),
      ],
    );
  }
}

class ReleaseNoteCard extends StatelessWidget {
  const ReleaseNoteCard({super.key, required this.note});

  final ReleaseNote note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final channelColor = note.channel == 'beta'
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${note.versionName}+${note.buildNumber} • ${note.date}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    note.channel == 'beta'
                        ? l10n.updaterBeta
                        : l10n.updaterStable,
                  ),
                  labelStyle: TextStyle(color: channelColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReleaseNoteSection(
              title: l10n.updaterYenilikler,
              items: note.highlights,
            ),
            _ReleaseNoteSection(
              title: l10n.updaterDuzeltmeler,
              items: note.fixes,
            ),
            _ReleaseNoteSection(title: l10n.updaterNotlar, items: note.notes),
          ],
        ),
      ),
    );
  }
}

class _ReleaseNoteSection extends StatelessWidget {
  const _ReleaseNoteSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(l10n.updaterItem(item)),
            ),
        ],
      ),
    );
  }
}

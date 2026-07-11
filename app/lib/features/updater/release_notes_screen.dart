import 'package:flutter/material.dart';

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

class ReleaseNotesScreen extends StatelessWidget {
  const ReleaseNotesScreen({super.key, this.service});

  final ReleaseNotesService? service;

  @override
  Widget build(BuildContext context) {
    final notesFuture = (service ?? ReleaseNotesService()).loadBundledNotes();

    return Scaffold(
      appBar: AppBar(title: const Text('Güncelleme notları')),
      body: FutureBuilder<List<ReleaseNote>>(
        future: notesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final notes = snapshot.data ?? const [];
          if (notes.isEmpty) {
            return const Center(
              child: Text('Henüz gösterilecek sürüm notu yok.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) => ReleaseNoteCard(note: notes[index]),
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
    final shownNote = note;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.auto_awesome),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              shownNote == null
                  ? 'Yenilikler'
                  : 'Yenilikler: ${shownNote.versionName}',
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: shownNote == null
            ? Text(
                '$fallbackVersion sürümüne geçtin. '
                'Bu sürüm için detaylı notlar yakında eklenecek.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    shownNote.title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _ReleaseNoteSection(
                    title: 'Öne çıkanlar',
                    items: shownNote.highlights,
                  ),
                  _ReleaseNoteSection(
                    title: 'Düzeltmeler',
                    items: shownNote.fixes,
                  ),
                  _ReleaseNoteSection(
                    title: 'Notlar',
                    items: shownNote.notes,
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tamam'),
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
                  label: Text(note.channel == 'beta' ? 'Beta' : 'Stable'),
                  labelStyle: TextStyle(color: channelColor),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ReleaseNoteSection(title: 'Yenilikler', items: note.highlights),
            _ReleaseNoteSection(title: 'Düzeltmeler', items: note.fixes),
            _ReleaseNoteSection(title: 'Notlar', items: note.notes),
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
              child: Text('• $item'),
            ),
        ],
      ),
    );
  }
}

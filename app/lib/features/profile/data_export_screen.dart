import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/providers/auth_providers.dart';
import '../../data/providers/data_export_providers.dart';
import '../../data/providers/gamification_providers.dart';
import '../../data/providers/study_providers.dart';
import '../../data/providers/subject_providers.dart';
import '../../data/repositories/data_export_repository.dart';
import '../../data/repositories/in_memory/in_memory_data_export_repository.dart';

/// WP-152: kendi verisini JSON dışa aktar + paylaş.
class DataExportScreen extends ConsumerStatefulWidget {
  const DataExportScreen({super.key});

  @override
  ConsumerState<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends ConsumerState<DataExportScreen> {
  DataExportRange _range = DataExportRange.hot90;
  bool _busy = false;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      _snack(l10n.exportFailed);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(dataExportRepositoryProvider);
      if (repo is InMemoryDataExportRepository) {
        final sessions =
            ref.read(userSessionsProvider).asData?.value ?? const [];
        final subjects =
            ref.read(userSubjectsProvider).asData?.value ?? const [];
        final summary = ref.read(userStudySummaryProvider).asData?.value;
        final xp =
            ref.read(gamificationSummaryProvider).asData?.value?.profile.xp;
        repo.seed(
          userId: user.id,
          profile: {
            'display_name': user.displayName,
            'daily_goal_minutes': user.dailyGoalMinutes,
            'animal': user.animal,
          },
          sessionList: sessions,
          subjectList: subjects,
          summary: summary,
          xp: xp ?? 0,
        );
      }

      final bundle = await repo.buildExport(userId: user.id, range: _range);
      if (bundle.sessionCount == 0 &&
          (bundle.payload['subjects'] as List?)?.isEmpty != false &&
          bundle.payload['profile'] == null) {
        _snack(l10n.exportEmpty);
        return;
      }

      final json = const JsonEncoder.withIndent('  ').convert(bundle.payload);
      if (kIsWeb) {
        await SharePlus.instance.share(
          ShareParams(text: json, subject: l10n.exportMyData),
        );
      } else {
        final dir = await getTemporaryDirectory();
        final idPart =
            user.id.length >= 8 ? user.id.substring(0, 8) : user.id;
        final file = File('${dir.path}/odak-kampi-export-$idPart.json');
        await file.writeAsString(json);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'application/json')],
            subject: l10n.exportMyData,
          ),
        );
      }
      if (mounted) _snack(l10n.exportSuccess);
    } catch (_) {
      if (mounted) _snack(l10n.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportMyData)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l10n.exportMyDataSubtitle),
          const SizedBox(height: 16),
          Text(
            l10n.exportRangeLabel,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final r in DataExportRange.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _range == r
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(switch (r) {
                DataExportRange.hot90 => l10n.exportRangeHot,
                DataExportRange.year => l10n.exportRangeYear,
                DataExportRange.all => l10n.exportRangeAll,
              }),
              onTap: _busy ? null : () => setState(() => _range = r),
              minVerticalPadding: 12,
            ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: l10n.exportMyData,
            child: FilledButton.icon(
              onPressed: _busy ? null : _export,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: Text(_busy ? l10n.exportInProgress : l10n.exportMyData),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

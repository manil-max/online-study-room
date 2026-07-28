import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';
import '../models/moderation_queue_report.dart';
import '../widgets/moderation_queue_card.dart';

/// WP-424: UGC rapor kuyruğu (super-admin, RLS) — ad + avatar ve güvenli ID.
class AdminModerationTab extends ConsumerStatefulWidget {
  const AdminModerationTab({super.key});

  @override
  ConsumerState<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends ConsumerState<AdminModerationTab> {
  late Future<List<ModerationQueueReport>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ModerationQueueReport>> _load() async {
    if (!SupabaseConfig.isConfigured) return const [];
    final client = Supabase.instance.client;
    final rawRows =
        await client
                .from('ugc_reports')
                .select()
                .order('created_at', ascending: false)
                .limit(100)
            as List;
    final rows = [
      for (final row in rawRows) Map<String, dynamic>.from(row as Map),
    ];
    final reporterIds = rows.map((row) => row['reporter_id'] as String).toSet();
    final directTargetIds = rows
        .where(
          (row) =>
              row['target_type'] == 'user' || row['target_type'] == 'profile',
        )
        .map((row) => row['target_id'] as String)
        .where(_looksLikeUuid)
        .toSet();
    final messageIds = rows
        .where((row) => row['target_type'] == 'message')
        .map((row) => row['target_id'] as String)
        .where(_looksLikeUuid)
        .toList();
    final messageOwners = <String, String>{};
    if (messageIds.isNotEmpty) {
      final messages =
          await client
                  .from('class_messages')
                  .select('id,user_id')
                  .inFilter('id', messageIds)
              as List;
      for (final message in messages) {
        final map = Map<String, dynamic>.from(message as Map);
        messageOwners[map['id'] as String] = map['user_id'] as String;
      }
    }
    final profileIds = {
      ...reporterIds,
      ...directTargetIds,
      ...messageOwners.values,
    };
    final profiles = <String, ModerationQueueIdentity>{};
    if (profileIds.isNotEmpty) {
      final profileRows =
          await client
                  .from('profiles')
                  .select('id,display_name,avatar_url')
                  .inFilter('id', profileIds.toList())
              as List;
      for (final profile in profileRows) {
        final map = Map<String, dynamic>.from(profile as Map);
        final id = map['id'] as String;
        profiles[id] = ModerationQueueIdentity(
          id: id,
          displayName:
              (map['display_name'] as String?)?.trim().isNotEmpty == true
              ? (map['display_name'] as String).trim()
              : '',
          avatarUrl: map['avatar_url'] as String?,
        );
      }
    }
    return rows
        .map((row) {
          final reporterId = row['reporter_id'] as String;
          final targetId = row['target_id'] as String;
          final targetProfileId = switch (row['target_type'] as String) {
            'user' || 'profile' => targetId,
            'message' => messageOwners[targetId],
            _ => null,
          };
          return ModerationQueueReport(
            id: row['id'] as String,
            targetType: row['target_type'] as String,
            reason: row['reason'] as String,
            status: row['status'] as String,
            contentSnapshot: row['content_snapshot'] as String?,
            reporter: profiles[reporterId] ?? _deletedIdentity(reporterId),
            target: targetProfileId == null
                ? _deletedIdentity(targetId)
                : profiles[targetProfileId] ??
                      _deletedIdentity(targetProfileId),
          );
        })
        .toList(growable: false);
  }

  ModerationQueueIdentity _deletedIdentity(String id) =>
      ModerationQueueIdentity(id: id, displayName: '', isDeleted: true);

  static bool _looksLikeUuid(String value) => RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);

  Future<void> _setStatus(String id, String status) async {
    if (!SupabaseConfig.isConfigured) return;
    await Supabase.instance.client
        .from('ugc_reports')
        .update({
          'status': status,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<ModerationQueueReport>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snap.data ?? const [];
          if (reports.isEmpty) {
            return Center(
              child: Text(AppLocalizations.of(context).adminUgcNoReports),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.separated(
              itemCount: reports.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) => ModerationQueueCard(
                report: reports[index],
                onStatusSelected: (status) =>
                    _setStatus(reports[index].id, status),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) =>
                      _ModerationDetailSheet(reportId: reports[index].id),
                ),
              ),
            ),
          );
        },
      );
}

class _ModerationDetailSheet extends StatelessWidget {
  const _ModerationDetailSheet({required this.reportId});

  final String reportId;

  Future<Map<String, dynamic>> _load() async {
    final result = await Supabase.instance.client.rpc(
      'admin_ugc_report_detail',
      params: {'p_report_id': reportId},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .9,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Icon(Icons.error_outline));
          }
          final detail = snapshot.data!;
          final report = Map<String, dynamic>.from(detail['report'] as Map);
          final contextRows = (detail['context'] as List? ?? const []).map(
            (row) => Map<String, dynamic>.from(row as Map),
          );
          final history = Map<String, dynamic>.from(detail['history'] as Map);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SelectableText(
                (report['content_snapshot'] as String?) ?? '',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if ((report['details'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                SelectableText(report['details'] as String),
              ],
              const Divider(height: 32),
              for (final row in contextRows)
                ListTile(
                  dense: true,
                  title: Text((row['display_name'] as String?) ?? ''),
                  subtitle: Text((row['body'] as String?) ?? ''),
                  selected: row['is_target'] == true,
                ),
              const Divider(height: 32),
              Text('${history['report_count'] ?? 0}'),
              for (final sanction
                  in (history['sanctions'] as List? ?? const []))
                Text((sanction as Map)['reason'] as String? ?? ''),
            ],
          );
        },
      ),
    ),
  );
}

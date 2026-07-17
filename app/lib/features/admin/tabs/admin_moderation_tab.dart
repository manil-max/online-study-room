import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/supabase_config.dart';

/// WP-117: UGC rapor kuyruğu (super-admin, RLS).
class AdminModerationTab extends ConsumerStatefulWidget {
  const AdminModerationTab({super.key});

  @override
  ConsumerState<AdminModerationTab> createState() => _AdminModerationTabState();
}

class _AdminModerationTabState extends ConsumerState<AdminModerationTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    if (!SupabaseConfig.isConfigured) return const [];
    final rows = await Supabase.instance.client
        .from('ugc_reports')
        .select()
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final r in rows as List)
        Map<String, dynamic>.from(r as Map),
    ];
  }

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
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snap.data ?? const [];
        if (rows.isEmpty) {
          return const Center(child: Text('UGC rapor yok / No UGC reports'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _future = _load());
            await _future;
          },
          child: ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = rows[i];
              return ListTile(
                title: Text('${r['target_type']} · ${r['reason']}'),
                subtitle: Text(
                  '${r['status']} · ${r['target_id']}\n${r['content_snapshot'] ?? ''}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (s) => _setStatus(r['id'] as String, s),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'in_review', child: Text('In review')),
                    PopupMenuItem(value: 'resolved', child: Text('Resolved')),
                    PopupMenuItem(value: 'rejected', child: Text('Rejected')),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

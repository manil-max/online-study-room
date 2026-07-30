import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/moderation_case.dart';
import '../../models/report_target.dart';
import '../admin_moderation_repository.dart';

/// WP-440: Kuyruğun sunucu tarafı.
///
/// Vaka listesi `admin_ugc_report_groups()`, durum yazımı
/// `admin_set_ugc_report_group_status()` RPC'lerinden gelir; ekran hiçbir
/// tabloya doğrudan dokunmaz. Kimlik çözümü (ad/avatar) bu katmanda kalır,
/// çünkü grup RPC'si yalnız kimlik döndürür.
class SupabaseAdminModerationRepository implements AdminModerationRepository {
  SupabaseAdminModerationRepository(this._client);

  final SupabaseClient _client;

  static const int _queueLimit = 100;

  @override
  Future<List<ModerationCase>> fetchQueue() async {
    final List<dynamic> groups;
    try {
      groups = await _client.rpc('admin_ugc_report_groups') as List;
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
    if (groups.isEmpty) return const [];

    final rows = [
      for (final raw in groups.take(_queueLimit))
        Map<String, dynamic>.from(raw as Map),
    ];

    // Raporlayanlar ve mesaj sahipleri grup RPC'sinde yok; vaka kartı için
    // rapor satırlarından çözülür.
    final reportIds = <String>[
      for (final row in rows)
        ...((row['report_ids'] as List?) ?? const []).cast<String>(),
    ];
    final reportRows = await _fetchReportRows(reportIds);

    final messageIds = <String>{
      for (final row in rows)
        if (row['target_type'] == 'message' &&
            _looksLikeUuid(row['target_id'] as String))
          row['target_id'] as String,
    };
    final messageOwners = await _fetchMessageOwners(messageIds);

    final profileIds = <String>{
      for (final report in reportRows.values) report.reporterId,
      ...messageOwners.values,
      for (final row in rows)
        if (_isProfileTarget(row['target_type'] as String) &&
            _looksLikeUuid(row['target_id'] as String))
          row['target_id'] as String,
    };
    final profiles = await _fetchProfiles(profileIds);

    ModerationIdentity identity(String id) =>
        profiles[id] ?? ModerationIdentity.unresolved(id);

    final cases = <ModerationCase>[];
    for (final row in rows) {
      final targetType = row['target_type'] as String;
      final targetId = row['target_id'] as String;
      final ids = ((row['report_ids'] as List?) ?? const []).cast<String>();

      final ReportTargetType type;
      final ModerationCaseStatus status;
      try {
        type = ReportTargetType.fromWire(targetType);
        status = ModerationCaseStatus.fromWire(row['status'] as String);
      } on ArgumentError {
        // Bilinmeyen/bozuk satır tüm kuyruğu düşürmez, atlanır.
        continue;
      }

      final targetProfileId = _isProfileTarget(targetType)
          ? targetId
          : messageOwners[targetId];

      cases.add(
        ModerationCase(
          targetType: type,
          targetId: targetId,
          targetIdentity:
              targetProfileId == null ? null : identity(targetProfileId),
          status: status,
          reportCount: (row['report_count'] as num?)?.toInt() ?? ids.length,
          reasons: ((row['reasons'] as List?) ?? const []).cast<String>(),
          latestAt:
              DateTime.tryParse(row['latest_at'] as String? ?? '')?.toLocal() ??
                  DateTime.now(),
          reporters: [
            for (final id in ids)
              if (reportRows[id] != null) identity(reportRows[id]!.reporterId),
          ],
          reportIds: ids,
        ),
      );
    }
    return cases;
  }

  @override
  Future<int> setCaseStatus({
    required ModerationCase moderationCase,
    required ModerationCaseStatus status,
  }) async {
    if (!status.writable) {
      // `admin_set_ugc_report_group_status` `open` kabul etmiyor; sessizce
      // başka duruma çevirmek yöneticiye yalan söylemek olurdu.
      throw const ModerationException(
        'Vakayı yeniden açma sunucuda henüz tanımlı değil.',
      );
    }
    try {
      final affected = await _client.rpc(
        'admin_set_ugc_report_group_status',
        params: {
          'p_target_type': moderationCase.targetType.wire,
          'p_target_id': moderationCase.targetId,
          'p_status': status.wire,
        },
      );
      return (affected as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<ModerationCaseDetail> fetchDetail(String reportId) async {
    final Map<String, dynamic> detail;
    try {
      final result = await _client.rpc(
        'admin_ugc_report_detail',
        params: {'p_report_id': reportId},
      );
      detail = Map<String, dynamic>.from(result as Map);
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
    final report = Map<String, dynamic>.from(detail['report'] as Map);
    final history = Map<String, dynamic>.from(
      (detail['history'] as Map?) ?? const {},
    );
    return ModerationCaseDetail(
      snapshot: (report['content_snapshot'] as String?) ?? '',
      details: report['details'] as String?,
      contextMessages: [
        for (final raw in (detail['context'] as List? ?? const []))
          if (raw is Map)
            ModerationContextMessage(
              displayName: (raw['display_name'] as String?) ?? '',
              body: (raw['body'] as String?) ?? '',
              isTarget: raw['is_target'] == true,
            ),
      ],
      reportCount: (history['report_count'] as num?)?.toInt() ?? 0,
      sanctionReasons: [
        for (final raw in (history['sanctions'] as List? ?? const []))
          if (raw is Map && raw['reason'] is String) raw['reason'] as String,
      ],
    );
  }

  Future<Map<String, _ReportRow>> _fetchReportRows(List<String> ids) async {
    final unique = ids.where(_looksLikeUuid).toSet().toList();
    if (unique.isEmpty) return const {};
    final rows = await _client
        .from('ugc_reports')
        .select('id,reporter_id')
        .inFilter('id', unique) as List;
    return {
      for (final raw in rows)
        (raw as Map)['id'] as String: _ReportRow(
          reporterId: raw['reporter_id'] as String,
        ),
    };
  }

  Future<Map<String, String>> _fetchMessageOwners(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('class_messages')
        .select('id,user_id')
        .inFilter('id', ids.toList()) as List;
    return {
      for (final raw in rows)
        (raw as Map)['id'] as String: raw['user_id'] as String,
    };
  }

  Future<Map<String, ModerationIdentity>> _fetchProfiles(
    Set<String> ids,
  ) async {
    final unique = ids.where(_looksLikeUuid).toList();
    if (unique.isEmpty) return const {};
    final rows = await _client
        .from('profiles')
        .select('id,display_name,avatar_url')
        .inFilter('id', unique) as List;
    return {
      for (final raw in rows)
        (raw as Map)['id'] as String: ModerationIdentity(
          id: raw['id'] as String,
          displayName: ((raw['display_name'] as String?) ?? '').trim(),
          avatarUrl: raw['avatar_url'] as String?,
        ),
    };
  }

  static bool _isProfileTarget(String targetType) =>
      targetType == 'user' || targetType == 'profile';

  static bool _looksLikeUuid(String value) => RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        caseSensitive: false,
      ).hasMatch(value);
}

class _ReportRow {
  const _ReportRow({required this.reporterId});
  final String reporterId;
}

import '../../models/admin_user_insight.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/moderation_appeal.dart';
import '../../models/moderation_case.dart';
import '../../models/moderation_sanction.dart';
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
  Future<int> reconcileStaleSanctions() async {
    try {
      final affected = await _client.rpc(
        'admin_reconcile_moderation_sanctions',
      );
      return (affected as num?)?.toInt() ?? 0;
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<List<ModerationCase>> fetchQueue() async {
    // WP-629: kuyruk açılışı uzlaştırmayı tetikler. Burası tek doğal tetik:
    // fonksiyon `is_super_admin()` istiyor, yani cron/service-role ile
    // koşturulamaz; bir yöneticinin oturumundan çağrılması ŞART.
    //
    // 🔴 Hata YUTULUR ve bu bilinçlidir: uzlaştırma bakım işidir, kuyruğun
    // görünmesini engellememeli. Bu, deponun genel "sessiz başarısızlık yasak"
    // kuralının istisnasıdır çünkü kullanıcının istediği iş (kuyruğu gör)
    // başarısız olmuyor; yan iş bir sonraki açılışta yeniden denenir.
    try {
      await reconcileStaleSanctions();
    } on ModerationException {
      // yut: aşağıdaki asıl okuma kendi hatasını bildirir.
    }

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
          caseId: row['case_id'] as String?,
          severity: ModerationSeverity.fromWire(row['severity'] as String?),
          slaDueAt: DateTime.tryParse(
            row['sla_due_at'] as String? ?? '',
          )?.toLocal(),
          quarantined: row['quarantined'] == true,
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
    final attachment = (report['attachment_path'] as String?)?.trim();
    return ModerationCaseDetail(
      snapshot: (report['content_snapshot'] as String?) ?? '',
      details: report['details'] as String?,
      // 🔴 WP-B: bu dört alan sunucudan `0097`ten beri geliyordu ve burada
      // sessizce atiliyordu (`ADMIN-PANEL-PLAN.md` §2.1).
      attachmentPath: (attachment == null || attachment.isEmpty)
          ? null
          : attachment,
      reason: report['reason'] as String?,
      createdAt: DateTime.tryParse(
        report['created_at'] as String? ?? '',
      )?.toLocal(),
      status: report['status'] as String?,
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
      // Eskiden yalnız `reason` alınıyordu; `action` ve `created_at` atılıyordu.
      sanctions: [
        for (final raw in (history['sanctions'] as List? ?? const []))
          if (raw is Map)
            ModerationSanctionHistoryEntry(
              action: raw['action'] as String?,
              reason: raw['reason'] as String?,
              createdAt: DateTime.tryParse(
                raw['created_at'] as String? ?? '',
              )?.toLocal(),
            ),
      ],
    );
  }

  @override
  Future<ModerationSanction> applySanction(
    ModerationSanctionRequest request,
  ) async {
    if (!request.isValid) {
      throw const ModerationException('Gerekçe ve hedef zorunludur.');
    }
    // Üç adım (aç → auth → kapat) sunucuda, tek Edge Function çağrısında
    // koşar. İstemci arada ölürse satır `pending` kalır ve uzlaştırma onu
    // temizler; kullanıcı yarım durumda cezalı kalmaz.
    try {
      final response = await _client.functions.invoke(
        'admin-user-actions',
        body: {
          ...request.toFunctionBody(),
          'action': 'moderation_sanction',
          'sanctionAction': request.action.wire,
        },
      );
      if (response.status != 200) {
        throw ModerationException('Yaptırım uygulanamadı: ${response.data}');
      }
      return _sanctionFrom(response.data);
    } on FunctionException catch (e) {
      throw ModerationException('Servis hatası: ${e.details}');
    }
  }

  @override
  Future<ModerationSanction> revokeSanction({
    required String sanctionId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw const ModerationException('Gerekçe zorunludur.');
    }
    try {
      final response = await _client.functions.invoke(
        'admin-user-actions',
        body: {
          'action': 'moderation_revoke',
          'sanctionId': sanctionId,
          'reason': reason.trim(),
        },
      );
      if (response.status != 200) {
        throw ModerationException('Yaptırım geri alınamadı: ${response.data}');
      }
      return _sanctionFrom(response.data);
    } on FunctionException catch (e) {
      throw ModerationException('Servis hatası: ${e.details}');
    }
  }

  @override
  Future<List<ModerationSanction>> fetchSanctions(String targetUserId) async {
    try {
      final rows = await _client
          .from('moderation_sanctions')
          .select()
          .eq('target_user_id', targetUserId)
          .order('created_at', ascending: false) as List;
      return [
        for (final raw in rows)
          ModerationSanction.fromWire(Map<String, dynamic>.from(raw as Map)),
      ];
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<void> setQuarantine({
    required ModerationCase moderationCase,
    required bool quarantined,
    required String reason,
  }) async {
    final caseId = moderationCase.caseId;
    if (caseId == null) {
      // Vakaya bağlanmamış tarihsel rapor: sessizce hiçbir şey yapmak yerine
      // yöneticiye neden yapılamadığını söylüyoruz.
      throw const ModerationException(
        'Bu tarihsel kayıt vakaya bağlı değil; karantina uygulanamaz.',
      );
    }
    try {
      await _client.rpc(
        'admin_set_case_quarantine',
        params: {
          'p_case_id': caseId,
          'p_quarantined': quarantined,
          'p_reason': reason.trim(),
        },
      );
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<List<ModerationAppeal>> fetchAppeals() async {
    try {
      final rows = await _client.rpc('admin_moderation_appeals') as List;
      return [
        for (final raw in rows)
          ModerationAppeal.fromWire(Map<String, dynamic>.from(raw as Map)),
      ];
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<ModerationAppeal> decideAppeal({
    required ModerationAppeal appeal,
    required bool overturn,
    required String note,
  }) async {
    if (note.trim().isEmpty) {
      throw const ModerationException('Gerekçe zorunludur.');
    }
    if (!appeal.decidable) {
      // Sunucu da reddeder; buradaki kapı yöneticiye neden olduğunu söyler.
      throw const ModerationException(
        'Kendi verdiğin yaptırımın itirazını karara bağlayamazsın.',
      );
    }
    try {
      final row = await _client.rpc(
        'admin_decide_moderation_appeal',
        params: {
          'p_appeal_id': appeal.id,
          'p_outcome': overturn ? 'overturned' : 'upheld',
          'p_note': note.trim(),
        },
      );
      return ModerationAppeal.fromWire(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  /// WP-775: kullanıcının moderasyon dosyası.
  ///
  /// Tek RPC, çünkü ekran hepsini AYNI ANDA gösteriyor; parça parça çağırmak
  /// yarım dolu bir panel üretirdi.
  @override
  Future<AdminUserInsight> fetchUserInsight(String userId) async {
    try {
      final row = await _client.rpc(
        'admin_user_insight',
        params: {'p_user_id': userId},
      );
      return AdminUserInsight.fromWire(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  ModerationSanction _sanctionFrom(dynamic payload) {
    final data = payload is Map ? payload['data'] : null;
    if (data is! Map) {
      throw const ModerationException('Sunucu yanıtı okunamadı.');
    }
    return ModerationSanction.fromWire(Map<String, dynamic>.from(data));
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

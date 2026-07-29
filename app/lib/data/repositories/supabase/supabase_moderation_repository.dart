import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../models/report_target.dart';
import '../moderation_repository.dart';
import 'report_attachment_upload.dart';

/// WP-439: `report_ugc` RPC'sinin **dağıtılmış** parametre sözleşmesi.
///
/// Migration `0104` hedef doğrulama, bağlam grubu ve sunucu-üretimli snapshot
/// eklenene kadar istemci bu altı anahtarın dışına çıkamaz; PostgREST bilinmeyen
/// parametreyi "function not found" ile reddeder ve şikâyet sessizce kaybolur.
const Set<String> kReportUgcRpcParams = {
  'p_target_type',
  'p_target_id',
  'p_reason',
  'p_details',
  'p_snapshot',
  'p_attachment_path',
};

/// WP-439: sunucunun `0104` öncesinde kabul ettiği hedef türleri.
///
/// [ReportTargetType.groupName] burada **yok**: `group_name` türü `0104` ile
/// açılır. O zamana kadar `group`'a düşürmek grubun kendisiyle aynı vakaya
/// bağlanmak demek olurdu — WP-439'un düzelttiği hatanın ta kendisi. Bu yüzden
/// sessiz düşüş yerine fail-closed hata veriyoruz.
const Set<ReportTargetType> kReportTargetTypesLiveOnServer = {
  ReportTargetType.message,
  ReportTargetType.profile,
  ReportTargetType.group,
};

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<void> acceptCommunityTerms(String version) async {
    try {
      await _client.rpc(
        'accept_community_terms',
        params: {'p_version': version},
      );
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<void> blockUser(String userId) async {
    try {
      await _client.rpc('block_user', params: {'p_blocked_id': userId});
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<void> unblockUser(String userId) async {
    try {
      await _client.rpc('unblock_user', params: {'p_blocked_id': userId});
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }

  @override
  Future<List<String>> listBlockedUserIds() async {
    final rows = await _client.from('user_blocks').select('blocked_id');
    return [
      for (final r in rows as List) r['blocked_id'] as String,
    ];
  }

  @override
  Future<List<Profile>> fetchBlockedProfiles() async {
    final ids = await listBlockedUserIds();
    if (ids.isEmpty) return const [];

    // WP-413: `profiles` artık engelli çifti reddediyor, bu ekran oradan
    // okuyamaz. `blocked_user_directory` yalnız çağıranın KENDİ engellediklerini
    // gerçek adıyla döndürür — kullanıcı kimi engellediğini görebilsin diye.
    // Okunamayanlar yine maskeli id ile gösterilir (RPC'siz eski sunucu).
    Map<String, Profile> byId = {};
    try {
      final rows = await _client.rpc('blocked_user_directory');
      for (final raw in rows as List) {
        final map = Map<String, dynamic>.from(raw as Map);
        final p = Profile.fromMap(map);
        byId[p.id] = p;
      }
    } on PostgrestException {
      byId = {};
    }

    final out = <Profile>[];
    for (final id in ids) {
      final known = byId[id];
      if (known != null) {
        out.add(known);
      } else {
        out.add(
          Profile(
            id: id,
            displayName: id.length > 8 ? '${id.substring(0, 8)}…' : id,
            createdAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          ),
        );
      }
    }
    out.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return out;
  }

  @override
  Future<void> reportUgc({
    required ReportTarget target,
    required String reason,
    String? details,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  }) async {
    if (!kReportTargetTypesLiveOnServer.contains(target.type)) {
      throw const ModerationException(
        'Bu şikâyet türü henüz sunucuda açık değil.',
      );
    }
    // WP-423: ek opsiyoneldir. Yükleme başarısızsa `null` döner ve şikâyet
    // eksiz gider — ek yüzünden bildirim kaybolmaz.
    final attachmentPath = await uploadReportAttachment(
      _client,
      bytes: attachmentBytes,
      ext: attachmentExt,
    );
    try {
      await _client.rpc(
        'report_ugc',
        params: reportUgcRpcParams(
          target: target,
          reason: reason,
          details: details,
          attachmentPath: attachmentPath,
        ),
      );
    } on PostgrestException catch (e) {
      throw ModerationException(e.message);
    }
  }
}

/// WP-439: [ReportTarget] → `report_ugc` parametreleri.
///
/// Ayrı fonksiyon, sözleşmenin Supabase istemcisi olmadan test edilebilmesi
/// içindir. `context_group_id` bilerek gönderilmez: RPC onu `0104`te tanıyacak.
Map<String, dynamic> reportUgcRpcParams({
  required ReportTarget target,
  required String reason,
  String? details,
  String? attachmentPath,
}) {
  return {
    'p_target_type': target.type.wire,
    'p_target_id': target.id,
    'p_reason': reason,
    'p_details': details,
    // Doğrulanmamış istemci ipucu; `0104` sonrası kanıt yerine yalnız bağlam.
    'p_snapshot': target.clientHint,
    'p_attachment_path': attachmentPath,
  };
}

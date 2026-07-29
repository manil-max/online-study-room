import 'package:flutter/foundation.dart';

/// WP-439: Şikâyet hedefi sözleşmesi.
///
/// Bir rapor hedefi iki parçadan oluşur: **tür** ve **değişmez kimlik**. İkisi
/// birlikte tek bir kanonik anahtar üretir ([caseKey]); moderasyon kuyruğu açık
/// vakayı bu anahtarla tekilleştirir.
///
/// Aynı kimliğin iki farklı türü **ayrı hedeftir**: grubun kendisi
/// ([ReportTargetType.group]) ile grubun adı ([ReportTargetType.groupName])
/// aynı `group.id` değerini taşır ama asla aynı vakaya bağlanmaz. WP-439
/// öncesinde ikisi de `group` türüyle gönderildiği için tek satıra çöküyordu.
enum ReportTargetType {
  /// Grup sohbetindeki tek bir mesaj. Kimlik = `chat_messages.id`.
  message('message'),

  /// Bir kullanıcının sosyal profili. Kimlik = `profiles.id`.
  ///
  /// Sunucudaki tarihsel adı `user`'dı; [fromWire] eski satırları da okur ama
  /// istemci artık yalnız `profile` yazar.
  profile('profile'),

  /// Grubun kendisi (içerik/davranış bütünü). Kimlik = `study_groups.id`.
  group('group'),

  /// Yalnız grubun **adı**. Kimlik yine `study_groups.id`'dir; türü ayırmak
  /// vakayı ayırır.
  groupName('group_name');

  const ReportTargetType(this.wire);

  /// Sunucuya gönderilen sabit metin (`ugc_reports.target_type`).
  final String wire;

  /// Bu tür, hedef kimliğinin yanında bir **bağlam grubu** ister mi?
  ///
  /// Mesaj raporunda sunucu, raporlayanın o grupta gerçekten aktif üye
  /// olduğunu ve mesajı görebildiğini doğrulamak zorundadır; kimlik tek başına
  /// bunu kanıtlamaz.
  bool get requiresContextGroup => this == ReportTargetType.message;

  static ReportTargetType fromWire(String wire) {
    switch (wire) {
      case 'message':
        return ReportTargetType.message;
      case 'profile':
      case 'user': // 0038'den kalan tarihsel ad.
        return ReportTargetType.profile;
      case 'group':
        return ReportTargetType.group;
      case 'group_name':
        return ReportTargetType.groupName;
    }
    throw ArgumentError.value(wire, 'wire', 'bilinmeyen rapor hedef türü');
  }
}

/// Tek bir şikâyetin kime/neye açıldığını taşıyan değişmez değer nesnesi.
///
/// Doğrulama burada yapılır ki hatalı tür/kimlik çifti hiç ağa çıkmasın.
@immutable
class ReportTarget {
  const ReportTarget._({
    required this.type,
    required this.id,
    this.contextGroupId,
    this.clientHint,
  });

  /// Grup sohbetindeki tek mesaj. [groupId] sunucunun ortak üyelik ve
  /// görünürlük doğrulaması için zorunludur.
  factory ReportTarget.message({
    required String messageId,
    required String groupId,
    String? hint,
  }) {
    final id = _requireId(messageId, 'messageId');
    final gid = _requireId(groupId, 'groupId');
    if (id == gid) {
      throw ArgumentError.value(
        messageId,
        'messageId',
        'mesaj kimliği grup kimliğiyle aynı olamaz',
      );
    }
    return ReportTarget._(
      type: ReportTargetType.message,
      id: id,
      contextGroupId: gid,
      clientHint: _normalizeHint(hint),
    );
  }

  /// Bir kullanıcının sosyal profili.
  factory ReportTarget.profile({required String userId, String? hint}) {
    return ReportTarget._(
      type: ReportTargetType.profile,
      id: _requireId(userId, 'userId'),
      clientHint: _normalizeHint(hint),
    );
  }

  /// Grubun kendisi.
  factory ReportTarget.group({required String groupId, String? hint}) {
    return ReportTarget._(
      type: ReportTargetType.group,
      id: _requireId(groupId, 'groupId'),
      clientHint: _normalizeHint(hint),
    );
  }

  /// Yalnız grubun adı — [ReportTarget.group]'tan ayrı vakadır.
  factory ReportTarget.groupName({required String groupId, String? hint}) {
    return ReportTarget._(
      type: ReportTargetType.groupName,
      id: _requireId(groupId, 'groupId'),
      clientHint: _normalizeHint(hint),
    );
  }

  /// Sunucudan/depodan okunan satırı sözleşmeye geri çevirir.
  factory ReportTarget.fromWire(Map<String, dynamic> map) {
    final type = ReportTargetType.fromWire(map['target_type'] as String);
    final id = _requireId(map['target_id'] as String? ?? '', 'target_id');
    final contextGroupId = map['context_group_id'] as String?;
    final hint = map['client_hint'] as String?;
    switch (type) {
      case ReportTargetType.message:
        return ReportTarget.message(
          messageId: id,
          groupId: contextGroupId ?? '',
          hint: hint,
        );
      case ReportTargetType.profile:
        return ReportTarget.profile(userId: id, hint: hint);
      case ReportTargetType.group:
        return ReportTarget.group(groupId: id, hint: hint);
      case ReportTargetType.groupName:
        return ReportTarget.groupName(groupId: id, hint: hint);
    }
  }

  final ReportTargetType type;

  /// Hedefin değişmez kimliği. İçerik silinse bile bu kimlik değişmez;
  /// kanıt saklama (WP-442) bu kimliğe bağlanır.
  final String id;

  /// Yalnız [ReportTargetType.message] için dolu: mesajın yaşadığı grup.
  final String? contextGroupId;

  /// İstemcinin gördüğü metnin kısaltılmış kopyası.
  ///
  /// **Kanıt değildir.** Kullanıcı cihazından gelir, doğrulanamaz ve
  /// değiştirilebilir; yalnız yöneticinin "hangi içerikten bahsediyor"
  /// sorusuna hızlı yanıt verir. Kanonik snapshot'ı sunucu üretir.
  final String? clientHint;

  /// Açık vaka tekilliği için kanonik anahtar. Tür + kimlik birlikte.
  String get caseKey => '${type.wire}:$id';

  /// Taşıma-bağımsız sözleşme gösterimi.
  Map<String, dynamic> toWire() => {
        'target_type': type.wire,
        'target_id': id,
        if (contextGroupId != null) 'context_group_id': contextGroupId,
        if (clientHint != null) 'client_hint': clientHint,
      };

  static const int maxHintLength = 200;

  static String _requireId(String raw, String name) {
    final value = raw.trim();
    if (value.isEmpty) {
      throw ArgumentError.value(raw, name, 'hedef kimliği boş olamaz');
    }
    if (value.length > 64 || value.contains(RegExp(r'\s'))) {
      throw ArgumentError.value(raw, name, 'geçersiz hedef kimliği');
    }
    return value;
  }

  static String? _normalizeHint(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length > maxHintLength
        ? value.substring(0, maxHintLength)
        : value;
  }

  @override
  bool operator ==(Object other) =>
      other is ReportTarget &&
      other.type == type &&
      other.id == id &&
      other.contextGroupId == contextGroupId;

  @override
  int get hashCode => Object.hash(type, id, contextGroupId);

  @override
  String toString() => 'ReportTarget($caseKey)';
}

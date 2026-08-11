import 'package:flutter/foundation.dart';

/// WP-694 - sinav geri sayiminin **cihazlar arasi** kayit bicimi.
///
/// 🔴 Bu dosyanin varlik sebebi tek bir kullanici sikayeti: *"Sinav geri
/// sayiminda telefon ve tablette ayri ayri ayarlanmasi gerekiyor."* Olculdu ve
/// haklıydi: `dday_prefs.dart` yalnizca `SharedPreferences`'a yaziyordu,
/// `supabase/migrations/` icinde geri sayim tablosu yoktu. Yani ozellik eksikti.
///
/// [ExamCountdown] **tel uzerindeki** bicimdir; ekranin cizdigi bicim
/// (`ExamListState`) `features/home/dday_prefs.dart` icinde kalir. Ayrik
/// tutulmalarinin sebebi yon: veri katmani ekran katmanini **import etmez**.
@immutable
class ExamCountdown {
  const ExamCountdown({
    required this.id,
    required this.name,
    required this.day,
    required this.sortOrder,
    required this.isPriority,
    required this.updatedAt,
  });

  /// Kalici kimlik. **uuid degildir**: bu depoda geri sayim kayitlari buluttan
  /// once dogdu ve yerelde `legacy` / `<mikrosaniye>-<sayac>` bicimindeler.
  /// Kimlikleri uuid'e cevirmek yerel kayit ile bulut satirini birbirine
  /// baglayamaz hale getirir; ikinci senkronda ayni sinav **iki kez** gorunur.
  final String id;

  /// Ad istege baglidir; bos olabilir (arayuz varsayilan basligi gosterir).
  final String name;

  /// Takvim gunu - saat tasimaz.
  final DateTime day;

  final int sortOrder;
  final bool isPriority;

  /// Son yazmanin ani (UTC). Cakisma cozumu **bu alan uzerinden** yurur.
  final DateTime updatedAt;

  ExamCountdown copyWith({
    int? sortOrder,
    bool? isPriority,
    DateTime? updatedAt,
  }) => ExamCountdown(
    id: id,
    name: name,
    day: day,
    sortOrder: sortOrder ?? this.sortOrder,
    isPriority: isPriority ?? this.isPriority,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Sunucuya giden govde (RPC parametreleri tek yerden uretilir; cagri yeri
  /// ile sozlesme testi ayni fonksiyonu okur).
  Map<String, dynamic> toRpcParams() => {
    'p_id': id,
    'p_name': name,
    'p_exam_day': encodeCountdownDay(day),
    'p_sort_order': sortOrder,
    'p_is_priority': isPriority,
    'p_updated_at': updatedAt.toUtc().toIso8601String(),
  };

  /// Bozuk satir `null` doner ve **atlanir**: tek bozuk bulut satiri yuzunden
  /// kullanicinin diger sinavlari ekrandan silinmez.
  static ExamCountdown? fromRow(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || id.isEmpty) return null;
    final day = decodeCountdownDay(raw['exam_day'] ?? raw['day']);
    if (day == null) return null;
    final name = raw['name'];
    final sortOrder = raw['sort_order'] ?? raw['sortOrder'];
    final updated =
        _instant(raw['updated_at'] ?? raw['updatedAt']) ?? epochUpdatedAt;
    return ExamCountdown(
      id: id,
      name: name is String ? name : '',
      day: day,
      sortOrder: sortOrder is int ? sortOrder : 0,
      isPriority:
          (raw['is_priority'] ?? raw['isPriority']) == true,
      updatedAt: updated,
    );
  }

  static DateTime? _instant(Object? value) {
    if (value is DateTime) return value.toUtc();
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  @override
  bool operator ==(Object other) =>
      other is ExamCountdown &&
      other.id == id &&
      other.name == name &&
      other.day == day &&
      other.sortOrder == sortOrder &&
      other.isPriority == isPriority &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, day, sortOrder, isPriority, updatedAt);

  @override
  String toString() =>
      'ExamCountdown($id, $name, ${encodeCountdownDay(day)}, '
      '#$sortOrder, priority=$isPriority, @$updatedAt)';
}

/// Hic damgalanmamis (bulut oncesi) yerel kayitlarin damgasi.
///
/// Epoch secilir cunku bu kayitlar cakisma yarisini **kaybetmeli**: sunucudaki
/// satir her zaman daha yenidir. Bulutta esi olmayanlar zaten yarisa girmez,
/// dogrudan yukari itilir.
final DateTime epochUpdatedAt = DateTime.utc(1970);

String encodeCountdownDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

DateTime? decodeCountdownDay(Object? raw) {
  if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);
  if (raw is! String) return null;
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Uzlastirma sonucu: ne cizilecek, sunucuya ne yazilacak, ne dustu.
@immutable
class ExamSyncPlan {
  const ExamSyncPlan({
    required this.merged,
    required this.push,
    required this.deleteOnServer,
    required this.dropped,
    required this.syncedIds,
    required this.pendingDeletes,
  });

  /// Ekranin cizecegi liste (siniri asmayan, sirali).
  final List<ExamCountdown> merged;

  /// Sunucuya yazilmasi gereken yerel satirlar.
  final List<ExamCountdown> push;

  /// Sunucuda hala duran, yerelde silinmis kayitlar.
  final List<String> deleteOnServer;

  /// Sinir asimindan **dusen** kayitlar. Bos degilse cagiran bunu sayaca
  /// yazar: bu depoda sessiz veri kaybi tekrarlayan bir hata sinifidir.
  final List<ExamCountdown> dropped;

  /// Sunucunun bildigi kimlikler. Bir kimlik burada olup sunucu listesinde
  /// yoksa, o kayit **baska cihazda silinmistir** ve yerelden de dusmelidir.
  final Set<String> syncedIds;

  /// Cevrimdisiyken silinmis, sunucu henuz haberdar olmayan kimlikler.
  final Set<String> pendingDeletes;
}

/// İki cihazin listesini tek listeye indirger.
///
/// **Cakisma kurali - kayit basina son yazan kazanir (`updatedAt`).**
/// Gerekce, secenekleri tek tek eleyerek:
///
/// * *Liste basina* LWW olsaydi: telefonda adi degistirilen sinav ile tablette
///   eklenen sinavdan biri SESSIZCE giderdi. Kayit basina cozumde iki duzenleme
///   de yasar.
/// * *Birlesme (union), silme yok* olsaydi: bir cihazda silinen sinav digerinin
///   bayat kopyasindan geri dogardi (zombi). Bu yuzden [syncedIds] tutulur -
///   sunucunun bir kez bildigi kimlik sunucudan dustuyse yerelden de duser.
/// * *Cevrimdisi silmeyi yok saymak* olsaydi: ucakta silinen sinav inisde geri
///   gelirdi. Bu yuzden [pendingDeletes] tutulur ve sunucuya tasinir.
/// * *Esitlikte yerel kazansin* olsaydi: iki cihaz birbirine yakinsamaz, her
///   biri kendi kopyasinda israr ederdi. Esitlikte **sunucu** kazanir; boylece
///   her cihaz ayni satira iner.
///
/// Ilk senkronun ozel hali: bu WP'den once her cihaz ayni sinavi **farkli**
/// kimlikle sakliyordu. Ikisini de yukari itmek kullaniciya ayni sinavi iki kez
/// gosterir; bu yuzden bulutta ayni (ad, gun) ciftine sahip canli satir varsa
/// yerel ikiz itilmez.
ExamSyncPlan reconcileExamCountdowns({
  required List<ExamCountdown> local,
  required List<ExamCountdown> remote,
  required Set<String> syncedIds,
  required Set<String> pendingDeletes,
  required int maxEntries,
}) {
  final remoteIds = {for (final r in remote) r.id};
  final localById = {for (final l in local) l.id: l};

  final kept = <ExamCountdown>[];
  final push = <ExamCountdown>[];
  final deleteOnServer = <String>[];
  final stillPending = <String>{};

  // 1) Sunucudaki satirlar.
  for (final r in remote) {
    if (pendingDeletes.contains(r.id)) {
      // Cevrimdisiyken silinmis; sunucu henuz bilmiyor. Geri cizilmez.
      deleteOnServer.add(r.id);
      stillPending.add(r.id);
      continue;
    }
    final l = localById[r.id];
    if (l == null) {
      kept.add(r);
      continue;
    }
    if (l.updatedAt.isAfter(r.updatedAt)) {
      kept.add(l);
      push.add(l);
    } else {
      kept.add(r);
    }
  }

  // 2) Sunucuda karsiligi olmayan yerel satirlar.
  for (final l in local) {
    if (remoteIds.contains(l.id)) continue;
    if (pendingDeletes.contains(l.id)) continue;
    if (syncedIds.contains(l.id)) continue; // baska cihazda silinmis.
    if (kept.any((m) => _sameExam(m, l))) continue; // ilk senkron ikizi.
    kept.add(l);
    push.add(l);
  }

  // 3) Sira ve sinir. Sunucunun bildigi satirlar `sort_order` ile gelir; yerel
  //    yeni satirlar listenin sonuna eklendigi icin dogal olarak arkada kalir.
  kept.sort((a, b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    final stamp = a.updatedAt.compareTo(b.updatedAt);
    if (stamp != 0) return stamp;
    return a.id.compareTo(b.id);
  });
  final merged = kept.length > maxEntries ? kept.sublist(0, maxEntries) : kept;
  final dropped = kept.length > maxEntries
      ? kept.sublist(maxEntries)
      : const <ExamCountdown>[];
  final droppedIds = {for (final d in dropped) d.id};
  push.removeWhere((e) => droppedIds.contains(e.id));

  // 4) Tek oncelik. Iki cihaz ayri kayitlari one cikardiysa en yeni damga
  //    kazanir; digerleri temizlenir (arayuz iki "one cikan" cizemez).
  final priorities = [for (final e in merged) if (e.isPriority) e];
  ExamCountdown? winner;
  for (final e in priorities) {
    if (winner == null || e.updatedAt.isAfter(winner.updatedAt)) winner = e;
  }
  final normalized = <ExamCountdown>[];
  for (var i = 0; i < merged.length; i++) {
    final e = merged[i];
    final wantPriority = winner != null && e.id == winner.id;
    normalized.add(
      e.sortOrder == i && e.isPriority == wantPriority
          ? e
          : e.copyWith(sortOrder: i, isPriority: wantPriority),
    );
  }

  final nextSynced = {
    for (final r in remote)
      if (!pendingDeletes.contains(r.id)) r.id,
  };
  // Dusen kayitlar sunucunun bildigi kimlikler degildir; bir daha yukari
  // itilmesinler diye isaretlenmezler, ama yerelden de gitmis olurlar.

  return ExamSyncPlan(
    merged: normalized,
    push: push,
    deleteOnServer: deleteOnServer,
    dropped: dropped,
    syncedIds: nextSynced,
    pendingDeletes: stillPending,
  );
}

bool _sameExam(ExamCountdown a, ExamCountdown b) =>
    a.day == b.day && a.name.trim().toLowerCase() == b.name.trim().toLowerCase();

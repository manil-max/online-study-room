import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import '../../core/stats/istanbul_calendar.dart';
import '../../data/models/exam_countdown.dart';
import '../../data/providers/exam_countdown_providers.dart';
import '../../data/repositories/exam_countdown_repository.dart';

/// WP-575 — sınav geri sayımı için cihazda tutulan **tek** takvim tarihi.
///
/// WP-632 bunu **en fazla üç kayda** çıkardı; bu anahtar artık yalnız
/// **taşıma girdisi** olarak okunur ve asla silinmez (bkz. [ExamListNotifier]).
const kExamDateKey = 'dday.exam_date_v1';

/// WP-632 — sınav listesi (en fazla üç kayıt) + öne çıkarılan kaydın kimliği.
///
/// WP-694 aynı anahtara iki alan daha ekledi (`synced`, `deleted`); eski
/// sürümler bu alanları görmezden gelir, yeni sürüm yokluklarını boş küme
/// sayar. Yani biçim **ileri ve geri** uyumludur.
const kExamListKey = 'dday.exams_v2';

/// Aynı anda tutulabilecek en fazla sınav sayısı. Proje sahibi kararı
/// (2026-08-09): *"max 3 tane eklesin"*. `docs/URUN-POLITIKALARI.md` §8.1.
const int kMaxExamEntries = 3;

/// Gün anahtarını prefs biçimine çevirir (`2026-06-20`).
String encodeExamDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Prefs değerini gün anahtarına çevirir; bozuk/eksik değer `null` döner —
/// kart o zaman "tarih seçilmedi" dalına düşer, çökmez.
DateTime? decodeExamDay(String? raw) {
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// Tek bir sınav kaydı.
///
/// [name] **isteğe bağlıdır** (proje sahibi kararı): boş bırakılırsa arayüz
/// varsayılan bir başlık gösterir. Boş adı burada bir metinle doldurmuyoruz
/// çünkü o metin dile bağlıdır ve veri katmanı dil bilmez — diskte kalıcı bir
/// Türkçe kelime bırakmak, kullanıcı dili değiştirince yanlış görünürdü.
@immutable
class ExamEntry {
  const ExamEntry({
    required this.id,
    required this.name,
    required this.day,
    this.updatedAt,
  });

  /// Kalıcı kimlik. Öncelik bir **indeks** değil bu kimlik üzerinden tutulur:
  /// indeks tutulsaydı sıralama değişince ya da bir kayıt silinince öncelik
  /// sessizce başka bir sınava kayardı.
  final String id;
  final String name;
  final DateTime day;

  /// WP-694 — son yazmanın anı (UTC). Cihazlar arası çakışmayı bu alan çözer.
  ///
  /// `null` = bu kayıt buluttan **önce** yazılmış, hiç damgalanmamış. Böyle bir
  /// kayıt çakışma yarışını kaybeder ama kaybolmaz: sunucuda eşi yoksa yukarı
  /// itilir (bkz. `reconcileExamCountdowns`).
  final DateTime? updatedAt;

  ExamEntry copyWith({String? name, DateTime? day, DateTime? updatedAt}) =>
      ExamEntry(
        id: id,
        name: name ?? this.name,
        day: day == null ? this.day : DateTime(day.year, day.month, day.day),
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'day': encodeExamDay(day),
    if (updatedAt != null) 'updatedAt': updatedAt!.toUtc().toIso8601String(),
  };

  /// Bozuk satır `null` döner ve **atlanır**; tek bozuk kayıt yüzünden
  /// kullanıcının diğer sınavları kaybolmaz.
  static ExamEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final day = decodeExamDay(raw['day'] as String?);
    if (id is! String || id.isEmpty || day == null) return null;
    final name = raw['name'];
    final stamp = raw['updatedAt'];
    return ExamEntry(
      id: id,
      name: name is String ? name : '',
      day: day,
      updatedAt: stamp is String ? DateTime.tryParse(stamp)?.toUtc() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ExamEntry &&
      other.id == id &&
      other.name == name &&
      other.day == day &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(id, name, day, updatedAt);
}

/// Kartın çizeceği tam durum: sıra kullanıcıya ait, öncelik isteğe bağlı.
@immutable
class ExamListState {
  const ExamListState({
    this.entries = const [],
    this.priorityId,
    this.syncedIds = const {},
    this.pendingDeletes = const {},
  });

  /// Kullanıcının belirlediği sıra. Kart bu sırayı **aynen** kullanır.
  final List<ExamEntry> entries;

  /// Öne çıkarılan kaydın kimliği; `null` ise kart üç kaydı **eşit** gösterir.
  final String? priorityId;

  /// WP-694 — sunucunun bir kez bildiği kimlikler.
  ///
  /// Bu küme olmasaydı, bir cihazda silinen sınav diğerinin bayat kopyasından
  /// geri doğardı (zombi kayıt). Kimlik burada olup sunucu listesinde yoksa
  /// kayıt **başka cihazda silinmiştir** ve yerelden de düşer.
  final Set<String> syncedIds;

  /// WP-694 — çevrimdışıyken silinmiş, sunucuya henüz iletilememiş kimlikler.
  /// Bu küme olmasaydı uçakta silinen sınav inişte geri gelirdi.
  final Set<String> pendingDeletes;

  bool get isEmpty => entries.isEmpty;
  bool get canAdd => entries.length < kMaxExamEntries;

  /// Öne çıkarılan kayıt — kimlik listede yoksa `null` (silinmiş olabilir).
  ExamEntry? get priority {
    final id = priorityId;
    if (id == null) return null;
    for (final e in entries) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Öne çıkarılan dışındakiler, **kullanıcının sırasıyla**.
  List<ExamEntry> get others {
    final id = priority?.id;
    if (id == null) return entries;
    return [
      for (final e in entries)
        if (e.id != id) e,
    ];
  }

  ExamListState copyWith({
    List<ExamEntry>? entries,
    String? priorityId,
    bool clearPriority = false,
    Set<String>? syncedIds,
    Set<String>? pendingDeletes,
  }) => ExamListState(
    entries: entries ?? this.entries,
    priorityId: clearPriority ? null : (priorityId ?? this.priorityId),
    syncedIds: syncedIds ?? this.syncedIds,
    pendingDeletes: pendingDeletes ?? this.pendingDeletes,
  );
}

/// Seçilen sınav gününe kalan gün sayısı.
///
/// [examDay] kullanıcının seçtiği **takvim tarihi**dir; [now] bir **an**dır ve
/// ürünün tek gün sınırından — [istanbulDay] — geçirilir.
///
/// 🔴 Burada `examDay.difference(now).inDays` YAZILMAZ. İki değer farklı
/// türdedir ("gün" ve "an"), bu yüzden çıkan sayı cihaz saatine göre bir gün
/// oynar: UTC cihazda İstanbul 00:00–03:00 penceresinde bir gün **fazla**,
/// UTC+4 ve doğusunda İstanbul akşamında bir gün **eksik** çıkar. Tam bu hata
/// bu depoda iki kez üretime çıktı (WP-561 gün anahtarı çift çevrimi, WP-571
/// "Bugün özeti" kartının yanlış günü seçmesi).
int daysUntilExam({required DateTime examDay, required DateTime now}) {
  final today = istanbulDay(now);
  // Fark **takvim** farkıdır: iki uç da UTC'ye sabitlenir, böylece cihazın yaz
  // saati geçişindeki 23/25 saatlik günü `inDays` aşağı yuvarlayamaz.
  final from = DateTime.utc(today.year, today.month, today.day);
  final to = DateTime.utc(examDay.year, examDay.month, examDay.day);
  return to.difference(from).inDays;
}

/// Geri sayımın test edilebilir tek saat kaynağı (`userTaskClockProvider` ile
/// aynı desen).
final ddayClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Depodan okunan ham metni duruma çevirir; **taşıma burada yapılır**.
///
/// 🔴 Taşıma sözleşmesi: `v2` yoksa `v1`deki tek tarih **kaybolmadan** tek
/// kayda dönüşür. Bu depoda sessiz veri kaybı tekrarlayan bir hata sınıfıdır;
/// o yüzden taşıma ayrı ve saf bir fonksiyondur ve doğrudan test edilir.
ExamListState decodeExamList({required String? listRaw, String? legacyRaw}) {
  if (listRaw != null && listRaw.isNotEmpty) {
    Object? parsed;
    try {
      parsed = jsonDecode(listRaw);
    } on FormatException {
      parsed = null;
    }
    if (parsed is Map) {
      final rawEntries = parsed['entries'];
      final entries = <ExamEntry>[
        if (rawEntries is List)
          for (final raw in rawEntries) ?ExamEntry.fromJson(raw),
      ];
      final capped = entries.length > kMaxExamEntries
          ? entries.sublist(0, kMaxExamEntries)
          : entries;
      final rawPriority = parsed['priority'];
      final priorityId = rawPriority is String && rawPriority.isNotEmpty
          ? rawPriority
          : null;
      // Listede olmayan bir öncelik kimliği taşınmaz: kart o zaman "öne çıkan
      // var" sanıp boş dal çizerdi.
      final valid = capped.any((e) => e.id == priorityId) ? priorityId : null;
      return ExamListState(
        entries: capped,
        priorityId: valid,
        syncedIds: _idSet(parsed['synced']),
        pendingDeletes: _idSet(parsed['deleted']),
      );
    }
    // `v2` bozuk: sessizce boş dönmek kullanıcının sınavlarını yok saymaktır.
    // Taşıma girdisi hâlâ duruyorsa ona düşülür.
  }
  final legacy = decodeExamDay(legacyRaw);
  if (legacy == null) return const ExamListState();
  return ExamListState(
    entries: [ExamEntry(id: 'legacy', name: '', day: legacy)],
  );
}

Set<String> _idSet(Object? raw) => {
  if (raw is List)
    for (final id in raw)
      if (id is String && id.isNotEmpty) id,
};

String encodeExamList(ExamListState state) => jsonEncode({
  'entries': [for (final e in state.entries) e.toJson()],
  'priority': state.priorityId,
  'synced': state.syncedIds.toList(),
  'deleted': state.pendingDeletes.toList(),
});

/// Sadece bu oturumda artan sayaç.
///
/// 🔴 Kimlik önce yalnız `microsecondsSinceEpoch` ile üretiliyordu ve testte
/// **çakıştı**: art arda eklenen iki sınav aynı kimliği alabiliyor. Aynı kimlik
/// sessiz bir felakettir — silme iki kaydı birden götürür, öne çıkarma yanlış
/// sınava düşer. Zaman damgası kurulumlar arası, sayaç ise aynı mikrosaniye
/// içinde ayırır.
int _idCounter = 0;

String _nextId() => '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// WP-694 — ekranın biçimi (`ExamListState`) → telin biçimi.
List<ExamCountdown> examCountdownsFromState(ExamListState state) => [
  for (var i = 0; i < state.entries.length; i++)
    ExamCountdown(
      id: state.entries[i].id,
      name: state.entries[i].name,
      day: state.entries[i].day,
      sortOrder: i,
      isPriority: state.entries[i].id == state.priorityId,
      updatedAt: state.entries[i].updatedAt ?? epochUpdatedAt,
    ),
];

/// WP-694 — telin biçimi → ekranın biçimi.
ExamListState examStateFromCountdowns(
  List<ExamCountdown> rows, {
  Set<String> syncedIds = const {},
  Set<String> pendingDeletes = const {},
}) {
  final sorted = [...rows]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  String? priorityId;
  for (final r in sorted) {
    if (r.isPriority) priorityId = r.id;
  }
  return ExamListState(
    entries: [
      for (final r in sorted)
        ExamEntry(
          id: r.id,
          name: r.name,
          day: r.day,
          updatedAt: r.updatedAt == epochUpdatedAt ? null : r.updatedAt,
        ),
    ],
    priorityId: priorityId,
    syncedIds: syncedIds,
    pendingDeletes: pendingDeletes,
  );
}

/// Sınav listesi.
///
/// WP-694'e kadar **yalnız cihazdaydı**; gerçek bir kullanıcı telefonda girdiği
/// tarihi tablette baştan girmek zorunda kaldığını bildirdi. Artık:
///
/// * **ekranın kaynağı** hâlâ yerel kopyadır — uygulama internetsiz açılırsa
///   geri sayım ilk karede görünür, ağ beklenmez;
/// * **doğruluğun kaynağı** sunucudur — açılışta bir tur yapılır, iki cihaz
///   aynı satıra iner;
/// * ağ düşerse yerel kopya ekranda **kalır**, boş liste çizilmez.
class ExamListNotifier extends Notifier<ExamListState> {
  Future<void>? _pending;
  var _disposed = false;

  /// Açılışta başlayan sunucu turu. Testler bunu bekler; üretimde kimse
  /// beklemez (kart yerel kopyayla zaten çizilmiştir).
  Future<void> get synced => _pending ?? Future<void>.value();

  @override
  ExamListState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    final prefs = ref.watch(sharedPreferencesProvider);
    final repo = ref.watch(examCountdownRepositoryProvider);
    final userId = ref.watch(examCountdownUserIdProvider);
    final local = decodeExamList(
      listRaw: prefs.getString(kExamListKey),
      legacyRaw: prefs.getString(kExamDateKey),
    );
    // Oturum ya da sunucu yoksa davranış WP-694 öncesiyle **birebir** aynıdır.
    // `_pull` ilk `await`ine kadar `state`e dokunmaz; build henüz dönmemiştir.
    _pending = (repo == null || userId == null) ? null : _pull(repo, userId);
    return local;
  }

  DateTime _now() => ref.read(ddayClockProvider)().toUtc();

  Future<void> _writeLocal(ExamListState next) => ref
      .read(sharedPreferencesProvider)
      .setString(kExamListKey, encodeExamList(next));

  /// Açılış turu: sunucuyu oku, uzlaştır, farkı yukarı it.
  Future<void> _pull(ExamCountdownRepository repo, String userId) async {
    final List<ExamCountdown> remote;
    try {
      remote = await repo.load(userKey: userId);
    } catch (_) {
      // 🔴 Çevrimdışı. Yerel kopya ekranda KALIR. Burada boş liste yazmak,
      // kullanıcının sınav tarihini "internet yok" diye silmek olurdu.
      return;
    }
    if (_disposed) return;
    final current = state;
    final plan = reconcileExamCountdowns(
      local: examCountdownsFromState(current),
      remote: remote,
      syncedIds: current.syncedIds,
      pendingDeletes: current.pendingDeletes,
      maxEntries: kMaxExamEntries,
    );
    final synced = {...plan.syncedIds};
    final pending = {...plan.pendingDeletes};
    await _drain(
      repo: repo,
      userId: userId,
      deletes: plan.deleteOnServer,
      writes: plan.push,
      synced: synced,
      pending: pending,
    );
    if (_disposed) return;
    final next = examStateFromCountdowns(
      plan.merged,
      syncedIds: synced,
      pendingDeletes: pending,
    );
    state = next;
    await _writeLocal(next);
    if (plan.dropped.isNotEmpty) {
      ref.read(examCountdownDropProvider.notifier).bump(plan.dropped.length);
    }
  }

  /// Sunucu yazmalarını sırayla dener; **her biri ayrı** denenir.
  ///
  /// Tek bir hata diğerlerini düşürmez: biri başarısız olsa bile kalanlar
  /// gider, düşen kayıt `synced`e girmediği için bir sonraki turda tekrar
  /// denenir. Hata yutulmaz, kaydın "senkron oldu" damgası **verilmez**.
  Future<void> _drain({
    required ExamCountdownRepository repo,
    required String userId,
    required List<String> deletes,
    required List<ExamCountdown> writes,
    required Set<String> synced,
    required Set<String> pending,
  }) async {
    for (final id in deletes) {
      try {
        await repo.delete(userKey: userId, id: id);
        pending.remove(id);
        synced.remove(id);
      } catch (_) {
        // Sunucuya ulaşılamadı; silme işareti duruyor, bir sonraki tur dener.
      }
    }
    for (final entry in writes) {
      try {
        await repo.upsert(userKey: userId, entry: entry);
        synced.add(entry.id);
      } catch (_) {
        // Yazılamadı; `synced`e girmez, kayıt yerelde durur, tur tekrarlanır.
      }
    }
  }

  /// 🔴 `v1` anahtarı **silinmez**. Taşımadan sonra tek kaynak `v2`dir (okuma
  /// önce ona bakar), ama yazma başarısız olursa ya da kullanıcı sürümü geri
  /// alırsa eski tarih hâlâ yerinde durur. Bir baytlık fosil, kaybolmuş bir
  /// sınav tarihinden ucuzdur.
  ///
  /// WP-694: sıra **önce durum, sonra disk, sonra sunucu**. Kullanıcı
  /// dokunduğu anda kart değişir; ağ beklemesi araya girmez. Damga yalnız
  /// **içeriği değişen** kayda vurulur — böylece telefondaki bir sıra
  /// değişikliği, tablette yapılan bir ad değişikliğini ezmez.
  Future<void> _persist(ExamListState next, {String? removedId}) async {
    final before = {
      for (final r in examCountdownsFromState(state)) r.id: r,
    };
    final now = _now();
    final stampedRows = <ExamCountdown>[];
    final changed = <ExamCountdown>[];
    for (final row in examCountdownsFromState(next)) {
      final old = before[row.id];
      if (old != null && _sameContent(old, row)) {
        stampedRows.add(row.copyWith(updatedAt: old.updatedAt));
      } else {
        final fresh = row.copyWith(updatedAt: now);
        stampedRows.add(fresh);
        changed.add(fresh);
      }
    }
    final pending = {...next.pendingDeletes};
    // Silme yalnız sunucunun BİLDİĞİ kayıt için işaretlenir; hiç yukarı
    // çıkmamış kaydın silme işaretini taşımanın anlamı yok.
    if (removedId != null && next.syncedIds.contains(removedId)) {
      pending.add(removedId);
    }
    final synced = {...next.syncedIds};
    var applied = examStateFromCountdowns(
      stampedRows,
      syncedIds: synced,
      pendingDeletes: pending,
    );
    state = applied;
    await _writeLocal(applied);

    final repo = ref.read(examCountdownRepositoryProvider);
    final userId = ref.read(examCountdownUserIdProvider);
    if (repo == null || userId == null) return;
    await _drain(
      repo: repo,
      userId: userId,
      deletes: pending.toList(),
      writes: changed,
      synced: synced,
      pending: pending,
    );
    if (_disposed) return;
    applied = state.copyWith(syncedIds: synced, pendingDeletes: pending);
    state = applied;
    await _writeLocal(applied);
  }

  /// Yeni kayıt ekler. Sınır dolu ise **hiçbir şey yapmaz** ve `false` döner;
  /// çağıran bunu kullanıcıya söyler (sessizce yutmak bu depodaki tekrarlayan
  /// hatadır).
  Future<bool> add({required String name, required DateTime day}) async {
    if (!state.canAdd) return false;
    final entry = ExamEntry(
      id: _nextId(),
      name: name.trim(),
      day: DateTime(day.year, day.month, day.day),
    );
    await _persist(state.copyWith(entries: [...state.entries, entry]));
    return true;
  }

  Future<void> update(String id, {String? name, DateTime? day}) async {
    final next = [
      for (final e in state.entries)
        if (e.id == id) e.copyWith(name: name?.trim(), day: day) else e,
    ];
    await _persist(state.copyWith(entries: next));
  }

  /// Kaydı siler. Silinen kayıt öne çıkarılmış olansa **öncelik kalkar** ve
  /// kart eşit görünüme döner; kendiliğinden başka bir sınava atlamaz.
  Future<void> remove(String id) async {
    final next = [
      for (final e in state.entries)
        if (e.id != id) e,
    ];
    final droppedPriority = state.priorityId == id;
    await _persist(
      ExamListState(
        entries: next,
        priorityId: droppedPriority ? null : state.priorityId,
        syncedIds: state.syncedIds,
        pendingDeletes: state.pendingDeletes,
      ),
      removedId: id,
    );
  }

  /// Öne çıkarma **anahtardır**: aynı kayda ikinci kez basmak işareti kaldırır
  /// ve kart eşit görünüme döner (proje sahibi kararı).
  Future<void> togglePriority(String id) async {
    final next = state.priorityId == id ? null : id;
    await _persist(
      ExamListState(
        entries: state.entries,
        priorityId: next,
        syncedIds: state.syncedIds,
        pendingDeletes: state.pendingDeletes,
      ),
    );
  }

  /// Kaydı bir sıra yukarı/aşağı taşır. Sıra **kullanıcıya** aittir; öncelik
  /// kimliğe bağlı olduğu için taşımadan etkilenmez.
  Future<void> move(String id, {required int delta}) async {
    final list = [...state.entries];
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0 || target >= list.length) return;
    final entry = list.removeAt(index);
    list.insert(target, entry);
    await _persist(state.copyWith(entries: list));
  }
}

/// İki satırın kullanıcıya görünen içeriği aynı mı — damga hariç.
bool _sameContent(ExamCountdown a, ExamCountdown b) =>
    a.name == b.name &&
    a.day == b.day &&
    a.sortOrder == b.sortOrder &&
    a.isPriority == b.isPriority;

final examListProvider = NotifierProvider<ExamListNotifier, ExamListState>(
  ExamListNotifier.new,
);

/// Geriye dönük okuma: ilk sınavın tarihi (Ayarlar satırı ve eski testler).
///
/// Öne çıkarılan varsa o, yoksa listenin ilki. `null` = hiç sınav yok.
final examDateProvider = Provider<DateTime?>((ref) {
  final list = ref.watch(examListProvider);
  return (list.priority ?? (list.entries.isEmpty ? null : list.entries.first))
      ?.day;
});

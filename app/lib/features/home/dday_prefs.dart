import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import '../../core/stats/istanbul_calendar.dart';

/// WP-575 — sınav geri sayımı için cihazda tutulan **tek** takvim tarihi.
///
/// WP-632 bunu **en fazla üç kayda** çıkardı; bu anahtar artık yalnız
/// **taşıma girdisi** olarak okunur ve asla silinmez (bkz. [ExamListNotifier]).
const kExamDateKey = 'dday.exam_date_v1';

/// WP-632 — sınav listesi (en fazla üç kayıt) + öne çıkarılan kaydın kimliği.
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
  const ExamEntry({required this.id, required this.name, required this.day});

  /// Kalıcı kimlik. Öncelik bir **indeks** değil bu kimlik üzerinden tutulur:
  /// indeks tutulsaydı sıralama değişince ya da bir kayıt silinince öncelik
  /// sessizce başka bir sınava kayardı.
  final String id;
  final String name;
  final DateTime day;

  ExamEntry copyWith({String? name, DateTime? day}) => ExamEntry(
    id: id,
    name: name ?? this.name,
    day: day == null ? this.day : DateTime(day.year, day.month, day.day),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'day': encodeExamDay(day),
  };

  /// Bozuk satır `null` döner ve **atlanır**; tek bozuk kayıt yüzünden
  /// kullanıcının diğer sınavları kaybolmaz.
  static ExamEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final day = decodeExamDay(raw['day'] as String?);
    if (id is! String || id.isEmpty || day == null) return null;
    final name = raw['name'];
    return ExamEntry(id: id, name: name is String ? name : '', day: day);
  }

  @override
  bool operator ==(Object other) =>
      other is ExamEntry &&
      other.id == id &&
      other.name == name &&
      other.day == day;

  @override
  int get hashCode => Object.hash(id, name, day);
}

/// Kartın çizeceği tam durum: sıra kullanıcıya ait, öncelik isteğe bağlı.
@immutable
class ExamListState {
  const ExamListState({this.entries = const [], this.priorityId});

  /// Kullanıcının belirlediği sıra. Kart bu sırayı **aynen** kullanır.
  final List<ExamEntry> entries;

  /// Öne çıkarılan kaydın kimliği; `null` ise kart üç kaydı **eşit** gösterir.
  final String? priorityId;

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
  }) => ExamListState(
    entries: entries ?? this.entries,
    priorityId: clearPriority ? null : (priorityId ?? this.priorityId),
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
      return ExamListState(entries: capped, priorityId: valid);
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

String encodeExamList(ExamListState state) => jsonEncode({
  'entries': [for (final e in state.entries) e.toJson()],
  'priority': state.priorityId,
});

/// Sadece bu oturumda artan sayaç.
///
/// 🔴 Kimlik önce yalnız `microsecondsSinceEpoch` ile üretiliyordu ve testte
/// **çakıştı**: art arda eklenen iki sınav aynı kimliği alabiliyor. Aynı kimlik
/// sessiz bir felakettir — silme iki kaydı birden götürür, öne çıkarma yanlış
/// sınava düşer. Zaman damgası kurulumlar arası, sayaç ise aynı mikrosaniye
/// içinde ayırır.
int _idCounter = 0;

String _nextId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${_idCounter++}';

/// Sınav listesi (cihazda kalıcı, hesaptan bağımsız).
class ExamListNotifier extends Notifier<ExamListState> {
  @override
  ExamListState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return decodeExamList(
      listRaw: prefs.getString(kExamListKey),
      legacyRaw: prefs.getString(kExamDateKey),
    );
  }

  /// 🔴 `v1` anahtarı **silinmez**. Taşımadan sonra tek kaynak `v2`dir (okuma
  /// önce ona bakar), ama yazma başarısız olursa ya da kullanıcı sürümü geri
  /// alırsa eski tarih hâlâ yerinde durur. Bir baytlık fosil, kaybolmuş bir
  /// sınav tarihinden ucuzdur.
  Future<void> _persist(ExamListState next) async {
    state = next;
    await ref
        .read(sharedPreferencesProvider)
        .setString(kExamListKey, encodeExamList(next));
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
    await _persist(
      state.copyWith(entries: [...state.entries, entry]),
    );
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
      ),
    );
  }

  /// Öne çıkarma **anahtardır**: aynı kayda ikinci kez basmak işareti kaldırır
  /// ve kart eşit görünüme döner (proje sahibi kararı).
  Future<void> togglePriority(String id) async {
    final next = state.priorityId == id ? null : id;
    await _persist(
      ExamListState(entries: state.entries, priorityId: next),
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

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
import '../models/subject.dart';
import '../repositories/subject_repository.dart';
import '../repositories/in_memory/in_memory_subject_repository.dart';
import '../repositories/supabase/supabase_subject_repository.dart';
import 'auth_providers.dart';

/// Aktif SubjectRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseSubjectRepository(Supabase.instance.client);
  }
  final repo = InMemorySubjectRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// WP-697: ders listesinin cihazdaki aynası (kullanıcı başına ayrı anahtar).
///
/// Dersler kişiye özeldir; başka hesabın satırı bu anahtardan okunmaz
/// ([readCachedSubjects] `user_id` doğrular).
String subjectsCacheKey(String userId) => 'subjects_cache.$userId';

/// Yerel aynayı okur. Anahtar hiç yazılmamışsa `null` döner — bu "önbellek YOK"
/// demektir ve boş liste (`[]`, "kullanıcının dersi yok") ile karıştırılmaz.
/// Ayrım şart: önbellek yokken ağ hatası yutulmamalı, ekrana çıkmalı.
List<Subject>? readCachedSubjects(SharedPreferences prefs, String userId) {
  final raw = prefs.getString(subjectsCacheKey(userId));
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final list = <Subject>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final map = item.map((key, value) => MapEntry('$key', value));
      if (map['id'] is! String || map['name'] is! String) continue;
      // Cihaz tek, hesap birden çok olabilir: yabancı satır asla sızmaz.
      if (map['user_id'] != userId) continue;
      list.add(Subject.fromMap(map));
    }
    return List.unmodifiable(list);
  } catch (_) {
    // Bozuk/eski biçim: önbellek yokmuş gibi davran (hata yüzeye çıksın).
    return null;
  }
}

/// Yerel aynayı **tamamen değiştirir**.
///
/// 🔴 Birleştirme (merge) YASAK: sunucudan gelen liste tek doğruluk kaynağıdır.
/// Birleştirilseydi sunucuda silinen bir ders yerelde sonsuza kadar diri kalır,
/// çevrimdışı açılışta seçilebilir görünür ve o dersle yazılan kayıt sunucuda
/// yabancı anahtar ihlaline düşerdi.
Future<void> writeCachedSubjects(
  SharedPreferences prefs,
  String userId,
  List<Subject> subjects,
) {
  return prefs.setString(
    subjectsCacheKey(userId),
    jsonEncode(subjects.map((s) => s.toMap()).toList()),
  );
}

/// Giriş yapan kullanıcının dersleri (ada göre sıralı).
///
/// WP-697: sunucu okunabildiği sürece davranış eskisiyle birebir aynıdır; ek
/// olarak her başarılı okuma yerel aynaya yazılır. Ağ koptuğunda liste bu
/// aynadan gelir — kullanıcı çevrimdışı çalışabiliyorken dersini de seçebilsin.
final userSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  final repository = ref.watch(subjectRepositoryProvider);
  return _watchSubjectsWithOfflineMirror(
    repository: repository,
    prefs: _prefsOrNull(ref),
    userId: user.id,
  );
});

/// Prefs sağlanmamışsa (yalıtılmış birim testleri) önbellek katmanı devre dışı
/// kalır; ürün akışında `main()` bu provider'ı her zaman override eder.
SharedPreferences? _prefsOrNull(Ref ref) {
  try {
    return ref.watch(sharedPreferencesProvider);
  } catch (_) {
    return null;
  }
}

Stream<List<Subject>> _watchSubjectsWithOfflineMirror({
  required SubjectRepository repository,
  required SharedPreferences? prefs,
  required String userId,
}) async* {
  if (prefs == null) {
    yield* repository.watchUserSubjects(userId);
    return;
  }
  // Açılışta beklemeden göster; sunucu yanıtı gelince üstüne yazılır.
  final warm = readCachedSubjects(prefs, userId);
  if (warm != null && warm.isNotEmpty) yield warm;
  try {
    await for (final subjects in repository.watchUserSubjects(userId)) {
      await writeCachedSubjects(prefs, userId, subjects);
      yield subjects;
    }
  } catch (_) {
    final fallback = readCachedSubjects(prefs, userId);
    // Önbellek yoksa hata YUTULMAZ: ekran "sessizce boş" kalmasın diye
    // AsyncError olarak yüzeye çıkar.
    if (fallback == null) rethrow;
    yield fallback;
  }
}

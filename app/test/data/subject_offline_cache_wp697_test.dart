// 🔴 WP-697 — "internet yokken ders secilemiyor".
//
// Duzeltmeden ONCE olculen davranis: `subject_providers.dart` icinde
// SharedPreferences hic gecmiyordu. `SupabaseSubjectRepository.watchUserSubjects`
// ilk `_fetch`te ag hatasi atinca `userSubjectsProvider` AsyncError'a dusuyor,
// her cagri yeri `.value ?? []` yazdigi icin liste BOS geliyordu. Kullanici
// cevrimdisi calisabiliyor ama dersini secemiyordu.
//
// Bu dosya sozlesmeyi UC yonlu baglar:
//   1. Basarili her sunucu okumasi onbellegi TAMAMEN degistirir (birlestirmez).
//   2. Sunucu hata verdiginde liste onbellekten gelir.
//   3. Onbellek yokken hata YUTULMAZ — AsyncError yuzeye cikar ki ekran
//      "sessizce bos" kalmasin.
//
// Sabotaj notu: `writeCachedSubjects` birlestirmeye cevrilirse (2. grup) ya da
// `catch` dalindaki `rethrow` silinirse (3. grup) bu dosya kirmiziya doner.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/subject_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ag hatasini istege bagli uretebilen ders deposu.
class _FlakySubjectRepository implements SubjectRepository {
  _FlakySubjectRepository(this.subjects);

  List<Subject> subjects;

  /// Doluyken `watchUserSubjects` bu hatayi atar (cevrimdisi taklidi).
  Object? error;

  int fetchCount = 0;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void emit(List<Subject> next) {
    subjects = next;
    _changes.add(null);
  }

  @override
  Future<void> addSubject(Subject subject) async {}

  @override
  Future<void> updateSubject(Subject subject) async {}

  @override
  Future<void> deleteSubject(String subjectId) async {}

  @override
  Stream<List<Subject>> watchUserSubjects(String userId) async* {
    fetchCount++;
    if (error != null) throw error!;
    yield subjects.where((s) => s.userId == userId).toList();
    await for (final _ in _changes.stream) {
      if (error != null) throw error!;
      yield subjects.where((s) => s.userId == userId).toList();
    }
  }

  void dispose() => _changes.close();
}

Subject _subject(String id, String userId, {String? name}) =>
    Subject(id: id, userId: userId, name: name ?? id, color: 'chart-1');

Future<void> _waitUntil(bool Function() condition, {String? reason}) async {
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(condition(), isTrue, reason: reason);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer open({
    required SubjectRepository repo,
    required String userId,
  }) {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: userId, displayName: userId, createdAt: DateTime(2026)),
          ),
        ),
        subjectRepositoryProvider.overrideWithValue(repo),
      ],
    );
    // 🔴 Riverpod 3: dinleyicisiz provider her `read`de yeniden kurulur; o
    // durumda asagidaki iddialar hep AsyncLoading olcerdi.
    container.listen(userSubjectsProvider, (_, _) {});
    addTearDown(container.dispose);
    return container;
  }

  List<String> cachedIds(String userId) {
    final raw = prefs.getString(subjectsCacheKey(userId));
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => (e as Map)['id'] as String)
        .toList();
  }

  group('1 - basarili sunucu okumasi onbellegi yazar', () {
    test('liste geldiginde cihazda saklanir', () async {
      final repo = _FlakySubjectRepository([
        _subject('math', 'u-a'),
        _subject('physics', 'u-a'),
      ]);
      addTearDown(repo.dispose);
      final container = open(repo: repo, userId: 'u-a');

      await _waitUntil(
        () => container.read(userSubjectsProvider).value?.length == 2,
      );
      await _waitUntil(() => cachedIds('u-a').length == 2);
      expect(cachedIds('u-a'), containsAll(<String>['math', 'physics']));
    });
  });

  group('2 - sunucu hata verirken liste onbellekten gelir', () {
    test('cevrimdisi ilk acilis: dersler yine de secilebilir', () async {
      // Onceki basarili oturumun birakti onbellek.
      await prefs.setString(
        subjectsCacheKey('u-a'),
        jsonEncode([
          _subject('math', 'u-a', name: 'Matematik').toMap(),
          _subject('physics', 'u-a', name: 'Fizik').toMap(),
        ]),
      );

      final repo = _FlakySubjectRepository([])
        ..error = const SocketExceptionLike();
      addTearDown(repo.dispose);
      final container = open(repo: repo, userId: 'u-a');

      await _waitUntil(
        () => container.read(userSubjectsProvider).value?.length == 2,
        reason: 'cevrimdisi liste onbellekten gelmeli',
      );
      final value = container.read(userSubjectsProvider);
      expect(value.hasError, isFalse);
      expect(
        value.value!.map((s) => s.name),
        containsAll(<String>['Matematik', 'Fizik']),
      );
    });

    test('baska hesabin onbellegi bu hesaba sizmaz', () async {
      await prefs.setString(
        subjectsCacheKey('u-a'),
        jsonEncode([_subject('math', 'u-a').toMap()]),
      );

      final repo = _FlakySubjectRepository([])
        ..error = const SocketExceptionLike();
      addTearDown(repo.dispose);
      final container = open(repo: repo, userId: 'u-b');

      await _waitUntil(() => container.read(userSubjectsProvider).hasError);
      expect(container.read(userSubjectsProvider).value, isNull);
      expect(prefs.getString(subjectsCacheKey('u-a')), isNotNull);
    });
  });

  group('3 - bayat onbellek silinmis dersi DIRILTMEZ', () {
    test('ilk basarili okuma onbellegi tamamen degistirir', () async {
      await prefs.setString(
        subjectsCacheKey('u-a'),
        jsonEncode([
          _subject('math', 'u-a').toMap(),
          _subject('physics', 'u-a').toMap(),
        ]),
      );

      // Sunucuda `physics` silinmis.
      final repo = _FlakySubjectRepository([_subject('math', 'u-a')]);
      addTearDown(repo.dispose);
      final container = open(repo: repo, userId: 'u-a');

      await _waitUntil(
        () => container.read(userSubjectsProvider).value?.length == 1,
      );
      expect(
        container.read(userSubjectsProvider).value!.single.id,
        'math',
        reason: 'sunucu listesi kazanmali',
      );
      await _waitUntil(() => cachedIds('u-a').length == 1);
      expect(
        cachedIds('u-a'),
        <String>['math'],
        reason: 'silinen ders onbellekte kalirsa sonraki cevrimdisi acilista '
            'dirilir',
      );
    });

    test('silme sonrasi cevrimdisi acilista da geri gelmez', () async {
      final repo = _FlakySubjectRepository([
        _subject('math', 'u-a'),
        _subject('physics', 'u-a'),
      ]);
      addTearDown(repo.dispose);
      final first = open(repo: repo, userId: 'u-a');
      await _waitUntil(() => cachedIds('u-a').length == 2);

      repo.emit([_subject('math', 'u-a')]);
      await _waitUntil(() => cachedIds('u-a').length == 1);
      first.dispose();

      // Yeni acilis, bu kez ag yok.
      repo.error = const SocketExceptionLike();
      final second = open(repo: repo, userId: 'u-a');
      await _waitUntil(
        () => second.read(userSubjectsProvider).value?.length == 1,
      );
      expect(
        second.read(userSubjectsProvider).value!.single.id,
        'math',
        reason: 'silinen `physics` cevrimdisi listede gorunmemeli',
      );
    });
  });

  group('4 - onbellek yokken hata yutulmaz', () {
    test('bos ekran yerine AsyncError yuzeye cikar', () async {
      final repo = _FlakySubjectRepository([])
        ..error = const SocketExceptionLike();
      addTearDown(repo.dispose);
      final container = open(repo: repo, userId: 'u-a');

      await _waitUntil(() => container.read(userSubjectsProvider).hasError);
      final value = container.read(userSubjectsProvider);
      expect(value.hasError, isTrue);
      expect(value.value, isNull);
      expect(prefs.getString(subjectsCacheKey('u-a')), isNull);
    });
  });
}

/// Ag kopmasini temsil eden hata (gercek `SocketException` icin `dart:io`
/// gerekmesin diye yerel tur).
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();

  @override
  String toString() => 'Failed host lookup: db.supabase.co';
}

// WP-613 (KANAMA-1) — "Durdur'a bastım, uygulamayı kapattım, çalışmam yok."
//
// 🔴 Ölçülen zincir (denetim: docs/denetim/DENETIM-sayac.md):
//   1. `addSessionLocalFirst` oturumu cache'e yazar, uzak gönderimi
//      `unawaited` bırakır.
//   2. Outbox kaydı YALNIZ gönderim hata verirse (`catch`) yazılırdı.
//   3. Süreç o aralıkta ölürse (kullanıcı uygulamayı kapatır / Android süreci
//      öldürür) outbox BOŞTUR.
//   4. Sonraki açılışta ilk sunucu snapshot'ı gelir; `_reconcileRemoteSessions`
//      "sunucu + BEKLEYEN outbox" kümesini üretir ve `saveUserSessions` cache'i
//      onunla DEĞİŞTİRİR → oturum cache'ten de silinir.
//   Uyarı yok, telemetri yok. Kullanıcının çalışması yok olur.
//
// Bu dosya o pencereyi **enjekte ederek** kurar: gerçek zamana, gerçek ağa ya
// da gerçek bir süreç ölümüne bağlanmaz. "Ölüm" = uzak gönderimin hiç
// sonuçlanmaması (`_HangingStudyRepository`); "yeniden açılış" = AYNI kalıcı
// depo üzerinde YENİ bir repo örneği.
//
// İddialar iki yönlüdür: kayıt gönderilemeden ölünce KAYBOLMAMALI, gönderim
// başarılı olunca da kuyrukta ÇÖP KALMAMALI. Tek yönlü ölçüm "her şeyi
// sonsuza dek kuyrukta tut" sabotajını yeşil geçirirdi.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/repositories/offline/offline_cache_store.dart';
import 'package:online_study_room/data/repositories/offline/offline_first_study_repository.dart';
import 'package:online_study_room/data/repositories/study_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sıcak pencere (90 gün) duvar saatine bakar; oturum bu yüzden "az önce"
/// olmalı. Sabit bir tarih testi bir gün sessizce boş listeye düşürürdü.
StudySession _session(String id) {
  final end = DateTime.now().subtract(const Duration(minutes: 1));
  return StudySession(
    id: id,
    userId: 'u1',
    start: end.subtract(const Duration(minutes: 25)),
    end: end,
    durationSeconds: 25 * 60,
    source: StudySource.live,
  );
}

Future<OfflineCacheStore> _store() async {
  SharedPreferences.setMockInitialValues({});
  return OfflineCacheStore(await SharedPreferences.getInstance());
}

Future<void> _pump() => Future<void>.delayed(const Duration(milliseconds: 30));

void main() {
  test('süreç gönderim ile outbox arasında ÖLÜRSE oturum kaybolmaz', () async {
    final cache = await _store();
    // Gönderim hiç sonuçlanmaz: ne başarı ne hata. `catch` kolu çalışmaz —
    // eski kodda outbox'a kayıt düşüren TEK yol buydu.
    final hanging = _HangingStudyRepository();
    addTearDown(hanging.release);
    final repo = OfflineFirstStudyRepository(
      remote: hanging,
      cache: cache,
      // Zaman aşımı da bir `catch`tir; testin kapattığı delik ondan ÖNCEKİ
      // penceredir. Aşağıdaki iddialar 30 ms içinde okunur, yani ölüm tam o
      // pencerede gerçekleşir.
      remoteDispatchTimeout: const Duration(seconds: 5),
    );

    await repo.addSessionLocalFirst(_session('kayip'));
    await _pump();

    expect(
      hanging.startedWrites,
      1,
      reason: 'uzak tur gerçekten başlamış olmalı (test boş çalışmasın)',
    );
    expect(
      (await cache.readPendingStudyMutations()).map((m) => m.sessionId),
      contains('kayip'),
      reason:
          'ASIL BUG: outbox burada BOŞTU — kalıcı hiçbir iz yoktu, oturum '
          'yalnız cache\'te duruyordu',
    );

    // ——— Yeniden açılış: aynı kalıcı depo, yeni repo örneği. Sunucu o oturumu
    // HİÇ görmedi (snapshot'ı boş) ve ağ hâlâ yok.
    final fresh = _FakeStudyRepository()..failWrites = true;
    final reopened = OfflineFirstStudyRepository(remote: fresh, cache: cache);

    // İlk emit cache'ten, ikincisi sunucu snapshot'ıyla uzlaşmış küme.
    final reconciled = await reopened
        .watchUserSessions('u1')
        .skip(1)
        .first
        .timeout(const Duration(seconds: 5));

    expect(
      reconciled.map((s) => s.id),
      contains('kayip'),
      reason:
          'sunucu snapshot\'ı boştu; outbox kaydı olmasaydı oturum ekrandan '
          'da silinirdi',
    );
    expect(
      (await cache.readUserSessions('u1'))!.map((s) => s.id),
      contains('kayip'),
      reason: 'snapshot cache\'i DEĞİŞTİRİR; kayıt orada da yaşamalı',
    );

    // ——— Ağ geri geldi: kayıt nihayet sunucuya gider ve kuyruk boşalır.
    fresh.failWrites = false;
    await reopened.flushPending();

    expect(fresh.sessions.map((s) => s.id), contains('kayip'));
    expect(await cache.readPendingStudyMutations(), isEmpty);
  });

  test('KARŞI İDDİA: gönderim başarılıysa kuyrukta çöp kalmaz', () async {
    // Bu olmadan "her şeyi sonsuza dek kuyrukta tut" sabotajı yeşil geçerdi:
    // kuyruk şişer, her açılışta aynı satırlar tekrar tekrar gönderilirdi.
    final cache = await _store();
    final remote = _FakeStudyRepository();
    final repo = OfflineFirstStudyRepository(remote: remote, cache: cache);

    await repo.addSessionLocalFirst(_session('temiz'));
    await _pump();

    expect(remote.sessions.single.id, 'temiz');
    expect(await cache.readPendingStudyMutations(), isEmpty);
  });

  test('bloklayan addSession yolu da yazılmadan önce kuyruğa alır', () async {
    // `_recordSession` yalnız `LocalFirstSessionWriter` destekleyen repolarda
    // yeni yolu kullanır; eski `addSession` da aynı garantiyi vermeli, yoksa
    // manuel süre ekleme aynı delikten düşer.
    SharedPreferences.setMockInitialValues({});
    final spy = _OrderSpyCacheStore(await SharedPreferences.getInstance());
    final hanging = _HangingStudyRepository();
    addTearDown(hanging.release);
    final repo = OfflineFirstStudyRepository(
      remote: hanging,
      cache: spy,
      remoteDispatchTimeout: const Duration(milliseconds: 50),
    );

    await repo.addSession(_session('manuel'));

    // Sıra ölçülür, yalnız "sonunda kuyrukta mı" değil: zaman aşımının
    // `catch` kolu da kuyruğa yazar, yani varlık iddiası eski davranışı da
    // yeşil geçirirdi. Kayıt gönderimden ÖNCE düşmeli.
    expect(spy.writes, <String>['outbox', 'cache']);
    expect(
      (await spy.readPendingStudyMutations()).map((m) => m.sessionId),
      contains('manuel'),
    );
    expect(
      (await spy.readUserSessions('u1'))!.map((s) => s.id),
      contains('manuel'),
    );
  });

  test('outbox kaydı cache yazımından ÖNCE düşer', () async {
    // İki kalıcı yazım arasında da bir pencere var. Sıra ters olsaydı orada
    // ölen süreç yine kayıp üretirdi: cache'te var, kuyrukta yok. Ölçüm
    // deponun kendisinden alınır; zamanlamaya bağlı bir okuma değil.
    SharedPreferences.setMockInitialValues({});
    final spy = _OrderSpyCacheStore(await SharedPreferences.getInstance());
    final hanging = _HangingStudyRepository();
    addTearDown(hanging.release);
    final repo = OfflineFirstStudyRepository(
      remote: hanging,
      cache: spy,
      remoteDispatchTimeout: const Duration(seconds: 5),
    );

    await repo.addSessionLocalFirst(_session('sira'));

    expect(
      spy.writes.first,
      'outbox',
      reason: 'ilk kalıcı iz outbox olmalı; cache ikinci sırada gelir',
    );
    expect(spy.writes, containsAllInOrder(<String>['outbox', 'cache']));
  });
}

/// Kalıcı yazımların SIRASINI kaydeden depo.
class _OrderSpyCacheStore extends OfflineCacheStore {
  _OrderSpyCacheStore(super.prefs);

  final writes = <String>[];

  @override
  Future<void> queueStudyMutation(OfflineStudyMutation mutation) {
    writes.add('outbox');
    return super.queueStudyMutation(mutation);
  }

  @override
  Future<void> upsertCachedSession(StudySession session) {
    writes.add('cache');
    return super.upsertCachedSession(session);
  }
}

/// Uzak yazımı **hiç sonuçlandırmayan** sahte sunucu.
///
/// "Süreç gönderim sırasında öldü" senaryosunun enjekte edilmiş hâli: istek
/// başlar, ne cevap ne hata gelir. Eski kodda outbox'a yazan tek kol `catch`
/// olduğu için bu durumda kalıcı hiçbir iz doğmuyordu.
class _HangingStudyRepository extends StudyRepository {
  int startedWrites = 0;
  final _pending = <Completer<void>>[];

  /// Test bitince asılı istekleri kapatır: `Future.timeout` zamanlayıcısı da
  /// böylece iptal olur, sızan bir Timer kalmaz.
  void release() {
    for (final completer in _pending) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('surec oldu'));
      }
    }
    _pending.clear();
  }

  Future<void> _hang() {
    final completer = Completer<void>();
    _pending.add(completer);
    return completer.future;
  }

  @override
  Future<void> addSession(StudySession session) {
    startedWrites++;
    return _hang();
  }

  @override
  Future<void> updateSession(StudySession session) => _hang();

  @override
  Future<void> deleteSession(String sessionId) => _hang();

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) =>
      const Stream<List<StudySession>>.empty();

  @override
  Future<UserStudySummary> fetchUserStudySummary(String userId) async =>
      const UserStudySummary(
        lifetimeSeconds: 0,
        yearSeconds: 0,
        hotWindowSeconds: 0,
      );

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) =>
      const Stream<List<StudySession>>.empty();

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) =>
      const Stream<List<DailyStat>>.empty();
}

/// Normal davranan sahte sunucu (yeniden açılış turu için).
class _FakeStudyRepository extends StudyRepository {
  final sessions = <StudySession>[];
  bool failWrites = false;

  @override
  Future<void> addSession(StudySession session) async {
    if (failWrites) throw StateError('offline');
    sessions.add(session);
  }

  @override
  Future<void> updateSession(StudySession session) async {
    if (failWrites) throw StateError('offline');
    sessions
      ..removeWhere((s) => s.id == session.id)
      ..add(session);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    if (failWrites) throw StateError('offline');
    sessions.removeWhere((s) => s.id == sessionId);
  }

  @override
  Stream<List<StudySession>> watchUserSessions(String userId) =>
      Stream.value(sessions.where((s) => s.userId == userId).toList());

  @override
  Future<UserStudySummary> fetchUserStudySummary(String userId) async =>
      const UserStudySummary(
        lifetimeSeconds: 0,
        yearSeconds: 0,
        hotWindowSeconds: 0,
      );

  @override
  Stream<List<StudySession>> watchGroupSessions(String groupId) =>
      const Stream<List<StudySession>>.empty();

  @override
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId) =>
      const Stream<List<DailyStat>>.empty();
}

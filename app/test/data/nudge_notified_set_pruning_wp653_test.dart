// WP-653 — dürtme belleği sınırsız büyüyordu (iki uçta birden).
//
// 🔴 Bulgu (hunter Lane C, koddan doğrulandı). `NudgeRepository.markRead`
// `lib/` içinde **hiçbir yerden çağrılmıyor** — 4 arama sonucundan 3'ü tanım,
// 1'i yorum. Yani her dürtme sunucuda ömür boyu `read_at = null` kalıyor.
// Bunun iki bedeli vardı:
//
//   1. `watchReceivedNudges` sorgusunda ne `limit` ne sıralama vardı: kullanıcı
//      **ömür boyu aldığı tüm dürtme satırlarını** her açılışta ve her realtime
//      değişiminde tel üzerinden çekiyordu. `_hydrateNudges` sonucu 50'ye
//      kırpıyordu ama kırpma İSTEMCİDE, yani yük zaten ödenmiş oluyordu.
//   2. Bildirilen id'lerin kalıcı seti (`notified_nudge_ids`) **hiç
//      budanmıyordu**: her dürtme id'si sonsuza kadar `SharedPreferences`'te
//      kalıyor ve her değişimde listenin tamamı yeniden yazılıyordu.
//
// Bu dosya ikinci maddeyi ölçer (birincisi sorgu sözleşmesidir, aşağıda ayrı
// bir iddia olarak sabitlenir).
//
// ⚠️ Budamanın tehlikeli yanı var ve testlerin asıl işi orayı korumak:
// realtime yeniden bağlanırken **geçici boş bir kare** gelirse ve o an
// budarsak, kare geri geldiğinde aynı dürtmeler TEKRAR bildirilir — bu, bu
// depoda daha önce yaşanan "kimse dürtmese bile sürekli dürtme" hatasının ta
// kendisidir.
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/nudge_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/nudge_notification_listener.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNudgeService implements NudgeNotificationGateway {
  final List<Nudge> shown = [];

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> showNudge(Nudge nudge) async => shown.add(nudge);
}

Nudge _nudge(String id, {DateTime? createdAt}) => Nudge(
  id: id,
  groupId: 'g1',
  senderId: 's1',
  recipientId: 'u1',
  createdAt: createdAt ?? DateTime(2026),
);

Future<void> _tick() =>
    Future.delayed(const Duration(milliseconds: 10), () => null);

void main() {
  const userId = 'u1';
  const key = 'notified_nudge_ids';

  Future<(ProviderContainer, _FakeNudgeService)> boot(
    SharedPreferences prefs,
    Stream<List<Nudge>> nudges,
  ) async {
    final fake = _FakeNudgeService();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: userId, displayName: 'Ben', createdAt: DateTime(2026)),
          ),
        ),
        nudgeNotificationServiceProvider.overrideWithValue(fake),
        receivedNudgesProvider(userId).overrideWith((ref) => nudges),
        mutedNudgeSenderIdsProvider.overrideWith((ref) async => <String>{}),
      ],
    );
    container.listen(nudgeNotificationListenerProvider, (prev, next) {});
    await container.read(authStateProvider.future);
    await container.read(mutedNudgeSenderIdsProvider.future);
    await _tick();
    return (container, fake);
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('🔴 pencereden dusen eski id kalici setten BUDANIR', () async {
    // Gecmisten kalma 500 id: budama olmadan bunlar omur boyu diskte kalir.
    final eski = [for (var i = 0; i < 500; i++) 'gecmis-$i'];
    SharedPreferences.setMockInitialValues({key: eski});
    final prefs = await SharedPreferences.getInstance();

    final controller = StreamController<List<Nudge>>();
    addTearDown(controller.close);
    final (container, _) = await boot(prefs, controller.stream);
    addTearDown(container.dispose);

    // Akisin tasidigi pencere: yalniz iki durtme.
    controller.add([_nudge('n1'), _nudge('n2')]);
    await _tick();

    final saklanan = prefs.getStringList(key)!.toSet();
    expect(
      saklanan.length,
      lessThan(eski.length),
      reason:
          'Kalici set hic budanmiyor: kullanicinin omur boyu aldigi her durtme '
          'id\'si diskte kaliyor ve her degisimde tamami yeniden yaziliyor.',
    );
    expect(saklanan, containsAll(<String>['n1', 'n2']));
    expect(
      saklanan.contains('gecmis-0'),
      isFalse,
      reason:
          'Pencerede olmayan ve bu oturumda eklenmemis bir id hala tutuluyor.',
    );
  });

  test('⚠️ BOS kare seti SILMEZ (uygulama yeniden acildiktan sonra)', () async {
    // 🔴 KARSI IDDIA — ve ilk yazimi ETKISIZDI.
    //
    // Ilk hali tek bir oturumda calisiyordu: durtme AYNI oturumda bildirildigi
    // icin `addedThisSession` onu zaten koruyordu. Gercek senaryo iki
    // oturumdur — uygulama kapanip aciliyor, set diskten geliyor, realtime
    // yeniden baglanirken bos kare dusuyor.
    //
    // Bu testin YAKALADIGI sey olculdu: budama `if (changed)` disina tasinip
    // KOSULSUZ hale getirilince bu iddia KIRMIZI duser. (Yalniz
    // `snapshotIds.isNotEmpty` satirini silmek kirmizi vermez; o satir bugun
    // ulasilamaz ve kaynak dosyada boyle yazili.)
    final gelecek = DateTime.now().toUtc().add(const Duration(days: 1));
    final canli = _nudge('canli', createdAt: gelecek);

    // --- Oturum 1: durtme bir kez bildirilir ve diske yazilir.
    final prefs = await SharedPreferences.getInstance();
    final c1 = StreamController<List<Nudge>>();
    final (container1, fake1) = await boot(prefs, c1.stream);
    c1.add([canli]);
    await _tick();
    expect(fake1.shown.map((n) => n.id), ['canli']);
    expect(prefs.getStringList(key), contains('canli'));
    container1.dispose();
    await c1.close();

    // --- Oturum 2: uygulama yeniden acildi. `addedThisSession` BOS.
    final c2 = StreamController<List<Nudge>>();
    addTearDown(c2.close);
    final (container2, fake2) = await boot(prefs, c2.stream);
    addTearDown(container2.dispose);

    // Realtime yeniden baglanirken gecici bos kare.
    c2.add(const <Nudge>[]);
    await _tick();
    expect(
      prefs.getStringList(key),
      contains('canli'),
      reason:
          'Bos kare kalici seti sildi. Kare geri gelince ayni durtme yeniden '
          '"yeni" sayilir.',
    );

    // Kare geri geliyor.
    c2.add([canli]);
    await _tick();

    expect(
      fake2.shown,
      isEmpty,
      reason:
          'Ayni durtme uygulama yeniden acilinca IKINCI kez bildirildi: bu, '
          'bu depoda daha once yasanan "kimse durtmese bile surekli durtme" '
          'hatasinin ayni yoldan geri gelmesidir.',
    );
  });

  test('🔴 sorgu penceresi SUNUCUDA: akis limit + siralama tasir', () {
    // Istemcide `take(50)` yapmak yuku ODEDIKTEN sonra kirpar. Bu iddia
    // sorgunun kendisini olcer; yorumlar dusurulur cunku asagidaki aciklama
    // `limit` kelimesini birebir tasiyor (WP-640 tuzagi).
    final source = _stripComments(
      File(
        'lib/data/repositories/supabase/supabase_nudge_repository.dart',
      ).readAsStringSync(),
    );
    final watch = source.substring(
      source.indexOf('Stream<List<Nudge>> watchReceivedNudges'),
      source.indexOf('Future<Nudge> sendNudge'),
    );
    expect(
      watch,
      contains('.limit('),
      reason:
          'Sorguda limit yok: kullanici omur boyu aldigi TUM durtme satirlarini '
          'her acilista ve her realtime degisiminde cekiyor.',
    );
    expect(
      watch,
      contains(".order('created_at')"),
      reason:
          'Limit var ama siralama yok: hangi 50 satirin gelecegi belirsiz, '
          'yani en yeni durtme pencereye girmeyebilir.',
    );
  });
}

String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'(?<!:)//.*'), '');

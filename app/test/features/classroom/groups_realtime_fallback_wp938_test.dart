// WP-938 — Gruplar sekmesi Realtime kurulamayinca "Beklenmeyen bir hata"
// demez; gruplar REST ile kalir.
//
// Sahibin beta ekrani: Gruplar sekmesi ve ana ekrandaki grup kartlari genel
// hata cumlesini gosteriyordu, "Yenile" ise ayni kopuk soketi yeniden
// aciyordu. Burada GERCEK `SupabaseGroupRepository` + paketin gercek
// `.stream()` kodu calisir; yalniz soket (sahte Realtime) ve http katmani
// sahtedir. Kanal `timedOut` durumuna dusurulur — sahadaki belirtinin aynisi.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:online_study_room/core/l10n/group_error_text.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart' as model;
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_group_repository.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

import '../../support/fake_realtime_supabase_wp938.dart';

final _me = Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026));

List<Override> _overrides(
  SharedPreferences prefs,
  Wp938FakeSupabaseClient client,
) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authStateProvider.overrideWith((ref) => Stream.value(_me)),
  // Olculen akis: gercek depo, gercek `.stream()`.
  groupRepositoryProvider.overrideWithValue(SupabaseGroupRepository(client)),
  // Sahnenin geri kalani bu testin konusu degil.
  groupMembersProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
  groupPresenceProvider.overrideWith(
    (ref) => Stream.value(const <model.Presence>[]),
  ),
  groupDailyStatsProvider.overrideWith(
    (ref) => Stream.value(const <DailyStat>[]),
  ),
  userSessionsProvider.overrideWith(
    (ref) => Stream.value(const <StudySession>[]),
  ),
];

void main() {
  final l10n = AppLocalizationsTr();

  late Wp938FakeRealtime realtime;
  late Wp938Backend backend;
  late Wp938FakeSupabaseClient client;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    realtime = Wp938FakeRealtime();
    backend = Wp938Backend()
      ..rows['group_members'] = [wp938MemberRow('g1', 'u1')]
      ..rows['groups'] = [wp938GroupRow('g1', 'Kamp Ekibi')]
      ..rows['user_group_preferences'] = const <Object>[];
    client = Wp938FakeSupabaseClient(realtime, backend);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        // Riverpod 3 otomatik yeniden denemesi testte kapali: olculen sey
        // akisin kendi davranisi; ayrica bekleyen retry zamanlayicisi birakmaz.
        retry: (retryCount, error) => null,
        overrides: _overrides(prefs, client),
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClassroomScreen(),
        ),
      ),
    );
    // Kamp atesi sonsuz animasyon tasir: pumpAndSettle yerine sinirli pump.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  testWidgets('Realtime timedOut: gruplar REST ile kalir, genel hata yok; '
      'Realtime donunce guncelleme akar', (tester) async {
    await pumpScreen(tester);
    expect(find.text('Kamp Ekibi'), findsWidgets);

    // Sahadaki belirti: soket kurulamaz, kanal zaman asimina duser.
    for (final channel in realtime.live) {
      channel.emitStatus(RealtimeSubscribeStatus.timedOut);
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text(l10n.authBeklenmeyenBirHataOlustu),
      findsNothing,
      reason: 'saf Realtime arizasi genel hata gostermemeli (WP-938 kok neden)',
    );
    expect(find.byKey(const Key('classroom-error-retry')), findsNothing);
    expect(find.text('Kamp Ekibi'), findsWidgets);

    // Realtime geri gelir: geri cekilme sonrasi yeni kanal kurulur ve canli
    // degisiklik ekrana akar.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 50));
    final members = realtime.forTable('group_members');
    expect(members.length, greaterThanOrEqualTo(2));
    final recovered = members.last;
    recovered.emitStatus(RealtimeSubscribeStatus.subscribed);
    backend.rows['groups'] = [wp938GroupRow('g1', 'Yeni Kamp')];
    recovered.emitUpdate('group_members', wp938MemberRow('g1', 'u1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Yeni Kamp'), findsWidgets);
    expect(find.text(l10n.authBeklenmeyenBirHataOlustu), findsNothing);

    // Iptal: ekran kapaninca yoklama/yeniden deneme zamanlayicisi ve canli
    // kanal kalmaz (testWidgets bekleyen zamanlayiciyi da reddeder).
    await unmount(tester);
    expect(realtime.live, isEmpty);
  });

  testWidgets('REST hatasi gercek ariza: genel hata + "Sunucu hatasi" ipucu', (
    tester,
  ) async {
    backend.failing.add('group_members');
    await pumpScreen(tester);

    expect(find.text(l10n.authBeklenmeyenBirHataOlustu), findsOneWidget);
    expect(find.byKey(const Key('classroom-error-retry')), findsOneWidget);
    final hint = tester.widget<Text>(find.byKey(kLoadErrorCauseHintKey));
    expect(hint.data, l10n.streamErrorCauseServer('XX000'));

    await unmount(tester);
  });

  test('ipucu siniflari: canli guncelleme / yetki / sunucu / uygulama', () {
    expect(
      loadErrorCauseHint(
        RealtimeSubscribeException(RealtimeSubscribeStatus.timedOut),
        l10n,
      ),
      l10n.streamErrorCauseRealtime,
    );
    expect(
      loadErrorCauseHint(
        const PostgrestException(message: 'rls', code: '42501'),
        l10n,
      ),
      l10n.streamErrorCauseAuth,
    );
    expect(
      loadErrorCauseHint(
        const PostgrestException(message: 'x', code: 'PGRST116'),
        l10n,
      ),
      l10n.streamErrorCauseServer('PGRST116'),
    );
    expect(loadErrorCauseHint(StateError('x'), l10n), l10n.streamErrorCauseApp);
    expect(l10n.streamErrorCauseRealtime, 'Bağlantı sorunu (canlı güncelleme)');
  });
}

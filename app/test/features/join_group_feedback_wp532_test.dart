// WP-532: davet koduyla gruba katılma akışında geri bildirim.
//
// WP-530'un (grup KURMA) ikizi. Düzeltmeden önce alınan prob ölçümü:
//   1. basıştan sonra diyalog açık mı? false
//   ilerleme göstergesi var mı?        false
//   bitişte başarı göstergesi var mı?  false
//   TOPLAM joinGroup çağrısı           = 2   (istek uçarken akış yeniden açıldı)
// Sunucu tarafı çift katılmayı yutuyor — `join_group` RPC'si
// (`supabase/migrations/0093_group_bans.sql`) zaten aktif üyeyse grubu aynen
// döner, `InMemoryGroupRepository._join` de aynı sözleşmeyi tutar. Yani
// kurmadaki gibi çift kayıt olmuyor; kusur **geri bildirim** ve gereksiz ikinci
// sunucu turu. Buradaki testler o kapıyı kilitler.
//
// 🔴 Riverpod 3 tuzağı: `authStateProvider` dinleyicisiz okunursa her `read`
// yeniden kurulur ve `.value` sonsuza dek null kalır; `joinGroupFlow` sessizce
// hiçbir şey yapmaz ve test "yeşil" görünürdü. Harness provider'ı `watch` ile
// canlı tutar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi flutter_riverpod 3'te bu yardımcı kütüphaneden gelir.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_switcher.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sahadaki 5-6 sn'lik sunucu turunu taklit eder ve çağrıyı sayar.
class _SlowGroupRepository extends InMemoryGroupRepository {
  _SlowGroupRepository(this.delay);

  final Duration delay;
  int joinCalls = 0;

  @override
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  }) async {
    joinCalls++;
    await Future<void>.delayed(delay);
    return super.joinGroup(inviteCode: inviteCode, member: member);
  }
}

class _JoinHarness extends ConsumerWidget {
  const _JoinHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authStateProvider); // Riverpod 3: provider'ı canlı tut.
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (ctx) => FilledButton(
            onPressed: () => joinGroupFlow(ctx, ref),
            child: const Text('harness-join'),
          ),
        ),
      ),
    );
  }
}

Widget _app(Widget home, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  group('gruba katılma geri bildirimi', () {
    late _SlowGroupRepository repo;
    late String inviteCode;

    /// Akışı açar, [code] kodunu yazar ve "Katıl"a basmaya hazır bırakır.
    Future<void> pumpFlow(WidgetTester tester, {String? code}) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = InMemoryAuthRepository();
      await auth.signUp(
        email: 'uye@ornek.com',
        password: '123456',
        displayName: 'Uye',
      );
      repo = _SlowGroupRepository(const Duration(seconds: 5));
      // Katılınacak grubu başkası kurar; davet kodu oradan gelir.
      final target = await repo.createGroup(
        name: 'Hedef Grup',
        creator: Profile(
          id: 'kurucu',
          displayName: 'Kurucu',
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      inviteCode = target.inviteCode;

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        _app(const _JoinHarness(), [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(repo),
        ]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('harness-join'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        code ?? inviteCode,
      );
      await tester.pump();
    }

    testWidgets('iki kez basılsa da tek katılma isteği gider', (tester) async {
      await pumpFlow(tester);

      final submit = find.byKey(const Key('join-group-submit'));
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Kullanıcının "1.de sorun mu vardı" anı: aynı düğmeye ikinci basış.
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // İstek hâlâ uçuyor; sonuç henüz gelmedi.
      expect(repo.joinCalls, 1, reason: 'İkinci basış ikinci istek gönderdi.');

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(
        repo.joinCalls,
        1,
        reason: 'İstek bittikten sonra da tek çağrı kalmalı.',
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Gruba katıldın.'), findsOneWidget);
    });

    testWidgets('istek sürerken ilerleme göstergesi ekranda', (tester) async {
      await pumpFlow(tester);

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'Basmadan önce gösterge olmamalı.',
      );

      await tester.tap(find.byKey(const Key('join-group-submit')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'Diyalog kapanırsa kullanıcı yine boş ekrana bakar.',
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Katılıyor…'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('hatada diyalog açık kalır ve düğme yeniden etkinleşir', (
      tester,
    ) async {
      // Var olmayan kod → `GroupException('Bu koda ait grup bulunamadı.')`.
      await pumpFlow(tester, code: 'ZZZZZZ');

      final submit = find.byKey(const Key('join-group-submit'));
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'Hata diyalog içinde gösterilmeli, akış kaybolmamalı.',
      );
      // 🔴 WP-540: burada `'Beklenmeyen bir hata oluştu.'` bekleniyordu ve bu
      // iddia YANLIŞ davranışı kilitliyordu — WP-532 kapsam dışı bıraktığı
      // için ("davet kodu yanlış olduğunda kullanıcı hâlâ genel mesajı
      // görüyor"), test o kusuru sözleşmeye çevirmişti. Sebep artık koddan
      // okunuyor (`groupActionErrorText`), kullanıcı ne düzelteceğini biliyor.
      expect(find.text('Bu koda ait grup bulunamadı.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<FilledButton>(submit).onPressed,
        isNotNull,
        reason: 'Hatadan sonra kullanıcı yeniden deneyebilmeli.',
      );

      // Yeniden denenebildiğinin kanıtı: doğru kodla ikinci deneme geçer.
      await tester.enterText(find.byType(TextField).first, inviteCode);
      await tester.pump();
      await tester.tap(submit);
      await tester.pump();
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(repo.joinCalls, 2);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Gruba katıldın.'), findsOneWidget);
    });
  });
}

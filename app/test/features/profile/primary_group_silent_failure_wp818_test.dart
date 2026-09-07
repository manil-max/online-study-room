// WP-818 — birincil grup secimi ag hatasinda ARTIK SESSIZ KALMIYOR.
//
// 🔴 OLCULEN KUSUR. `_select` yalnizca `on GroupException` yakaliyordu.
// `SupabaseGroupRepository.setPrimaryGroup` ise SADECE `PostgrestException`i
// `GroupException`a sarar; ag kopmasi (`SocketException`, `ClientException`,
// `TimeoutException`) sarilmadan yukari cikar ve o dalin YANINDAN gecer.
// Cagri yeri de `onTap: () => _select(...)`, yani bir `VoidCallback` — dusen
// `Future` hicbir yere ulasmaz.
//
// Kullanicinin gordugu: gosterge doner, durur, **ne onay ne hata**.
//
// Zarari bu ekranda normalden agir, cunku secimin bir SOGUMA PENCERESI var
// (`primaryGroupLockedUntil`): kullanici "degistirdim" sanip birakir, oysa
// secim yokken grup ilerlemesi hicbir gruba yazilmaz (WP-352) ve bu kayip
// baska hicbir yuzeyde gorunmez.
//
// Bu tam olarak WP-610/617/619'da ALTI ayri yuzeyde kapatilan desendir; bu
// dosya o turlarin SAHIP yollarinda degildi. `analysis_options.yaml`
// `unawaited_futures` lint'ini acmadigi icin dusen `Future` analiz kapisinda
// da gorunmuyor.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/profile/widgets/primary_group_selector_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _me = 'me-1';

StudyGroup _group(String id, String name) => StudyGroup(
  id: id,
  name: name,
  inviteCode: 'INV$id',
  createdBy: 'owner-1',
  createdAt: DateTime.utc(2026, 7, 1),
  timeZone: 'Europe/Istanbul',
);

/// `setPrimaryGroup` istenen hatayi firlatir; gerisi bellek-ici depodur.
class _FailingGroupRepo extends InMemoryGroupRepository {
  _FailingGroupRepo(this.error);

  /// `GroupException` DEGIL: asil kusur, sarilmamis hatalarin kacmasiydi.
  final Object error;
  int calls = 0;

  @override
  Future<PrimaryGroupPreference> setPrimaryGroup({
    required String userId,
    required String groupId,
    required int expectedRevision,
  }) async {
    calls++;
    throw error;
  }
}

Future<_FailingGroupRepo> _pump(WidgetTester tester, Object error) async {
  final repo = _FailingGroupRepo(error);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: _me, displayName: 'Ben', createdAt: DateTime(2026)),
          ),
        ),
        groupRepositoryProvider.overrideWithValue(repo),
        userGroupsProvider.overrideWith(
          (ref) => Stream.value([_group('g1', 'Kamp A'), _group('g2', 'Kamp B')]),
        ),
        primaryGroupPreferenceProvider.overrideWith(
          (ref) => Stream.value(
            const PrimaryGroupPreference(
              primaryGroupId: 'g1',
              selectionRevision: 1,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: PrimaryGroupSelectorCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Ikinci grubu secip onay diyalogunu gecer.
Future<void> _selectSecondGroup(WidgetTester tester) async {
  await tester.tap(find.text('Kamp B'));
  await tester.pumpAndSettle();
  // Onay diyalogundaki olumlu dugme.
  final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  await tester.tap(find.text(l10n.primaryGroupConfirmAction));
  await tester.pumpAndSettle();
}

void main() {
  late String failedMessage;

  setUpAll(() async {
    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    failedMessage = l10n.primaryGroupChangeFailed;
  });

  // --- ASIL IDDIA ----------------------------------------------------------
  testWidgets('🔴 SARILMAMIS ag hatasi da kullaniciya SOYLENIR', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      const SocketException('baglanti koptu'),
    );

    await _selectSecondGroup(tester);

    expect(repo.calls, 1, reason: 'Yazma hic denenmedi.');
    expect(
      find.text(failedMessage),
      findsOneWidget,
      reason:
          'Ag kopmasi `GroupException` degildir; eski kod onu yakalamiyordu ve '
          'ekran ne onay ne hata gosteriyordu. Soguma penceresi yuzunden '
          'kullanici degisikligin olmadigini baska hicbir yerden ogrenemez.',
    );
  });

  testWidgets('zaman asimi da sessiz kalmaz', (tester) async {
    await _pump(tester, TimeoutException('zaman asimi'));
    await _selectSecondGroup(tester);
    expect(find.text(failedMessage), findsOneWidget);
  });

  testWidgets('beklenmeyen her hata da sessiz kalmaz', (tester) async {
    // Depo katmani ilerideki bir turda baska bir sinif firlatirsa bu ekran
    // yine konusmali — sessizlik hicbir hata sinifi icin dogru cevap degil.
    await _pump(tester, StateError('beklenmeyen'));
    await _selectSecondGroup(tester);
    expect(find.text(failedMessage), findsOneWidget);
  });

  // --- ESKI DAL BOZULMADI --------------------------------------------------
  testWidgets('GroupException dali eskisi gibi calisir', (tester) async {
    await _pump(
      tester,
      const GroupException('birincil grup yazilamadi'),
    );
    await _selectSecondGroup(tester);
    expect(
      find.text(failedMessage),
      findsOneWidget,
      reason: 'Genis yakalama eklenirken mevcut dal bozulmus olamaz.',
    );
  });

  // --- GOSTERGE TAKILI KALMAZ ----------------------------------------------
  testWidgets('hata sonrasi gosterge takili kalmaz, satir yeniden secilebilir', (
    tester,
  ) async {
    final repo = await _pump(
      tester,
      const SocketException('baglanti koptu'),
    );

    await _selectSecondGroup(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Ikinci deneme GERCEKTEN deponun kapisina iner: satir hala etkin.
    await _selectSecondGroup(tester);
    expect(
      repo.calls,
      2,
      reason:
          'Hatadan sonra satir devre disi kalirsa kullanici soguma penceresine '
          'sikisir ve tekrar deneyemez.',
    );
  });
}

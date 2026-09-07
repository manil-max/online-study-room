// WP-817 — yükleme karesindeki sahte "0", hedef kutlamasını tetikliyordu.
//
// `todayRecordedSecondsProvider` oturumları `.value ?? const []` ile okur, yani
// oturumlar yüklenirken **0** döner: "henüz bilmiyorum" ile "hiç çalışmamış"
// aynı sayıya düşer. `GoalCard` bunu `ref.listen` ile izliyor ve 0 → gerçek
// toplam sıçramasını "eşik AZ ÖNCE geçildi" sayıyordu. Sonuç: hedefini tutmuş
// kullanıcı HER SOĞUK AÇILIŞTA titreşim + halka halosu + ✓ darbesi alıyordu.
// Uygulamadaki tek kutlama anı, her açılışta oynayınca anlamını yitirir.
//
// 🔴 Ölçüt "animasyon oynadı mı" DEĞİL, **dokunsal**: `HapticFeedback`
// `MotionTokens.reduced` kontrolünden ÖNCE çağrılır (bilinçli WP-808 kararı),
// yani "animasyonları azalt" açık olan kullanıcı bile bu titreşimi hisseder.
// Ölçülebilir tek uç budur: `SystemChannels.platform` üzerindeki
// `HapticFeedback.vibrate` çağrısı. Desen `timer_haptics_wp808_test.dart`
// `_recordHaptics` yardımcısından kopyalandı (o dosyaya dokunulmadı).
//
// 🔴 Her testte kutlamanın YOKLUĞUNU iddia etmek tek başına zayıftır: kart
// sonsuza kadar iskelet kalsaydı da titreşim olmazdı ve test yeşil yanardı.
// Bu yüzden her senaryoda kartın GERÇEKTEN çizildiği ve hedefe ulaşıldığı
// (✓ ikonu) ayrıca ölçülür.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/app_locale.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/home/widgets/card_data_gate.dart';
import 'package:online_study_room/features/home/widgets/goal_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Günlük hedef: 240 dk = 14400 sn.
const _goalMinutes = 240;
const _goalSeconds = _goalMinutes * 60;

/// Gün anahtarı `dayOf(session.start)`, toplam ise `durationSeconds` üzerinden
/// gelir (`dailyTotals`). Bu yüzden başlangıcı **şimdi** verip süreyi ayrıca
/// söylemek, gece yarısı koşumunda bile bugüne düşen deterministik bir kayıt
/// üretir (v49 dersi: saatinden dolayı kırılan test).
StudySession _session(String id, int seconds) => StudySession(
  id: id,
  userId: 'u1',
  start: DateTime.now(),
  end: DateTime.now(),
  durationSeconds: seconds,
  source: StudySource.live,
);

/// Platform kanalına düşen darbeleri sırayla toplar.
List<String> _recordHaptics(WidgetTester tester) {
  final seen = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        seen.add((call.arguments as String?) ?? 'default');
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return seen;
}

/// Kartı GERÇEK sağlayıcı zinciriyle kurar: oturum akışı →
/// `dailyTotalsProvider` → `todayRecordedSecondsProvider`. Zinciri kısa devre
/// yapıp doğrudan saniye enjekte etmek, tam da düzeltilen kusuru ölçüm dışında
/// bırakırdı (kusur oturum akışının yükleme durumundan doğuyor).
Future<void> _pumpGoalCard(
  WidgetTester tester,
  Stream<List<StudySession>> sessions,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Kişisel seri kapsamı `null` kalsın: rozet kendi boş projeksiyonuna
        // düşer, testin ölçtüğü şeye karışan ikinci bir akış olmaz.
        authStateProvider.overrideWith((ref) => Stream<Profile?>.value(null)),
        dailyGoalMinutesProvider.overrideWithValue(_goalMinutes),
        userSessionsProvider.overrideWith((ref) => sessions),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Center(
            child: SizedBox(width: 360, height: 320, child: GoalCard()),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Akış olayı bir kare, kartın yeniden çizimi ikinci kare; üçüncüsü kutlamanın
/// gerçekten oynayacağı kare.
Future<void> _settleAfterEmission(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    // `formatHuman` bağlamsız çalışır ve etkin dile bakar.
    setActiveAppLocale(const Locale('tr'));
  });

  testWidgets(
    'oturumlar bir kare SONRA hedefi aşan listeyle gelirse kutlama OYNAMAZ',
    (tester) async {
      final haptics = _recordHaptics(tester);
      final sessions = StreamController<List<StudySession>>();
      addTearDown(sessions.close);

      await _pumpGoalCard(tester, sessions.stream);
      // Yükleme karesi: kart hiçbir sayı iddia etmez.
      expect(
        find.byKey(kCardSkeletonKey),
        findsOneWidget,
        reason: 'Oturumlar gelmeden kart yer tutucu çizmeli.',
      );

      // İlk emisyon hedefi ZATEN aşıyor: kullanıcı hedefini dün/bugün erken
      // tutturmuş, şimdi sadece uygulamayı açıyor.
      sessions.add([_session('s1', _goalSeconds)]);
      await _settleAfterEmission(tester);

      // Kart gerçekten çizildi ve hedefe ULAŞILMIŞ durumda — yani aşağıdaki
      // "titreşim yok" iddiası boş bir ağaç üzerinden gelmiyor.
      expect(find.byKey(kCardSkeletonKey), findsNothing);
      expect(
        find.byIcon(Icons.check_circle),
        findsOneWidget,
        reason: 'Hedef tutmuş görünmeli; yoksa test yanlış dalı ölçüyor.',
      );
      expect(
        haptics,
        isEmpty,
        reason:
            'Yükleme karesindeki sahte 0 → gerçek toplam sıçraması kutlama '
            'sayıldı. Kullanıcı o anı yaşamadı, sadece uygulamayı açtı.',
      );
    },
  );

  testWidgets('veri geldikten SONRA eşik gerçekten aşılırsa kutlama OYNAR', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);
    final sessions = StreamController<List<StudySession>>();
    addTearDown(sessions.close);

    await _pumpGoalCard(tester, sessions.stream);

    // Hedefin ALTINDA bir başlangıç: kart normal çizilir, kutlama yok.
    sessions.add([_session('s1', _goalSeconds - 3600)]);
    await _settleAfterEmission(tester);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(haptics, isEmpty);

    // Kullanıcı çalışmaya devam etti ve eşiği AZ ÖNCE geçti.
    sessions.add([
      _session('s1', _goalSeconds - 3600),
      _session('s2', 3600),
    ]);
    await _settleAfterEmission(tester);

    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
      reason: 'Hedef tutuldu; ✓ çizilmeli.',
    );
    expect(
      haptics,
      ['HapticFeedbackType.mediumImpact'],
      reason:
          'Düzeltme kutlamayı ÖLDÜRMEMELİ: gerçek eşik geçişi hâlâ '
          'kutlanmalı, yoksa çare hastalıktan kötü olur.',
    );
  });

  testWidgets('hedef zaten tutulmuş veriyle açılışta kutlama YOK', (
    tester,
  ) async {
    final haptics = _recordHaptics(tester);

    // Tek seferde, senkron gelen veri: akış açılır açılmaz hedefi aşıyor.
    await _pumpGoalCard(
      tester,
      Stream.value([_session('s1', _goalSeconds + 1800)]),
    );
    await _settleAfterEmission(tester);

    expect(find.byKey(kCardSkeletonKey), findsNothing);
    expect(
      find.byIcon(Icons.check_circle),
      findsOneWidget,
      reason: 'Hedef tutmuş görünmeli; yoksa test yanlış dalı ölçüyor.',
    );
    expect(
      haptics,
      isEmpty,
      reason: 'Açılış bir kutlama anı değildir.',
    );
  });
}

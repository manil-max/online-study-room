// WP-592: bildirim izni reddedilince sayaç GÖRÜNMEZ çalışıyordu.
//
// `requestPermissionIfNeeded` bilerek hiçbir koşulda hata fırlatmıyor (WP-520
// kararı, doğru karar: sayaç başlatma izne bağlı olmamalı). Ama izin
// reddedilince kullanıcıya HİÇBİR YERDE tek kelime söylenmiyordu:
// `notificationsEnabled` `lib/` içinde yalnız Profil → Ayarlar → Bildirim
// Merkezi'nde okunuyordu ve sayacı başlatan kişi oraya hiç uğramaz.
//
// Karşılığı: kalıcı bildirim yok, bildirimden durdurma yok, kullanıcı "sayaç
// bozuk" der. Salt-okunur denetim (WP-581) bunu KANAMA olarak işaretledi.
//
// 🔴 İki yönlü iddia zorunlu: şerit izin KAPALIYKEN görünmeli, AÇIKKEN hiç
// çizilmemeli. Tek yönlü ölçüm "şeridi koşulsuz çiz" sabotajını sessizce
// geçirirdi.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/widgets/error_retry_view.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sayaç kartının kendi konusundan (süre, hedef) bağımsız kalması için
/// notifier gerçek `build()`i atlar.
class _IdleTimerNotifier extends StudyTimerNotifier {
  @override
  StudyTimerState build() => const StudyTimerState();
}

class _FakePermissionGateway implements TimerNotificationPermissionGateway {
  _FakePermissionGateway(this._granted);

  final bool _granted;
  int settingsOpened = 0;

  @override
  Future<bool> hasPermission() async => _granted;

  @override
  Future<void> openSystemNotificationSettings() async => settingsOpened++;
}

const Key _kDeniedBanner = Key('timer-notification-denied');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pumpCard(
    WidgetTester tester,
    _FakePermissionGateway gateway,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userSessionsProvider.overrideWith(
            (_) => Stream.value(const <StudySession>[]),
          ),
          userSubjectsProvider.overrideWith(
            (_) => Stream.value(const <Subject>[]),
          ),
          dailyGoalMinutesProvider.overrideWithValue(240),
          userGroupProvider.overrideWithValue(
            const AsyncData<StudyGroup?>(null),
          ),
          studyTimerProvider.overrideWith(_IdleTimerNotifier.new),
          timerNotificationPermissionProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SizedBox(height: 620, child: StudyTimerCard()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('izin KAPALIYKEN sayac kartinda uyari serit gorunur', (
    tester,
  ) async {
    await pumpCard(tester, _FakePermissionGateway(false));

    expect(find.byKey(_kDeniedBanner), findsOneWidget);
  });

  testWidgets('izin ACIKKEN serit HIC cizilmez (tek yonlu iddia kapani)', (
    tester,
  ) async {
    await pumpCard(tester, _FakePermissionGateway(true));

    expect(find.byKey(_kDeniedBanner), findsNothing);
  });

  testWidgets('seritteki dugme sistem ayarlarini BIR KEZ acar', (tester) async {
    final gateway = _FakePermissionGateway(false);
    await pumpCard(tester, gateway);

    expect(gateway.settingsOpened, 0);

    await tester.tap(
      find.descendant(
        of: find.byKey(_kDeniedBanner),
        matching: find.byKey(kErrorRetryButtonKey),
      ),
    );
    await tester.pumpAndSettle();

    // "Dugme var ama hicbir sey yapmiyor" hatanin kendisinden kotudur
    // (WP-560 dersi): olculen sey metin degil cagri sayaci.
    expect(gateway.settingsOpened, 1);
  });

  testWidgets('dugme metni "Tekrar dene" DEGIL, dogru eylemi soyler', (
    tester,
  ) async {
    await pumpCard(tester, _FakePermissionGateway(false));

    final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
    expect(find.text(l10n.clockEksikIzinleriAc), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(_kDeniedBanner),
        matching: find.text(l10n.commonTekrarDene),
      ),
      findsNothing,
      reason:
          'Bildirim izni kapaliyken dogru cikis sistem ayarlarini acmaktir; '
          '"Tekrar dene" kullaniciya yanlis seyi vaat eder.',
    );
  });
}

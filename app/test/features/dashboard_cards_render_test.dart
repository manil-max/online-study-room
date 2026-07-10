import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';

/// §2E — Her kart tüm en-boy oranlarında taşma/clipping olmadan çizilmeli.
/// Kartları çok küçük, orta ve büyük bounded kutularda gerçek veriyle render eder
/// ve hiçbir RenderFlex/overflow istisnası atılmadığını doğrular.
void main() {
  final now = DateTime.now();

  // Birçok gün + saat + derse yayılmış örnek oturumlar (grafiklerin dolu çizmesi
  // için). Boş veri çoğu kartı "kayıt yok" kısa yoluna sokar; dolu veri gerçek
  // yerleşimi zorlar.
  final sessions = <StudySession>[
    for (var d = 0; d < 40; d++)
      StudySession(
        id: 's$d',
        userId: 'u1',
        start: DateTime(now.year, now.month, now.day, 8 + (d % 12))
            .subtract(Duration(days: d)),
        end: DateTime(now.year, now.month, now.day, 9 + (d % 12))
            .subtract(Duration(days: d)),
        durationSeconds: 1800 + (d % 5) * 900,
        source: StudySource.live,
        subjectId: d.isEven ? 'sub1' : (d % 3 == 0 ? 'sub2' : null),
      ),
  ];

  const subjects = <Subject>[
    Subject(id: 'sub1', userId: 'u1', name: 'Matematik', color: 'chart-1'),
    Subject(id: 'sub2', userId: 'u1', name: 'Fizik', color: 'chart-3'),
  ];

  final overrides = [
    userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
    userSubjectsProvider.overrideWith((ref) => Stream.value(subjects)),
    dailyGoalMinutesProvider.overrideWithValue(240),
    // Grup kartları deterministik olarak "grup yok" (GroupCardShell) yoluna gitsin.
    userGroupProvider.overrideWithValue(const AsyncData<StudyGroup?>(null)),
  ];

  // (etiket, genişlik, yükseklik) — 1x1 minik hücreden geniş+uzun karta kadar.
  const sizes = <(String, double, double)>[
    ('minik', 150, 90),
    ('orta', 320, 200),
    ('genis', 700, 520),
  ];

  for (final type in DashboardCardType.values) {
    // Sayaç kartı (2H) kendi periyodik timer'ıyla gelir; render testi askıda
    // kalmasın diye dışarıda tutulur (boyut davranışı 2H'de kapsanır).
    if (type == DashboardCardType.timer) continue;

    for (final (label, w, h) in sizes) {
      testWidgets('${type.name} kartı $label boyutta taşmaz', (tester) async {
        final details = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = details.add;
        addTearDown(() => FlutterError.onError = prev);

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: w,
                    child: dashboardCardFor(type, DashboardCardSize.medium,
                        height: h),
                  ),
                ),
              ),
            ),
          ),
        );
        // Stream sağlayıcılarının veriyi yayması için bir kare ilerlet.
        await tester.pump();

        FlutterError.onError = prev;

        expect(
          details.map((d) => d.exceptionAsString()),
          isEmpty,
          reason: '${type.name} @ $label ($w x $h) taşma/istisna üretti',
        );
      });
    }
  }
}

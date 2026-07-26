import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tour/tour_models.dart';
import 'package:online_study_room/core/tour/tour_overlay.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  List<TourDefinition> definitions(
    AppLocalizations l10n, {
    required bool hasContent,
  }) {
    final primary = GlobalKey();
    final secondary = GlobalKey();
    return [
      AppTours.home(
        l10n,
        dashboardAnchor: primary,
        editAnchor: secondary,
        isEmpty: !hasContent,
      ),
      AppTours.timer(
        l10n,
        dashboardAnchor: primary,
        editAnchor: secondary,
        isAvailable: hasContent,
      ),
      AppTours.groups(
        l10n,
        contentAnchor: primary,
        switcherAnchor: secondary,
        hasGroup: hasContent,
      ),
      AppTours.campfire(l10n, campfireAnchor: primary, hasGroup: hasContent),
      AppTours.stats(l10n, periodAnchor: primary, hasSessions: hasContent),
      AppTours.profile(l10n, identityAnchor: primary, actionsAnchor: secondary),
    ];
  }

  test('six tours have stable versioned ids and short readable steps', () {
    final overflowingSteps = <String>[];
    for (final l10n in [AppLocalizationsTr(), AppLocalizationsEn()]) {
      for (final hasContent in [true, false]) {
        final tours = definitions(l10n, hasContent: hasContent);
        expect(tours.map((tour) => tour.storageId), [
          'home.v1',
          'timer.v1',
          'groups.v1',
          'campfire.v1',
          'stats.v1',
          'profile.v1',
        ]);
        expect(tours.map((tour) => tour.id).toSet(), hasLength(tours.length));

        for (final tour in tours) {
          expect(tour.steps, isNotEmpty);
          expect(tour.steps.length, lessThanOrEqualTo(4));
          expect(
            tour.steps.map((step) => step.id).toSet(),
            hasLength(tour.steps.length),
          );
          for (final step in tour.steps) {
            expect(step.text.trim(), isNotEmpty);
            expect(step.text, isNot(contains('\n')));
            expect(step.text.length, lessThanOrEqualTo(110));
            final bodyLayout = TextPainter(
              text: TextSpan(
                text: step.text,
                style: const TextStyle(fontSize: 14),
              ),
              textDirection: TextDirection.ltr,
              maxLines: 2,
            )..layout(maxWidth: 288);
            if (bodyLayout.didExceedMaxLines) {
              overflowingSteps.add(
                '${l10n.localeName}:${tour.storageId}/${step.id}',
              );
            }
          }
        }
      }
    }
    expect(overflowingSteps, isEmpty, reason: 'Tour body exceeds two lines');
  });

  test('empty states never point at content that does not exist', () {
    final l10n = AppLocalizationsTr();
    final dashboard = GlobalKey();
    final edit = GlobalKey();
    final period = GlobalKey();

    final home = AppTours.home(
      l10n,
      dashboardAnchor: dashboard,
      editAnchor: edit,
      isEmpty: true,
    );
    final timer = AppTours.timer(
      l10n,
      dashboardAnchor: dashboard,
      editAnchor: edit,
      isAvailable: false,
    );
    final campfire = AppTours.campfire(
      l10n,
      campfireAnchor: GlobalKey(),
      hasGroup: false,
    );
    final stats = AppTours.stats(
      l10n,
      periodAnchor: period,
      hasSessions: false,
    );

    expect(home.steps.single.anchor, same(edit));
    expect(timer.steps.single.anchor, same(edit));
    expect(campfire.steps.single.anchor, isNull);
    expect(stats.steps.single.anchor, isNull);
  });

  test('Turkish and English tour content is independently localized', () {
    final tr = definitions(AppLocalizationsTr(), hasContent: true);
    final en = definitions(AppLocalizationsEn(), hasContent: true);

    for (var index = 0; index < tr.length; index++) {
      expect(
        tr[index].steps.map((step) => step.text),
        isNot(equals(en[index].steps.map((step) => step.text))),
      );
    }
  });

  testWidgets('all Turkish and English balloons fit a 360 px screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final allDefinitions = [
      ...definitions(AppLocalizationsTr(), hasContent: true),
      ...definitions(AppLocalizationsTr(), hasContent: false),
      ...definitions(AppLocalizationsEn(), hasContent: true),
      ...definitions(AppLocalizationsEn(), hasContent: false),
    ];

    for (final definition in allDefinitions) {
      for (var index = 0; index < definition.steps.length; index++) {
        final original = definition.steps[index];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TourOverlay(
                step: TourStep(
                  id: original.id,
                  title: original.title,
                  text: original.text,
                ),
                index: index,
                total: definition.steps.length,
                strings: const TourOverlayStrings(
                  skip: 'Atla / Skip',
                  next: 'İleri / Next',
                  stepCounter: _stepCounter,
                ),
                onNext: _noop,
                onSkip: _noop,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        final bubble = tester.getRect(find.byKey(const Key('tour-bubble')));
        expect(bubble.left, greaterThanOrEqualTo(0));
        expect(bubble.top, greaterThanOrEqualTo(0));
        expect(bubble.right, lessThanOrEqualTo(360));
        expect(bubble.bottom, lessThanOrEqualTo(640));
      }
    }
  });
}

String _stepCounter(int current, int total) => '$current/$total';

void _noop() {}

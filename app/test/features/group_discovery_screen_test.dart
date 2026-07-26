import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/classroom/widgets/class_switcher.dart';
import 'package:online_study_room/features/classroom/widgets/group_discovery_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final owner = Profile(
    id: 'owner',
    displayName: 'Owner',
    createdAt: DateTime(2026),
  );
  final member = Profile(
    id: 'member',
    displayName: 'Member',
    createdAt: DateTime(2026),
  );

  Future<ProviderScope> buildScope({
    required InMemoryGroupRepository repository,
    required Profile user,
    required Widget child,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ProviderScope(
      overrides: [
        groupRepositoryProvider.overrideWithValue(repository),
        authStateProvider.overrideWith((ref) => Stream.value(user)),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: child,
    );
  }

  for (final locale in const [Locale('en'), Locale('tr')]) {
    testWidgets(
      'public discovery is safe and joins in ${locale.languageCode}',
      (tester) async {
        final repository = InMemoryGroupRepository();
        await repository.createGroup(
          name: 'Global Focus',
          creator: owner,
          visibility: GroupVisibility.public,
        );
        await repository.createGroup(name: 'Hidden Group', creator: owner);

        await tester.pumpWidget(
          await buildScope(
            repository: repository,
            user: member,
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const GroupDiscoveryScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.text('Global Focus'), findsOneWidget);
        expect(find.text('Hidden Group'), findsNothing);
        expect(
          find.text(locale.languageCode == 'en' ? 'Public' : 'Herkese açık'),
          findsOneWidget,
        );
        expect(find.textContaining('owner', findRichText: true), findsNothing);

        await tester.tap(
          find.text(locale.languageCode == 'en' ? 'Join' : 'Katıl'),
        );
        await tester.pump();
        await tester.pump();

        expect(
          find.text(locale.languageCode == 'en' ? 'Joined' : 'Katıldın'),
          findsWidgets,
        );
      },
    );
  }

  for (final width in [360.0, 600.0, 1200.0]) {
    testWidgets('public discovery has no overflow at ${width.toInt()}px', (
      tester,
    ) async {
      final repository = InMemoryGroupRepository();
      await repository.createGroup(
        name: 'Long public group name that must remain readable',
        creator: owner,
        visibility: GroupVisibility.public,
      );
      tester.view.physicalSize = Size(width * 3, 1800);
      tester.view.devicePixelRatio = 3;
      final errors = <FlutterErrorDetails>[];
      final previousError = FlutterError.onError;
      FlutterError.onError = errors.add;

      await tester.pumpWidget(
        await buildScope(
          repository: repository,
          user: member,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const GroupDiscoveryScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      FlutterError.onError = previousError;
      expect(errors.map((error) => error.exceptionAsString()), isEmpty);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('create group explains private and public access', (
    tester,
  ) async {
    final repository = InMemoryGroupRepository();
    await tester.pumpWidget(
      await buildScope(
        repository: repository,
        user: member,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => FilledButton(
                onPressed: () => createGroupFlow(context, ref),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(find.text('Private'), findsOneWidget);
    expect(
      find.text('Only people with the invite code can join.'),
      findsOneWidget,
    );
    expect(find.text('Public'), findsOneWidget);
    expect(
      find.text('Anyone can discover and join this group.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await tester.pump();
  });

  testWidgets('public card shows its zone and opens the live difference', (
    tester,
  ) async {
    final repository = InMemoryGroupRepository();
    await repository.createGroup(
      name: 'New York Focus',
      creator: owner,
      visibility: GroupVisibility.public,
      timeZone: 'America/New_York',
    );

    await tester.pumpWidget(
      await buildScope(
        repository: repository,
        user: member,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GroupDiscoveryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('New York'), findsOneWidget);
    await tester.tap(find.text('New York'));
    await tester.pump();

    expect(find.text('Group time zone'), findsOneWidget);
    expect(find.textContaining('from you'), findsWidgets);
  });

  testWidgets('discovery filters hide full groups and narrow by region', (
    tester,
  ) async {
    final repository = InMemoryGroupRepository();
    final full = await repository.createGroup(
      name: 'Full New York',
      creator: owner,
      visibility: GroupVisibility.public,
      memberLimit: 2,
      timeZone: 'America/New_York',
    );
    await repository.joinPublicGroup(groupId: full.id, member: member);
    await repository.createGroup(
      name: 'Open Tokyo',
      creator: Profile(
        id: 'owner-2',
        displayName: 'Other',
        createdAt: DateTime(2026),
      ),
      visibility: GroupVisibility.public,
      timeZone: 'Asia/Tokyo',
    );

    await tester.pumpWidget(
      await buildScope(
        repository: repository,
        user: Profile(
          id: 'viewer',
          displayName: 'Viewer',
          createdAt: DateTime(2026),
        ),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GroupDiscoveryScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Has open seats'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Full New York'), findsNothing);
    expect(find.text('Open Tokyo'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tokyo').last);
    await tester.pump();
    await tester.pump();
    expect(find.text('Open Tokyo'), findsOneWidget);
  });
}

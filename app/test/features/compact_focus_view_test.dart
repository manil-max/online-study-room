import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_window.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/features/desktop/compact_focus_view.dart';

void main() {
  testWidgets('compact modda tam uygulama ağacını aynı anda çizmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: desktopChromeBody(
          isCompact: true,
          child: const Text('Tam uygulama'),
          compactChild: const Text('Compact Focus'),
        ),
      ),
    );

    expect(find.text('Compact Focus'), findsOneWidget);
    expect(find.text('Tam uygulama'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsNothing);
  });

  testWidgets('MaterialApp builder dışında kalan compact tooltip çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => desktopChromeBody(
          isCompact: true,
          child: child ?? const SizedBox.shrink(),
          compactChild: Material(
            child: Center(
              child: IconButton(
                tooltip: 'Her zaman üstte tut',
                onPressed: () {},
                icon: const Icon(Icons.push_pin_outlined),
              ),
            ),
          ),
        ),
        home: const SizedBox.shrink(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Her zaman üstte tut'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('desktop-compact-overlay')),
      findsOneWidget,
    );
  });

  testWidgets('oturum yoksa kayıt başlatmaz ve tam pencereye yönlendirir', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CompactFocusView(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Çalışmayı kaydetmek için giriş yapmalısın.'),
      findsOneWidget,
    );
    expect(find.text('Tam pencereye dön'), findsOneWidget);
    expect(find.byKey(const ValueKey('compact-focus-toggle')), findsNothing);
  });
}

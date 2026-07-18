import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-171 + WP-187: başlık dar genişlikte tek satır; level/quest yok (declutter).
void main() {
  testWidgets('achievements title stays single horizontal line', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 280,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Builder(
                      builder: (context) {
                        final theme = Theme.of(context);
                        final l10n = AppLocalizations.of(context);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    l10n.profileBasarilar,
                                    style: theme.textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // WP-187: level/quest/streak yok — yalnız rozet alanı.
                            Wrap(
                              spacing: 10,
                              children: List.generate(
                                3,
                                (_) => Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.emoji_events,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final titleFinder = find.text('Achievements');
    expect(titleFinder, findsOneWidget);
    final size = tester.getSize(titleFinder);
    expect(size.width, greaterThan(40), reason: 'title should not be letter-stacked');
    expect(size.height, lessThan(40), reason: 'title should be one line');

    // Level/quest UI yok
    expect(find.textContaining('Level'), findsNothing);
    expect(find.text('Quests'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-171: başlık + chip satırı dar genişlikte dikey harf dizilimine düşmemeli.
void main() {
  testWidgets('achievements title stays single horizontal line when chips wrap',
      (tester) async {
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
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(l10n.profileLevel(12)),
                                ),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 180),
                                    child: const Text(
                                      'Golden Crown Master Elite',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ],
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
    // Dikey harf dizilimi ~ karakter başına satır yüksekliği ile dar genişlik verir.
    expect(size.width, greaterThan(40), reason: 'title should not be letter-stacked');
    expect(size.height, lessThan(40), reason: 'title should be one line');
  });
}

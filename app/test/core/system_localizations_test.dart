import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/l10n/system_localizations.dart';

void main() {
  test('Turkish system locale resolves to Turkish', () async {
    final l10n = await loadSystemLocalizations(const Locale('tr', 'TR'));

    expect(l10n.localeName, 'tr');
    expect(l10n.commonCalismaHazir, 'Çalışma hazır');
  });

  test('unsupported system locale falls back to English', () async {
    final l10n = await loadSystemLocalizations(const Locale('fr', 'FR'));

    expect(l10n.localeName, 'en');
    expect(l10n.commonCalismaHazir, 'Ready to study');
  });

  test('German system locale loads de catalog (EN baseline strings ok)', () async {
    final l10n = await loadSystemLocalizations(const Locale('de', 'DE'));
    expect(l10n.localeName, 'de');
    // Baseline ARB hâlâ İngilizce metin taşıyabilir.
    expect(l10n.commonCalismaHazir, isNotEmpty);
  });
}

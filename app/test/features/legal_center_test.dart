import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/profile/legal_documents.dart';

void main() {
  test('legal versions and TR/EN bodies non-empty', () {
    expect(LegalDocuments.policyVersion, isNotEmpty);
    expect(LegalDocuments.communityVersion, isNotEmpty);
    expect(LegalDocuments.privacy(turkish: true).length, greaterThan(100));
    expect(LegalDocuments.privacy(turkish: false).length, greaterThan(100));
    expect(LegalDocuments.terms(turkish: true), contains('Odak'));
    expect(LegalDocuments.community(turkish: false), contains('Prohibited'));
  });

  // WP-525: bu test eskiden "varsayilan derlemede LEGAL_BASE_URL bostur"
  // diyordu ve `hasPublicLegalSite`i kosulsuz `false` bekliyordu. Adres yayin
  // derlemesine baglaninca (release.yml env.json) CI'da kirmizi dustu --
  // urunde bir hata yoktu, testin varsayimi eskimisti.
  //
  // Dogru sozlesme "adres bos" degil, "adres nasil kurulur": bos ise yol
  // uretilmez, doluysa taban + yol birlestirilir ve tabandaki fazladan `/`
  // yutulur. Iki hal de burada olculur, hangi derleme oldugu fark etmez.
  test('public URL is built only from a configured LEGAL_BASE_URL', () {
    final base = LegalDocuments.legalBaseUrl.trim();
    final url = LegalDocuments.publicUrl('legal/privacy-tr.html');

    if (base.isEmpty) {
      expect(LegalDocuments.hasPublicLegalSite, isFalse);
      expect(url, isNull);
      return;
    }

    expect(LegalDocuments.hasPublicLegalSite, isTrue);
    expect(url, isNotNull);
    expect(url, startsWith('https://'));
    expect(url, endsWith('/legal/privacy-tr.html'));
    // Tabanda sondaki egik cizgi varsa cift `//` uretilmemeli.
    expect(url!.substring('https://'.length), isNot(contains('//')));
  });
}

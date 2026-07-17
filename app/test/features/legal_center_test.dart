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

  test('public URL only when LEGAL_BASE_URL set (default empty)', () {
    // Default compile: no LEGAL_BASE_URL
    expect(LegalDocuments.hasPublicLegalSite, isFalse);
    expect(LegalDocuments.publicUrl('legal/privacy-tr.html'), isNull);
  });
}

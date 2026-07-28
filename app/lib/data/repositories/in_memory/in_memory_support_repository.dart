import 'dart:typed_data';

import '../../models/faq_entry.dart';
import '../support_repository.dart';

class InMemorySupportRepository implements SupportRepository {
  @override
  Future<List<FaqEntry>> fetchPublishedFaq(String locale) async =>
      List.unmodifiable(kFallbackFaq.where((entry) => entry.locale == locale));

  @override
  Future<void> submitQuestion({
    required String question,
    required String userId,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  }) async {}
}

const kFallbackFaq = <FaqEntry>[
  FaqEntry(
    id: 'fallback-tr-widget',
    locale: 'tr',
    sortOrder: 1,
    question: 'Ana ekrana widget nasıl eklenir?',
    answer:
        'Telefonunun widget ekleme ekranından Odak Kampı widgetını seç. Bildirim izni ve pil optimizasyonu ayarları kapalıysa widget güncel kalmayabilir.',
  ),
  FaqEntry(
    id: 'fallback-tr-notifications',
    locale: 'tr',
    sortOrder: 2,
    question: 'Bildirimleri nereden kontrol ederim?',
    answer:
        'Ayarlar > Bildirimler bölümünden izinleri ve uygulama içi duyuruları kontrol edebilirsin.',
  ),
  FaqEntry(
    id: 'fallback-tr-offline',
    locale: 'tr',
    sortOrder: 3,
    question: 'İnternetim yokken ne olur?',
    answer:
        'Uygulama son bilinen bilgileri gösterebilir. Süre ve grup verilerinin güvenli biçimde eşitlenmesi için tekrar çevrimiçi olman gerekir.',
  ),
  FaqEntry(
    id: 'fallback-en-widget',
    locale: 'en',
    sortOrder: 1,
    question: 'How do I add a home-screen widget?',
    answer:
        'Open your phone’s widget picker and select the Focus Camp widget. Notification permission and battery optimisation can affect updates.',
  ),
  FaqEntry(
    id: 'fallback-en-notifications',
    locale: 'en',
    sortOrder: 2,
    question: 'Where can I manage notifications?',
    answer:
        'Open Settings > Notifications to review permissions and in-app announcements.',
  ),
  FaqEntry(
    id: 'fallback-en-offline',
    locale: 'en',
    sortOrder: 3,
    question: 'What happens when I am offline?',
    answer:
        'The app can show its last known information. Reconnect to safely sync time and group data.',
  ),
];

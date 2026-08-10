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

/// Sunucuya ulaşılamadığında gösterilen SSS yedeği.
///
/// 🔴 WP-658 — BU LİSTE İKİNCİ BİR GERÇEK KAYNAKTIR ve bir kez eskidi.
/// SSS'in asıl kaynağı veritabanıdır (`supabase/migrations/0091`, `0123`,
/// `0130`). Buradaki kopya sunucu düzeltildiğinde **kendiliğinden
/// güncellenmez**: `0130` dokuz SSS cümlesini ürünle çeliştiği için
/// düzeltti, ama çevrimdışı kullanıcı hâlâ bu listedeki eski metni görürdü.
///
/// Kural: buraya **eskiyebilecek iddia yazılmaz.** Sayı vermek ("tek widget",
/// "2 başarımda bronz"), akış anlatmak ("giriş yaparsan istek iptal olur") ve
/// eşik saymak yasaktır — hepsi kodun değişmesiyle sessizce yalan olur.
/// Yalnız yapısal, ürün ömrü boyunca doğru kalan cümleler kalır.
/// Sözleşme: `app/test/data/faq_fallback_claims_wp658_test.dart`.
const kFallbackFaq = <FaqEntry>[
  FaqEntry(
    id: 'fallback-tr-widget',
    locale: 'tr',
    sortOrder: 1,
    question: 'Ana ekrana widget nasıl eklenir?',
    answer:
        'Telefonunun widget ekleme ekranından Odak Kampı widget seçeneklerinden birini seç. Bildirim izni ve pil optimizasyonu ayarları kapalıysa widget güncel kalmayabilir.',
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
        'Open your phone’s widget picker and pick one of the Focus Camp widgets. Notification permission and battery optimisation can affect updates.',
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

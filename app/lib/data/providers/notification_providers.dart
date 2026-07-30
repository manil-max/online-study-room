import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../models/announcement.dart';
import '../repositories/in_memory/in_memory_notification_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/supabase/supabase_notification_repository.dart';
import 'auth_providers.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final client = _supabaseClientOrNull();
  if (client != null) {
    return SupabaseNotificationRepository(client);
  }
  return InMemoryNotificationRepository();
});

/// Kullanıcıya görünen duyurular (RLS ile filtrelenir).
final myAnnouncementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const [];
  final prefs = ref.watch(notificationPreferencesProvider);
  if (!prefs.announcementsEnabled) return const [];
  return ref
      .watch(notificationRepositoryProvider)
      .fetchMyAnnouncements(user.id);
});

final readAnnouncementIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const {};
  return ref
      .watch(notificationRepositoryProvider)
      .fetchReadAnnouncementIds(user.id);
});

/// Okunmamış duyuru sayısı — rozet zincirinin duyuru ayağı.
///
/// WP-436/459: Feedback konuşmasıyla ilişkili duyurular **ayrı bir okunmamış
/// gerçek değildir**; onların gerçeği konuşma watermark'ıdır
/// (`unreadFeedbackReplyCountProvider`). Bu sayaç bu yüzden feedback
/// duyurularını dışarıda bırakır; aksi hâlde tek admin yanıtı her yüzeyde iki
/// kez sayılırdı. İkinci bir "filtreli" sayaç tutulmaz — tek ad, tek gerçek.
final unreadAnnouncementCountProvider = Provider<int>((ref) {
  final announcements = ref.watch(myAnnouncementsProvider).value ?? const [];
  final read = ref.watch(readAnnouncementIdsProvider).value ?? const {};
  return announcements
      .where(
        (announcement) =>
            announcement.relatedFeedbackTicketId == null &&
            !read.contains(announcement.id),
      )
      .length;
});

/// Bildirim tercihleri değiştikçe akıllı hatırlatmaları (seri + haftalık özet)
/// yeniden planlar. Kabuk boyunca izlenir; böylece kullanıcı Bildirim
/// Merkezi'ni açmasa da planlama tercihlerle tutarlı kalır.
///
/// WP-304: kişisel çalışma hatırlatıcıları kaldırıldı; burada artık yalnız
/// WP-153'ün akıllı hatırlatmaları planlanır.
final reminderSyncListenerProvider = Provider<void>((ref) {
  final prefs = ref.watch(notificationPreferencesProvider);
  // Bildirim eklentisi yalnız gerçek cihazda vardır; test/masaüstünde çağrı
  // atarsa sessizce yut, arayüzü etkilemesin.
  unawaited(
    ref
        .read(reminderNotificationServiceProvider)
        .syncSmartReminders(prefs)
        .catchError((_) {}),
  );
});

SupabaseClient? _supabaseClientOrNull() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

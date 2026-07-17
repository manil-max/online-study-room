import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/notifications/notification_preferences.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../models/announcement.dart';
import '../models/study_reminder.dart';
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

/// Giriş yapan kullanıcının çalışma hatırlatıcıları.
final myRemindersProvider = FutureProvider<List<StudyReminder>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const [];
  return ref.watch(notificationRepositoryProvider).fetchReminders(user.id);
});

/// Kullanıcıya görünen duyurular (RLS ile filtrelenir).
final myAnnouncementsProvider = FutureProvider<List<Announcement>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const [];
  final prefs = ref.watch(notificationPreferencesProvider);
  if (!prefs.announcementsEnabled) return const [];
  return ref.watch(notificationRepositoryProvider).fetchMyAnnouncements(user.id);
});

final readAnnouncementIdsProvider = FutureProvider<Set<String>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const {};
  return ref
      .watch(notificationRepositoryProvider)
      .fetchReadAnnouncementIds(user.id);
});

/// Okunmamış duyuru sayısı — Bildirim Merkezi rozetinde kullanılır.
final unreadAnnouncementCountProvider = Provider<int>((ref) {
  final announcements = ref.watch(myAnnouncementsProvider).value ?? const [];
  final read = ref.watch(readAnnouncementIdsProvider).value ?? const {};
  return announcements.where((a) => !read.contains(a.id)).length;
});

/// Hatırlatıcılar veya bildirim tercihleri değiştikçe yerel bildirimleri
/// yeniden planlar. Kabuk boyunca izlenir; böylece kullanıcı Bildirim
/// Merkezi'ni açmasa da planlama tercihlerle tutarlı kalır.
final reminderSyncListenerProvider = Provider<void>((ref) {
  final reminders = ref.watch(myRemindersProvider).value;
  final prefs = ref.watch(notificationPreferencesProvider);
  if (reminders == null) return;
  // Bildirim eklentisi yalnız gerçek cihazda vardır; test/masaüstünde çağrı
  // atarsa sessizce yut, arayüzü etkilemesin.
  // WP-153: syncAll ayrıca smart streak/weekly planlar.
  unawaited(
    ref
        .read(reminderNotificationServiceProvider)
        .syncAll(reminders, prefs)
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

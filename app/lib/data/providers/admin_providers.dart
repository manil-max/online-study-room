import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/admin_audit_log.dart';
import '../models/admin_user_dto.dart';
import '../models/announcement.dart';
import '../models/feedback_ticket.dart';
import '../models/study_group.dart';
import '../repositories/admin_repository.dart';
import '../repositories/in_memory/in_memory_admin_repository.dart';
import '../repositories/supabase/supabase_admin_repository.dart';
import 'auth_providers.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = _supabaseClientOrNull();
  if (client != null) {
    return SupabaseAdminRepository(client);
  }

  final repo = InMemoryAdminRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final adminIsSuperAdminProvider = FutureProvider<bool>((ref) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return false;
  return ref.watch(adminRepositoryProvider).isSuperAdmin(profile.id);
});

final adminDashboardSummaryProvider = FutureProvider<AdminDashboardSummary?>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return null;
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return null;
  return ref.watch(adminRepositoryProvider).fetchDashboardSummary(profile.id);
});

final adminFeedbackTicketsProvider = FutureProvider<List<FeedbackTicket>>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return const [];
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchFeedbackTickets(profile.id);
});

final myFeedbackTicketsProvider = FutureProvider<List<FeedbackTicket>>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return const [];
  return ref.watch(adminRepositoryProvider).fetchMyFeedbackTickets(profile.id);
});

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserDto>>((ref) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final adminGroupsProvider = FutureProvider.autoDispose<List<StudyGroup>>((ref) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchGroups();
});

final adminAnnouncementsProvider = FutureProvider.autoDispose<List<Announcement>>((ref) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchAnnouncements();
});

final adminAuditLogsProvider = FutureProvider.autoDispose<List<AdminAuditLog>>((ref) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchAuditLogs();
});

SupabaseClient? _supabaseClientOrNull() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

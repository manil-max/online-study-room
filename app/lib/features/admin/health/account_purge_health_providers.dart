import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

/// WP-E — hesap silme kuyrugunun sagligi.
///
/// 🔴 Neden `data/providers/admin_providers.dart` icinde DEGIL: o dosya bu tur
/// baska bir WP'nin (WP-692) SAHIP yolu. Saglayici, tuketicisiyle ayni klasorde
/// duruyor; tasinmasi gerekirse tek satirlik bir tasima isi.
///
/// `autoDispose` **degil**: dinleyicisiz kalip her okumada yeniden kurulan bir
/// saglayici hem karti yanip sondururdu hem de regresyon testini sessizce
/// etkisiz kilardi (Riverpod 3 tuzagi, `unreadFeedbackReplyCountProvider`
/// yorumundaki ayni ders).
final accountPurgeHealthProvider = FutureProvider<AccountPurgeHealth>((
  ref,
) async {
  // Yetki sunucudadir; istemci kapisi yalnizca gereksiz cagriyi engeller.
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) {
    throw const AdminException('not_super_admin', code: 'not_super_admin');
  }
  return ref.watch(adminRepositoryProvider).fetchAccountPurgeHealth();
});

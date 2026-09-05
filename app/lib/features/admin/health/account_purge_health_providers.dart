import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/core/net/read_retry_policy.dart';
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
///
/// 🔴 WP-771: `retry:` YOKTU. Riverpod 3 varsayilani kalici bir reddi
/// (`not_super_admin`, `42501`) 10 kez / ~38 sn yeniden dener; o sure boyunca
/// panel donen bir cark gosterir ve kayip hic yazilmaz — tuzak
/// `core/net/read_retry_policy.dart:14-21` icinde acikca yaziliydi ve diger
/// tum admin okuma saglayicilari politikayi tasiyordu.
final accountPurgeHealthProvider = FutureProvider<AccountPurgeHealth>((
  ref,
) async {
  // Yetki sunucudadir; istemci kapisi yalnizca gereksiz cagriyi engeller.
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) {
    throw const AdminException('not_super_admin', code: 'not_super_admin');
  }
  return ref.watch(adminRepositoryProvider).fetchAccountPurgeHealth();
}, retry: readRetryPolicy);

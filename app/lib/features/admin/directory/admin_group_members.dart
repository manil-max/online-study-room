import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';

/// WP-F — yonetici, **uyesi olmadigi** grubun uye listesi.
///
/// 🔴 Kusur: yonetici bir gruptan uye **atabiliyor** (`remove_group_member`)
/// ama kimin uye oldugunu **goremiyordu**. Iki sunucu siniri birden:
///   * `0115_profile_titles.sql:103` — `group_member_directory` cagirani
///     `is_group_member` ile suzer, uye olmayana `42501` doner,
///     ve
///   * `0001_initial_schema.sql:156` — `members_select` politikasi da
///     `is_group_member(group_id)`; yonetici icin SELECT istisnasi yok.
///
/// Cozum yolu (a): `admin-operations` edge fonksiyonuna `list_group_members`
/// eylemi. Fonksiyon zaten **service role** ile calisir (RLS'i asar) ve
/// **yonetici kapisinin** arkasindadir. Boylece RLS'e kalici bir yonetici
/// istisnasi acilmadi — `is_group_member` bu depoda cok yerde kullanildigi
/// icin oraya acilan her istisna butun yuzeyleri etkilerdi.
///
/// Saglayici **autoDispose degil**: `groupId` basina tek giris tutulur ve
/// dinleyicisi olmayan bir `read` yeniden istek acmaz (Riverpod 3 tuzagi).
/// Tazeleme `ref.invalidate` ile acikca yapilir.
final adminGroupMembersProvider = FutureProvider.family<List<Profile>, String>(
  (ref, groupId) async {
    // Istemci kapisi sunucunun yerine gecmez, onu **tekrarlar**: yonetici
    // olmayan bir oturum bu istegi sunucuya hic ulastirmaz (fail-closed).
    final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
    if (!isAdmin) {
      // 🔴 Mesaj TR duz metin DEGIL, kod dizesidir ve bu kasitlidir:
      // bu istisna kullaniciya HIC gosterilmiyor. Yuzey `view.unavailable`
      // dalinda kendi cevirisini ciziyor (`admin_member_picker.dart:268`,
      // `l10n.adminUyeListesiOkunamadi`). Buraya Turkce cumle yazmak,
      // hicbir yerde gorunmeyen ikinci bir metin kaynagi acardi -- l10n
      // denetimi (`scripts/l10n_audit.py`) bunu hakli olarak kirmiziya
      // dusurdu.
      throw const AdminException(
        'admin_required',
        code: 'admin_required',
      );
    }
    return ref.watch(adminRepositoryProvider).fetchGroupMembers(groupId);
  },
  // 🔴 Riverpod 3 varsayilani hatali saglayiciyi 10 kez, ~38 saniye boyunca
  // yeniden dener (`ProviderContainer.defaultRetry`) ve bu sure boyunca durum
  // `AsyncLoading(retrying: true)` kalir. Yani reddedilen bir okuma ekranda
  // yarim dakika DONEN BIR CARK olarak gorunur, kayip hic yazilmaz. Burada
  // baskin hata `403`/yetki; tekrar denemek onu duzeltmez. Hata aninda yuzeye
  // cikar, tazeleme dugmesi acikca elde kalir.
  retry: (_, _) => null,
);

/// Iki kaynagin birlesmis hali.
///
/// Kaynaklar:
///   1. [adminGroupMembersProvider] — yonetici yolu; uyesi olunmayan grupta da
///      calisir, gercek kimligi tasir.
///   2. `groupMembersByIdProvider` — kamp atesi/uye akisi; yonetici gruptaysa
///      **gercek zamanli** gunceller ama uye degilse `42501` ile duser.
///
/// Ikisi ayni kumeyi anlatir, bu yuzden **birlesim** alinir: biri dususe digeri
/// ekrani ayakta tutar. Sessiz bos liste yok — [unavailable] yalniz ikisi de
/// duserse dogrudur.
@immutable
class AdminGroupMemberView {
  const AdminGroupMemberView({
    required this.members,
    required this.isLoading,
    required this.unavailable,
  });

  final List<Profile> members;

  /// Hicbir kaynak henuz cevap vermedi.
  final bool isLoading;

  /// 🔴 Iki kaynak da okunamadi. Bos bir grup ile okunamayan bir liste ayni
  /// sey degildir; yonetici hangisi oldugunu bilmelidir.
  final bool unavailable;
}

/// Ayni kisi iki kaynakta da varsa tek satir kalir.
///
/// Kimlik secimi bilincli: **yonetici kaynagi kazanir**. `group_member_directory`
/// engellenen uyenin adini/avatarini `0115` geregi BOSALTIR (satiri silmez);
/// bu kural kamp atesi icindir ve degistirilmedi. Ama moderasyon gorunumunde
/// bosalmis bir kimlik, yoneticinin **kimi attigini** bilmeden dugmeye basmasi
/// demektir — yoneticinin kisisel engel listesi moderasyonu kor etmemeli.
AdminGroupMemberView adminGroupMemberUnion({
  required AsyncValue<List<Profile>> adminList,
  required AsyncValue<List<Profile>> memberStream,
}) {
  final admins = adminList.value;
  final streamed = memberStream.value;

  if (admins == null && streamed == null) {
    final bothFailed = adminList.hasError && memberStream.hasError;
    return AdminGroupMemberView(
      members: const [],
      isLoading: !bothFailed,
      unavailable: bothFailed,
    );
  }

  final merged = <String, Profile>{};
  final order = <String>[];

  void put(Profile profile, {required bool authoritative}) {
    final existing = merged[profile.id];
    if (existing == null) {
      merged[profile.id] = profile;
      order.add(profile.id);
      return;
    }
    if (!authoritative) {
      // Akistan gelen satir yalniz **eksigi** tamamlar.
      if (existing.displayName.trim().isEmpty &&
          profile.displayName.trim().isNotEmpty) {
        merged[profile.id] = existing.copyWith(displayName: profile.displayName);
      }
      return;
    }
    merged[profile.id] = profile.displayName.trim().isEmpty
        ? profile.copyWith(displayName: existing.displayName)
        : profile;
  }

  for (final profile in admins ?? const <Profile>[]) {
    put(profile, authoritative: true);
  }
  for (final profile in streamed ?? const <Profile>[]) {
    put(profile, authoritative: false);
  }

  return AdminGroupMemberView(
    members: [for (final id in order) merged[id]!],
    isLoading: false,
    unavailable: false,
  );
}

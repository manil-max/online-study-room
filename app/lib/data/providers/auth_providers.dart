import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/auth_redirect_config.dart';
import '../../core/config/supabase_config.dart';
import '../models/profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/in_memory/in_memory_auth_repository.dart';
import '../repositories/offline/offline_cache_store.dart';
import '../repositories/supabase/supabase_auth_repository.dart';
import 'offline_providers.dart';

/// WP-287: Şifre sıfırlama e-postasının derin bağlantı hedefi. Android'de
/// flavor'a uygun scheme (`…://login-callback`), Windows/masaüstü/web'de null
/// (kullanıcı e-postadaki kod ile sıfırlar).
Future<String?> resolveRecoveryRedirect() async {
  if (kIsWeb) return null;
  if (!Platform.isAndroid) return null;
  try {
    final info = await PackageInfo.fromPlatform();
    return authRecoveryRedirectUrl(info.packageName, isAndroid: true);
  } catch (_) {
    return null; // Paket adı okunamazsa güvenli tarafta OTP yoluna düş.
  }
}

/// Aktif AuthRepository. Anahtarlar verilmişse Supabase, yoksa bellek-içi.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAuthRepository(
      Supabase.instance.client,
      recoveryRedirect: resolveRecoveryRedirect,
      // WP-609: ağ yolu düşerse depo, metadata'dan eksik profil üretmek
      // yerine önbellekteki son gerçek profili döndürür.
      cachedProfile: () => ref.read(offlineCacheStoreProvider).readProfile(),
      // 🔴 WP-621: önbelleğe YALNIZ sunucudan gerçekten okunan profil yazılır.
      // Aşağıdaki `onRemoteProfile` akıştan geçen HER profil için çalışıyor ve
      // çevrimdışı üretilen (günlük hedefi varsayılana düşmüş) yedeği de
      // "son gerçek profil" diye diske yazıyordu; WP-609 sonra onu okuyordu,
      // yani bozuk veri kalıcılaşıyordu.
      onServerProfile: (profile) {
        // `_offlineCacheOrNull`: önbellek açılışın YEDEĞİdir, yokluğu
        // (prefs override edilmemiş test) açılışı düşürmemeli.
        final write = _offlineCacheOrNull(ref)?.saveProfile(profile);
        if (write != null) unawaited(write.catchError((_) {}));
      },
    );
  }
  final repo = InMemoryAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

/// WP-603: açılışın ağ beklemesine izin verilen üst sınırı.
///
/// 🔴 Ölçüldü, tahmin edilmedi (`docs/analiz/WP-603-cevrimdisi-acilis.md`):
/// internet yokken oturumu olan kullanıcı **~20 saniye** dönen bir çemberle
/// karşılaşıyordu. Zincir şuydu:
///
/// 1. `authStateProvider` ilk olayını `SupabaseAuthRepository._sessionProfiles`
///    üretir; o da ilk `yield`den ÖNCE `profiles` satırını çeker.
/// 2. İstek `AuthHttpClient.send` içinden geçer; bu sarmalayıcı istekten önce
///    `_getAccessToken()` bekler. Oturumun süresi dolmuşsa gotrue orada
///    yeniden deneme döngüsüne girer (`autoRefreshTickDuration` = 10 sn).
/// 3. Ancak ondan sonra gövde `TimeoutHttpClient`e ulaşır ve WP-542'nin 10
///    saniyelik tavanına takılır.
///
/// Yani WP-542 tavanı zincirin **yalnız ikinci yarısını** kapsıyordu:
/// 10 sn (token tazeleme) + 10 sn (istek) = kullanıcının saydığı 20 saniye.
///
/// Bu bütçe o zincirin uzunluğundan bağımsızdır: cihazda kalıcı bir oturum
/// varsa açılış en geç bu süre içinde tamamlanır. Sağlıklı ağda ilk olay çok
/// daha erken gelir ve yedek **hiç** devreye girmez.
@visibleForTesting
const Duration kAuthColdStartBudget = Duration(seconds: 2);

/// Ağa hiç gitmeden, cihazdaki oturumdan profil üretebilen okuyucu.
typedef LocalSessionProfileReader = Future<Profile?> Function();

/// Oturum akışını ağ beklemesinden ayırır (WP-603).
///
/// Sözleşme iki yönlüdür:
/// * Ağ yokken: [source] [budget] içinde konuşmazsa **yerel** oturum profili
///   yayınlanır; uygulama açılır.
/// * Ağ varken: [source] bütçeden önce konuşur, yedek hiç çalışmaz ve
///   çevrimiçi davranış birebir korunur.
///
/// Hata dalı da yedeğe düşer. Gerekçesi: `AuthGate`in hata ekranı kullanıcıya
/// "Tekrar dene" ve "Çıkış yap" sunar; metroda ikisi de çıkışsızdır —
/// yeniden denemek yine ağ ister, çıkmak ise çevrimdışı geri girilemeyen bir
/// kapıdır. Yerel oturum varken doğru cevap kullanıcıyı içeri almaktır.
/// Yerel oturum **yoksa** hata aynen iletilir (gerçek arıza gizlenmez).
///
/// 🔴 WP-748: hata dalı kullanıcıyı **içeri alır ama İDDİA KURMAZ.** Bir hata,
/// "internet yok"un kanıtı değildir. Çevrimdışılığın bu depoda ölçülen imzası
/// **sessizliktir** ([kAuthColdStartBudget] belgesindeki zincir: 10 sn token
/// tazeleme + 10 sn istek tavanı ≈ 20 sn cevapsızlık) — 200 ms'de dönen,
/// sınıflandırılmamış bir hata değil. Eskiden hata dalı da `onOfflineOpen`
/// tetikliyordu, yani çevrimiçi bir cihazdaki tek bir başarısız istek
/// kullanıcıya "İnternet yok" dedirtiyordu.
@visibleForTesting
Stream<Profile?> authStateWithOfflineFallback({
  required Stream<Profile?> source,
  required LocalSessionProfileReader localProfile,
  Duration budget = kAuthColdStartBudget,
  void Function(Profile profile)? onRemoteProfile,
  void Function()? onOfflineOpen,
}) {
  final out = StreamController<Profile?>();
  StreamSubscription<Profile?>? sub;
  Timer? timer;
  // Kaynak bir kez konuştuysa yedek bir daha ASLA devreye girmez: geç gelen
  // gerçek profilin üstüne bayat yedeği yazmak WP-478'in kapattığı hatanın
  // aynısını geri getirirdi.
  var sourceSpoke = false;
  // Dinleyici kalmadıysa geri çağırmalar ATEŞLENMEZ. Riverpod'da bu, atılmış
  // bir sağlayıcıya `ref.read` demek olurdu; zamanlayıcı ile iptal arasındaki
  // yarışı bayrak kapatır.
  var cancelled = false;

  // WP-748: AÇILIŞ ile İDDİA ayrıdır. [claimOffline] yalnız sessizlik
  // ölçüldüğünde (bütçe doldu) true'dur; hata dalı kullanıcıyı içeri alır ama
  // çevrimdışılık iddia etmez.
  Future<bool> emitLocal({required bool claimOffline}) async {
    if (sourceSpoke || cancelled || out.isClosed) return false;
    Profile? local;
    try {
      local = await localProfile();
    } catch (_) {
      local = null;
    }
    if (sourceSpoke || cancelled || out.isClosed || local == null) return false;
    out.add(local);
    if (claimOffline) onOfflineOpen?.call();
    return true;
  }

  out.onListen = () {
    timer = Timer(budget, () => emitLocal(claimOffline: true));
    sub = source.listen(
      (profile) {
        sourceSpoke = true;
        timer?.cancel();
        if (profile != null && !cancelled) onRemoteProfile?.call(profile);
        out.add(profile);
      },
      onError: (Object error, StackTrace stack) async {
        timer?.cancel();
        final rescued = await emitLocal(claimOffline: false);
        sourceSpoke = true;
        if (out.isClosed) return;
        if (!rescued) out.addError(error, stack);
      },
      onDone: () async {
        timer?.cancel();
        await emitLocal(claimOffline: true);
        if (!out.isClosed) await out.close();
      },
    );
  };
  out.onCancel = () {
    cancelled = true;
    timer?.cancel();
    return sub?.cancel();
  };
  return out.stream;
}

/// Cihazdaki oturumdan (ağ olmadan) profil üretir.
///
/// Öncelik önbellekteki son gerçek profildir; yoksa oturumun `user_metadata`
/// alanı kullanılır. İkinci yol `SupabaseAuthRepository._profileFor`un
/// çevrimdışı yedeğiyle aynıdır — orada günlük hedef varsayılana düşer,
/// bu yüzden önbellek tercih edilir.
@visibleForTesting
Future<Profile?> localSessionProfile(OfflineCacheStore? cache) async {
  final user = currentLocalSessionUser();
  if (user == null) return null;
  final cached = cache?.readProfile();
  if (cached != null && cached.id == user.id) return cached;
  return Profile(
    id: user.id,
    displayName: (user.userMetadata?['display_name'] as String?)?.trim() ?? '',
    createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
  );
}

/// Yerel (diskten geri yüklenmiş) oturumun kullanıcısı. Ağ isteği YAPMAZ:
/// `Supabase.initialize` içindeki `setInitialSession` bunu `runApp`'ten önce
/// zaten belleğe koyar.
@visibleForTesting
User? currentLocalSessionUser() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client.auth.currentUser;
  } catch (_) {
    // Supabase hiç kurulmadıysa (bellek-içi mod, testler) yerel oturum yoktur.
    return null;
  }
}

/// WP-603: bu açılış yerel oturumla mı tamamlandı? `AuthGate` bunu bir kez
/// kullanıcıya söyler; sessiz çevrimdışılık, uygulamanın bozuk olduğunu
/// düşündürüyordu.
final authOpenedOfflineProvider =
    NotifierProvider<AuthOpenedOfflineNotifier, bool>(
      AuthOpenedOfflineNotifier.new,
    );

class AuthOpenedOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void mark() {
    if (!state) state = true;
  }

  void clear() {
    if (state) state = false;
  }
}

/// Açılışın çevrimdışı yedeği — ayrı bir sağlayıcı olmasının sebebi
/// **ölçülebilirlik**: testte gerçek `authStateProvider` ayağa kalkabilsin ve
/// yerel oturum enjekte edilebilsin. Doğrudan `Supabase.instance` okuyan bir
/// gövde, kablonun bağlı olup olmadığını sınanamaz hale getirirdi (bu deponun
/// tekrar eden hatası: yazılmış ama çağıran yok).
final localSessionProfileProvider = Provider<LocalSessionProfileReader>((ref) {
  final cache = _offlineCacheOrNull(ref);
  return () => localSessionProfile(cache);
});

/// Oturum durumu: giriş yapan profil veya null.
final authStateProvider = StreamProvider<Profile?>((ref) {
  return authStateWithOfflineFallback(
    source: ref.watch(authRepositoryProvider).authStateChanges(),
    localProfile: ref.watch(localSessionProfileProvider),
    onRemoteProfile: (profile) {
      // 🔴 WP-621: buradaki önbellek yazımı KALDIRILDI. Bu geri çağırım
      // akıştan geçen her profil için çalışıyor ve çevrimdışı üretilen eksik
      // yedeği de "son gerçek profil" diye yazıyordu. Yazma artık depodaki
      // `onServerProfile` ile yalnız gerçek sunucu satırında yapılıyor.
      ref.read(authOpenedOfflineProvider.notifier).clear();
    },
    onOfflineOpen: () => ref.read(authOpenedOfflineProvider.notifier).mark(),
  );
});

/// `sharedPreferencesProvider` yalnız `main()` içinde override edilir; onu
/// okumayan testlerde bu sağlayıcı fırlatır. Önbellek açılışın **yedeği**
/// olduğundan yokluğu açılışı düşürmemeli.
OfflineCacheStore? _offlineCacheOrNull(Ref ref) {
  try {
    return ref.watch(offlineCacheStoreProvider);
  } catch (_) {
    return null;
  }
}

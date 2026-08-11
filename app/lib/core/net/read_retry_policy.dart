import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/moderation_repository.dart';

/// Okuma saglayicilarinin **tek kanonik** yeniden deneme politikasi.
///
/// WP-692 bunu `admin_providers.dart` icinde `adminRetryPolicy` adiyla yazdi;
/// WP-702 ayni tuzagin kullaniciya gorunen saglayicilarda da durdugunu olctu
/// (moderasyon, analitik, moderasyon kuyrugu — 13 okuma saglayicisi). Politika
/// artik "admin" degil, **okuma** politikasidir; iki kopya tutulmaz.
///
/// Kusur (riverpod-3.3.2): `ProviderContainer.defaultRetry`
/// (`provider_container.dart:940`) yalniz `Error` ve `ProviderException` icin
/// durur. Uygulamanin `AdminException`/`ModerationException`'i ve ham
/// `PostgrestException` **`Exception`**tir → **10 kez / ~38 sn** yeniden
/// denenir. O sure boyunca element `AsyncLoading(retrying: true)` doner
/// (`element.dart:781-787`), yani ekranda **donen cark** vardir ve kayip hic
/// yazilmaz; ustelik `onLoading` completer'i tamamlamadigi icin
/// (`element.dart:80`) `.future` bekleyen her cagri de askida kalir.
///
/// 🔴 Kapatma **TOPTAN DEGIL**. Ayni istisna tipi gercekten gecici bir ag
/// hatasini da sarar (`SocketException`, `ClientException`, zaman asimi); o
/// izlerde yeniden deneme YARARLIDIR ve acik birakilir. Ayrim bu yuzden
/// **saglayici basina degil, hata basina** yapilir.
///
/// Olcum: `test/features/admin/admin_provider_retry_wp692_test.dart` ve
/// `test/data/user_provider_retry_wp702_test.dart`.
Duration? readRetryPolicy(int retryCount, Object error) {
  if (isPermanentReadFailure(error)) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

/// Gecici (yeniden denemeye deger) ag izleri. Kullaniciya gosterilen metin
/// degil, istisna sinifi adlari/soket hata metinleridir — l10n kapsami disi.
const List<String> _transientErrorMarkers = <String>[
  'socketexception',
  'clientexception',
  'httpexception',
  'handshakeexception',
  'timeoutexception',
  'timed out',
  'failed host lookup',
  'connection closed',
  'connection reset',
  'connection refused',
  'connection attempt failed',
  'network is unreachable',
  'software caused connection abort',
];

bool _looksTransient(String message) {
  final normalized = message.toLowerCase();
  return _transientErrorMarkers.any(normalized.contains);
}

/// Hatanin tekrar denemekle **duzelmeyecegi** bir cevap olup olmadigi.
bool isPermanentReadFailure(Object error) {
  if (error is AdminException) {
    // Varsayilan: kalici. `AdminException` = "sunucu/istemci kapisi HAYIR
    // dedi". Yalniz acikca gecici bir ag izi tasiyorsa istisna yapilir.
    return !_looksTransient('${error.code ?? ''} ${error.message}');
  }
  if (error is ModerationException) {
    // Ayni sozlesme: depo katmani PostgREST reddini (`permission denied`,
    // `42501`, dogrulama) bu tipe sarar. Genis `catch` dallari ag hatasini da
    // ayni tipe sardigi icin ayrim yine METINDEN yapilir.
    return !_looksTransient(error.message);
  }
  if (error is PostgrestException) {
    // Ham PostgREST hatasi da saglayiciya ulasir: `analytics_query` deposu
    // hicbir seyi sarmalamaz, `listBlockedUserIds` de sarmalamaz.
    // Siniflandirma icin **yeni bir kaynak acilmaz**, deponun kendi esleyicisi
    // kullanilir.
    return classifyFeedbackSubmitError(
          postgrestCode: error.code,
          message: error.message,
        ) ==
        'session_or_rls';
  }
  return false;
}

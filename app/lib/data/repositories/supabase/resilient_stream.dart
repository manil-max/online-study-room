import 'dart:async';
import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

// WP-938 — canli akis (Realtime) koparsa ekran REST ile calismaya devam eder.
//
// 🔴 Neden var (olculdu, tahmin degil): `supabase-2.13.0`
// `supabase_stream_builder.dart` icinde kanal `timedOut` / `channelError`
// durumuna dustugunde akisa `RealtimeSubscribeException` yazar. Ust kattaki
// `StreamProvider` bu hatayi VERININ YERINE koyar; Gruplar sekmesi ve ana
// ekrandaki grup kartlari "Beklenmeyen bir hata olustu" der ve "tekrar dene"
// ayni kopuk soketi yeniden acar. Sunucu saglikliydi, REST calisiyordu; yalniz
// websocket kurulamiyordu (ISS/DPI, captive ag, arka plandan donus).
//
// Sozlesme:
//   * dinlenince REST verisi HEMEN istenir — soket hic baglanmasa da ekran dolar;
//   * Realtime calisirsa guncellemeler aynen akar;
//   * Realtime'in kendi hatasi (abonelik zaman asimi, kanal hatasi, soket)
//     akisa HATA OLARAK DUSMEZ: son veri korunur, REST yoklamasina
//     ([kResilientPollInterval]) gecilir ve abonelik geri cekilmeyle
//     ([kResilientRetryBackoff]) yeniden denenir;
//   * REST'in kendi hatasi (yetki, sunucu, ag) GIZLENMEZ — gercek ariza gorunur;
//   * dinleyici iptal edince zamanlayici ve kanal birakilir.

/// Realtime koptugunda REST yoklama araligi.
const Duration kResilientPollInterval = Duration(seconds: 30);

/// Realtime aboneligini yeniden deneme beklemeleri; son deger tavandir.
const List<Duration> kResilientRetryBackoff = [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 60),
];

/// Yeniden kurulan abonelik bu sure hatasiz yasarsa saglikli sayilir: yoklama
/// durur, geri cekilme sifirlanir. Realtime katilim zaman asimindan (10 sn)
/// uzun secildi; yoksa ayni soket bir kez daha dusmeden saglikli ilan edilirdi.
const Duration kResilientHealthyAfter = Duration(seconds: 30);

/// Hata Realtime tasima katmanindan mi geliyor (veri/yetki degil)?
///
/// `RealtimeSubscribeException` paketin kendi turudur. Websocket hatalari
/// (`WebSocketChannelException` vb.) dogrudan bagimlilik olmayan bir paketten
/// geldigi icin tur adiyla taninir.
bool isRealtimeTransportError(Object error) {
  if (error is RealtimeSubscribeException) return true;
  return error.runtimeType.toString().contains('WebSocket');
}

/// [realtime] canli akisini [fetch] REST yedegiyle saran akis (WP-938).
///
/// [realtime] her (yeniden) abonelikte yeniden cagrilir; her cagri taze bir
/// kanal kurmalidir (`client.from(...).stream(...)` boyledir).
Stream<T> resilientRealtimeStream<T>({
  required Stream<T> Function() realtime,
  required Future<T> Function() fetch,
  Duration pollInterval = kResilientPollInterval,
  List<Duration> retryBackoff = kResilientRetryBackoff,
  Duration healthyAfter = kResilientHealthyAfter,
  bool Function(Object error) isRealtimeFailure = isRealtimeTransportError,
}) {
  assert(retryBackoff.isNotEmpty, 'retryBackoff bos olamaz');
  late final StreamController<T> controller;
  StreamSubscription<T>? realtimeSub;
  Timer? pollTimer;
  Timer? retryTimer;
  Timer? healthyTimer;
  var disposed = false;
  var degraded = false;
  var attempt = 0;
  // Her abonelik kendi kusagini tasir; iptal edilmis eski aboneligin gec
  // gelen olayi yeni durumu bozamaz.
  var generation = 0;
  // Realtime'dan veri geldikce artar: o veriden ONCE baslamis bir REST
  // cevabi daha eskidir ve yazilmaz (eski liste yeni listeyi ezmesin).
  var realtimeEpoch = 0;
  var fetchSeq = 0;

  bool isOpen() => !disposed && !controller.isClosed;

  Future<void> refresh() async {
    final seq = ++fetchSeq;
    final startedEpoch = realtimeEpoch;
    try {
      final value = await fetch();
      if (!isOpen() || seq != fetchSeq || realtimeEpoch != startedEpoch) return;
      controller.add(value);
    } catch (error, stackTrace) {
      if (!isOpen() || seq != fetchSeq || realtimeEpoch != startedEpoch) return;
      controller.addError(error, stackTrace);
    }
  }

  void startPolling() {
    pollTimer ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
  }

  void stopPolling() {
    pollTimer?.cancel();
    pollTimer = null;
  }

  late final void Function() subscribe;

  void realtimeLost() {
    if (!isOpen()) return;
    generation++;
    healthyTimer?.cancel();
    healthyTimer = null;
    final lost = realtimeSub;
    realtimeSub = null;
    if (lost != null) unawaited(lost.cancel());
    degraded = true;
    startPolling();
    // Kopukluk penceresinde kacan degisiklikler hemen tazelenir.
    unawaited(refresh());
    if (retryTimer == null) {
      final delay = retryBackoff[math.min(attempt, retryBackoff.length - 1)];
      attempt++;
      retryTimer = Timer(delay, () {
        retryTimer = null;
        if (isOpen()) subscribe();
      });
    }
  }

  subscribe = () {
    final myGeneration = ++generation;
    final Stream<T> source;
    try {
      source = realtime();
    } catch (error, stackTrace) {
      if (isRealtimeFailure(error)) {
        realtimeLost();
      } else if (isOpen()) {
        controller.addError(error, stackTrace);
      }
      return;
    }
    realtimeSub = source.listen(
      (value) {
        if (!isOpen() || myGeneration != generation) return;
        realtimeEpoch++;
        controller.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!isOpen() || myGeneration != generation) return;
        if (isRealtimeFailure(error)) {
          realtimeLost();
        } else {
          controller.addError(error, stackTrace);
        }
      },
      onDone: () {
        // Paket `closed` durumunda akisi sessizce kapatir; sessiz donma
        // yerine yoklamaya gecilir ve abonelik yeniden denenir.
        if (!isOpen() || myGeneration != generation) return;
        realtimeLost();
      },
    );
    if (degraded) {
      healthyTimer = Timer(healthyAfter, () {
        healthyTimer = null;
        if (!isOpen() || myGeneration != generation) return;
        degraded = false;
        attempt = 0;
        stopPolling();
      });
    }
  };

  controller = StreamController<T>(
    onListen: () {
      unawaited(refresh());
      subscribe();
    },
    onCancel: () async {
      disposed = true;
      generation++;
      pollTimer?.cancel();
      retryTimer?.cancel();
      healthyTimer?.cancel();
      pollTimer = retryTimer = healthyTimer = null;
      final sub = realtimeSub;
      realtimeSub = null;
      await sub?.cancel();
    },
  );
  return controller.stream;
}

/// Tek `eq` suzgecli bir tablonun canli akisi + ayni sorgunun REST esi.
///
/// Iki yol ayni filtreyi, sirayi ve limiti kullanir; [map] iki yolda da ayni
/// satir listesine uygulanir, boylece REST yedegi canli akisla ayni sonucu
/// uretir. `order` verilmezse iki yol da sunucu sirasina birakir.
Stream<T> resilientTableStream<T>({
  required SupabaseClient client,
  required String table,
  required List<String> primaryKey,
  required String eqColumn,
  required Object eqValue,
  String? orderBy,
  bool ascending = false,
  int? limit,
  required FutureOr<T> Function(List<Map<String, dynamic>> rows) map,
  Duration pollInterval = kResilientPollInterval,
  List<Duration> retryBackoff = kResilientRetryBackoff,
  Duration healthyAfter = kResilientHealthyAfter,
}) {
  Stream<List<Map<String, dynamic>>> live() {
    final filtered = client
        .from(table)
        .stream(primaryKey: primaryKey)
        .eq(eqColumn, eqValue);
    if (orderBy == null) {
      return limit == null ? filtered : filtered.limit(limit);
    }
    final ordered = filtered.order(orderBy, ascending: ascending);
    return limit == null ? ordered : ordered.limit(limit);
  }

  Future<List<Map<String, dynamic>>> rest() async {
    final filtered = client.from(table).select().eq(eqColumn, eqValue);
    if (orderBy == null) {
      return limit == null ? await filtered : await filtered.limit(limit);
    }
    final ordered = filtered.order(orderBy, ascending: ascending);
    return limit == null ? await ordered : await ordered.limit(limit);
  }

  return resilientRealtimeStream<T>(
    realtime: () => live().asyncMap(map),
    fetch: () async => map(await rest()),
    pollInterval: pollInterval,
    retryBackoff: retryBackoff,
    healthyAfter: healthyAfter,
  );
}

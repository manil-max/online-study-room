import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';

/// WP-373 — çoklu cihaz sayaç senkronunun sözleşme kapanı.
///
/// 🔴 Kapatılan arıza: V2 komut protokolünün `origin` sözlüğü **üç ayrı yerde**
/// tanımlıydı ve ikisi ayrışmıştı. Sunucu `app|widget|notification|recovery`
/// bekliyor, native üretici ham `dart_app|native_widget|native_notification`
/// yazıyordu. Aradaki çeviri hiç yazılmamıştı; her `start` RPC'si
/// `invalid_global_timer_origin` ile patlıyor, hata istemcide yutuluyordu.
/// Sonuç: WP-341'den WP-373'ye kadar **tek bir komut bile** sunucuya ulaşmadı.
///
/// Neden hiçbir test yakalamadı: pgTAP sunucuyu kendi uydurduğu `'app'` değeriyle
/// çağırıyordu, Dart testleri `flushShadow()`'u komple stub'lıyordu ve InMemory
/// repo payload'ı hiç doğrulamıyordu. Yani her uç kendi içinde tutarlıydı,
/// aralarını tutan hiçbir iddia yoktu.
///
/// Bu dosya tam olarak o boşluğu doldurur: üç ucu (Kotlin üretici · Dart sabit ·
/// migration allowlist) **birbirine karşı** ölçer. Biri değişip diğeri
/// değişmezse test kırmızı düşer.
const _storePath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
    'TimerStateStore.kt';
const _servicePath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/'
    'StudyTimerService.kt';
const _migrationPath = '../supabase/migrations/0082_global_timer_v2.sql';

/// Native `canonicalV2Origin` gövdesindeki `"x" -> "y"` eşlemeleri.
Map<String, String> _nativeOriginMapping(String store) {
  final start = store.indexOf('fun canonicalV2Origin');
  expect(start, isNot(-1), reason: 'canonicalV2Origin native tarafta yok');
  final end = store.indexOf('\n    }', start);
  expect(end, isNot(-1), reason: 'canonicalV2Origin gövdesi kapanmıyor');
  final body = store.substring(start, end);
  return {
    for (final match in RegExp(
      r'"([a-z_]+)"\s*->\s*"([a-z_]+)"',
    ).allMatches(body))
      match.group(1)!: match.group(2)!,
  };
}

/// Migration'daki `v_origin not in ('app', 'widget', ...)` allowlist'i.
Set<String> _serverAllowlist(String migration) {
  final match = RegExp(
    r"v_origin not in \(([^)]*)\)",
  ).firstMatch(migration);
  expect(match, isNotNull, reason: 'sunucu origin allowlist\'i bulunamadı');
  return RegExp("'([a-z_]+)'")
      .allMatches(match!.group(1)!)
      .map((m) => m.group(1)!)
      .toSet();
}

void main() {
  late String store;
  late String service;
  late String migration;

  // Satır sonları normalize edilir: bu depoda kaynak dosyalar karışık CRLF/LF
  // taşıyor ve ham `\n` içeren iddialar dosyaya dokunan her araçla kırılıyor.
  String read(String path) =>
      File(path).readAsStringSync().replaceAll('\r\n', '\n');

  setUpAll(() {
    store = read(_storePath);
    service = read(_servicePath);
    migration = read(_migrationPath);
  });

  test('istemci sabiti sunucu allowlist\'iyle birebir aynıdır', () {
    expect(
      TimerV2CommandEnvelope.canonicalOrigins,
      _serverAllowlist(migration),
      reason:
          'Sunucu bu kümenin dışındaki her origin\'i reddeder. Kümeler '
          'ayrışırsa senkron sessizce ölür — WP-373\'ye kadar tam olarak bu oldu.',
    );
  });

  test('native üretici yalnız sunucunun tanıdığı origin\'i yazar', () {
    final mapping = _nativeOriginMapping(store);

    expect(
      mapping,
      isNotEmpty,
      reason: 'native tarafta hiç origin çevirisi yok',
    );
    for (final produced in mapping.values) {
      expect(
        TimerV2CommandEnvelope.canonicalOrigins,
        contains(produced),
        reason:
            '"$produced" sunucu allowlist\'inde yok; bu origin\'le gönderilen '
            'her komut invalid_global_timer_origin ile reddedilir.',
      );
    }
  });

  test('uygulamanın ürettiği her startOrigin ya çevrilir ya bilinçli dışlanır',
      () {
    final mapping = _nativeOriginMapping(store);
    // Uygulamanın gerçekten yazabildiği yerel origin değerleri.
    const produced = <String>{
      'dart_app',
      'native_widget',
      'native_notification',
      'global_timer_mirror',
    };
    // Ayna, kullanıcının yeni bir niyeti değil uzak gerçeğin gösterimidir;
    // komut üretmemesi DOĞRUDUR (aksi halde echo start döngüsü olurdu).
    const deliberatelyExcluded = <String>{'global_timer_mirror'};

    for (final origin in produced) {
      if (deliberatelyExcluded.contains(origin)) {
        expect(
          mapping.containsKey(origin),
          isFalse,
          reason: '$origin komut üretmemeli — ayna echo start yaratır',
        );
        continue;
      }
      expect(
        mapping.containsKey(origin),
        isTrue,
        reason:
            '$origin için protokol çevirisi yok → bu yoldan başlatılan sayaç '
            'hiçbir zaman diğer cihaza yansımaz.',
      );
    }

    // Kaynak dosyalarda gerçekten bu değerlerin geçtiğini de doğrula; biri
    // yeniden adlandırılırsa yukarıdaki liste sessizce bayatlamasın.
    expect(service, contains('startOrigin = "native_widget"'));
    expect(service, contains('"native_notification"'));
    expect(
      File('lib/core/background/timer_foreground_service.dart')
          .readAsStringSync(),
      contains("String startOrigin = 'dart_app'"),
    );
  });

  test('şema sürümü Kotlin üretici ile Dart tüketicide aynıdır', () {
    expect(
      store,
      contains('"schema_version", ${TimerV2CommandEnvelope.schemaVersion}'),
      reason:
          'Sürümler ayrışırsa native yazdığı zarfı Dart hiç tanımaz ve kuyruk '
          'sessizce boşa döner.',
    );
  });

  test('durdurma zarfı oturum muhasebesinden bağımsız üretilir', () {
    // 🔴 Kapatılan arıza: `appendV2Command("stop")` `recordInterval` bloğunun
    // içindeydi. Uygulama içi Durdur STOP_SILENT (recordInterval=false) yolunu
    // kullanır → en sık kullanılan durdurma hiç sinyal üretmiyordu.
    // Yapısal ölçüm: `handleStop` içinde 12 boşluk = fonksiyon gövdesi,
    // 16 boşluk = `if (recordInterval) {` bloğunun içi. Zarfı üreten çağrının
    // girintisi, hangi kapsamda olduğunun kaçamaksız kanıtıdır.
    final stopCall = RegExp(
      r'\n( *)TimerStateStore\.appendV2Command\(\n[^)]*action = "stop"',
    ).firstMatch(service);
    expect(
      stopCall,
      isNotNull,
      reason: 'native tarafta V2 durdurma zarfını üreten çağrı yok',
    );
    expect(
      stopCall!.group(1)!.length,
      12,
      reason:
          'V2 stop zarfı hâlâ recordInterval bloğunun içinde (16 boşluk); '
          'uygulama içi Durdur karşı cihazı durduramaz.',
    );
    expect(service, contains('ACTION_STOP_SILENT -> handleStop(recordInterval = false)'));
    expect(service, contains('KEY_V2_RUN_ID'));
    expect(service, contains('KEY_V2_RUN_REVISION'));
  });

  test('sunucu stop için zorunlu tuttuğu alanlar zarfta garanti edilir', () {
    expect(migration, contains('stop_run_revision_required'));
    // Native: kimliksiz stop zarfı hiç yazılmaz (kalıcı zehir üretmesin).
    expect(store, contains('if (action == "stop" &&'));
    // Dart: kimliksiz stop zarfı parse edilmez (eski kayıtlar düşsün).
    const stopWithoutRevision = {
      'kind': 'global_timer_command',
      'schema_version': TimerV2CommandEnvelope.schemaVersion,
      'command_id': 'command-1',
      'account_id': 'account-a',
      'installation_id': 'installation-1',
      'action': 'stop',
      'client_occurred_at': '2026-07-27T20:15:00.000Z',
      'origin': 'app',
      'run_id': 'run-1',
    };
    expect(TimerV2CommandEnvelope.tryParse(stopWithoutRevision), isNull);
    expect(
      TimerV2CommandEnvelope.tryParse({
        ...stopWithoutRevision,
        'expected_run_revision': 3,
      }),
      isNotNull,
    );
  });

  test('eski sözlükle yazılmış zarflar kuyruktan düşer', () {
    const adapter = TimerV2CommandFlushAdapter();
    // Cihazlarda birikmiş gerçek kayıt biçimi: schema 2 + ham `dart_app`.
    const legacy = {
      'kind': 'global_timer_command',
      'schema_version': 2,
      'command_id': 'command-legacy',
      'account_id': 'account-a',
      'installation_id': 'installation-1',
      'action': 'start',
      'client_occurred_at': '2026-07-26T14:51:00.000Z',
      'origin': 'dart_app',
    };
    expect(
      adapter.inspect(legacy, authenticatedAccountId: 'account-a'),
      TimerV2CommandDisposition.discard,
      reason:
          'Yoksa uygulanamayacak kayıt her senkron turunda yeniden denenir ve '
          'kuyruk sonsuza kadar büyür.',
    );
    // Yeni şema ama tanınmayan origin de aynı şekilde düşer.
    expect(
      adapter.inspect({
        ...legacy,
        'schema_version': TimerV2CommandEnvelope.schemaVersion,
      }, authenticatedAccountId: 'account-a'),
      TimerV2CommandDisposition.discard,
    );
  });
}

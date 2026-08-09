import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/updater/updater_dialog.dart';
import 'package:online_study_room/features/updater/updater_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-578 — Windows güncelleme akışının **davranış** kapısı.
///
/// WP-568 artefakt adı zincirini metin düzeyinde kilitledi; burada asıl soru
/// başka: **indirilen arşiv gerçekten doğrulanıyor mu ve kullanıcı ne
/// görüyor?** Üretilen MSIX imzasız olduğu için kullanıcıda hiç kurulmuyordu
/// (`0x800B010A`) ve uygulama bunu "Kurulum iptal edildi." diye gösteriyordu —
/// yani sessiz başarısızlık. Yeni akış ZIP indirir, SHA-256 doğrular ve
/// kullanıcıya üç adımı açıkça söyler.
///
/// Bu dosya ağ katmanını sahte bir `HttpClientAdapter` ile besler; metin
/// aramaz, gerçek durum geçişlerini sürer.
void main() {
  late Directory tempDir;
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('tr'));
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('wp578_');
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  final archive = Uint8List.fromList(List<int>.generate(2048, (i) => i % 251));
  final trueDigest = sha256.convert(archive).toString();

  UpdateInfo infoWith({String? sha256Url}) => UpdateInfo(
    versionCode: 62,
    versionName: '1.0.62',
    releaseNotes: 'not',
    downloadUrl: 'https://example.com/odak-kampi-windows-stable.zip',
    sha256Url: sha256Url,
    packageKind: UpdatePackageKind.windowsZip,
  );

  File expectedArchive() =>
      File('${tempDir.path}/odak-kampi-windows-62.zip');

  Future<void> startDownload(
    WidgetTester tester, {
    required UpdateInfo info,
    required _FakeReleaseServer server,
  }) async {
    final dio = Dio()..httpClientAdapter = server;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UpdaterDialog(
            info: info,
            dioOverride: dio,
            saveDirectoryOverride: tempDir,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 🔴 Dokunuş `runAsync` içinde: indirme zinciri gerçek dosya/ağ işine
    // dayanıyor ve fake-async saatinde ilerlemiyor. Zincir gerçek zamanda
    // başlarsa sonraki `runAsync` pencerelerinde ilerleyebiliyor.
    await tester.runAsync(() => tester.tap(find.byIcon(Icons.download)));
    await tester.pump();
  }

  /// [finder] görünene kadar gerçek zaman + kare çizimini dönüşümlü sür.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 120; i++) {
      await tester.pump();
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    await tester.pump();
  }

  testWidgets('SHA-256 tutarsa yönerge ekranı gelir, kurulum başlatılmaz', (
    tester,
  ) async {
    final server = _FakeReleaseServer(
      archive: archive,
      sha256Body: '$trueDigest  odak-kampi-windows-stable.zip',
    );
    await startDownload(
      tester,
      info: infoWith(sha256Url: 'https://example.com/a.zip.sha256'),
      server: server,
    );

    final ready = find.text(l10n.updaterIndirmeDogrulandi);
    await pumpUntil(tester, ready);

    expect(ready, findsOneWidget);
    expect(find.text(l10n.updaterWindowsAcikkenYazilamaz), findsOneWidget);
    expect(find.text(l10n.updaterWindowsAdimKapat), findsOneWidget);
    expect(find.text(l10n.updaterWindowsAdimCikar), findsOneWidget);
    expect(find.text(l10n.updaterWindowsAdimCalistir), findsOneWidget);
    expect(find.text(l10n.updaterKlasoruAc), findsOneWidget);

    final saved = expectedArchive();
    expect(saved.existsSync(), isTrue, reason: 'Arşiv diskte kalmalı.');
    expect(
      find.text(l10n.updaterIndirilenDosyaPath(saved.path)),
      findsOneWidget,
      reason: 'Kullanıcı dosyayı elle açacak; tam yolu görmeli.',
    );
    expect(
      find.text(l10n.updaterKurulumIptalEdildi),
      findsNothing,
      reason: 'Başarılı akışta kurulum/iptal metni görünmemeli.',
    );
  });

  testWidgets('SHA-256 tutmazsa dosya silinir ve kendi hatası gösterilir', (
    tester,
  ) async {
    final server = _FakeReleaseServer(
      archive: archive,
      sha256Body:
          '${'0' * 64}  odak-kampi-windows-stable.zip', // kasten yanlış
    );
    await startDownload(
      tester,
      info: infoWith(sha256Url: 'https://example.com/a.zip.sha256'),
      server: server,
    );

    final failure = find.text(l10n.updaterDosyaDogrulanamadi);
    await pumpUntil(tester, failure);

    expect(failure, findsOneWidget);
    expect(
      find.text(l10n.updaterKurulumIptalEdildi),
      findsNothing,
      reason:
          'Bozuk indirme ile kullanıcının vazgeçmesi aynı cümleye düşerse '
          'gerçek arıza görünmez olur (WP-578 sessiz başarısızlık yasağı).',
    );
    expect(
      find.text(l10n.updaterIndirmeDogrulandi),
      findsNothing,
      reason: 'Doğrulanamayan arşiv "hazır" diye sunulamaz.',
    );
    expect(
      expectedArchive().existsSync(),
      isFalse,
      reason: 'Doğrulamayı geçemeyen dosya diskte bırakılmaz.',
    );
  });

  testWidgets('sha256 asset\'i yoksa Windows kolu fail-closed durur', (
    tester,
  ) async {
    final server = _FakeReleaseServer(archive: archive, sha256Body: null);
    await startDownload(tester, info: infoWith(), server: server);

    final failure = find.text(l10n.updaterDosyaDogrulanamadi);
    await pumpUntil(tester, failure);

    expect(
      failure,
      findsOneWidget,
      reason:
          'CI her artefaktın yanında `<ad>.sha256` üretir. Yoksa doğrulama '
          'sessizce atlanamaz; doğrulanmamış arşiv kullanıcıya verilmez.',
    );
    expect(find.text(l10n.updaterIndirmeDogrulandi), findsNothing);
    expect(expectedArchive().existsSync(), isFalse);
    expect(
      server.requestedUrls.where((u) => u.endsWith('.sha256')),
      isEmpty,
      reason: 'Asset yokken boş bir sha256 isteği atılmamalı.',
    );
  });
}

/// GitHub Release'in yerine geçen küçük adaptör: arşivi ve (varsa) sha256
/// gövdesini döndürür.
class _FakeReleaseServer implements HttpClientAdapter {
  _FakeReleaseServer({required this.archive, required this.sha256Body});

  final Uint8List archive;
  final String? sha256Body;
  final List<String> requestedUrls = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requestedUrls.add(url);
    if (url.endsWith('.sha256')) {
      final body = sha256Body;
      if (body == null) return ResponseBody.fromString('missing', 404);
      return ResponseBody.fromString(
        body,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    return ResponseBody.fromBytes(
      archive,
      200,
      headers: {
        Headers.contentLengthHeader: ['${archive.length}'],
      },
    );
  }
}

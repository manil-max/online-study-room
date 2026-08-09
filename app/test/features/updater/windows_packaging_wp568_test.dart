import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-568 — Windows dağıtım hattının sözleşme kapısı.
///
/// Bu dosya tek bir soruyu koruyor: **uygulamanın aradığı paket ile CI'ın
/// ürettiği paket aynı şey mi?** Bu zincir bugüne kadar hiçbir kapıda
/// bağlanmamıştı; üç ucu (uygulama kodu, Windows iş akışı, Release iş akışı)
/// birbirinden habersiz metin olarak yaşıyordu:
///
/// - `updater_service.dart` sabit bir artefakt adı arıyor,
/// - `windows-release.yml` o adı üretiyor,
/// - `release.yml` onu GitHub Release'e ekliyor.
///
/// **WP-578 güncellemesi:** zincirin ucundaki artefakt MSIX değil **taşınabilir
/// ZIP**'tir. MSIX imzasız üretildiği için kullanıcıda hiç kurulmuyordu
/// (`0x800B010A`), bu yüzden uygulama içi güncelleme artık ZIP indiriyor. Kapı
/// aynı soruyu koruyor, yalnız doğru artefaktı gösteriyor; MSIX'in CI/Release
/// tarafındaki adı ise ikincil artefakt olarak korunmaya devam ediyor.
///
/// Aradan biri yeniden adlandırılsa hiçbir test kırmızıya düşmezdi; sonuç
/// kullanıcıda "güncelleme yok" ya da "indirdi ama kuramadı" olarak görünürdü.
/// Bu yüzden iddialar metin düzeyinde: korunması gereken şey zaten iki ayrı
/// dosyaya elle yazılmış bir dize.
void main() {
  final windowsWorkflow = _read('../.github/workflows/windows-release.yml');
  final releaseWorkflow = _read('../.github/workflows/release.yml');
  final updaterSource = _read('lib/features/updater/updater_service.dart');
  final pubspec = _read('pubspec.yaml');

  group('WP-568 artefakt adı zinciri', () {
    test('uygulamanın aradığı ZIP adları tam olarak beta + stable', () {
      final names = RegExp(r"'odak-kampi-windows-(\w+)\.zip'")
          .allMatches(updaterSource)
          .map((m) => m.group(1))
          .toSet();

      expect(
        names,
        {'beta', 'stable'},
        reason:
            'UpdaterService yalnız bu iki adı arar; CI öneki bu kümeyle aynı '
            'kanal adlarını üretmek zorunda.',
      );
    });

    test('CI öneki kanal adından türer ve msix/zip/sha256 üçlüsünü üretir', () {
      expect(
        windowsWorkflow,
        contains(r'"prefix=odak-kampi-windows-$channel"'),
        reason: 'Önek kanal adından türemezse uygulama asset\'i bulamaz.',
      );
      expect(windowsWorkflow, contains(r'Join-Path $out "$prefix.msix"'));
      expect(windowsWorkflow, contains(r'Join-Path $out "$prefix.zip"'));
      expect(
        windowsWorkflow,
        contains(r'Set-Content "$_.sha256"'),
        reason:
            'UpdaterService bütünlük dosyasını `<asset>.sha256` adıyla arar; '
            'yoksa SHA-256 doğrulaması sessizce atlanır.',
      );
    });

    test('Release iş akışı Windows artefaktlarının üçünü de ekler', () {
      for (final glob in const [
        'release-assets/windows/*.msix',
        'release-assets/windows/*.zip',
        'release-assets/windows/*.sha256',
      ]) {
        expect(
          releaseWorkflow,
          contains(glob),
          reason: 'Üretilip yayınlanmayan artefakt kullanıcı için yok demektir.',
        );
      }
    });
  });

  group('WP-568 kanal kimliği', () {
    test('stable kimliği pubspec ile aynı, beta AYRI kimlik alır', () {
      final identityName = RegExp(r'^\s*identity_name:\s*(\S+)\s*$', multiLine: true)
          .firstMatch(pubspec)
          ?.group(1);
      expect(identityName, isNotNull, reason: 'pubspec msix_config.identity_name yok.');

      expect(
        windowsWorkflow,
        contains("\$identity = '$identityName'"),
        reason:
            'Yayınlanmış stable kimliği kalıcıdır '
            '(docs/WINDOWS-RELEASE-GATE.md); iş akışı onu değiştiremez.',
      );
      expect(
        windowsWorkflow,
        contains("\$identity = '$identityName.Beta'"),
        reason:
            'Beta ile stable aynı Windows kimliğini paylaşırsa beta kurulumu '
            'stable\'ı ezer ve daha yüksek paket sürümü yüzünden kullanıcı bir '
            'daha stable\'a dönemez (Android tarafında ayrı applicationId var).',
      );
    });

    test('beta paketi Başlat menüsünde ayrı adla görünür', () {
      expect(
        windowsWorkflow,
        contains("'Odak Kampı (Beta)'"),
        reason:
            'İki paket yan yana kuruluyorsa kullanıcı hangisini açtığını '
            'görebilmeli.',
      );
    });
  });

  group('WP-568 sürüm senkronu', () {
    test('MSIX paket sürümü pubspec major.minor ile aynı seriden türer', () {
      final version =
          RegExp(r'^version:\s*(\d+)\.(\d+)\.\d+\+\d+\s*$', multiLine: true)
              .firstMatch(pubspec);
      expect(version, isNotNull, reason: 'pubspec `version:` okunamadı.');
      final series = '${version!.group(1)}.${version.group(2)}';

      // Paket sürümünün ilk iki alanı iş akışında SABİT yazılı. pubspec bir üst
      // seriye geçtiğinde (ör. 2.0.0) iş akışı eski seriyi damgalamaya devam
      // eder; Windows o zaman yükseltmeyi reddeder. Kapı bu ayrışmayı yakalar.
      expect(
        windowsWorkflow,
        contains('\$version = "$series.\$patch.\$sequence"'),
        reason: 'Beta paket sürümü pubspec serisinden ayrışmış.',
      );
      expect(
        windowsWorkflow,
        contains('\$version = "$series.\$patch.0"'),
        reason: 'Stable paket sürümü pubspec serisinden ayrışmış.',
      );
    });

    test('sürüm adı ile build numarası birbirini doğrular', () {
      expect(
        windowsWorkflow,
        contains(r'$patch * 100 + $sequence'),
        reason:
            'AGENTS.md §4.1 beta kodlaması (patch*100+sıra) CI\'da '
            'doğrulanmazsa yanlış eşleşen tag sessizce paketlenir.',
      );
      expect(windowsWorkflow, contains(r'inputs.version_name'));
      expect(windowsWorkflow, contains(r'inputs.build_number'));
    });

    test('paket sürümü komut satırından verilir, pubspec değiştirilmez', () {
      expect(
        windowsWorkflow,
        contains(r"--version '${{ steps.msix.outputs.version }}'"),
      );
      expect(
        windowsWorkflow,
        isNot(contains('Set-Content pubspec.yaml')),
        reason:
            'Paylaşılan sıcak dosyayı derleme ortasında yeniden yazmak hem '
            'sızıntı hem de idempotent koşumda yanlış kırmızı üretiyordu.',
      );
      expect(
        windowsWorkflow,
        contains(r'if ((Get-FileHash pubspec.yaml -Algorithm SHA256).Hash -ne $pubspecBefore)'),
        reason: 'Dokunmadığımızı iddia etmek yetmez; ölçülmeli.',
      );
    });
  });

  group('WP-568 paket doğrulama ve imza', () {
    test('üretilen paket kendi manifestinden doğrulanır', () {
      expect(
        windowsWorkflow,
        contains("GetEntry('AppxManifest.xml')"),
        reason:
            'Sessizce yok sayılan bir msix bayrağı yanlış kimlikli paket '
            'üretir; kimliği paketin kendisinden okumak tek kanıttır.',
      );
      expect(windowsWorkflow, contains(r'$packageIdentity.Name -ne'));
      expect(windowsWorkflow, contains(r'$packageIdentity.Version -ne'));
    });

    test('stable kanalda test sertifikası fail-closed', () {
      expect(
        windowsWorkflow,
        contains("'CN=Msix Testing, O=Msix Testing Corporation, S=Some-State, C=US'"),
        reason:
            'Sertifika verilmediğinde msix paketi pub.dev\'deki herkese açık '
            'test sertifikasını kullanır; böyle imzalanan MSIX kullanıcıda '
            'kurulmaz (0x800B010A).',
      );
      expect(
        windowsWorkflow,
        contains('vars.WINDOWS_ALLOW_TEST_SIGNING'),
        reason:
            'docs/WINDOWS-RELEASE-GATE.md "stable imzasız dağıtım stable '
            'sayılmaz" diyor; kuralın çağıranı bu kapıdır. Muafiyet ancak '
            'açık bir repo değişkeniyle verilir.',
      );
      expect(
        windowsWorkflow,
        contains('signing = @{ publisher ='),
        reason:
            'İmza gerçeği platform manifestine yazılmazsa yayın sonrası '
            'hangi paketin güvenilir imzalandığı hatırlamaya kalır.',
      );
    });
  });

  group('WP-578 taşınabilir ZIP birincil yol', () {
    test('uygulama artık hiçbir MSIX asset adı aramaz', () {
      expect(
        updaterSource,
        isNot(contains('.msix')),
        reason:
            'İmzasız MSIX kullanıcıda 0x800B010A ile REDDEDİLİYOR. Uygulama '
            'onu indirirse kullanıcı ~40 MB iner ve kurulum hiç başlamaz; '
            'WP-578 kararı bu yüzden ZIP-öncelikli.',
      );
    });

    test('paket türü enum\'u ZIP kolunu taşır, MSIX kolunu değil', () {
      expect(updaterSource, contains('enum UpdatePackageKind { apk, windowsZip }'));
      expect(
        updaterSource,
        isNot(contains('UpdatePackageKind.msix')),
        reason: 'MSIX koluna geri dönülürse kurulamayan paket yeniden akar.',
      );
    });

    test('ZIP artefaktının yanında SHA-256 dosyası üretilir', () {
      expect(
        windowsWorkflow,
        contains(r'@($msixOut, $zipOut)'),
        reason:
            'Bütünlük dosyası döngüsünden ZIP çıkarılırsa uygulama '
            '`<ad>.zip.sha256` bulamaz; WP-578 Windows kolunda doğrulama '
            'atlanamaz (fail-closed), yani güncelleme tamamen durur.',
      );
    });

    test('Release iş akışı ZIP ve sha256 asset\'lerini yayınlar', () {
      expect(releaseWorkflow, contains('release-assets/windows/*.zip'));
      expect(releaseWorkflow, contains('release-assets/windows/*.sha256'));
    });
  });

  group('WP-568 paketleme', () {
    test('taşınabilir ZIP kendi kurulumunun kopyasını taşımaz', () {
      expect(
        windowsWorkflow,
        contains(r"$_.Extension -ne '.msix'"),
        reason:
            'msix:create paketi Release klasörünün içine yazar; klasör olduğu '
            'gibi sıkıştırılırsa ZIP MSIX\'i de içerir (gereksiz ~2x indirme).',
      );
    });

    test('boş artefakt yüklemesi hata sayılır', () {
      expect(windowsWorkflow, contains('if-no-files-found: error'));
    });
  });
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      'Sözleşme dosyası bulunamadı: $path '
      '(çalışma dizini: ${Directory.current.path})',
    );
  }
  return file.readAsStringSync();
}

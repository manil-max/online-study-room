import 'dart:io';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/distribution_channel.dart';

/// WP-614 — masaüstü sürüm hattının **ölçen** kapıları.
///
/// Denetim (`docs/denetim/DENETIM-masaustu-surum.md`) dört bulgu çıkardı; bu
/// dosya üçünün sözleşmesini tutuyor. Ortak hastalık tek cümleyle: *kapı
/// vardı, ölçtüğü şey yoktu.*
///
/// 1. **Store paketi mağaza dışı güncelleyiciyi AÇIK taşıyordu.** İş akışı her
///    koşumda `DISTRIBUTION_CHANNEL='windows'` yazıyordu; `--store` yalnız
///    paketlemeyi değiştiriyordu. Aşağıdaki ilk grup, iş akışına yazılmış
///    kanal dizelerini **kodun kendi çözümleyicisinden geçirir** — yani iddia
///    metin eşleşmesi değil, davranış: mağaza dalının dizesi sideload'u
///    kapatan bir kanala çözülmek zorunda.
/// 2. **Yayınlanan ZIP hiçbir kapıda çalıştırılmıyordu.**
///    `scripts/windows_fast_smoke.ps1` repoda duruyor ama hiçbir iş akışından
///    ve `test_all.py`'den çağrılmıyordu.
/// 3. **Kapsam kapısı kendi kendini iyileştiriyordu** (baseline yoksa yazıp
///    geçiyordu) ve masaüstü/updater ağaçları kritik yol listesinde yoktu.
///
/// Ayrıca Windows entegrasyon kapısının sessiz mobil geri düşüşü de burada
/// korunuyor: o düşüş geri gelirse kapı yine hiçbir şey ölçmez.
void main() {
  final workflow = _read('../.github/workflows/windows-release.yml');
  final ci = _read('../.github/workflows/ci.yml');
  final testAll = _read('../scripts/test_all.py');
  final coverageAudit = _read('../scripts/coverage_audit.py');
  final integrationTest = _read('integration_test/v8_critical_flows_test.dart');

  /// İş akışına yazılmış `DISTRIBUTION_CHANNEL` atamaları (yazıldıkları sırada).
  List<String> channelAssignments() => RegExp(
    r"DISTRIBUTION_CHANNEL\s*=\s*'([^']+)'",
  ).allMatches(workflow).map((match) => match.group(1)!).toList();

  /// ZIP smoke adımının gövdesi (açıklama yorumları değil, KOŞAN kısım).
  String smokeStep() => _section(
    workflow,
    '- name: Yayınlanan ZIP gerçekten açılıyor mu',
    '- name: Store derlemesi',
  );

  /// İş akışındaki dizeyi **kodun** çözümleyicisinden geçir.
  DistributionChannel resolveAsBuildWould(String define) =>
      DistributionConfig.resolve(
        distributionDefine: define,
        legacyChannel: 'stable',
        flutterAppFlavor: null,
        isWeb: false,
        platform: TargetPlatform.windows,
      );

  group('WP-614/1 — Store paketi mağaza kanalıdır', () {
    test('iş akışı tam iki kanal yazar: sideload ve mağaza', () {
      expect(
        channelAssignments(),
        hasLength(2),
        reason:
            'Beklenen iki atama: sideload/ZIP derlemesi ve mağaza derlemesi. '
            'Sayı değiştiyse hattın kanal kararı yeniden yazılmış demektir; '
            'bu dosyadaki iddialar da gözden geçirilmeli.',
      );
    });

    test('sideload/ZIP derlemesinde updater AÇIK kalır', () {
      // ZIP kullanıcısı güncellemeyi başka yerden alamaz; mağaza düzeltmesi
      // yaparken bu kolu kapatmak sessiz bir gerileme olurdu.
      final channel = resolveAsBuildWould(channelAssignments().first);
      expect(
        DistributionConfig.allowsSideloadUpdatesFor(channel),
        isTrue,
        reason:
            'Taşınabilir ZIP `$channel` kanalıyla çıkıyor ve güncelleme '
            'kontrolü kapalı; GitHub\'dan indiren kullanıcı bir daha sürüm '
            'yükseltemez.',
      );
    });

    test('🔴 mağaza derlemesinde sideload updater KAPALI', () {
      // Kapının çekirdeği. Dize `'windows'`e döndürülürse (eski hâl) bu iddia
      // kırmızıya düşer — çünkü karar metinden değil çözümleyiciden geliyor.
      final define = channelAssignments().last;
      final channel = resolveAsBuildWould(define);
      expect(
        DistributionConfig.allowsSideloadUpdatesFor(channel),
        isFalse,
        reason:
            'Mağaza derlemesi `$define` yazıyor, bu da `$channel` kanalına '
            'çözülüyor ve mağaza dışı güncelleyici AÇIK. Microsoft Store\'dan '
            'kuran kullanıcı "yeni sürüm var, ZIP indir" diyaloğu görür: '
            'mağaza kuralına aykırı ve paketi kuramaz.',
      );
    });

    test('mağaza derlemesi Store moduna KOŞULLU ayrı bir derlemedir', () {
      expect(
        workflow,
        contains("if: steps.msix.outputs.store_mode == 'true'"),
        reason: 'Mağaza derlemesi koşulsuz koşarsa her sürüm iki kez derlenir.',
      );
      final builds = RegExp(
        r'flutter build windows --release[^\n]*',
      ).allMatches(workflow).length;
      expect(
        builds,
        2,
        reason:
            'Mağaza ve sideload paketleri AYRI derlemelerdir; '
            '`DISTRIBUTION_CHANNEL` derleme zamanında gömülür, tek derlemeden '
            'iki politika çıkmaz.',
      );
      final storeStep = workflow.substring(
        workflow.indexOf("if: steps.msix.outputs.store_mode == 'true'"),
      );
      expect(
        storeStep.substring(0, storeStep.indexOf('- name: MSIX üret')),
        contains('microsoftStore'),
        reason: 'Store derleme adımı mağaza kanalını hiç yazmıyor.',
      );
    });

    test('kimlik/Store adımı env.json manifestinden ÖNCE gelir', () {
      // Sıra sözleşmedir: Store modu env.json yazılmadan önce bilinmezse
      // mağaza kanalı define edilemez.
      expect(
        workflow.indexOf('id: msix'),
        lessThan(workflow.indexOf('- name: Kanal/backend manifestini üret')),
        reason:
            'Store kararı env.json\'dan sonra alınırsa mağaza paketi yine '
            'sideload kanalıyla derlenir — WP-614 öncesi durum.',
      );
    });

    test('derleme öncesi kanal kapısı iki derlemede de koşar', () {
      final guards = RegExp(
        r'distribution_define_wp614_test\.dart',
      ).allMatches(workflow).length;
      expect(
        guards,
        2,
        reason:
            'Kanal kapısı hem sideload hem mağaza derlemesinden önce '
            'koşmalı; biri atlanırsa o paket ölçülmeden çıkar.',
      );
      expect(workflow, contains('ENFORCE_CURRENT_BUILD_MANIFEST=true'));
    });
  });

  group('WP-614/4 — yayınlanan ZIP en az bir kez çalıştırılır', () {
    test('iş akışı ZIP\'i açıp içinden çıkan EXE\'yi smoke\'a verir', () {
      // 🔴 İddia ADIM GÖVDESİNDE ölçülür, dosyanın tamamında değil. İlk
      // yazımda `workflow` üzerinde aranıyordu ve SABOTAJLA ÖLÇÜLDÜ: çağrıyı
      // silip yerine yorum bırakınca test YİNE GEÇTİ, çünkü aynı yol adı
      // açıklama satırlarında da geçiyor. Kapı tam da kovaladığı hatanın
      // kurbanı olacaktı.
      final step = smokeStep();
      expect(
        step,
        contains(r'& ../scripts/windows_fast_smoke.ps1'),
        reason:
            'Gerçek smoke betiği adım gövdesinden çağrılmıyor: kullanıcıya '
            'giden arşiv bir kez bile açılmadan yayınlanıyor.',
      );
      expect(
        step,
        contains('Expand-Archive'),
        reason:
            'Smoke, derleme klasörünü değil YAYINLANACAK arşivi ölçmeli; '
            'aksi hâlde bozuk paketleme kapıdan görünmez.',
      );
      expect(
        step,
        contains(r'online_study_room.exe'),
        reason: 'ZIP içinden uygulamanın çıktığı doğrulanmıyor.',
      );
    });

    test('smoke başarısızsa iş KIRMIZI düşer (uyarıyla geçilmez)', () {
      final step = smokeStep();
      expect(
        step,
        contains('throw'),
        reason:
            'Smoke yalnız uyarı üretiyorsa kapı değildir; açılmayan paket '
            'yine yayınlanır.',
      );
      expect(
        step,
        isNot(contains('continue-on-error')),
        reason: 'Kapı gevşetilmiş.',
      );
    });

    test('yerel koşucu da aynı betiği bir kapı olarak taşır', () {
      // Yol adı yorumlarda da geçiyor; ölçüm kapının ARGÜMAN listesinde.
      expect(
        testAll,
        contains('"scripts/windows_fast_smoke.ps1"'),
        reason:
            '`test_all.py` bu betiği hiç çağırmıyordu; yerelde Windows '
            'paketinin açıldığını ölçen tek komut yoktu.',
      );
      expect(
        testAll,
        contains('"windows-smoke"'),
        reason: 'Kapı anahtarı yok; `--only windows-smoke` ile koşulamaz.',
      );
    });

    test('platform manifesti smoke sonucunu kaydeder', () {
      expect(
        workflow,
        contains('zipSmokePassed'),
        reason:
            'Manifest "bu ZIP bir kez açıldı" bilgisini taşımazsa, yayın '
            'sonrası ölçülüp ölçülmediği hatırlamaya kalır.',
      );
    });
  });

  group('WP-614/3 — kapsam kapısı kendini savunur', () {
    test('baseline yoksa kapı artık kendi eşiğini yazıp geçmez', () {
      final evaluate = _section(
        coverageAudit,
        'def evaluate(',
        'def self_test(',
      );
      expect(
        evaluate,
        contains('if baseline is None'),
        reason: 'Eksik baseline hâli hiç ele alınmıyor.',
      );
      expect(
        evaluate,
        isNot(contains('write_baseline')),
        reason:
            'Kapı eksik eşiği kendi ölçümüyle dolduruyorsa, eşiği silmek '
            'kapıyı geçmenin yoludur.',
      );
    });

    test('masaüstü ve updater ağaçları kritik yolda', () {
      // Ölçüm listenin KENDİSİNDE: dosyanın herhangi bir yerinde geçen yol adı
      // (sözleşme kopyası, yorum) kapıyı yanlışlıkla yeşil tutardı.
      final criticalPaths =
          _section(coverageAudit, 'CRITICAL_PATHS = (', '\n)');
      for (final path in const [
        'lib/core/desktop/',
        'lib/features/desktop/',
        'lib/features/updater/',
      ]) {
        expect(
          criticalPaths,
          contains('"$path"'),
          reason:
              'Windows dağıtımının tamamı bu ağaçlardan geçiyor; kritik yol '
              'listesinde olmayan kod "genel ortalama iyi" diye testsiz kalır.',
        );
      }
    });

    test('kendi kendini sınayan kapı hem CI\'da hem yerel koşucuda bağlı', () {
      expect(
        ci,
        contains('run: python scripts/coverage_audit.py --self-test'),
        reason: 'Kapının kapı olduğu CI\'da hiç ölçülmüyor.',
      );
      expect(
        testAll,
        contains('"coverage-self"'),
        reason: 'Yerel tam turda kapsam kapısı sınanmıyor.',
      );
    });
  });

  group('WP-614/2 — Windows entegrasyon kapısı sessizce mobile düşemez', () {
    test('masaüstü paneli zorunlu; mobil geri düşüş yok', () {
      expect(
        integrationTest,
        isNot(contains('find.byType(NavigationBar)')),
        reason:
            'Test masaüstü panelini bulamayınca mobil `NavigationBar`\'a '
            'düşüp YEŞİL dönüyordu: `home_shell.dart` masaüstü dalı silinse '
            'bile "Windows integration (critical flows)" işi geçerdi.',
      );
      expect(
        integrationTest,
        contains('find.byType(DesktopNavigationPane),\n      findsOneWidget'),
        reason: 'Masaüstü panelinin varlığı zorunlu tutulmuyor.',
      );
    });

    test('geçişler gerçekten tıklanır (callback doğrudan çağrılmaz)', () {
      expect(
        integrationTest,
        contains('await tester.tap('),
        reason:
            'Geçiş `onSelected` geri çağrısıyla yapılırsa ölçülen tek şey '
            '"verdiğim sayıyı geri aldım mı" olur; panelin çizildiği, öğenin '
            'tıklanabildiği hiç ölçülmez.',
      );
      expect(
        integrationTest,
        isNot(contains('.onSelected(')),
        reason: 'Doğrudan geri çağrı yolu geri gelmiş.',
      );
    });
  });
}

/// [start] ile [end] arasındaki gövde. Bölge dışına bakan iddia, kapıyı değil
/// dosyanın rastgele bir yerindeki metni ölçer.
String _section(String source, String start, String end) {
  final from = source.indexOf(start);
  expect(from, isNonNegative, reason: 'Bölge başlangıcı bulunamadı: $start');
  final to = source.indexOf(end, from + start.length);
  expect(to, greaterThan(from), reason: 'Bölge sonu bulunamadı: $end');
  return source.substring(from, to);
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail(
      'Sözleşme dosyası bulunamadı: $path '
      '(çalışma dizini: ${Directory.current.path})',
    );
  }
  // 🔴 SATIR SONU NORMALLESTIRILIR. Bu dosyadaki iddialarin cogu metin
  // icinde \n tasiyor. Windows kosucusunda git `core.autocrlf` ile depoyu
  // **CRLF** olarak cikariyor; Linux ta LF kaliyor. Sonuc: ayni kapi Android
  // isinde YESIL, Windows isinde KIRMIZI dustu (v63 yayin turu, run
  // 31330594205 -- 2424 test gecti, 1 dustu) ve kirilan sey uygulama degil
  // KAPININ KENDISIYDI.
  //
  // Duzeltme tek tek iddialara degil BURAYA yaziliyor: yeni bir iddia
  // eklerken kimse bu tuzagi yeniden kesfetmek zorunda kalmasin.
  return file.readAsStringSync().replaceAll('\r\n', '\n');
}

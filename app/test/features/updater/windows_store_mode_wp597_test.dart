import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// WP-597 — Microsoft Store yolunun sözleşme kapısı.
///
/// **Neden var:** Windows dağıtımı bugüne kadar tek bir varsayımla tıkalıydı —
/// "kurulabilir bir MSIX için kod imzalama sertifikası satın almak gerekir"
/// (yıllık birkaç yüz dolar). Bu varsayım Store DIŞI dağıtım için doğru, Store
/// için YANLIŞ: Store'a yüklenen paketi Microsoft sertifikasyondan sonra kendi
/// sertifikasıyla yeniden imzalar ve geliştirici kaydı da ücretsizdir. Yani
/// para ödemeden kurulabilir bir Windows paketi çıkarmanın bir yolu vardı ve
/// hat bunu hiç desteklemiyordu.
///
/// 🔴 **Bu kapının koruduğu asıl tehlike bir GERİLEME:** Store paketi
/// **imzasızdır** ve bu kasıtlıdır. `msix:create --store` imzalamaz. Ama
/// hattaki imza kapısı yalnız "pub.dev test sertifikası mı?" diye bakıyordu;
/// Store paketinin yayıncısı test sertifikası olmadığı için kapı onu
/// "güvenilir" sayıp GitHub Release'e koyardı. Sonuç WP-590'ın düzelttiği
/// hatanın aynısı olurdu: kullanıcı indirir, `0x800B010A` ile KURAMAZ.
/// Bu yüzden Store modunda paket yayından zorla alıkonur ve ayrı bir
/// artefakta gider.
///
/// İddialar metin düzeyinde, çünkü korunan şey bir iş akışı dosyasına elle
/// yazılmış dallanma. Store hesabı olmadan bu dal CI'da hiç koşamaz — o yüzden
/// tek koruma bu sözleşmedir. Ölçmediğimiz şey: paketin Partner Center
/// sertifikasyonundan gerçekten geçtiği. Bu ancak gerçek gönderimde görülür.
void main() {
  final workflow = File(
    '../.github/workflows/windows-release.yml',
  ).readAsStringSync();

  /// İmza kapısının karar gövdesi. Bölge dışına bakan iddia, kapıyı değil
  /// dosyanın rastgele bir yerindeki metni ölçer.
  String signingGate() {
    const start = r'$testPublisher =';
    const end = r'"withheld_reason=$withheldReason" >> $env:GITHUB_OUTPUT';
    final from = workflow.indexOf(start);
    final to = workflow.indexOf(end);
    expect(from, isNonNegative, reason: 'İmza kapısı bulunamadı.');
    expect(to, greaterThan(from), reason: 'İmza kapısının sonu bulunamadı.');
    return workflow.substring(from, to);
  }

  group('WP-597 — Store modu yapılandırması', () {
    test('dört Partner Center değeri de okunuyor', () {
      // 🔴 WP-664: dördüncüsü REZERVE EDİLMİŞ UYGULAMA ADI. Diğer üçü doğruyken
      // bile paketin içindeki ad rezerve adla birebir eşleşmezse Partner Center
      // gönderimi reddeder.
      for (final name in const [
        'MSIX_STORE_IDENTITY_NAME',
        'MSIX_STORE_PUBLISHER',
        'MSIX_STORE_PUBLISHER_DISPLAY_NAME',
        'MSIX_STORE_DISPLAY_NAME',
      ]) {
        expect(
          workflow,
          contains('vars.$name'),
          reason: '$name iş akışında hiç okunmuyor.',
        );
      }
    });

    test('yarım yapılandırma FAIL-CLOSED: iş durur', () {
      // Üçünden yalnız ikisi doluyken sessizce devam etmek, Partner Center'ın
      // reddedeceği bir paketi tüm sürüm koşumu bittikten SONRA fark ettirirdi.
      expect(
        workflow,
        contains(r'$storeSet -gt 0 -and $storeSet -lt 4'),
        reason: 'Yarım Store yapılandırması sessizce geçiyor.',
      );
      expect(
        workflow.contains(r'throw "Store yapılandırması YARIM'),
        isTrue,
        reason: 'Yarım yapılandırma `throw` etmiyor.',
      );
    });

    test('Store modu yalnız stable kanalda açılır', () {
      // Sahip kararı: beta kanalı atlanıyor, Store'a gönderilmiyor.
      expect(
        workflow,
        contains(r"($storeSet -eq 4) -and ($channel -eq 'stable')"),
        reason: 'Store modu kanaldan bağımsız açılıyor.',
      );
    });
  });

  group('WP-597 — paketleme', () {
    test('`--store` YALNIZ Store dalında geçilir', () {
      final storeCalls = RegExp(
        r'dart run msix:create[^\n]*',
      ).allMatches(workflow).map((m) => m.group(0)!).toList();

      expect(
        storeCalls.length,
        2,
        reason:
            'İki dal beklenir (Store / Store dışı); bulunan: '
            '${storeCalls.length}.',
      );
      expect(
        storeCalls.where((c) => c.contains(' --store ')).length,
        1,
        reason: '`--store` ya hiç geçmiyor ya da her iki dalda da geçiyor.',
      );
      final store = storeCalls.firstWhere((c) => c.contains(' --store '));
      expect(
        store,
        contains('--publisher '),
        reason: 'Store paketine Partner Center Publisher ID verilmiyor.',
      );
      expect(
        store,
        contains('--publisher-display-name '),
        reason: 'Store paketine yayıncı görünen adı verilmiyor.',
      );
    });

    test('paket kimliği Store modunda Partner Center kimliğiyle doğrulanır', () {
      // Bayrak sessizce yok sayılırsa yanlış kimlikli paket üretilir; bu
      // ancak paketin KENDİSİ okunarak yakalanır.
      expect(
        workflow,
        contains(r'if ($packageIdentity.Name -ne $expectedIdentity)'),
        reason: 'Kimlik doğrulaması Store kimliğini hesaba katmıyor.',
      );
      expect(
        workflow,
        contains(r'$storeMode -and $packageIdentity.Publisher -ne'),
        reason: 'Store paketinin yayıncısı manifestten doğrulanmıyor.',
      );
    });
  });

  group('WP-665 — mağaza paketi sürüm KESMEDEN üretilebilir', () {
    /// Tetikleyici bölgesi. Bölge dışına bakan iddia, `on:` bloğunu değil
    /// dosyanın rastgele bir yerindeki metni ölçerdi.
    String triggers() {
      final from = workflow.indexOf('\non:\n');
      final to = workflow.indexOf('\npermissions:');
      expect(from, isNonNegative, reason: '`on:` bloğu bulunamadı.');
      expect(to, greaterThan(from), reason: '`permissions:` bulunamadı.');
      return workflow.substring(from, to);
    }

    /// Bir tetikleyicinin ilan ettiği girdi ADLARI.
    Set<String> inputsOf(String trigger) {
      final block = triggers();
      final start = block.indexOf(trigger);
      expect(start, isNonNegative, reason: '$trigger yok.');
      final rest = block.substring(start + trigger.length);
      final next = RegExp(r'\n  \w').firstMatch(rest);
      final scope = next == null ? rest : rest.substring(0, next.start);
      return RegExp(r'^      (\w+): \{', multiLine: true)
          .allMatches(scope)
          .map((m) => m.group(1)!)
          .toSet();
    }

    test('iş akışı elle de tetiklenebilir', () {
      // 🔴 Ölçülen sonuç: WP-664 uygulamanın koduna hiç dokunmadı, ama mağaza
      // paketi v65 etiketinden alınamıyordu — çünkü paketi üretmenin tek yolu
      // sürüm hattıydı ve etiket düzeltmeyi taşımıyordu. Paketleme hatası her
      // seferinde bir sürüm numarası yakıyordu.
      expect(
        triggers(),
        contains('workflow_dispatch:'),
        reason:
            'Windows paketi yalnız sürüm koşumundan üretilebiliyor; paketleme '
            'düzeltmesi için sürüm kesmek gerekiyor.',
      );
      expect(
        triggers(),
        contains('workflow_call:'),
        reason: 'Sürüm hattı bu işi çağıramaz hâle geldi.',
      );
    });

    test('iki tetikleyici AYNI girdileri ister', () {
      // Girdiler ayrışırsa elle koşum sürüm hattından FARKLI bir paket üretir
      // ve fark ancak Partner Center reddedince görülür.
      final call = inputsOf('workflow_call:');
      expect(call, isNotEmpty, reason: 'workflow_call girdileri okunamadı.');
      expect(
        inputsOf('workflow_dispatch:'),
        call,
        reason: 'Elle koşum sürüm hattından farklı girdi kümesi kullanıyor.',
      );
    });

    test('elle koşum GitHub Release YAYINLAYAMAZ', () {
      // Tetikleyiciyi eklemek güvenli, çünkü bu dosyada yayın adımı yok:
      // üretilen her şey artefakt olarak kalır. Bu iddia düşerse tetikleyici
      // sürüm kapılarını atlatan bir yola dönüşmüş demektir.
      expect(
        workflow.contains('action-gh-release'),
        isFalse,
        reason:
            'Windows iş akışı kendi başına GitHub Release yayınlıyor; elle '
            'tetiklenebilir olması artık sürüm kapılarını atlatır.',
      );
    });
  });

  group('WP-664 — Store paketi REZERVE EDİLMİŞ adla üretilir', () {
    /// Paketleme adımının, ada karar veren ve adı doğrulayan bölgesi.
    String packageStep() {
      const start = r'$display = if ($storeMode)';
      const end = r'"withheld_reason=$withheldReason" >> $env:GITHUB_OUTPUT';
      final from = workflow.indexOf(start);
      final to = workflow.indexOf(end);
      expect(
        from,
        isNonNegative,
        reason:
            'Store modunda paket adını seçen dal yok. Ad koşulsuz yazılıyorsa '
            'rezerve adla eşleşmesi tesadüfe kalır.',
      );
      expect(to, greaterThan(from), reason: 'Paketleme adımının sonu yok.');
      return workflow.substring(from, to);
    }

    test('paket adı Store modunda değişkenden gelir, koda gömülü DEĞİL', () {
      final step = packageStep();
      final storeBranch = step.substring(0, step.indexOf('elseif'));
      expect(
        storeBranch,
        contains('steps.msix.outputs.store_app_name'),
        reason: 'Store dalı paket adını Partner Center değerinden almıyor.',
      );
      expect(
        storeBranch.contains('Odak Kampı'),
        isFalse,
        reason:
            'Store paketi hâlâ koda gömülü adla üretiliyor. Rezerve ad bugün '
            'buna eşit olsa bile bu tesadüftür ve mağaza tarafı değişince '
            'sessizce ayrışır.',
      );
    });

    test('adın pakete GERÇEKTEN girdiği manifestten okunur', () {
      // Bayrağı komut satırına yazmak, adın pakete işlendiği anlamına gelmez;
      // Partner Center'ın reddettiği şey manifestteki addır. Bu iddia olmadan
      // yanlış ad ancak gönderimde, tüm koşum bittikten sonra görülürdü.
      final step = packageStep();
      expect(
        step,
        contains(r'$appxManifest.Package.Properties.DisplayName'),
        reason: 'Paket adı manifestten hiç okunmuyor.',
      );
      expect(
        step,
        contains(r'$storeMode -and $packageDisplayName -ne'),
        reason: 'Manifestteki ad rezerve adla karşılaştırılmıyor.',
      );
    });
  });

  group('WP-597 — imzasız Store paketi kullanıcıya SUNULMAZ', () {
    test('imza kapısı Store modunda yayını zorla keser', () {
      final gate = signingGate();
      expect(
        gate,
        contains(r'if ($storeMode)'),
        reason:
            'İmza kapısı Store modunu hiç tanımıyor: imzasız paketi '
            '"güvenilir" sayıp yayınlar.',
      );
      // Kararın yönü de ölçülür: "tanıyor ama yine de yayınlıyor" hâli
      // yalnızca `$storeMode` geçtiğini görmekle yakalanamazdı.
      final storeBranch = gate.substring(gate.indexOf(r'if ($storeMode)'));
      expect(
        storeBranch.substring(0, storeBranch.indexOf('elseif')),
        contains(r'$publishMsix = $false'),
        reason:
            'Store modunda paket yayından ALIKONMUYOR — WP-590 hatasının '
            'aynısı: kullanıcı indirir, kuramaz.',
      );
    });

    test('Store paketi Release klasörüne DEĞİL ayrı klasöre kopyalanır', () {
      // `windows-dist` klasörünün tamamı GitHub Release'e gidiyor.
      expect(
        workflow,
        contains("\$storeOut = 'build/windows-store'"),
        reason: 'Store paketi için ayrı klasör yok.',
      );
      expect(
        workflow,
        contains('app/build/windows-store/*'),
        reason: 'Store paketi ayrı artefakt olarak yüklenmiyor.',
      );
      expect(
        workflow,
        contains('name: windows-store-package'),
        reason: 'Store artefaktının adı sözleşmede yok.',
      );
    });

    test('Store artefaktı Store modu kapalıyken hiç yüklenmez', () {
      // Koşulsuz bırakılırsa Store'suz her koşum `if-no-files-found: error`
      // yüzünden kırmızıya düşerdi.
      expect(
        workflow,
        contains("if: steps.msix.outputs.store_mode == 'true'"),
        reason: 'Store artefakt adımı koşulsuz koşuyor.',
      );
    });

    test('taşınabilir ZIP hâlâ KOŞULSUZ yayınlanır (WP-590 korunuyor)', () {
      // Store modu eklenirken ZIP'in koşula bağlanması, kullanıcıda gerçekten
      // çalışan tek artefaktı kaybettirirdi.
      expect(
        workflow,
        contains(r'$published = @($zipOut)'),
        reason: 'ZIP artık koşulsuz yayınlanmıyor.',
      );
    });
  });

  test('paket, uygulamanın DESTEKLEDİĞİ her dili ilan eder', () {
    // 🔴 WP-606: `msix_config.languages` yalnız `tr-tr` idi, oysa uygulama
    // TR + EN destekliyor. Microsoft Store bu alanı dil listesi olarak
    // kullanır; İngilizce kullanıcı uygulamayı "yalnız Türkçe" görürdü.
    //
    // İddia iki ucu BAĞLAR: dil listesi `AppLocalizations.supportedLocales`
    // ile karşılaştırılır. İleride üçüncü bir dil açılırsa (l10n_dormant
    // altında hazır katalog var) paket sessizce geride kalamaz.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(r'^  languages: (.+)$', multiLine: true)
        .firstMatch(pubspec)
        ?.group(1);
    expect(declared, isNotNull, reason: 'msix_config.languages satırı yok.');

    final packageLanguages = declared!
        .split(',')
        .map((value) => value.trim().split('-').first.toLowerCase())
        .toSet();

    final supported = RegExp(r"Locale\('(\w+)'\)")
        .allMatches(
          File('lib/l10n/app_localizations.dart')
              .readAsStringSync()
              .split('supportedLocales')
              .last
              .split(']')
              .first,
        )
        .map((match) => match.group(1)!)
        .toSet();

    expect(supported, isNotEmpty, reason: 'supportedLocales okunamadı.');
    expect(
      packageLanguages,
      containsAll(supported),
      reason:
          'Paket, uygulamanın desteklediği bir dili ilan etmiyor: Store o dili '
          'konuşan kullanıcıya uygulamayı eksik gösterir.',
    );
  });

  test('sahibe ne yapacağını anlatan belge var ve iş akışı ona işaret eder', () {
    expect(
      File('../docs/WINDOWS-STORE-YOLU.md').existsSync(),
      isTrue,
      reason:
          'Store yolu yalnız sahip bir hesap açtığında işler; talimat yoksa '
          'bu dal ölü kod olarak kalır.',
    );
    expect(
      workflow,
      contains('docs/WINDOWS-STORE-YOLU.md'),
      reason: 'İş akışı belgeye işaret etmiyor.',
    );
  });
}

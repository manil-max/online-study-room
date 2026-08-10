// WP-658 — çevrimdışı SSS yedeği İKİNCİ bir gerçek kaynaktır; eskiyebilecek
// iddia taşımamalıdır.
//
// 🔴 Nasıl ortaya çıktı. `0130` (WP-656) SSS'te **dokuz** cümleyi ürünle
// çeliştiği için düzeltti — en ağırı "hesabını silmeyi istedikten sonra tekrar
// giriş yaparsan istek iptal olur" idi. O cümle yanlış: iptalin tek yolu
// kullanıcının Hesap Ayarları'ndaki "iptal et" satırına dokunmasıdır
// (`account_settings_screen.dart:443,596`; giriş akışında sıfır çağrı yeri).
// Cümleye güvenen kullanıcı hesabını KAYBEDER.
//
// Veritabanı düzeldi. Ama `kFallbackFaq` (sunucuya ulaşılamayınca gösterilen
// yedek, `faq_screen.dart` → `in_memory_support_repository.dart`) ayrı bir
// kopyadır ve **kendiliğinden güncellenmez**. Yani aynı yanlış, çevrimdışı
// kullanıcıda yaşamaya devam edebilirdi.
//
// ⚠️ Bu kapı "yedek ile veritabanı birebir aynı olsun" DEMİYOR — onu ölçmek
// SQL metnini ayrıştırmayı gerektirir ve her düzeltmede kırılırdı. Ölçtüğü şey
// daha dayanıklı bir kural: **yedek, eskiyebilecek türden iddia taşımaz.**
// Sayı vermek, eşik saymak ve akış anlatmak yasak; yapısal cümleler serbest.
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_support_repository.dart';

void main() {
  test('kapi bos olcum yapmiyor: yedek gercekten dolu ve iki dilli', () {
    expect(kFallbackFaq, isNotEmpty);
    for (final locale in const ['tr', 'en']) {
      expect(
        kFallbackFaq.where((e) => e.locale == locale),
        isNotEmpty,
        reason: '$locale yedegi bos; kapi bu dilde hicbir sey olcmez.',
      );
    }
  });

  test('yedek KUCUK kalir (surunun tamami buraya kopyalanmaz)', () {
    // Yedek buyudukce eskime yuzeyi buyur. SSS'in tamami veritabanindadir;
    // burasi yalniz "internet yokken bile isine yarar" birkac madde icindir.
    for (final locale in const ['tr', 'en']) {
      expect(
        kFallbackFaq.where((e) => e.locale == locale).length,
        lessThanOrEqualTo(5),
        reason:
            'Yedek surumun SSS korpusunu kopyalamaya baslamis. Her kopyalanan '
            'madde, veritabani duzeltildiginde sessizce yalan soyleyecek '
            'ikinci bir kaynak demektir (WP-656\'da dokuz kez oldu).',
      );
    }
  });

  test('🔴 yedek, 0130 ile YALANLANMIS iddialari tekrar etmez', () {
    // Her desen `0130`'un duzelttigi somut bir yanlisin izidir.
    const yasak = <String, String>{
      'iptal olur':
          'Hesap silme istegi girisle iptal OLMAZ; tek yol kullanicinin '
          'Hesap Ayarlari\'ndaki dokunusudur.',
      'bronz': 'Tac kademeleri basarim SAYISINA gore degildir, toplam XP\'ye gore.',
      'gümüş': 'Tac kademeleri basarim SAYISINA gore degildir, toplam XP\'ye gore.',
      'grubunun zaman dilimi':
          'Urunun tek takvim siniri Europe/Istanbul; grup/hesap bazli saat '
          'dilimi YOK.',
      'zaman diliminde':
          'Urunun tek takvim siniri Europe/Istanbul; "etkin zaman dilimi" '
          'diye bir kavram yok.',
    };

    final ihlaller = <String>[];
    for (final entry in kFallbackFaq) {
      final metin = '${entry.question} ${entry.answer}'.toLowerCase();
      for (final desen in yasak.entries) {
        if (metin.contains(desen.key.toLowerCase())) {
          ihlaller.add('${entry.id}: "${desen.key}" — ${desen.value}');
        }
      }
    }

    expect(
      ihlaller,
      isEmpty,
      reason:
          'Cevrimdisi yedek, veritabaninda DUZELTILMIS bir yanlisi tekrar '
          'ediyor:\n${ihlaller.join('\n')}',
    );
  });

  test('🔴 yedek SAYI vermez (sayilar urun buyudukce yalana doner)', () {
    // WP-656\'da olculdu: yedek "Odak Kampi widgetini sec" diyordu (tekil),
    // urunde ALTI widget var (`res/xml/odak_*_widget_info.xml`). Sayi vermeyen
    // bir cumle bu sinifi bastan onler.
    final sayiliRakam = RegExp(r'\b\d+\b');
    final ihlaller = <String>[];
    for (final entry in kFallbackFaq) {
      final metin = '${entry.question} ${entry.answer}';
      final bulunan = sayiliRakam.allMatches(metin).map((m) => m.group(0)!);
      if (bulunan.isNotEmpty) {
        ihlaller.add('${entry.id}: ${bulunan.join(", ")}');
      }
    }
    expect(
      ihlaller,
      isEmpty,
      reason:
          'Yedekte sayi var. Sayilar (kac widget, kac gun, kac basarim, hangi '
          'esik) urun degisince SESSIZCE yalan olur ve cevrimdisi kullanici '
          'duzeltmeyi hic gormez:\n${ihlaller.join('\n')}',
    );
  });
}

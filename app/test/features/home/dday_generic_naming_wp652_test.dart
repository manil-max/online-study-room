// WP-652 — geri sayım kartı tek bir olay türünü adlandırmaz.
//
// Proje sahibi cihazda bildirdi: *"sınav countdown sayacının ismini 'geri sayım'
// ya da genel başka bir isim koysak güzel olabilir."*
//
// Gerekçesi ürün gerçeği: kullanıcı o karta her tarihi giriyor — tatil, doğum
// günü, teslim tarihi. Kartın "Sınav" demesi özelliği **daraltıyor**; kullanıcı
// oraya sınav dışı bir şey girmenin yanlış olduğunu sanıyor.
//
// 🔴 Neden bir kapı gerekiyor. Bu bir ürün kararıdır, bir hata düzeltmesi değil;
// yani hiçbir davranış testi onu korumaz. Anahtar ADLARI hâlâ `homeSinav*`
// (koda ve testlere bağlılar, yeniden adlandırmak gereksiz churn olurdu), o
// yüzden bir sonraki tur birinin değeri "Sınav ekle"ye geri çevirmesini
// engelleyen tek şey burasıdır.
//
// ⚠️ Ölçüm **değerler** üzerinde; anahtar adları kapsam dışı. `homeSinavAdi`
// gibi bir anahtarın adında "Sinav" geçmesi kusur değildir — kullanıcı anahtar
// adını görmez.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kartın ve ayarlardaki tarih satırının kullanıcıya görünen tüm metinleri.
const _keys = <String>[
  'homeSinavGeriSayimi',
  'homeSinavGeriSayimiAciklama',
  'homeSinavTarihiSecilmedi',
  'homeSinavTarihiniAyarlardanSec',
  'homeSinavBugun',
  'homeSinavGecti',
  'homeSinavVarsayilanAd',
  'homeSinavlariDuzenle',
  'homeSinavEkle',
  'homeSinaviDuzenle',
  'homeSinavAdi',
  'homeSinavAdiIstegeBagli',
  'homeSinavSil',
  'homeSinavEkleSayac',
  'homeSinavSiniriDoldu',
  'profileSinavTarihi',
  'profileSinavTarihiniTemizle',
];

void main() {
  final tr = _catalog('lib/l10n/app_tr.arb');
  final en = _catalog('lib/l10n/app_en.arb');

  test('kapi bos olcum yapmiyor: her anahtar iki katalogda da var', () {
    for (final key in _keys) {
      expect(tr.containsKey(key), isTrue, reason: 'TR katalogunda yok: $key');
      expect(en.containsKey(key), isTrue, reason: 'EN katalogunda yok: $key');
    }
  });

  test('🔴 hicbir metin kullanicinin girdigi olayi SINAV diye adlandirmaz', () {
    final offenders = <String>[];
    for (final key in _keys) {
      final trValue = tr[key]!;
      final enValue = en[key]!;
      if (trValue.toLowerCase().contains('sınav') ||
          trValue.toLowerCase().contains('sinav')) {
        offenders.add('TR $key = "$trValue"');
      }
      if (enValue.toLowerCase().contains('exam')) {
        offenders.add('EN $key = "$enValue"');
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'Kart tek bir olay turunu adlandiriyor. Kullanici oraya tatil, dogum '
          'gunu ve teslim tarihi de giriyor; "sinav" demek ozelligi daraltir '
          've kullaniciyi yaniltir (sahip karari, 2026-08-10):\n'
          '${offenders.join('\n')}',
    );
  });

  test('bos birakinca yazilan ad ile ipucu AYNI kelimeyi soyler', () {
    // Ipucu "bos birakirsan X yazilir" diyor; X gercekten yazilan ad olmali.
    // Ikisi ayri anahtarda oldugu icin biri degisince digeri sessizce yalan
    // soyler — kullanici vaat edilenden baska bir kelime gorur.
    for (final entry in {'TR': tr, 'EN': en}.entries) {
      final catalog = entry.value;
      final fallback = catalog['homeSinavVarsayilanAd']!;
      expect(
        catalog['homeSinavAdiIstegeBagli'],
        contains(fallback),
        reason:
            '${entry.key}: ipucu "$fallback" demiyor, yani kullaniciya '
            'yazilacak addan BASKA bir kelime vaat ediliyor.',
      );
    }
  });
}

Map<String, String> _catalog(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    fail('Katalog bulunamadi: $path (calisma dizini: ${Directory.current.path})');
  }
  final decoded = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in decoded.entries)
      if (!e.key.startsWith('@') && e.value is String) e.key: e.value as String,
  };
}

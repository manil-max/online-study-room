// WP-651 — kamp ateşi önizlemesinin **sahne saati** kolu.
//
// 🔴 Neden var. Proje sahibi *"gece gündüzde erken gece oluyor"* dedi. Ölçüldü
// ve hipotez **doğrulanmadı**: 10 Ağustos'ta sahne 20:01'e kadar tam gündüz,
// 29 dakikada yumuşakça kararıp 20:30'da geceye geçiyor (İstanbul'da gerçek
// günbatımı 20:07, sivil karanlık ~20:38) ve mevsime göre kayıyor — 21
// Haziran'da gece 21:04, 21 Aralık'ta 18:18. Bir sayı "düzeltmek" doğru çalışan
// tek yüzeyi bozardı.
//
// Bu yüzden kod değil **ölçüm aracı** teslim edildi: sahip saati sürer, gecenin
// kendisine göre hangi dakikada bastığını söyler, sayı ondan sonra kodlanır.
//
// ⚠️ Ölçmeyen bir önizleme, önizleme değildir. Bu dosya kolun gerçekten
// **sahneyi sürdüğünü** kanıtlar: kolu oynatmak okunan fazı değiştirmeli.
// Aksi hâlde sahip yanlış bir karede sayı seçer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/campfire_preview.dart';

void main() {
  testWidgets('sahne saati kolu gercekten gokyuzunu surer', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildCampfirePreviewApp(locale: const Locale('tr')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final slider = find.byKey(const ValueKey('scene-clock'));
    expect(
      slider,
      findsOneWidget,
      reason: 'Sahne saati kolu ekranda yok; sahip saati suremiyor.',
    );

    // Kolu en sola (00:00) getir: gece yarisi her mevsimde GECE'dir.
    await tester.drag(slider, const Offset(-2000, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.textContaining('night'),
      findsWidgets,
      reason:
          'Kol 00:00\'a surulduyu halde okunan faz gece degil: kol sahneyi '
          'surmuyor, yalniz kendi degerini gosteriyor.',
    );

    // Kolu en saga (23:59) getir: yine gece — yani "her zaman gece" demiyoruz,
    // asagida gunduz de gosterilecek.
    await tester.drag(slider, const Offset(4000, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('night'), findsWidgets);

    // 🔴 KARSI IDDIA. Kol gun ortasina getirilince faz GUNDUZ olmali. Bu
    // olmadan yukaridaki iki iddia, ekranda sabit "night" yazan bir etiketle
    // de gecerdi.
    //
    // Olculdu: `tester.drag` basisi widget'in MERKEZINDEN baslatir ve Slider
    // dokunulan noktaya atlar; yani 1 px'lik surukleme kolu ~gun ortasina
    // kurar. Ilk yazimda "genisligin yarisi kadar sag" varsayilmisti ve test
    // 23:59'a savrulup kirmizi dustu -- varsayim degil olcum.
    await tester.drag(slider, const Offset(1, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      find.textContaining('day'),
      findsWidgets,
      reason:
          'Kol gun ortasina surulduyu halde faz gunduz degil: okuma satiri '
          'sahneyle ayni ani kullanmiyor.',
    );
  });

  testWidgets('okuma satiri BUGUNUN cipalarini yazar', (tester) async {
    // Sahip ekran goruntusu gonderdiginde tek basina goruntu kanit degildir;
    // yanindaki sayilar kanittir. Bu yuzden cipalar ekranda yazili olmali.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildCampfirePreviewApp(locale: const Locale('tr')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.textContaining('GECE'),
      findsWidgets,
      reason:
          'Gecenin bastigi dakika ekranda yazmiyor; sahip "erken" derken neye '
          'gore erken oldugunu soyleyemez.',
    );
    expect(find.textContaining('batis'), findsWidgets);
  });
}

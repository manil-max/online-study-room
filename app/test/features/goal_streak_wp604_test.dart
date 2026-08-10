// WP-604 — seri (alev) göstergesi: ÜÇ ayrı kök neden.
//
// Sahip bunu üç dört kez bildirdi ve her seferinde yama yapıldı. Belirti:
// *"dün hedefimi tamamladım, seri 1 oldu ve alev yanıyordu. Bugün henüz
// tamamlamadım ama alev hâlâ canlı renkte."* İstenen (chess.com modeli, sahibin
// kendi tarifi): bugünün hedefi tamamlanmadıysa alev SOLUK; bugünkü tamamlanınca
// canlı renge döner ve sayı artar.
//
// Neden bugüne kadar çözülmedi — üç ayrı sebep vardı ve hepsi ayrı katmanda:
//
//   1. 🔴 GÖRÜNÜŞ: `pendingToday` ile `completedToday` **birebir aynı** canlı
//      turuncuyu (0xFFEA580C) kullanıyordu; tek fark dolu/içi boş glifti ve
//      rozet boyutunda görünmüyordu. Üstelik bu `progress.md`de bir SAHİP
//      KARARI olarak yazılıydı (WP-481), yani sonraki her tur "doğru"yu
//      koruyordu. Sahip 2026-08-09'da kararı değiştirdi.
//
//   2. 🔴 ZAMAN BİR GİRDİ DEĞİLDİ — asıl kök neden. Durum bir ZAMAN
//      fonksiyonudur (aynı veriyle, gün değişince durum değişir), ama
//      projeksiyon yalnız VERİ değişince yeniden hesaplanıyordu
//      (`goal_progress_events` akışı). Gece yarısı hiçbir satır değişmez →
//      kullanıcı dünkü `completedToday` ile kalır. Rengi düzeltmek bunu
//      çözmezdi: durum zaten yanlış durumdu.
//
//   3. 🔴 GÜN ANAHTARI cihazın yerel takviminden alınıyordu, İstanbul
//      takviminden değil. Aynı sınıf hata bu depoda iki kez üretime çıktı
//      (WP-561, WP-571).
//
// Bu dosya üçünü de AYRI AYRI ölçer; biri düzelip diğeri bozulursa kırmızıya
// düşer.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/repositories/goal_streak_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_goal_streak_repository.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';

const _scheme = ColorScheme.light();

void main() {
  group('WP-604 (1) — "bugün tamamlanmadı" GÖRÜNÜR biçimde soluk', () {
    test('pendingToday rengi completedToday ile AYNI DEĞİL', () {
      final done = goalStreakFlameVisual(
        GoalStreakState.completedToday,
        _scheme,
      );
      final pending = goalStreakFlameVisual(
        GoalStreakState.pendingToday,
        _scheme,
      );

      expect(
        pending.foreground,
        isNot(done.foreground),
        reason:
            'Sahibin bildirdiği hata tam olarak buydu: bugün tamamlanmamışken '
            'alev canlı renkte kalıyor.',
      );
      // 🔴 WP-657 SAHİP KARARI (2026-08-10): ayrım artık "aynı turuncunun daha
      // açığı" değil, **ton**. Sahip doğrudan gri istedi: "gri renk daha güzel
      // olur". Eski iki iddia (luminance farkı > 0.12 + soluk DAHA AÇIK olacak)
      // o eski kararı sabitliyordu ve yeni emirle çelişiyor; yerlerine daha
      // sert olan doygunluk iddiası geçti — "bir tık farklı turuncu" da,
      // "biraz daha açık turuncu" da artık geçemez.
      expect(
        HSLColor.fromColor(pending.foreground).saturation,
        lessThanOrEqualTo(0.12),
        reason: 'Bekleyen durum GRİ olmalı (sahip emri).',
      );
      expect(
        HSLColor.fromColor(done.foreground).saturation,
        greaterThan(0.35),
        reason: 'Canlı alev renkli kalmalı; üç durum tek griye çökmemeli.',
      );
      // Ölçüldü: gri ile turuncu AYNI parlaklıkta olabilir (bu şemada fark
      // 0.003). Yani luminance farkı artık ayrım kanalı değildir; ayrımı ton +
      // glif taşır. Renk körü kullanıcı için kalan kanal glif ve sayıdır ve
      // ikisi de burada ölçülüyor.
      expect(pending.icon, isNot(done.icon));
      expect(
        pending.background,
        isNot(done.background),
        reason: 'Rozet dolgusu da iki durumda ayrı olmalı.',
      );
    });

    test('soluk alev, SIFIRLANMIŞ durumun grisiyle karışmaz', () {
      final pending = goalStreakFlameVisual(
        GoalStreakState.pendingToday,
        _scheme,
      );
      final none = goalStreakFlameVisual(GoalStreakState.empty, _scheme);

      // 🔴 WP-657: sahip ikisinin de GRİ olmasını istedi, yani ayrımı renk
      // taşıyamaz. Ama korunması gereken şey duruyor: kullanıcı serisi
      // yaşarken "seri bitti" sanmamalı. Ayrım artık GLİF taşıyor — içi boş
      // alev (seri yaşıyor, bugün henüz yok) ile dolu alev (seri yok).
      //
      // Bu iddia yumuşatma değil yer değiştirmedir: eskiden renk ölçülüyordu,
      // şimdi ekranda gerçekten ayırt edici olan kanal ölçülüyor. `expired`
      // ve `empty` her zaman "0" taşır (`projectGoalStreak`), `pendingToday`
      // en az 1 — üçüncü kanal da yerinde.
      expect(
        pending.icon,
        isNot(none.icon),
        reason:
            'İki durum aynı glife düşerse kullanıcı serisinin bittiğini sanır.',
      );
      expect(pending.icon, Icons.local_fire_department_outlined);
      expect(none.icon, Icons.local_fire_department);
    });

    test('dört durumun (ikon, renk) çifti dört AYRI değer taşır', () {
      final seen = <String>{};
      for (final state in GoalStreakState.values) {
        final v = goalStreakFlameVisual(state, _scheme);
        seen.add('${v.icon.codePoint}|${v.foreground.toARGB32()}');
      }
      // `expired` ve `empty` bilerek aynı görünür (ikisi de "seri yok").
      expect(
        seen.length,
        GoalStreakState.values.length - 1,
        reason: 'İki durum sessizce aynı görünüme düşmüş.',
      );
    });
  });

  group('WP-604 (2) — ZAMAN bir girdi: gün dönüşünde yeniden hesaplanır', () {
    const scope = GoalStreakScope(
      type: GoalStreakScopeType.personal,
      id: 'me',
      timeZone: 'Europe/Istanbul',
    );

    // 🔴 Ölçüm GERÇEK bir widget üzerinden yapılır, çıplak `ProviderContainer`
    // üzerinden değil. Sebep ölçüldü: `container.listen` ile geçersiz kılma
    // "kirli" işaretleniyor ama yeniden okuma bir sonraki OKUMAYA kadar
    // ertelenir; testin `pump`ı onu tetiklemez. Üretimde tetikleyen şey
    // rozetin bir sonraki karede provider'ı okumasıdır — test de aynı yoldan
    // ölçmeli, yoksa "geçti" demesi üretimle ilgisiz olurdu.
    Future<ProviderContainer> pumpBadge(
      WidgetTester tester,
      DateTime Function() clock,
      List<GoalStreakScope> reads,
    ) async {
      final container = ProviderContainer(
        overrides: [
          goalStreakClockProvider.overrideWithValue(clock),
          goalStreakRepositoryProvider.overrideWithValue(
            _RecordingRepository(reads),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: _StreakProbe(scope)),
        ),
      );
      return container;
    }

    testWidgets('uygulama öne gelince GÜN DEĞİŞTİYSE yeniden okur', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 8, 8, 12);
      final reads = <GoalStreakScope>[];
      final container = await pumpBadge(tester, () => now, reads);
      expect(reads, hasLength(1));

      // Ertesi sabah: kullanıcı uygulamayı öne getiriyor.
      now = DateTime.utc(2026, 8, 9, 9);
      container
          .read(goalStreakDayRolloverProvider)
          .didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      expect(
        reads.length,
        greaterThan(1),
        reason:
            'Gün değişti ama projeksiyon yeniden okunmadı: kullanıcı dünkü '
            '"bugün tamamlandı" durumunda takılı kalır -- bildirilen hata bu.',
      );

      // Konteyner elle kuruldu (UncontrolledProviderScope), o yüzden elle
      // kapatılır; yoksa gün dönüşü zamanlayıcısı test bitince asılı kalır.
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('AYNI gün içinde öne gelme boşuna okuma YAPMAZ', (
      tester,
    ) async {
      var now = DateTime.utc(2026, 8, 8, 12);
      final reads = <GoalStreakScope>[];
      final container = await pumpBadge(tester, () => now, reads);
      final before = reads.length;

      // Sekme değiştirip geri gelmek günü değiştirmez.
      now = DateTime.utc(2026, 8, 8, 15);
      container
          .read(goalStreakDayRolloverProvider)
          .didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();

      // Bu iddia olmadan "her öne gelmede tazele" çözümü de geçerdi; o da her
      // sekme geçişinde sunucuya gitmek demektir.
      expect(reads.length, before);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });

  group('WP-604 (3) — gün anahtarı İSTANBUL takviminden', () {
    test('İstanbul günü, UTC gününden farklıyken İstanbul kazanır', () {
      // 2026-08-08 22:30 UTC = İstanbul'da 2026-08-09 01:30.
      // Eski kod `DateTime.utc(value.year, value.month, value.day)` diyordu,
      // yani verilen anın UTC alanlarını alıyordu -> 8 Ağustos. Bu test
      // hangi makinede koşarsa koşsun aynı sonucu verir.
      final instant = DateTime.utc(2026, 8, 8, 22, 30);

      expect(
        SupabaseGoalStreakRepository.dayKeyFor(instant),
        istanbulDay(instant),
      );
      expect(
        SupabaseGoalStreakRepository.dayKeyFor(instant).day,
        9,
        reason:
            'Sunucuya YANLIŞ gün soruluyor: seri durumu bir gün kayar ve alev '
            'yanlış durumda takılı görünür.',
      );
    });

    test('gün ortasında İstanbul ve UTC aynı günü verirken de doğru', () {
      final instant = DateTime.utc(2026, 8, 9, 9);
      expect(SupabaseGoalStreakRepository.dayKeyFor(instant).day, 9);
    });
  });
}

/// Rozetin ta kendisi değil ama onunla aynı şeyi yapan en küçük tüketici:
/// provider'ı **izler**. Gerçek rozet ek sağlayıcılar istiyor; ölçülen bağ
/// (gün dönüşü → yeniden okuma) ikisinde de aynı.
class _StreakProbe extends ConsumerWidget {
  const _StreakProbe(this.scope);

  final GoalStreakScope scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projection = ref.watch(goalStreakProjectionProvider(scope));
    return Text(
      '${projection.value?.currentStreak ?? -1}',
      textDirection: TextDirection.ltr,
    );
  }
}

/// Her `watchProjection` çağrısını kaydeden sahte depo: ölçülen şey "kaç kez
/// yeniden okundu", çünkü hatanın kendisi "hiç yeniden okunmuyordu"ydu.
class _RecordingRepository implements GoalStreakRepository {
  _RecordingRepository(this.reads);

  final List<GoalStreakScope> reads;

  @override
  Future<GoalStreakProjection> readProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) async => _empty(scope);

  @override
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) {
    reads.add(scope);
    return Stream.value(_empty(scope));
  }

  GoalStreakProjection _empty(GoalStreakScope scope) => GoalStreakProjection(
    scope: scope,
    asOfDay: DateTime.utc(2026, 8, 8),
    currentStreak: 0,
    completionCount: 0,
    state: GoalStreakState.empty,
    sourceVersion: 'test',
  );
}

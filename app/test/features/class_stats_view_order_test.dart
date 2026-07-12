import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';

Profile _profile(String id, String name) => Profile(
      id: id,
      displayName: name,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  testWidgets(
      'ClassStatsView bölümleri §8.3 sırasında dizilir '
      '(hedef → özet → sıralama → günlük trend → uzun eğilim → tüm zamanlar → '
      'karşılaştırma)', (tester) async {
    // İç bölümlerin (fl_chart + heat tablo) hepsinin build olması için uzun viewport;
    // geniş tutuldu ki bu order testi dar-ekran layout taşmalarıyla değil yalnız
    // dikey sırayla ilgilensin (_GroupGoalCard'ın iç yerleşimi WP-44 kapsamı dışı).
    tester.view.physicalSize = const Size(2400, 9000); // 800x3000 logical
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final members = [_profile('u1', 'Ada'), _profile('u2', 'Bora')];
    final stats = [
      DailyStat(userId: 'u1', day: today, seconds: 3600),
      DailyStat(userId: 'u2', day: today, seconds: 1800),
      DailyStat(userId: 'u1', day: yesterday, seconds: 2400),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ClassStatsView(
              stats: stats,
              members: members,
              currentUserId: 'u1',
              groupName: 'Test Grubu',
              groupGoalMinutes: 120,
            ),
          ),
        ),
      ),
    );
    // fl_chart giriş animasyonunu tamamla; sonsuz animasyon yok.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    double topOf(String text) => tester.getTopLeft(find.text(text)).dy;

    // Beklenen sıra (yukarıdan aşağı). Her etiket ekranda benzersiz olacak şekilde
    // seçildi ('Kişi başı ort.' özet kartı için, 'Grup toplamı' değil — o Tüm
    // zamanlar kartında da geçer).
    final goal = topOf('Bugünkü grup hedefi');
    final summary = topOf('Kişi başı ort.');
    final ranking = topOf('Sıralama');
    final dailyTrend = topOf('Grup günlük trendi (son 7 gün)');
    final longTrend = topOf('Grup eğilimi (son 30 gün)');
    final allTime = topOf('Tüm zamanlar');
    final comparison = topOf('Karşılaştırma tablosu');

    expect(goal < summary, isTrue, reason: 'hedef, özetin üstünde olmalı');
    expect(summary < ranking, isTrue,
        reason: 'özet, sıralamanın üstünde olmalı');
    expect(ranking < dailyTrend, isTrue,
        reason: 'sıralama, günlük trendin ÜSTÜNDE olmalı (kullanıcı isteği)');
    expect(dailyTrend < longTrend, isTrue,
        reason: 'günlük trend, uzun eğilimin üstünde olmalı');
    expect(longTrend < allTime, isTrue,
        reason: 'uzun eğilim, tüm zamanların üstünde olmalı');
    expect(allTime < comparison, isTrue,
        reason: 'tüm zamanlar, karşılaştırmanın üstünde olmalı');

    // Sıralama gerçekten dolu render olur (ölü bölüm değil): geçerli kullanıcı
    // "(sen)" etiketiyle işaretli bir leaderboard satırı olarak görünür.
    expect(find.textContaining('(sen)'), findsWidgets);
    expect(find.text('Bora'), findsWidgets);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/dashboard_card.dart';
import 'package:online_study_room/features/home/dashboard_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DashboardCardConfig serilestirme', () {
    test('yeni 6xN formatini "tur:x:y:w:h" olarak kodlar/cozer', () {
      const c = DashboardCardConfig(
        DashboardCardType.weekly,
        x: 1,
        y: 2,
        w: 4,
        h: 3,
      );

      expect(c.encode(), 'weekly:1:2:4:3');
      expect(DashboardCardConfig.decode(c.encode()), c);
    });

    test('yeni format sinirlari guvenli bicimde kirpar', () {
      final back = DashboardCardConfig.decode('line:9:-2:99:0');

      expect(back, isNotNull);
      expect(back!.x, 0);
      expect(back.y, 0);
      expect(back.w, kGridColumns);
      expect(back.h, 1);
    });

    test('geriye uyum: sade "tur" tam genislik ve 4 satira gocer', () {
      final back = DashboardCardConfig.decode('timer');

      expect(back, isNotNull);
      expect(back!.x, 0);
      expect(back.y, 0);
      expect(back.w, 6);
      expect(back.h, 4);
      expect(back.effectiveHeight, defaultCardHeight(DashboardCardSize.large));
    });

    test('geriye uyum: eski "tur:small" 3x2 hucreye gocer', () {
      final back = DashboardCardConfig.decode('today:small');

      expect(back, isNotNull);
      expect(back!.w, 3);
      expect(back.h, 2);
    });

    test('geriye uyum: eski "tur:genislik:yukseklik" hucreye snaplenir', () {
      final back = DashboardCardConfig.decode('records:8:300');

      expect(back, isNotNull);
      expect(back!.w, 4);
      expect(back.h, 4);
    });

    test('decodeList eski kayitlari ilk uygun bos hucreye yerlestirir', () {
      final list = DashboardCardConfig.decodeList([
        'timer:12:320',
        'today:6:160',
        'leaderboard:6:160',
        'weekly:12:240',
      ]);

      expect(list, [
        const DashboardCardConfig(
          DashboardCardType.timer,
          x: 0,
          y: 0,
          w: 6,
          h: 4,
        ),
        const DashboardCardConfig(
          DashboardCardType.today,
          x: 0,
          y: 4,
          w: 3,
          h: 2,
        ),
        const DashboardCardConfig(
          DashboardCardType.leaderboard,
          x: 3,
          y: 4,
          w: 3,
          h: 2,
        ),
        const DashboardCardConfig(
          DashboardCardType.weekly,
          x: 0,
          y: 6,
          w: 6,
          h: 3,
        ),
      ]);
    });

    test('withBounds konumu ve boyutu 6 sutun icinde tutar', () {
      const c = DashboardCardConfig(
        DashboardCardType.goal,
        x: 2,
        y: 5,
        w: 3,
        h: 2,
      );
      final next = c.withBounds(x: 5, y: -4, w: 4, h: 0);

      expect(next.x, 2);
      expect(next.y, 0);
      expect(next.w, 4);
      expect(next.h, 1);
    });

    test('firstAvailable dolu alanin altina yerlesir', () {
      final next = DashboardCardConfig.firstAvailable(
        [
          const DashboardCardConfig(
            DashboardCardType.timer,
            x: 0,
            y: 0,
            w: 6,
            h: 4,
          ),
          const DashboardCardConfig(
            DashboardCardType.today,
            x: 0,
            y: 4,
            w: 3,
            h: 2,
          ),
        ],
        DashboardCardType.records,
        w: 3,
        h: 2,
      );

      expect(
        next,
        const DashboardCardConfig(
          DashboardCardType.records,
          x: 3,
          y: 4,
          w: 3,
          h: 2,
        ),
      );
    });
  });

  group('DashboardLayoutNotifier migration', () {
    test('eski prefs listesini profil formatina gocurur', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout': ['timer:12:320', 'today:small'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final layout = container.read(dashboardLayoutProvider);

      expect(layout, [
        const DashboardCardConfig(
          DashboardCardType.timer,
          x: 0,
          y: 0,
          w: 6,
          h: 4,
        ),
        const DashboardCardConfig(
          DashboardCardType.today,
          x: 0,
          y: 4,
          w: 3,
          h: 2,
        ),
      ]);
      // Geri alma güvenliği için eski anahtar korunur; aktif profil v2'ye yazılır.
      expect(prefs.getStringList('dashboard_layout'), [
        'timer:12:320',
        'today:small',
      ]);
      expect(prefs.getStringList('dashboard_layout_v2_6'), [
        'timer:0:0:6:4',
        'today:0:4:3:2',
      ]);
    });

    test('setBounds carpisan kartlari asagi iter', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout': ['timer:0:0:6:2', 'today:0:2:6:2'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container
          .read(dashboardLayoutProvider.notifier)
          .setBounds(DashboardCardType.timer, y: 1);

      expect(container.read(dashboardLayoutProvider), [
        const DashboardCardConfig(
          DashboardCardType.timer,
          x: 0,
          y: 1,
          w: 6,
          h: 2,
        ),
        const DashboardCardConfig(
          DashboardCardType.today,
          x: 0,
          y: 3,
          w: 6,
          h: 2,
        ),
      ]);
    });

    test('compactUp bosluklari kaldirir ve aktif profile kaydeder', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout_v2_6': [
          'timer:0:6:3:2',
          'today:3:9:3:2',
          'leaderboard:0:14:6:3',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(dashboardLayoutProvider.notifier).compactUp();

      expect(prefs.getStringList('dashboard_layout_v2_6'), [
        'timer:0:0:3:2',
        'today:3:0:3:2',
        'leaderboard:0:2:6:3',
      ]);
    });

    test('6, 12 ve 16 sutun profilleri bagimsiz saklanir', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout': ['timer:0:0:6:4', 'today:0:4:3:2'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(dashboardLayoutProvider).first.w, 6);

      container
          .read(dashboardGridDensityProvider.notifier)
          .set(DashboardGridDensity.columns12);
      expect(container.read(dashboardGridColumnsProvider), 12);
      expect(container.read(dashboardLayoutProvider).first.w, 12);

      container
          .read(dashboardLayoutProvider.notifier)
          .setBounds(DashboardCardType.timer, w: 10);
      final customized12 = [...container.read(dashboardLayoutProvider)];

      container
          .read(dashboardGridDensityProvider.notifier)
          .set(DashboardGridDensity.columns16);
      expect(container.read(dashboardGridColumnsProvider), 16);
      expect(container.read(dashboardLayoutProvider).first.w, 13);
      container
          .read(dashboardLayoutProvider.notifier)
          .setBounds(DashboardCardType.timer, w: 15);
      final customized16 = [...container.read(dashboardLayoutProvider)];

      container
          .read(dashboardGridDensityProvider.notifier)
          .set(DashboardGridDensity.columns6);
      expect(container.read(dashboardLayoutProvider).first.w, 6);

      container
          .read(dashboardGridDensityProvider.notifier)
          .set(DashboardGridDensity.columns12);
      expect(container.read(dashboardLayoutProvider), customized12);
      container
          .read(dashboardGridDensityProvider.notifier)
          .set(DashboardGridDensity.columns16);
      expect(container.read(dashboardLayoutProvider), customized16);
      expect(prefs.getString('dashboard_grid_density'), 'columns16');
    });

    test('otomatik yogunluk genislige gore 6 8 12 16 secer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(dashboardGridColumnsProvider.notifier);
      expect(container.read(dashboardGridColumnsProvider), 6);
      notifier.resolveForWidth(900);
      expect(container.read(dashboardGridColumnsProvider), 8);
      notifier.resolveForWidth(1200);
      expect(container.read(dashboardGridColumnsProvider), 12);
      notifier.resolveForWidth(1400);
      expect(container.read(dashboardGridColumnsProvider), 16);
      notifier.resolveForWidth(600);
      expect(container.read(dashboardGridColumnsProvider), 6);
    });
  });
}

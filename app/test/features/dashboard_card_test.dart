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
    test('eski prefs listesini 32-sutun profil formatina gocurur', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout': ['timer:12:320', 'today:small'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final layout = container.read(dashboardLayoutProvider);
      // WP-186: runtime 32; legacy önce 6-sütunda decode, sonra 32'ye projekte.
      // timer 6×4 → 32×21; today 3×2 → 16×11.
      expect(layout.length, 2);
      expect(layout.first.type, DashboardCardType.timer);
      expect(layout.first.w, 32);
      expect(layout.first.h, 21);
      expect(layout[1].type, DashboardCardType.today);
      expect(layout[1].w, 16);
      for (final card in layout) {
        expect(card.x + card.w, lessThanOrEqualTo(32));
      }
      // Geri alma güvenliği için eski anahtar korunur; aktif profil v2_32.
      expect(prefs.getStringList('dashboard_layout'), [
        'timer:12:320',
        'today:small',
      ]);
      expect(prefs.getStringList('dashboard_layout_v2_32'), isNotNull);
      expect(prefs.getString('dashboard_grid_density'), 'columns32');
    });

    test('setBounds carpisan kartlari asagi iter', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout_v2_32': [
          'timer:0:0:32:2',
          'today:0:2:32:2',
        ],
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
          w: 32,
          h: 2,
        ),
        const DashboardCardConfig(
          DashboardCardType.today,
          x: 0,
          y: 3,
          w: 32,
          h: 2,
        ),
      ]);
    });

    test('compactUp bosluklari kaldirir ve aktif profile kaydeder', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout_v2_32': [
          'timer:0:6:16:2',
          'today:16:9:16:2',
          'leaderboard:0:14:32:3',
        ],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(dashboardLayoutProvider.notifier).compactUp();

      expect(prefs.getStringList('dashboard_layout_v2_32'), [
        'timer:0:0:16:2',
        'today:16:0:16:2',
        'leaderboard:0:2:32:3',
      ]);
    });

    test('WP-186 density herkeste sabit 32; eski pref migrate', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_grid_density': 'columns12',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(dashboardGridDensityProvider),
        DashboardGridDensity.columns32,
      );
      expect(container.read(dashboardGridColumnsProvider), 32);
      expect(prefs.getString('dashboard_grid_density'), 'columns32');

      // set() de pin eder
      container
          .read(dashboardGridDensityProvider.notifier)
          .set(DashboardGridDensity.columns6);
      expect(container.read(dashboardGridColumnsProvider), 32);
      expect(prefs.getString('dashboard_grid_density'), 'columns32');
    });

    test('eski automatic tercihi 32 ye duser', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_grid_density': 'automatic',
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container.read(dashboardGridDensityProvider),
        DashboardGridDensity.columns32,
      );
      expect(container.read(dashboardGridColumnsProvider), 32);
      expect(prefs.getString('dashboard_grid_density'), 'columns32');
    });

    test('varsayilan duzen 32 sutunda tasmadan olceklenir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(DashboardGridDensity.columns32.columns, 32);
      expect(DashboardGridDensity.columns32.label, '32');
      expect(container.read(dashboardGridColumnsProvider), 32);

      final layout = container.read(dashboardLayoutProvider);
      expect(layout.first.w, 32);
      for (final card in layout) {
        expect(card.x + card.w, lessThanOrEqualTo(32));
      }
      expect(prefs.getString('dashboard_grid_density'), 'columns32');
    });

    test('yeni kart eklerken varsayilan boyut 32-gridde kullanislidir', () async {
      SharedPreferences.setMockInitialValues({
        'dashboard_layout_v2_32': ['timer:0:0:32:8'],
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container
          .read(dashboardLayoutProvider.notifier)
          .addCard(DashboardCardType.today);
      final added = container
          .read(dashboardLayoutProvider)
          .firstWhere((c) => c.type == DashboardCardType.today);
      // 6-sütun 3×3 ölçeği → 32'de 16×16
      expect(added.w, 16);
      expect(added.h, 16);
      expect(DashboardCardConfig.defaultAddWidth(32), 16);
      expect(DashboardCardConfig.defaultAddHeight(32), 16);
    });
  });
}

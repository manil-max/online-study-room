import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/grid/grid_reflow.dart';
import '../../core/prefs/app_prefs.dart';
import 'dashboard_card.dart';

const _kLayoutKey = 'dashboard_layout';
const _kLayoutProfilePrefix = 'dashboard_layout_v2_';
const _kLastColumnsKey = 'dashboard_grid_last_columns';
const _kDensityKey = 'dashboard_grid_density';
const _kClassroomTimerKey = 'classroom_show_timer';

enum DashboardGridDensity {
  automatic,
  columns6,
  columns8,
  columns12,
  columns16,
}

extension DashboardGridDensityX on DashboardGridDensity {
  String get label => switch (this) {
    DashboardGridDensity.automatic => 'Otomatik',
    DashboardGridDensity.columns6 => '6 sütun',
    DashboardGridDensity.columns8 => '8 sütun',
    DashboardGridDensity.columns12 => '12 sütun',
    DashboardGridDensity.columns16 => '16 sütun',
  };

  int? get fixedColumns => switch (this) {
    DashboardGridDensity.automatic => null,
    DashboardGridDensity.columns6 => 6,
    DashboardGridDensity.columns8 => 8,
    DashboardGridDensity.columns12 => 12,
    DashboardGridDensity.columns16 => 16,
  };
}

class DashboardGridDensityNotifier extends Notifier<DashboardGridDensity> {
  @override
  DashboardGridDensity build() {
    final raw = ref.watch(sharedPreferencesProvider).getString(_kDensityKey);
    return DashboardGridDensity.values
            .where((value) => value.name == raw)
            .firstOrNull ??
        DashboardGridDensity.automatic;
  }

  void set(DashboardGridDensity value) {
    state = value;
    ref.read(sharedPreferencesProvider).setString(_kDensityKey, value.name);
  }
}

final dashboardGridDensityProvider =
    NotifierProvider<DashboardGridDensityNotifier, DashboardGridDensity>(
      DashboardGridDensityNotifier.new,
    );

class DashboardGridColumnsNotifier extends Notifier<int> {
  @override
  int build() {
    return ref.watch(dashboardGridDensityProvider).fixedColumns ??
        kDefaultGridColumns;
  }

  void resolveForWidth(double width) {
    if (ref.read(dashboardGridDensityProvider) !=
        DashboardGridDensity.automatic) {
      return;
    }
    final next = width < 720
        ? 6
        : width < 1080
        ? 8
        : width < 1360
        ? 12
        : 16;
    if (next != state) state = next;
  }
}

final dashboardGridColumnsProvider =
    NotifierProvider<DashboardGridColumnsNotifier, int>(
      DashboardGridColumnsNotifier.new,
    );

String _profileKey(int columns) => '$_kLayoutProfilePrefix$columns';

List<DashboardCardConfig> defaultDashboardLayout(int columns) {
  final left = columns ~/ 2;
  return [
    DashboardCardConfig(
      DashboardCardType.timer,
      x: 0,
      y: 0,
      w: columns,
      h: (4 * columns / kDefaultGridColumns).round(),
    ),
    DashboardCardConfig(
      DashboardCardType.today,
      x: 0,
      y: (4 * columns / kDefaultGridColumns).round(),
      w: left,
      h: (3 * columns / kDefaultGridColumns).round(),
    ),
    DashboardCardConfig(
      DashboardCardType.leaderboard,
      x: left,
      y: (4 * columns / kDefaultGridColumns).round(),
      w: columns - left,
      h: (3 * columns / kDefaultGridColumns).round(),
    ),
  ];
}

List<DashboardCardConfig> projectDashboardLayout({
  required List<DashboardCardConfig> source,
  required int fromColumns,
  required int toColumns,
}) {
  if (fromColumns == toColumns) {
    return [for (final item in source) item.withBounds(columns: toColumns)];
  }

  var projected = <DashboardCardConfig>[];
  for (final sourceItem in source) {
    int scale(int value, {int minimum = 0}) =>
        (value * toColumns / fromColumns).round().clamp(minimum, 9999).toInt();
    final desired = sourceItem.withBounds(
      x: scale(sourceItem.x),
      y: scale(sourceItem.y),
      w: scale(sourceItem.w, minimum: 1),
      h: scale(sourceItem.h, minimum: 1),
      columns: toColumns,
    );
    final flowed = placeGridItem(
      items: [
        for (final item in projected)
          GridItemBounds(
            id: item.type.name,
            x: item.x,
            y: item.y,
            w: item.w,
            h: item.h,
          ),
        GridItemBounds(
          id: desired.type.name,
          x: desired.x,
          y: desired.y,
          w: desired.w,
          h: desired.h,
        ),
      ],
      id: desired.type.name,
      x: desired.x,
      y: desired.y,
      w: desired.w,
      h: desired.h,
      columns: toColumns,
    );
    final byId = {for (final item in flowed) item.id: item};
    projected = [
      for (final item in [...projected, desired])
        item.withBounds(
          x: byId[item.type.name]!.x,
          y: byId[item.type.name]!.y,
          w: byId[item.type.name]!.w,
          h: byId[item.type.name]!.h,
          columns: toColumns,
        ),
    ];
  }
  return projected;
}

/// Ana Sayfa kart düzeni (sıralı kartlar; tür + boyut). Kişiye özel, cihazda
/// kalıcı (§3.9/§3.11). İlk açılışta varsayılan; kullanıcı ekler/çıkarır/sıralar
/// ve her kartın boyutunu (küçük/orta/büyük) ayarlar.
class DashboardLayoutNotifier extends Notifier<List<DashboardCardConfig>> {
  @override
  List<DashboardCardConfig> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final columns = ref.watch(dashboardGridColumnsProvider);
    final stored = prefs.getStringList(_profileKey(columns));
    if (stored != null) {
      prefs.setInt(_kLastColumnsKey, columns);
      return DashboardCardConfig.decodeList(stored, columns: columns);
    }

    final lastColumns = prefs.getInt(_kLastColumnsKey);
    final lastProfile = lastColumns == null
        ? null
        : prefs.getStringList(_profileKey(lastColumns));
    final legacy = prefs.getStringList(_kLayoutKey);
    final sourceColumns = lastProfile != null
        ? lastColumns!
        : kDefaultGridColumns;
    final sourceRaw = lastProfile ?? legacy;
    final layout = sourceRaw == null
        ? defaultDashboardLayout(columns)
        : projectDashboardLayout(
            source: DashboardCardConfig.decodeList(
              sourceRaw,
              columns: sourceColumns,
            ),
            fromColumns: sourceColumns,
            toColumns: columns,
          );
    prefs.setStringList(
      _profileKey(columns),
      layout.map((item) => item.encode()).toList(),
    );
    prefs.setInt(_kLastColumnsKey, columns);
    return layout;
  }

  void _save() {
    final columns = ref.read(dashboardGridColumnsProvider);
    ref
        .read(sharedPreferencesProvider)
        .setStringList(
          _profileKey(columns),
          state.map((c) => c.encode()).toList(),
        );
  }

  int _indexOf(DashboardCardType type) =>
      state.indexWhere((c) => c.type == type);

  /// Kartı ekle (yoksa ilk uygun boş hücreye) veya çıkar (varsa).
  void toggle(DashboardCardType type) {
    final i = _indexOf(type);
    if (i >= 0) {
      removeCard(type);
    } else {
      addCard(type);
    }
  }

  void addCard(DashboardCardType type) {
    if (_indexOf(type) >= 0) return;
    final columns = ref.read(dashboardGridColumnsProvider);
    state = [
      ...state,
      DashboardCardConfig.firstAvailable(state, type, columns: columns),
    ];
    _save();
  }

  void removeCard(DashboardCardType type) {
    final i = _indexOf(type);
    if (i < 0) return;
    state = [...state]..removeAt(i);
    _save();
  }

  void setBounds(
    DashboardCardType type, {
    int? x,
    int? y,
    int? w,
    int? h,
    bool persist = true,
  }) {
    final i = _indexOf(type);
    if (i < 0) return;
    final columns = ref.read(dashboardGridColumnsProvider);
    final list = [...state];
    final target = list[i].withBounds(x: x, y: y, w: w, h: h, columns: columns);
    final flowed = placeGridItem(
      items: [
        for (final config in list)
          GridItemBounds(
            id: config.type.name,
            x: config.x,
            y: config.y,
            w: config.w,
            h: config.h,
          ),
      ],
      id: type.name,
      x: target.x,
      y: target.y,
      w: target.w,
      h: target.h,
      columns: columns,
    );
    final byId = {for (final item in flowed) item.id: item};
    state = [
      for (final config in list)
        config.withBounds(
          x: byId[config.type.name]!.x,
          y: byId[config.type.name]!.y,
          w: byId[config.type.name]!.w,
          h: byId[config.type.name]!.h,
          columns: columns,
        ),
    ];
    if (persist) _save();
  }

  /// Bir kartın ızgara genişliğini aktif profil sınırlarında ayarlar.
  void setWidth(DashboardCardType type, int width) {
    setBounds(type, w: width);
  }

  /// Bir kartın serbest yüksekliğini (px) ayarlar. Sürükleyerek boyutlandırma
  /// sırasında [persist] `false` verilir (her piksel için diske yazmamak için);
  /// sürükleme bitince [persist] kalır → kalıcılaşır (§2D).
  void setHeight(DashboardCardType type, double height, {bool persist = true}) {
    setBounds(
      type,
      h: DashboardCardConfig.rowsForLegacyHeight(height),
      persist: persist,
    );
  }

  /// Mevcut düzeni diske yazar (canlı sürükleme bitince çağrılır).
  void persist() => _save();

  /// Ana Sayfa düzenini varsayılana döndür.
  void reset() {
    state = defaultDashboardLayout(ref.read(dashboardGridColumnsProvider));
    _save();
  }

  /// Sürükle-bırak ile yeniden sırala. `onReorderItem` zaten [newIndex]'i
  /// kaldırılan öğeye göre düzeltir, ek düzeltme gerekmez.
  void reorderItem(int oldIndex, int newIndex) {
    final list = [...state];
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    _save();
  }
}

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, List<DashboardCardConfig>>(
      DashboardLayoutNotifier.new,
    );

/// Sayaç kartı Sınıflar ekranında da gösterilsin mi? (Varsayılan kapalı — sayaç
/// Ana Sayfa'da gelir; isteyen Sınıflar'a ekler.) Cihazda kalıcı.
class ClassroomShowTimerNotifier extends Notifier<bool> {
  @override
  bool build() {
    return ref.watch(sharedPreferencesProvider).getBool(_kClassroomTimerKey) ??
        false;
  }

  void set(bool value) {
    state = value;
    ref.read(sharedPreferencesProvider).setBool(_kClassroomTimerKey, value);
  }
}

final classroomShowTimerProvider =
    NotifierProvider<ClassroomShowTimerNotifier, bool>(
      ClassroomShowTimerNotifier.new,
    );

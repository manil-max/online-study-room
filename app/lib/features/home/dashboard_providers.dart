import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import 'dashboard_card.dart';

const _kLayoutKey = 'dashboard_layout';
const _kClassroomTimerKey = 'classroom_show_timer';

/// Varsayılan Ana Sayfa düzeni (ilk açılış): sayaç üstte tam genişlik, altında
/// bugün özeti + sıralama yan yana. Değerler 6 sütunlu matris hücresidir.
const List<DashboardCardConfig> _kDefaultLayout = [
  DashboardCardConfig(DashboardCardType.timer, x: 0, y: 0, w: 6, h: 4),
  DashboardCardConfig(DashboardCardType.today, x: 0, y: 4, w: 3, h: 3),
  DashboardCardConfig(DashboardCardType.leaderboard, x: 3, y: 4, w: 3, h: 3),
];

/// Ana Sayfa kart düzeni (sıralı kartlar; tür + boyut). Kişiye özel, cihazda
/// kalıcı (§3.9/§3.11). İlk açılışta varsayılan; kullanıcı ekler/çıkarır/sıralar
/// ve her kartın boyutunu (küçük/orta/büyük) ayarlar.
class DashboardLayoutNotifier extends Notifier<List<DashboardCardConfig>> {
  @override
  List<DashboardCardConfig> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_kLayoutKey);
    if (stored == null) return List.of(_kDefaultLayout);
    // Eski "tür:genişlik[:yükseklik]", "tür:boyut" ve sade "tür" kayıtları
    // 6 sütunlu x/y/w/h formata göçer. Boş liste geçerlidir.
    final decoded = DashboardCardConfig.decodeList(stored);
    final migrated = decoded.map((c) => c.encode()).toList();
    if (!_sameStringList(stored, migrated)) {
      prefs.setStringList(_kLayoutKey, migrated);
    }
    return decoded;
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kLayoutKey, state.map((c) => c.encode()).toList());
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
    state = [...state, DashboardCardConfig.firstAvailable(state, type)];
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
    final list = [...state];
    list[i] = list[i].withBounds(x: x, y: y, w: w, h: h);
    state = list;
    if (persist) _save();
  }

  /// Bir kartın ızgara genişliğini (hücre, 1..[kGridColumns]) ayarlar.
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
    state = List.of(_kDefaultLayout);
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

bool _sameStringList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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

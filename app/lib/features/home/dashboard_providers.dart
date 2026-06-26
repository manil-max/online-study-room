import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import 'dashboard_card.dart';

const _kLayoutKey = 'dashboard_layout';
const _kClassroomTimerKey = 'classroom_show_timer';

/// Varsayılan Ana Sayfa düzeni (ilk açılış): sayaç (tam) + bugün özeti (yarım)
/// + sıralama (yarım). Genişlikler ızgara hücresi cinsinden (1..[kGridColumns]).
const List<DashboardCardConfig> _kDefaultLayout = [
  DashboardCardConfig(DashboardCardType.timer, width: kGridColumns),
  DashboardCardConfig(DashboardCardType.today, width: kGridColumns ~/ 2),
  DashboardCardConfig(DashboardCardType.leaderboard, width: kGridColumns ~/ 2),
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
    // "tür:boyut" (veya eski sade "tür") çözümle; bilinmeyenleri yok say. Boş
    // liste de geçerlidir (kullanıcı tüm kartları kaldırmış olabilir).
    return [
      for (final raw in stored) ?DashboardCardConfig.decode(raw),
    ];
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kLayoutKey, state.map((c) => c.encode()).toList());
  }

  int _indexOf(DashboardCardType type) =>
      state.indexWhere((c) => c.type == type);

  /// Kartı ekle (yoksa sona, yarım genişlik) veya çıkar (varsa).
  void toggle(DashboardCardType type) {
    final i = _indexOf(type);
    if (i >= 0) {
      state = [...state]..removeAt(i);
    } else {
      state = [
        ...state,
        DashboardCardConfig(type, width: kGridColumns ~/ 2),
      ];
    }
    _save();
  }

  /// Bir kartın ızgara genişliğini (hücre, 1..[kGridColumns]) ayarlar.
  void setWidth(DashboardCardType type, int width) {
    final i = _indexOf(type);
    if (i < 0) return;
    final list = [...state];
    list[i] = list[i].withWidth(width);
    state = list;
    _save();
  }

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

final dashboardLayoutProvider =
    NotifierProvider<DashboardLayoutNotifier, List<DashboardCardConfig>>(
        DashboardLayoutNotifier.new);

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
        ClassroomShowTimerNotifier.new);

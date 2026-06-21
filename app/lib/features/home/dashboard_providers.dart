import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';
import 'dashboard_card.dart';

const _kLayoutKey = 'dashboard_layout';
const _kClassroomTimerKey = 'classroom_show_timer';

/// Varsayılan Ana Sayfa düzeni (ilk açılış): sayaç + bugün özeti + sıralama.
const List<DashboardCardType> _kDefaultLayout = [
  DashboardCardType.timer,
  DashboardCardType.today,
  DashboardCardType.leaderboard,
];

/// Ana Sayfa kart düzeni (sıralı, görünen kartlar). Kişiye özel, cihazda kalıcı
/// (§3.9). İlk açılışta varsayılan; kullanıcı ekler/çıkarır/sıralar.
class DashboardLayoutNotifier extends Notifier<List<DashboardCardType>> {
  @override
  List<DashboardCardType> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getStringList(_kLayoutKey);
    if (stored == null) return List.of(_kDefaultLayout);
    // İsimleri enum'a çevir (bilinmeyen/eski isimleri yok say). Boş liste de
    // geçerlidir (kullanıcı tüm kartları kaldırmış olabilir).
    final byName = {for (final t in DashboardCardType.values) t.name: t};
    return [
      for (final name in stored)
        if (byName[name] != null) byName[name]!,
    ];
  }

  void _save() {
    ref
        .read(sharedPreferencesProvider)
        .setStringList(_kLayoutKey, state.map((t) => t.name).toList());
  }

  /// Kartı ekle (yoksa sona) veya çıkar (varsa).
  void toggle(DashboardCardType type) {
    if (state.contains(type)) {
      state = [...state]..remove(type);
    } else {
      state = [...state, type];
    }
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
    NotifierProvider<DashboardLayoutNotifier, List<DashboardCardType>>(
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

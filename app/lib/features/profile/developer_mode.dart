import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/prefs/app_prefs.dart';

/// WP-514: gizli geliştirici kapısı (Android "Build number"a 7 kez dokun deseni).
///
/// 🔴 Neden gizli kapı, neden admin-only değil: sayaç tanılama kaydı
/// (`TimerDiagnosticJournal`) **her cihazda** tutuluyor. Admin kapısı kaydın
/// *üretilmesini* değil yalnız *okunmasını* engellerdi — yani sahip dışında
/// birinin "bazen oluyor" hatası yine kanıtlanamazdı. Gizli kapı kaydı normal
/// kullanıcının önünden kaldırır ama destek gerektiğinde herhangi bir cihazda
/// telefonla tarif edilerek açılabilir kalır.
const kDeveloperModeKey = 'developer.mode_enabled_v1';

/// Kilidi açmak için gereken toplam dokunma sayısı.
const kDeveloperModeTapTarget = 7;

/// Kaçıncı dokunmadan sonra "N adım kaldı" geri bildirimi gösterilir.
const kDeveloperModeHintAfter = 3;

/// Ardışık sayılan dokunmalar arası azami süre.
///
/// Pencere olmadan sayaç sonsuza kadar birikirdi: sürüm satırını aylar içinde
/// yedi kez açıp kapatan normal bir kullanıcı geliştirici modunu **kazara**
/// açardı.
const kDeveloperModeTapWindow = Duration(seconds: 3);

/// Saf dokunma sayacı — pencere dışındaki dokunma diziyi sıfırlar.
///
/// Zamanı dışarıdan alır ki test gerçek saat beklemeden pencereyi sınayabilsin.
class DeveloperGateCounter {
  DeveloperGateCounter({this.window = kDeveloperModeTapWindow});

  final Duration window;

  int _count = 0;
  DateTime? _last;

  int get count => _count;

  /// [now] anındaki dokunmayı işler ve dizideki sıra numarasını döndürür.
  int registerTap(DateTime now) {
    final previous = _last;
    if (previous == null || now.difference(previous) > window) {
      _count = 0;
    }
    _last = now;
    _count += 1;
    return _count;
  }

  void reset() {
    _count = 0;
    _last = null;
  }
}

class DeveloperModeNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(kDeveloperModeKey) ?? false;

  Future<void> setEnabled(bool value) async {
    await ref.read(sharedPreferencesProvider).setBool(kDeveloperModeKey, value);
    state = value;
  }
}

final developerModeProvider = NotifierProvider<DeveloperModeNotifier, bool>(
  DeveloperModeNotifier.new,
);

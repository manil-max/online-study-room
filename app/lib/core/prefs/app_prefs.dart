import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yerel kalıcı ayarlar (cihazda). `main()` içinde gerçek örnekle override edilir;
/// testlerde `SharedPreferences.setMockInitialValues({})` ile sağlanır.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
      'sharedPreferencesProvider main() içinde override edilmeli'),
);

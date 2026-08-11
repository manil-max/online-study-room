import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../repositories/exam_countdown_repository.dart';
import '../repositories/supabase/supabase_exam_countdown_repository.dart';
import 'auth_providers.dart';

/// WP-694 - geri sayimin sunucu ucu; **yoksa `null`**.
///
/// 🔴 `null` donmesi bir kacamak degil sozlesmedir: geri sayim buluttan once
/// vardi ve bulut olmadan da calismak **zorundadir**. Depo yoksa
/// `ExamListNotifier` yalnizca yerel kopyayi cizer; hicbir sey kirilmaz.
///
/// `Supabase.instance` baslatilmamisken (unit test, acilisin ilk karesi)
/// firlatir. Bu firlatma yutulur cunku alternatif, geri sayim kartinin
/// **cokmesi**dir - kullanicinin sinav tarihi, olmayan bir sunucu yuzunden
/// ekrandan silinemez.
final examCountdownRepositoryProvider = Provider<ExamCountdownRepository?>((
  ref,
) {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return SupabaseExamCountdownRepository(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

/// Senkronun kime ait oldugu. `null` = oturum yok -> yalnizca cihaz.
///
/// `authStateProvider` bir `StreamProvider`'dir; olusturucusu firlatirsa
/// `AsyncError` doner, **yeniden firlatmaz**. Bu yuzden burada `.value` okumak
/// baslatilmamis Supabase'de bile guvenlidir (`user_task_providers.dart:35`
/// ayni deseni kullanir).
final examCountdownUserIdProvider = Provider<String?>((ref) {
  final id = ref.watch(authStateProvider).value?.id;
  return (id == null || id.isEmpty) ? null : id;
});

/// Sinir asimindan **dusen** geri sayim sayisi.
///
/// Bu sayac olmasaydi kayip SESSIZ olurdu: iki cihaz cevrimdisiyken ayri ayri
/// sinav eklerse birlesme ucu asabilir ve fazlasi hicbir iz birakmadan yok
/// olurdu. Bu depoda sessiz veri kaybi tekrarlayan bir hata sinifidir.
final examCountdownDropProvider =
    NotifierProvider<ExamCountdownDropCounter, int>(
      ExamCountdownDropCounter.new,
    );

class ExamCountdownDropCounter extends Notifier<int> {
  @override
  int build() => 0;

  void bump(int count) => state = state + count;
}

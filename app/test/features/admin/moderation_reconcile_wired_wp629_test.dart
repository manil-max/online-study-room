// WP-629 — `admin_reconcile_moderation_sanctions()` YAZILMIŞ AMA ÇAĞIRANI YOKTU.
//
// `0105:355` fonksiyonu tanımlıyor, `0105:541` yetkisini veriyor, hatta
// `moderation_enforcement_wp441_test.dart:395` SQL metninde geçtiğini
// doğruluyor. Ama `lib/` içinde tek bir çağrı yeri yoktu — yani özellik yoktu.
//
// 🔴 Sonucu sessiz bir yarım durum: yaptırımın auth adımı geçip kapanış çağrısı
// düşünce satır sonsuza kadar `pending` kalır. `pending` satır **aktif yaptırım
// sayılmaz** (`isActive` yalnız `applied` kabul eder), yani:
//   * kullanıcı aslında cezasız gezer,
//   * admin cezayı uyguladığını sanır,
//   * hiç kimse hata görmez — çünkü hata yok, iş yarıda kaldı.
//
// Bu, deponun tekrarlayan "yazılmış ama çağıran yok" sınıfının bir örneği.
// Bu dosya hem kabloyu hem davranışı ölçer.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';

void main() {
  group('uzlaştırma kablosu', () {
    test('kuyruğu açmak uzlaştırmayı TETİKLER', () async {
      final repo = InMemoryAdminModerationRepository();
      expect(repo.reconcileCallCount, 0);

      await repo.fetchQueue();

      expect(
        repo.reconcileCallCount,
        1,
        reason:
            'Kuyruk açılışı uzlaştırmayı çağırmıyor: yarım kalmış yaptırımlar '
            'sonsuza kadar `pending` kalır ve kimse fark etmez.',
      );
    });

    test('15 dakikayı geçmiş `pending` yaptırım `failed`e kapanır', () async {
      final now = DateTime(2026, 8, 9, 12, 0);
      final repo = InMemoryAdminModerationRepository()..clock = () => now;

      final stale = repo.seedPendingSanction(
        targetUserId: 'user-stale',
        action: ModerationAction.suspend24h,
        openedAt: now.subtract(const Duration(minutes: 16)),
      );

      final closed = await repo.reconcileStaleSanctions();
      expect(closed, 1);

      final after = await repo.fetchSanctions('user-stale');
      final row = after.firstWhere((s) => s.id == stale.id);
      expect(row.state, ModerationSanctionState.failed);
      expect(
        row.failureReason,
        'reconciled_timeout',
        reason:
            'Kapanış sebebi yazılmazsa admin satırın neden düştüğünü göremez.',
      );
    });

    test('🔴 HENÜZ TAZE olan `pending` yaptırıma DOKUNULMAZ', () async {
      // Ters iddia. Bu olmadan "her `pending` satırı kapat" çözümü de geçerdi
      // ve o çözüm, auth tarafı hâlâ çalışırken cezayı iptal ederdi.
      final now = DateTime(2026, 8, 9, 12, 0);
      final repo = InMemoryAdminModerationRepository()..clock = () => now;

      final fresh = repo.seedPendingSanction(
        targetUserId: 'user-fresh',
        action: ModerationAction.suspend24h,
        openedAt: now.subtract(const Duration(minutes: 3)),
      );

      final closed = await repo.reconcileStaleSanctions();
      expect(closed, 0);

      final after = await repo.fetchSanctions('user-fresh');
      expect(
        after.firstWhere((s) => s.id == fresh.id).state,
        ModerationSanctionState.pending,
        reason:
            'Uzlaştırma daha koşmakta olan yaptırımı iptal ediyor: auth tarafı '
            'işini bitirdiğinde satır zaten `failed` olur.',
      );
    });
  });

  test('sunucu deposu RPC`yi GERÇEKTEN çağırıyor (kablo sözleşmesi)', () {
    // 🔴 Taklit depo yeşil olsa da asıl yol kopuk olabilir — bu deponun
    // tekrarlayan hatası tam olarak bu. Supabase yolu isimle doğrulanır.
    final source = File(
      'lib/data/repositories/supabase/supabase_admin_moderation_repository.dart',
    ).readAsStringSync();

    final code = source
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('//'))
        .join('\n');

    expect(
      code,
      // Biçimlendirmeye bağlanmaz: `dart format` satırı birleştirebilir.
      contains("'admin_reconcile_moderation_sanctions'"),
      reason: 'Sunucu deposu uzlaştırma RPC`sini çağırmıyor.',
    );

    final queueStart = code.indexOf('Future<List<ModerationCase>> fetchQueue()');
    expect(queueStart, isNonNegative);
    final queueBody = code.substring(queueStart, queueStart + 500);
    expect(
      queueBody,
      contains('reconcileStaleSanctions()'),
      reason:
          'Kuyruk açılışı uzlaştırmayı tetiklemiyor: fonksiyonun tek doğal '
          'tetiği bu (`is_super_admin` istediği için cron ile koşamaz).',
    );
  });
}

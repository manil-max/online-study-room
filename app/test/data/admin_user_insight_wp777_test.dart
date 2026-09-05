import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_insight.dart';

/// WP-777 — `admin_user_insight` RPC'sinin **iki ucu** arasindaki sozlesme.
///
/// 🔴 Bu depoda bir ozellik tam da burada sessizce olmustu: sunucu bir sey
/// yaziyor, istemci baska bir anahtar okuyor, hicbir kapi kirmizi olmuyor ve
/// ekran sifir gosteriyordu. Bu yuzden dosya iki isi birden yapar:
///
///   1. `AdminUserInsight.fromWire` cozumlemesini SQL'in **gercekten**
///      dondurdugu jsonb ornegi uzerinde olcer,
///   2. `0137_admin_user_insight.sql` dosyasini okuyup modelin bekledigi her
///      anahtarin sunucuda gercekten uretildigini dogrular.
///
/// Yalniz (1) yazilsaydi, SQL'de bir anahtar yeniden adlandirildiginda test
/// yesil kalirdi — cunku fikstur de elle yazilmis olurdu.
void main() {
  // SQL'in dondurdugu nesnenin BIREBIR ornegi: `jsonb_build_object` sayilari
  // JSON sayisi, `timestamptz`leri ISO-8601 metni, `text[]`i JSON dizisi yapar.
  Map<String, dynamic> wire() => <String, dynamic>{
    'user_id': '10000000-0000-0000-0000-000000000001',
    'reports_against': 7,
    'reports_against_upheld': 3,
    'reports_filed': 4,
    'reports_filed_upheld': 1,
    'display_name': 'Fixture Alpha',
    'email': 'fixture-alpha@example.invalid',
    'account_created_at': '2026-03-01T09:15:00+00:00',
    'last_seen_at': '2026-09-01T18:40:00+00:00',
    'total_study_seconds': 54000,
    'current_streak_days': 12,
    'group_names': <String>['Recovery Fixture Group', 'Sabah Kampi'],
    'is_deleted': false,
  };

  group('fromWire — sunucunun gercek jsonb sekli', () {
    test('tam nesne bire bir cozulur', () {
      final insight = AdminUserInsight.fromWire(wire());

      expect(insight.userId, '10000000-0000-0000-0000-000000000001');
      expect(insight.reportsAgainst, 7);
      expect(insight.reportsAgainstUpheld, 3);
      expect(insight.reportsFiled, 4);
      expect(insight.reportsFiledUpheld, 1);
      expect(insight.displayName, 'Fixture Alpha');
      expect(insight.email, 'fixture-alpha@example.invalid');
      expect(insight.totalStudySeconds, 54000);
      expect(insight.currentStreakDays, 12);
      expect(insight.groupNames, ['Recovery Fixture Group', 'Sabah Kampi']);
      expect(insight.isDeleted, isFalse);

      // Yerel saate cevriliyor; iddia saat diliminden bagimsiz olsun diye
      // UTC'ye geri dondurulerek olculur.
      expect(
        insight.accountCreatedAt?.toUtc(),
        DateTime.utc(2026, 3, 1, 9, 15),
      );
      expect(insight.lastSeenAt?.toUtc(), DateTime.utc(2026, 9, 1, 18, 40));
    });

    test('bos nesne cokmez, guvenli varsayilanlara duser', () {
      final insight = AdminUserInsight.fromWire(const {});

      expect(insight.userId, '');
      expect(insight.reportsAgainst, 0);
      expect(insight.reportsFiled, 0);
      expect(insight.displayName, isNull);
      expect(insight.email, isNull);
      expect(insight.accountCreatedAt, isNull);
      expect(insight.lastSeenAt, isNull);
      expect(insight.totalStudySeconds, 0);
      expect(insight.currentStreakDays, 0);
      expect(insight.groupNames, isEmpty);
      expect(insight.isDeleted, isFalse);
    });

    test('purge edilmis hesap: adlar null, is_deleted true', () {
      // SQL bu satiri `auth.users` satiri yokken uretir: `display_name`,
      // `email` ve tarihler NULL doner ama sikayet gecmisi DURUR — moderator
      // dosyayi yine de acabilmelidir.
      final insight = AdminUserInsight.fromWire({
        ...wire(),
        'display_name': null,
        'email': null,
        'account_created_at': null,
        'last_seen_at': null,
        'group_names': <String>[],
        'is_deleted': true,
      });

      expect(insight.isDeleted, isTrue);
      expect(insight.displayName, isNull);
      expect(insight.accountCreatedAt, isNull);
      expect(insight.groupNames, isEmpty);
      // Silinmis olmasi sayilari silmez.
      expect(insight.reportsAgainst, 7);
    });

    test('sayi metin olarak gelirse yine sayi olarak okunur', () {
      final insight = AdminUserInsight.fromWire({
        ...wire(),
        'reports_against': '7',
        'reports_against_upheld': '3',
        'total_study_seconds': '54000',
        'current_streak_days': 12.0,
      });

      expect(insight.reportsAgainst, 7);
      expect(insight.reportsAgainstUpheld, 3);
      expect(insight.totalStudySeconds, 54000);
      expect(insight.currentStreakDays, 12);
    });

    test('bozuk tarih cokme degil null uretir', () {
      final insight = AdminUserInsight.fromWire({
        ...wire(),
        'account_created_at': 'not-a-date',
        'last_seen_at': 42,
      });

      expect(insight.accountCreatedAt, isNull);
      expect(insight.lastSeenAt, isNull);
    });

    test('group_names karisik tipte gelse bile metne cevrilir', () {
      final insight = AdminUserInsight.fromWire({
        ...wire(),
        'group_names': <Object>['Kamp', 7],
      });

      expect(insight.groupNames, ['Kamp', '7']);
    });
  });

  group('oranlar — null ile 0.0 AYRI teshistir', () {
    test('hic sikayet yoksa oran null (olculmemis)', () {
      final insight = AdminUserInsight.fromWire({
        ...wire(),
        'reports_against': 0,
        'reports_against_upheld': 0,
        'reports_filed': 0,
        'reports_filed_upheld': 0,
      });

      expect(insight.upheldAgainstRatio, isNull);
      expect(insight.upheldFiledRatio, isNull);
    });

    test('bes sikayet, hicbiri tutmadiysa oran 0.0 (olculdu, sifir cikti)', () {
      final insight = AdminUserInsight.fromWire({
        ...wire(),
        'reports_against': 5,
        'reports_against_upheld': 0,
        'reports_filed': 5,
        'reports_filed_upheld': 0,
      });

      // 🔴 Kritik ayrim: bu kullanici hedef aliniyor olabilir. `null`'a
      // yuvarlamak onu "hic sikayet edilmemis" gibi gosterirdi.
      expect(insight.upheldAgainstRatio, 0.0);
      expect(insight.upheldAgainstRatio, isNotNull);
      expect(insight.upheldFiledRatio, 0.0);
    });

    test('kismi oran dogru hesaplanir', () {
      final insight = AdminUserInsight.fromWire(wire());
      expect(insight.upheldAgainstRatio, closeTo(3 / 7, 1e-9));
      expect(insight.upheldFiledRatio, closeTo(1 / 4, 1e-9));
    });
  });

  group('uyari isaretleri', () {
    test('tekrar eden ve cogunlukla hakli cikan oruntu isaretlenir', () {
      final flagged = AdminUserInsight.fromWire({
        ...wire(),
        'reports_against': 5,
        'reports_against_upheld': 3,
      });
      expect(flagged.flaggedAsOffender, isTrue);
    });

    test('tek tuk hakli cikan sikayet damgalamaz', () {
      // Iki hakli sikayet esigi gecmez; cok sikayet alip cogu tutmayan da.
      expect(
        AdminUserInsight.fromWire({
          ...wire(),
          'reports_against': 2,
          'reports_against_upheld': 2,
        }).flaggedAsOffender,
        isFalse,
      );
      expect(
        AdminUserInsight.fromWire({
          ...wire(),
          'reports_against': 7,
          'reports_against_upheld': 3,
        }).flaggedAsOffender,
        isFalse,
      );
    });

    test('cok sikayet edip tutturamayan raporlayici isaretlenir', () {
      expect(
        AdminUserInsight.fromWire({
          ...wire(),
          'reports_filed': 5,
          'reports_filed_upheld': 1,
        }).flaggedAsAbusiveReporter,
        isTrue,
      );
      expect(
        AdminUserInsight.fromWire({
          ...wire(),
          'reports_filed': 4,
          'reports_filed_upheld': 2,
        }).flaggedAsAbusiveReporter,
        isFalse,
      );
    });
  });

  test('accountAgeDays sureyi olcer, bilinmiyorsa null', () {
    final insight = AdminUserInsight.fromWire(wire());
    expect(
      insight.accountAgeDays(now: DateTime.utc(2026, 3, 31, 9, 15)),
      30,
    );
    expect(
      AdminUserInsight.fromWire({
        ...wire(),
        'account_created_at': null,
      }).accountAgeDays(now: DateTime.utc(2026, 3, 31)),
      isNull,
    );
  });

  group('0137 migration sozlesmesi — sunucu bu anahtarlari GERCEKTEN uretiyor',
      () {
    final migration = File(
      '../supabase/migrations/0137_admin_user_insight.sql',
    ).readAsStringSync();

    // 🔴 Iddialar YORUMA degil KODA bakmalidir. Dosyanin basindaki aciklama
    // blogu, bilerek, var olmayan `target_user_id` kolonunun adini geciyor;
    // ham metinde arayan bir iddia bunu "kolon kullaniliyor" sanip yanlis
    // kirmizi verir (ilk kosuda tam bunu yapti). Tam satir yorumlari atilir.
    final code = migration
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n');

    test('modelin okudugu her anahtar jsonb_build_object icinde var', () {
      // Liste `AdminUserInsight.fromWire` govdesinden birebir alindi.
      const keys = <String>[
        'user_id',
        'reports_against',
        'reports_against_upheld',
        'reports_filed',
        'reports_filed_upheld',
        'display_name',
        'email',
        'account_created_at',
        'last_seen_at',
        'total_study_seconds',
        'current_streak_days',
        'group_names',
        'is_deleted',
      ];
      for (final key in keys) {
        expect(
          code.contains("'$key',"),
          isTrue,
          reason:
              "0137 '$key' anahtarini uretmiyor; ekran bu alanda sessizce "
              'sifir gosterir.',
        );
      }
    });

    test('super-admin kapisi var', () {
      // pgTAP 035 her `public.admin_*` fonksiyonunun bu kapiyi tasidigini
      // ayrica supurur; burada dosya duzeyinde de sabitlenir.
      expect(code.contains('is_super_admin()'), isTrue);
      expect(code.contains('not_super_admin'), isTrue);
    });

    test('olmayan bir kolona dayanmiyor', () {
      // `ugc_reports.target_user_id` YOKTUR; fonksiyonun tum degeri hedefi
      // cozumlemesinden gelir.
      expect(code.contains('target_user_id'), isFalse);
      // Mesaj yazari `user_id`'dir (0015), `author_id` degil.
      expect(code.contains('m.user_id = p_user_id'), isTrue);
    });

    test('text -> uuid cevrimi korumali; korumasiz tek bir cast bile yok', () {
      expect(
        code.contains(
          r"'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'",
        ),
        isTrue,
        reason: 'Guvenli cevrim koruyucusu kaldirilmis.',
      );
      // Tek cast vardir ve `case` icindedir. Ikinci bir cast eklenirse bu sayi
      // degisir ve bozuk `target_id` yeniden butun RPC'yi dusurebilir.
      expect(
        'target_id::uuid'.allMatches(code).length,
        1,
        reason: 'Korumasiz ikinci bir target_id cast eklenmis olabilir.',
      );
    });

    test('grup hedefi kullaniciya sayilmaz, kullanici/profil sayilir', () {
      expect(code.contains("in ('user', 'profile')"), isTrue);
      expect(code.contains("x.target_type = 'message'"), isTrue);
    });

    test("hakli cikan 'resolved' ile olculur, 'rejected' ile degil", () {
      // 0105'teki `admin_reporter_abuse_score` `rejected` sayar; bu sozlesme
      // `resolved` sayar. Ikisini karistirmak open/in_review vakalari haksiz
      // saydirirdi.
      expect(code.contains("effective_status = 'resolved'"), isTrue);
      expect(code.contains("effective_status = 'rejected'"), isFalse);
    });
  });
}

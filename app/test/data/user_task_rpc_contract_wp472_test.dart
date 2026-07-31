// WP-472 — Dart ↔ SQL iki uçlu RPC sözleşmesi.
//
// 🔴 Bu dosya kartın kapanış şartıdır. Sebebi somut: WP-449/450 istemciye
// `p_interval_days`, `p_anchor_date` ve `p_occurrence_day` gönderten kodu
// indirdi, ama sunucuda bu parametreler yoktu (`0048` tek tanımdı). Test
// yalnız `InMemoryUserTaskRepository`yi çalıştırdığı için kopukluk yeşil
// kapıların arkasında saklandı; sahadaki her görev yazımı PostgREST'ten
// `PGRST202` alırdı. Aynı sessiz kopukluk timer-sync'te bir kez sahaya çıktı.
//
// Test iki ucu da GERÇEK kaynaktan okur:
//   * Dart ucu → `SupabaseUserTaskRepository.upsertParams` /
//     `completionParams` (RPC çağrısının kendi kullandığı fonksiyonlar),
//   * SQL ucu → `supabase/migrations/*.sql` içindeki canlı imza.
// Tek uçta yapılan değişiklik diğerini kırar; sabit bir liste kopyalanmaz.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_user_task_repository.dart';

/// `supabase/migrations` içindeki tüm SQL, migration sırasına göre birleştirilmiş.
///
/// Sıra önemlidir: aynı fonksiyonun birden çok tanımı varsa geçerli olan
/// **son** migration'daki tanımdır, replay de bu sırayla uygular.
String _migrations() {
  final dir = Directory('../supabase/migrations');
  expect(dir.existsSync(), isTrue, reason: 'migration dizini bulunamadı');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.sql'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return files
      .map((file) => file.readAsStringSync().replaceAll('\r\n', '\n'))
      .join('\n');
}

/// Bir SQL fonksiyonunun **son** tanımındaki parametre adları, bildirim sırasıyla.
List<String> _sqlParameters(String functionName) {
  final sql = _migrations();
  final header = RegExp(
    'create or replace function public\\.$functionName\\s*\\(',
    caseSensitive: false,
  );
  final matches = header.allMatches(sql).toList();
  expect(
    matches,
    isNotEmpty,
    reason: '$functionName hiçbir migration\'da tanımlı değil',
  );

  // Parametre listesini parantez dengeleyerek al; `default` ifadeleri iç içe
  // parantez taşıyabilir.
  final start = matches.last.end;
  var depth = 1;
  var index = start;
  while (index < sql.length && depth > 0) {
    if (sql[index] == '(') depth += 1;
    if (sql[index] == ')') depth -= 1;
    index += 1;
  }
  expect(depth, 0, reason: '$functionName imzası kapanmıyor');

  final body = sql.substring(start, index - 1);
  return RegExp(r'(^|,)\s*(p_[a-z0-9_]+)', multiLine: true)
      .allMatches(body)
      .map((match) => match.group(2)!)
      .toList(growable: false);
}

/// Varsayılan değeri olan parametreler — sahadaki v56 istemcisi bunları
/// göndermez, dolayısıyla hepsi `default` taşımak zorundadır.
Set<String> _sqlDefaultedParameters(String functionName) {
  final sql = _migrations();
  final header = RegExp(
    'create or replace function public\\.$functionName\\s*\\(',
    caseSensitive: false,
  );
  final start = header.allMatches(sql).last.end;
  var depth = 1;
  var index = start;
  while (index < sql.length && depth > 0) {
    if (sql[index] == '(') depth += 1;
    if (sql[index] == ')') depth -= 1;
    index += 1;
  }
  final body = sql.substring(start, index - 1);
  return RegExp(
    r'(p_[a-z0-9_]+)[^,]*\bdefault\b',
    caseSensitive: false,
  ).allMatches(body).map((match) => match.group(1)!).toSet();
}

UserTask _recurringTask() => UserTask(
  id: 'aa000000-0000-4000-8000-000000000001',
  title: 'Üç günde bir tekrar',
  completed: false,
  createdAt: DateTime.utc(2026, 7, 1, 6),
  sortOrder: 0,
  recurrence: UserTaskRecurrence.daily,
  intervalDays: 3,
  anchorDate: DateTime(2026, 7, 1),
);

void main() {
  group('upsert_user_task', () {
    test('Dart\'ın gönderdiği her parametre SQL imzasında var', () {
      final sent = SupabaseUserTaskRepository.upsertParams(
        task: _recurringTask(),
        operationId: 'bb000000-0000-4000-8000-000000000001',
        archived: false,
      ).keys.toSet();
      final declared = _sqlParameters('upsert_user_task').toSet();

      expect(
        sent.difference(declared),
        isEmpty,
        reason: 'istemci sunucuda olmayan parametre gönderiyor (PGRST202)',
      );
      expect(
        declared.difference(sent),
        isEmpty,
        reason: 'sunucu istemcinin doldurmadığı parametre bekliyor',
      );
    });

    test('tekrar alanları imzada gerçekten var', () {
      final declared = _sqlParameters('upsert_user_task');
      expect(declared, containsAll(<String>['p_interval_days', 'p_anchor_date']));
    });

    test('WP-449 alanları varsayılanlı — v56 istemcisi kırılmaz', () {
      expect(
        _sqlDefaultedParameters('upsert_user_task'),
        containsAll(<String>['p_interval_days', 'p_anchor_date']),
      );
    });

    test('eski 7 parametreli imza düşürülmüş (42725 belirsizliği yok)', () {
      expect(
        _migrations().contains(
          'drop function if exists public.upsert_user_task('
          'uuid, text, timestamptz, text, integer, boolean, uuid)',
        ),
        isTrue,
        reason:
            'varsayılanlı yeni imza eski imzayla birlikte adaydır; '
            'PostgREST adlandırılmış çağrıyı çözemez',
      );
    });
  });

  group('set_user_task_completion', () {
    test('Dart\'ın gönderdiği her parametre SQL imzasında var', () {
      final sent = SupabaseUserTaskRepository.completionParams(
        taskId: 'aa000000-0000-4000-8000-000000000001',
        completed: true,
        occurredAt: DateTime.utc(2026, 7, 7, 9),
        occurrenceDay: DateTime(2026, 7, 7),
        operationId: 'bb000000-0000-4000-8000-000000000002',
      ).keys.toSet();
      final declared = _sqlParameters('set_user_task_completion').toSet();

      expect(sent.difference(declared), isEmpty);
      expect(declared.difference(sent), isEmpty);
    });

    test('p_occurrence_day varsayılanlı ve imzanın sonunda', () {
      final declared = _sqlParameters('set_user_task_completion');
      expect(declared.last, 'p_occurrence_day');
      expect(
        _sqlDefaultedParameters('set_user_task_completion'),
        contains('p_occurrence_day'),
      );
    });

    test('eski 4 parametreli imza düşürülmüş', () {
      expect(
        _migrations().contains(
          'drop function if exists public.set_user_task_completion('
          'uuid, boolean, timestamptz, uuid)',
        ),
        isTrue,
      );
    });
  });

  group('list_user_tasks projeksiyonu', () {
    test('model\'in okuduğu snake_case kolonlar sunucudan dönüyor', () {
      final sql = _migrations();
      final start = sql.lastIndexOf(
        'create or replace function public.list_user_tasks()',
      );
      expect(start, greaterThan(-1));
      final signature = sql.substring(start, sql.indexOf('\$\$', start));

      // `UserTask.fromMap` bu adları okur; biri eksikse alan sessizce
      // varsayılana düşer ve tekrar döngüsü istemcide bozulur.
      for (final column in <String>[
        'interval_days',
        'anchor_date',
        'completion_day',
        'recurrence',
      ]) {
        expect(
          signature.contains(column),
          isTrue,
          reason: 'list_user_tasks $column döndürmüyor',
        );
      }
    });

    test('dönen satır UserTask.fromMap ile tekrar fazına çevrilebiliyor', () {
      final row = <String, dynamic>{
        'id': 'aa000000-0000-4000-8000-000000000001',
        'title': 'Üç günde bir tekrar',
        'recurrence': 'daily',
        'interval_days': 3,
        'anchor_date': '2026-07-01',
        'sort_order': 0,
        'completed': false,
        'created_at': '2026-07-01T06:00:00Z',
      };
      final task = UserTask.fromMap(row);

      expect(task.intervalDays, 3);
      expect(task.anchorDate, DateTime(2026, 7, 1));
      expect(task.isRecurring, isTrue);
      expect(
        task.isDaily,
        isFalse,
        reason: 'interval 3 olan görev "günlük" sayılmamalı',
      );
    });
  });
}

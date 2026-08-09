import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _listenerFile = 'lib/data/providers/device_integration_listener.dart';
const _notifierFile = 'lib/data/providers/study_providers.dart';

/// Ekranda gerçekten düğmesi olan yüzeyler — varsayılan `user_button` damgasını
/// hak eden tek küme. Buraya bir dosya eklemek, WP-599'un kapattığı açığı geri
/// açmak demektir; bilinçli bir karar olmalı.
const _userSurfaces = <String>{
  'lib/features/classroom/widgets/study_timer_card.dart',
  'lib/features/classroom/widgets/focus_timer_screen.dart',
  'lib/features/desktop/compact_focus_view.dart',
};

/// WP-599 — SÖZLEŞME: `StudyTimerNotifier.start` / `.stop` çağıran her yol,
/// günlüğe **ayırt edilebilir bir kaynak** yazmak zorundadır.
///
/// 🔴 Neden kaynak taraması: davranış testi yalnız BİLDİĞİ yolları ölçer. Bu
/// repoda tekrarlanan hata "kural yazılıydı ama çağıran yoktu"
/// (`docs/analiz/WP-595-sayac-xp-teshis.md`): `start()` yorumu "her başlatmanın
/// görülebilir bir kaynağı olmalı" diyordu, cihaz entegrasyonu o kuralın
/// dışındaydı ve kimse fark etmedi. Bu test kuralı **çağıran yerlerin
/// listesine** bağlar.
///
/// Kural iki maddedir:
///   1. Parmak yüzeyleri ([_userSurfaces]) `trigger:` yazmaz — varsayılan
///      zaten `user_button`.
///   2. Başka HER çağrı yeri `trigger:` yazmak ZORUNDADIR.
void main() {
  final sites = _scanCallSites();

  test('tarayici gercekten kod goruyor (bos tarama = hep yesil test)', () {
    // Bu iddia olmadan, bozulan bir regex sözleşmeyi sessizce etkisizleştirir.
    expect(
      sites,
      isNotEmpty,
      reason: 'lib/ icinde tek bir sayac start/stop cagrisi bile bulunamadi',
    );
    for (final surface in _userSurfaces) {
      expect(
        sites.where((site) => site.file == surface),
        isNotEmpty,
        reason: '$surface artik sayaci baslatmiyorsa listeden cikarilmali',
      );
    }
    expect(
      sites.where((site) => site.file == _listenerFile).length,
      5,
      reason:
          'cihaz entegrasyonu 5 sayac cagrisi yapar (START_TIMER / STOP_TIMER / '
          'START_POMODORO / START_STOPWATCH / TAKE_BREAK)',
    );
    expect(
      sites.where((site) => site.file == _notifierFile),
      isNotEmpty,
      reason: 'bildirim/widget kuyrugunun sinif ici cagrisi da taranmali',
    );
  });

  test('start/stop cagiran her yol kaynagini gunluge yazar', () {
    final ihlaller = [
      for (final site in sites)
        if (!site.declaresTrigger && !_userSurfaces.contains(site.file)) site,
    ];
    expect(
      ihlaller,
      isEmpty,
      reason:
          'Bu cagri yerleri sayaci baslatiyor/durduruyor ama gunluge kaynak '
          'yazmiyor. TimerJournalTriggers ile bir trigger: gec, ya da gercekten '
          'parmakla basilan bir yuzeyse _userSurfaces listesine ekle:\n'
          '${ihlaller.map((site) => '  - $site').join('\n')}',
    );
  });

  test('cihaz entegrasyonunun bes cagrisinin besi de kaynak yazar', () {
    final device = sites.where((site) => site.file == _listenerFile);
    for (final site in device) {
      expect(
        site.declaresTrigger,
        isTrue,
        reason: '$site — Samsung Routine baslatmasi parmakla es yazilamaz',
      );
    }
  });

  test('parmak yuzeyleri cihaz damgasi yapistirmaz', () {
    for (final site in sites.where(
      (site) => _userSurfaces.contains(site.file),
    )) {
      expect(
        site.declaresDeviceTrigger,
        isFalse,
        reason: '$site — ekran dugmesi cihaz damgasi yazamaz',
      );
    }
  });
}

/// Bir `start` / `stop` çağrı yeri.
class _CallSite {
  _CallSite({
    required this.file,
    required this.line,
    required this.method,
    required this.args,
  });

  final String file;
  final int line;
  final String method;

  /// Çağrının argümanları; tear-off (`notifier.start,`) ise `null`.
  final String? args;

  bool get declaresTrigger => args?.contains('trigger:') ?? false;

  bool get declaresDeviceTrigger {
    final text = args;
    if (text == null) return false;
    return text.contains('TimerJournalTriggers.deviceIntegration') ||
        text.contains('deviceIntegrationTrigger');
  }

  @override
  String toString() => '$file:$line ($method)';
}

/// Yorum ve dize içeriğini **indeksleri koruyarak** boşlukla değiştirir.
///
/// Gerekli, çünkü `study_providers.dart` yorumlarında birebir `stop()` geçiyor
/// (satır ~1882); ham tarama onu çağrı sanardı.
String _blankNonCode(String source) {
  const backslash = '\\';
  final chars = source.split('');
  var index = 0;

  void blank(int at) {
    if (chars[at] != '\n') chars[at] = ' ';
  }

  while (index < source.length) {
    final current = source[index];
    final next = index + 1 < source.length ? source[index + 1] : '';
    if (current == '/' && next == '/') {
      while (index < source.length && source[index] != '\n') {
        blank(index);
        index++;
      }
      continue;
    }
    if (current == '/' && next == '*') {
      while (index + 1 < source.length &&
          !(source[index] == '*' && source[index + 1] == '/')) {
        blank(index);
        index++;
      }
      if (index < source.length) blank(index++);
      if (index < source.length) blank(index++);
      continue;
    }
    if (current == "'" || current == '"') {
      final quote = current;
      blank(index);
      index++;
      while (index < source.length) {
        if (source[index] == backslash) {
          blank(index);
          index++;
          if (index < source.length) blank(index++);
          continue;
        }
        if (source[index] == quote) {
          blank(index);
          index++;
          break;
        }
        // Tek satırlık dize varsayımı: kapanmadan satır bitiyorsa bırak.
        if (source[index] == '\n') break;
        blank(index);
        index++;
      }
      continue;
    }
    index++;
  }
  return chars.join();
}

/// `(` konumundan başlayarak eşleşen `)`'e kadarki argüman metni.
String? _argsAt(String source, int openParen) {
  var depth = 0;
  for (var i = openParen; i < source.length; i++) {
    final char = source[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) return source.substring(openParen + 1, i);
    }
  }
  return null;
}

int _lineOf(String source, int index) =>
    '\n'.allMatches(source.substring(0, index)).length + 1;

/// `.start` / `.stop`'un alıcısı sayaç notifier'ı mı.
///
/// Sırf "yakında bir yerde notifier geçiyor" demek yetmez: `stats_period_bar`
/// içindeki `ref.read(statsPeriodProvider.notifier).setCustomRange(range.start,
/// …)` satırı böyle bir gevşek ölçütle yanlışlıkla yakalanıyordu. Alıcı ya
/// `...notifier` biçiminde bir tanımlayıcı olmalı, ya da
/// `ref.read(studyTimerProvider.notifier)` çağrısının kapanış parantezi.
///
/// Bilinen sınır: `final t = ref.read(studyTimerProvider.notifier); t.start();`
/// biçimi yakalanmaz. Repodaki tüm çağrı yerleri `notifier` adını kullanıyor;
/// bu kalıp benimsenirse ölçüt burada genişletilmeli.
bool _isTimerNotifierReceiver(String code, int dotIndex) {
  var index = dotIndex - 1;
  if (index < 0) return false;
  if (code[index] == ')') {
    final from = dotIndex - 120 < 0 ? 0 : dotIndex - 120;
    return code
        .substring(from, dotIndex)
        .contains('studyTimerProvider.notifier');
  }
  final identifier = StringBuffer();
  while (index >= 0 && RegExp(r'[A-Za-z0-9_$]').hasMatch(code[index])) {
    identifier.write(code[index]);
    index--;
  }
  // Ters yazıldı: `notifier` → `reifiton`.
  return identifier.toString().toLowerCase().startsWith('reifiton');
}

/// `(`'e kadar boşluk atlar; çağrı değilse (tear-off) `null` döner.
int? _openParenAfter(String source, int from) {
  var index = from;
  while (index < source.length &&
      (source[index] == ' ' || source[index] == '\n')) {
    index++;
  }
  return (index < source.length && source[index] == '(') ? index : null;
}

List<_CallSite> _scanCallSites() {
  final sites = <_CallSite>[];
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  for (final file in files) {
    final path = file.path.replaceAll('\\', '/');
    final code = _blankNonCode(
      file.readAsStringSync().replaceAll('\r\n', '\n'),
    );

    // (a) Alıcı üzerinden çağrı: `notifier.start(...)`, tear-off,
    //     `ref.read(studyTimerProvider.notifier).stop()`.
    for (final match in RegExp(r'\.(start|stop)\b').allMatches(code)) {
      if (!_isTimerNotifierReceiver(code, match.start)) continue;
      final open = _openParenAfter(code, match.end);
      sites.add(
        _CallSite(
          file: path,
          line: _lineOf(code, match.start),
          method: match.group(1)!,
          args: open == null ? null : _argsAt(code, open),
        ),
      );
    }

    // (b) Sınıf içi çıplak çağrı — yalnız notifier'ın kendi dosyasında anlamlı.
    //     Bildirim/widget kuyruğu `start()`'ı buradan çağırır.
    if (path != _notifierFile && !path.endsWith('/$_notifierFile')) continue;
    for (final match in RegExp(r'\b(start|stop)\s*\(').allMatches(code)) {
      if (match.start > 0 && code[match.start - 1] == '.') continue;
      final lineStart = code.lastIndexOf('\n', match.start) + 1;
      final before = code.substring(lineStart, match.start);
      // Bildirim satırı (`void start(`, `Future<void> stop(`) çağrı değildir.
      if (RegExp(r'(?:void|Future<[^>]*>)\s+$').hasMatch(before)) continue;
      sites.add(
        _CallSite(
          file: path,
          line: _lineOf(code, match.start),
          method: match.group(1)!,
          args: _argsAt(code, code.indexOf('(', match.start)),
        ),
      );
    }
  }
  return sites;
}

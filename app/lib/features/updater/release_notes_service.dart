// Alan `_preferences` private, ama kurucu parametresi public adlı (`preferences:`)
// kalmalı — testler bu adla çağırıyor. Named parametre `_` ile başlayamayacağı
// için initializing formal burada uygulanamaz; lint bilinçli devre dışı.
// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama içi sürüm notlarının tek bundled kaynağı.
///
/// GitHub Release body boş olduğunda updater bu veriyi fallback olarak kullanır.
/// Açılıştaki "Yenilikler" penceresi de son görülen build numarasını bu servisle
/// takip eder.
///
/// Metinler TR varsayılan + isteğe bağlı `*En` alanları; [ReleaseNote.forLocale]
/// uygulama diline göre seçer (yalnız `tr` → TR, diğer → EN, EN yoksa TR).
class ReleaseNotesService {
  ReleaseNotesService({
    SharedPreferences? preferences,
    Future<String> Function(String path)? assetLoader,
    Future<PackageInfo> Function()? packageInfoLoader,
  }) : _preferences = preferences,
       _assetLoader = assetLoader ?? rootBundle.loadString,
       _packageInfoLoader = packageInfoLoader ?? PackageInfo.fromPlatform;

  static const assetPath = 'assets/release_notes.json';
  static const _kLastSeenBuild = 'release_notes_last_seen_build';

  final SharedPreferences? _preferences;
  final Future<String> Function(String path) _assetLoader;
  final Future<PackageInfo> Function() _packageInfoLoader;

  Future<List<ReleaseNote>> loadBundledNotes() async {
    final raw = await _assetLoader(assetPath);
    final decoded = jsonDecode(raw);
    final releases = decoded is Map<String, dynamic>
        ? decoded['releases']
        : null;
    if (releases is! List) return const [];

    final notes =
        releases
            .whereType<Map<String, dynamic>>()
            .map(ReleaseNote.fromJson)
            .toList()
          ..sort((a, b) => b.buildNumber.compareTo(a.buildNumber));
    return notes;
  }

  Future<ReleaseNote?> noteForBuild(int buildNumber, {String? channel}) async {
    final notes = await loadBundledNotes();
    for (final note in notes) {
      if (note.buildNumber != buildNumber) continue;
      if (channel != null && note.channel != channel) continue;
      return note;
    }
    for (final note in notes) {
      if (note.buildNumber == buildNumber) return note;
    }
    return null;
  }

  Future<CurrentReleaseState> currentReleaseState() async {
    final packageInfo = await _packageInfoLoader();
    final buildNumber = int.tryParse(packageInfo.buildNumber) ?? 0;
    final channel = const String.fromEnvironment(
      'CHANNEL',
      defaultValue: 'stable',
    );
    final note = await noteForBuild(buildNumber, channel: channel);
    return CurrentReleaseState(
      buildNumber: buildNumber,
      versionName: packageInfo.version,
      channel: channel,
      note: note,
    );
  }

  Future<bool> shouldShowWhatsNew({int? currentBuildNumber}) async {
    final buildNumber =
        currentBuildNumber ??
        (int.tryParse((await _packageInfoLoader()).buildNumber) ?? 0);
    if (buildNumber <= 0) return false;
    final prefs = await _prefs();
    final lastSeen = prefs.getInt(_kLastSeenBuild) ?? 0;
    return buildNumber > lastSeen;
  }

  Future<void> markBuildSeen(int buildNumber) async {
    if (buildNumber <= 0) return;
    await (await _prefs()).setInt(_kLastSeenBuild, buildNumber);
  }

  Future<void> markCurrentBuildSeen() async {
    final packageInfo = await _packageInfoLoader();
    await markBuildSeen(int.tryParse(packageInfo.buildNumber) ?? 0);
  }

  Future<SharedPreferences> _prefs() async =>
      _preferences ?? SharedPreferences.getInstance();
}

class CurrentReleaseState {
  const CurrentReleaseState({
    required this.buildNumber,
    required this.versionName,
    required this.channel,
    required this.note,
  });

  final int buildNumber;
  final String versionName;
  final String channel;
  final ReleaseNote? note;
}

class ReleaseNote {
  const ReleaseNote({
    required this.versionName,
    required this.buildNumber,
    required this.channel,
    required this.date,
    required this.title,
    required this.highlights,
    required this.fixes,
    required this.notes,
    this.titleEn = '',
    this.highlightsEn = const [],
    this.fixesEn = const [],
    this.notesEn = const [],
  });

  factory ReleaseNote.fromJson(Map<String, dynamic> json) {
    return ReleaseNote(
      versionName: _string(json['versionName']),
      buildNumber: _int(json['buildNumber']),
      channel: _string(json['channel'], fallback: 'stable'),
      date: _string(json['date']),
      title: _string(json['title']),
      highlights: _stringList(json['highlights']),
      fixes: _stringList(json['fixes']),
      notes: _stringList(json['notes']),
      titleEn: _string(json['titleEn']),
      highlightsEn: _stringList(json['highlightsEn']),
      fixesEn: _stringList(json['fixesEn']),
      notesEn: _stringList(json['notesEn']),
    );
  }

  final String versionName;
  final int buildNumber;
  final String channel;
  final String date;

  /// Türkçe (veya eski tek-dilli) metinler.
  final String title;
  final List<String> highlights;
  final List<String> fixes;
  final List<String> notes;

  /// İngilizce; boşsa [forLocale] TR'ye düşer.
  final String titleEn;
  final List<String> highlightsEn;
  final List<String> fixesEn;
  final List<String> notesEn;

  String get displayVersion =>
      '$versionName+$buildNumber ${channel == 'beta' ? 'Beta' : 'Stable'}';

  /// Yalnız sistem/uygulama dili `tr` ise Türkçe; aksi halde İngilizce
  /// (EN yoksa TR yedek).
  ReleaseNote forLocale(Locale locale) {
    final useTr = locale.languageCode == 'tr';
    if (useTr) {
      return this;
    }
    return ReleaseNote(
      versionName: versionName,
      buildNumber: buildNumber,
      channel: channel,
      date: date,
      title: titleEn.isNotEmpty ? titleEn : title,
      highlights: highlightsEn.isNotEmpty ? highlightsEn : highlights,
      fixes: fixesEn.isNotEmpty ? fixesEn : fixes,
      notes: notesEn.isNotEmpty ? notesEn : notes,
      titleEn: titleEn,
      highlightsEn: highlightsEn,
      fixesEn: fixesEn,
      notesEn: notesEn,
    );
  }

  String plainText({
    required String highlightsLabel,
    required String fixesLabel,
    required String notesLabel,
  }) {
    final buffer = StringBuffer();
    if (title.isNotEmpty) buffer.writeln(title);
    void section(String label, List<String> items) {
      if (items.isEmpty) return;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(label);
      for (final item in items) {
        buffer.writeln('• $item');
      }
    }

    section(highlightsLabel, highlights);
    section(fixesLabel, fixes);
    section(notesLabel, notes);
    return buffer.toString().trim();
  }

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  static int _int(Object? value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
}

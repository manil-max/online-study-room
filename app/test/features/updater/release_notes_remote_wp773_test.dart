import 'dart:io';

import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/updater/release_notes_service.dart';

/// WP-773 (sahip, cihazda, v77): guncelleme penceresinde "notlar kisminda
/// hicbir sey yok, sadece GitHub linki". GitHub Release govdesi otomatik
/// "Full Changelog" baglantisiydi; BOS olmadigi icin bundled not hic devreye
/// girmiyordu. Ustelik bundled not yeni surumun notunu ZATEN tasiyamaz:
/// pencere eski surumde kosar. Cozum, etiketin kendi `release_notes.json`u.
void main() {
  const json =
      '{"schemaVersion":2,"releases":[{"versionName":"1.0.78","buildNumber":78,'
      '"channel":"stable","date":"2026-09-06","title":"TR başlık",'
      '"highlights":["TR madde"],"fixes":[],"notes":[],"titleEn":"EN title",'
      '"highlightsEn":["EN item"],"fixesEn":[],"notesEn":[]}]}';

  test('raw dosya adresi etiketten kurulur', () {
    expect(
      ReleaseNotesService.rawNotesUrlForTag(' v78 ').toString(),
      'https://raw.githubusercontent.com/manil-max/online-study-room/v78/'
      'app/assets/release_notes.json',
    );
  });

  test('etiketin notu build numarasiyla bulunur ve dile gore secilir', () async {
    Uri? requested;
    final service = ReleaseNotesService(
      remoteLoader: (url) async {
        requested = url;
        return json;
      },
    );

    final note = await service.fetchNoteForTag(tag: 'v78', buildNumber: 78);

    expect(requested, ReleaseNotesService.rawNotesUrlForTag('v78'));
    expect(note, isNotNull);
    expect(note!.forLocale(const Locale('en')).title, 'EN title');
    expect(note.forLocale(const Locale('en')).highlights, ['EN item']);
    expect(note.forLocale(const Locale('tr')).title, 'TR başlık');
    expect(await service.fetchNoteForTag(tag: 'v78', buildNumber: 77), isNull);
  });

  test('ag ya da JSON hatasi SESSIZCE null: pencere not yuzunden dusmez',
      () async {
    final offline = ReleaseNotesService(
      remoteLoader: (_) async => throw const SocketException('offline'),
    );
    expect(await offline.fetchNoteForTag(tag: 'v78', buildNumber: 78), isNull);

    final garbage = ReleaseNotesService(remoteLoader: (_) async => 'not json');
    expect(await garbage.fetchNoteForTag(tag: 'v78', buildNumber: 78), isNull);

    final noRemote = ReleaseNotesService();
    expect(await noRemote.fetchNoteForTag(tag: 'v78', buildNumber: 78), isNull);

    final blankTag = ReleaseNotesService(remoteLoader: (_) async => json);
    expect(await blankTag.fetchNoteForTag(tag: '', buildNumber: 78), isNull);
  });

  test('pencere: once etiketin notu, sonra bundled, en son GitHub govdesi', () {
    final dialog = File(
      'lib/features/updater/updater_dialog.dart',
    ).readAsStringSync();
    final updater = File(
      'lib/features/updater/updater_service.dart',
    ).readAsStringSync();

    // Eski kapi: govde bos DEGILSE bundled nota hic inilmiyordu. Geri gelirse
    // kullanici yine yalniz "Full Changelog" linkini gorur.
    expect(dialog, isNot(contains('if (info.releaseNotes.trim().isEmpty)')));
    expect(dialog, contains('fetchNoteForTag('));
    expect(
      dialog.indexOf('fetchNoteForTag('),
      lessThan(dialog.indexOf('noteForBuild(')),
      reason: 'etiketin notu bundled nottan ONCE denenmeli',
    );
    expect(dialog, contains('note ??= await notesService.noteForBuild('));
    // Etiket GitHub cevabindan tasinir; onsuz ham dosya adresi kurulamaz.
    expect(updater, contains("tag: (data['tag_name'] as String? ?? '').trim()"));
  });
}

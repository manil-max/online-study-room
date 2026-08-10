import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/desktop/desktop_layout.dart';
import '../../core/desktop/desktop_window.dart';
import '../../core/l10n/app_locale.dart';
import '../../data/models/faq_entry.dart';
import '../../data/providers/auth_providers.dart';
import '../../data/providers/support_providers.dart';
import '../../data/repositories/in_memory/in_memory_support_repository.dart';
import '../../l10n/app_localizations.dart';

/// WP-683 — SSS okuma sütununun genişlik tavanı (SPEC §3 **A3**, §2.3).
///
/// 🔴 Türetildi, seçilmedi. SSS bir **prose** ekranıdır: cevaplar paragraftır.
/// SPEC §2.3 düz metni **600 px**'te tavanlar (80 karakter × 7.5 px, WCAG 2.1
/// SC 1.4.8) ve `DesktopSurface.readingWidth = 760`'ın prose için **yanlış**
/// olduğunu açıkça yazar (760 / 7.5 = 101 karakter). Cevap metni
/// `ExpansionTile`ın `childrenPadding`i (2 × 16 = 32) içinde durduğu için
/// kartın tavanı 600 + 32 = **632 px**'tir. 632, 4'ün katıdır.
///
/// 🔴 ÖLÇÜLEN KUSUR (WP-683 öncesi, `desktop_wp683_screens_test.dart`):
/// en geniş kart 1008'de 976 px, 1200'de 1168, 1920'de **1888**, 2560'ta
/// **2528 px**; açık bir cevabın boyanan metni 2560'ta 1386 px.
/// Bu ekranın iki çağrı yeri var ve **yalnız biri** panelin içinde:
/// `settings_screen.dart:515` (920 px panel) ve `auth_screen.dart:446`
/// (oturum açmadan, **tam pencere**). İkincisinde satır gerçekten pencereyle
/// birlikte büyüyordu.
///
/// SSS metni sunucudan gelir ve çevrimdışı yedeği vardır; WP-683 **yalnız
/// düzeni** değiştirdi, tek bir cümleye dokunmadı (SPEC §7).
const double kFaqReadingMaxWidth = DesktopBreakpoints.maxProseWidth + 32;

class FaqScreen extends ConsumerStatefulWidget {
  const FaqScreen({super.key});

  @override
  ConsumerState<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends ConsumerState<FaqScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(faqEntriesProvider);
    final isSignedIn = ref.watch(authStateProvider).value != null;
    // WP-526: cevrimdisi yedek liste de ARAYUZUN dilini izlemeli. Eski kod
    // tercihi okuyup `system`'i Turkce sayiyordu.
    final locale = ref.watch(contentLanguageCodeProvider);
    final serverEntries = switch (entries) {
      AsyncData(:final value) => value,
      _ => null,
    };
    final fallback = entries.hasError;
    final visible = _filter(
      serverEntries ??
          kFallbackFaq.where((entry) => entry.locale == locale).toList(),
    );

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: l10n.faqSearch,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        if (fallback)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.faqOfflineFallback,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        Expanded(
          child: entries.isLoading && serverEntries == null
              ? const Center(child: CircularProgressIndicator())
              : visible.isEmpty
              ? Center(child: Text(l10n.faqNoResults))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final entry = visible[index];
                    return Card(
                      child: ExpansionTile(
                        title: Text(entry.question),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(entry.answer),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: () => isSignedIn ? _askQuestion() : _showLoginRequired(),
            icon: const Icon(Icons.question_answer_outlined),
            label: Text(l10n.faqAskQuestion),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.faqTitle)),
      // Mobilde `body` olduğu gibi geçer: ağaca tek bir düğüm eklenmez.
      body: !isDesktopWindow
          ? body
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kFaqReadingMaxWidth,
                ),
                child: body,
              ),
            ),
    );
  }

  List<FaqEntry> _filter(List<FaqEntry> entries) {
    final query = _query.toLowerCase();
    if (query.isEmpty) return entries;
    return entries
        .where(
          (entry) =>
              '${entry.question} ${entry.answer}'.toLowerCase().contains(query),
        )
        .toList();
  }

  Future<void> _showLoginRequired() async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.faqLoginRequired)));
  }

  /// Galeriden tek foto seçer. Asıl boyut/tür kapısı sunucudadır (`0096`);
  /// buradaki eleme yalnız boşa yükleme yapmamak için.
  Future<(Uint8List, String)?> _pickSupportImage() async {
    final l10n = AppLocalizations.of(context);
    try {
      final xFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (xFile == null) return null;
      final bytes = await xFile.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.profileDosyaBoyutu5mbdanKucuk)),
          );
        }
        return null;
      }
      var ext = xFile.name.split('.').last.toLowerCase();
      if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(ext)) ext = 'jpg';
      return (bytes, ext);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileResimSecilemedi)));
      }
      return null;
    }
  }

  Future<void> _askQuestion() async {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context);
    // WP-423: soruya tek ve opsiyonel foto eklenebilir.
    Uint8List? attachmentBytes;
    String? attachmentExt;

    final question = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.faqAskQuestion),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 1200,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(hintText: l10n.faqAskQuestionHint),
              ),
              if (attachmentBytes != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        image: DecorationImage(
                          image: MemoryImage(attachmentBytes!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.coreKapat,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: Icon(
                        Icons.cancel,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                      ),
                      onPressed: () => setDialogState(() {
                        attachmentBytes = null;
                        attachmentExt = null;
                      }),
                    ),
                  ],
                )
              else
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await _pickSupportImage();
                    if (picked == null) return;
                    setDialogState(() {
                      attachmentBytes = picked.$1;
                      attachmentExt = picked.$2;
                    });
                  },
                  icon: const Icon(Icons.attach_file),
                  label: Text(l10n.profileEkranGoruntusuEkleOpsiyonel),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.profileIptal),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: Text(l10n.profileGonder),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (question == null || question.isEmpty || !mounted) return;
    try {
      await ref.read(submitFaqQuestionProvider)(
        question,
        attachmentBytes: attachmentBytes,
        attachmentExt: attachmentExt,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.faqQuestionSent)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.faqQuestionFailed)));
      }
    }
  }
}

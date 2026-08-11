import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:online_study_room/core/config/supabase_config.dart';
import 'package:online_study_room/data/repositories/supabase/report_attachment_upload.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-B — sikayete eklenen **kanit gorseli**.
///
/// 🔴 Olcum (`docs/design/ADMIN-PANEL-PLAN.md` §2.1): `0096_report_attachments`
/// private bucket'i **ve admin SELECT politikasini** kuruyor, `0097` detay
/// RPC'si `attachment_path` donduruyor, ama
/// `grep -rn "attachment_path\|attachmentPath" app/lib/` moderasyon tarafinda
/// SIFIR sonuc veriyordu. Yani kullanici sikayetine ekran goruntusu yukluyor,
/// sunucu admin'e vermeye hazir bekliyor, panel hic istemiyordu.
///
/// URL'yi **sunucu** imzalar: bucket private, `0096` politikasi yalniz
/// super-admin'e okuma verir. Istemci kapisi yok; yetki orada.
final moderationAttachmentUrlProvider = FutureProvider.family<String?, String>((
  ref,
  path,
) async {
  // Supabase yapilandirilmamis (bellek-ici/demo/test) kosumda imzali URL
  // uretilemez. `null` = "onizleme yok", sessiz basarisizlik degil: cagiran
  // bunu kullaniciya yazar.
  if (!SupabaseConfig.isConfigured) return null;
  return Supabase.instance.client.storage
      .from(kReportAttachmentBucket)
      .createSignedUrl(path, _signedUrlSeconds);
});

/// Imzali URL omru — onizleme icin bir dakika yeter, bagi paylasilamaz kilar.
const int _signedUrlSeconds = 60;

const Key kModerationAttachmentButtonKey = Key('moderation-attachment-open');
const Key kModerationAttachmentDialogKey = Key('moderation-attachment-dialog');

/// Ek yolu **dolu** olan vakada gorunen onizleme dugmesi.
///
/// Yol bossa bu widget hic cizilmez; "her vakada duran ama hicbir sey acmayan
/// dugme" panelin zaten sikayet edilen hastaligiydi (§1.2).
class ModerationAttachmentButton extends StatelessWidget {
  const ModerationAttachmentButton({super.key, required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        key: kModerationAttachmentButtonKey,
        icon: const Icon(Icons.image_outlined, size: 20),
        label: Text(l10n.adminIncelemeEkiAc),
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => _AttachmentDialog(path: path),
        ),
      ),
    );
  }
}

class _AttachmentDialog extends ConsumerWidget {
  const _AttachmentDialog({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final url = ref.watch(moderationAttachmentUrlProvider(path));
    return AlertDialog(
      key: kModerationAttachmentDialogKey,
      title: Text(l10n.adminIncelemeEk),
      content: SizedBox(
        width: 480,
        child: url.when(
          loading: () => const Center(
            heightFactor: 3,
            child: CircularProgressIndicator(),
          ),
          error: (_, _) => Text(l10n.adminIncelemeEkAcilamadi),
          data: (value) => value == null
              ? Text(l10n.adminIncelemeEkAcilamadi)
              : InteractiveViewer(
                  child: Image.network(
                    value,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) =>
                        Text(l10n.adminIncelemeEkAcilamadi),
                  ),
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminIptal),
        ),
      ],
    );
  }
}

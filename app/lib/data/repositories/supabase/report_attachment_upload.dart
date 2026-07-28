import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// WP-423: şikâyet ve destek sorusu foto ekinin yüklendiği **private** bucket.
///
/// 🔴 `avatars` bucket'ı bilerek kullanılmaz — onun public okuma politikası var
/// (`0002`), ek oraya konsaydı herkese açılırdı. Bu bucket private; okuma
/// politikası yalnız super-admin'e açık (`0096`), yani imzalı URL'yi de yalnız
/// super-admin üretebilir.
const String kReportAttachmentBucket = 'report_attachments';

/// İstemcinin kabul ettiği uzantılar. **Asıl kapı sunucudadır**
/// (bucket `file_size_limit` + `allowed_mime_types` ve
/// `assert_report_attachment_allowed`); buradaki liste yalnız gereksiz yüklemeyi
/// önler.
const List<String> kReportAttachmentExtensions = ['jpg', 'jpeg', 'png', 'webp'];

/// Tek foto ekini yükler ve sunucunun beklediği `<uid>/<uuid>.<ext>` yolunu
/// döndürür.
///
/// Ek **opsiyoneldir**: yükleme başarısız olursa `null` döner ve çağıran
/// şikâyeti/soruyu eksiz göndermeye devam eder. Ek yüzünden bildirim düşmez.
Future<String?> uploadReportAttachment(
  SupabaseClient client, {
  required Uint8List? bytes,
  required String? ext,
}) async {
  if (bytes == null || ext == null || bytes.isEmpty) return null;

  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final normalized = ext.startsWith('.') ? ext.substring(1) : ext;
  final safeExt = kReportAttachmentExtensions.contains(normalized.toLowerCase())
      ? normalized.toLowerCase()
      : 'jpg';
  final path = '$userId/${const Uuid().v4()}.$safeExt';

  try {
    await client.storage
        .from(kReportAttachmentBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(safeExt),
            upsert: false,
          ),
        );
    return path;
  } on StorageException {
    // Boyut/MIME sunucuda reddedilmiş olabilir; şikâyet yine de gitmeli.
    return null;
  } catch (_) {
    return null;
  }
}

String _contentTypeFor(String ext) => switch (ext) {
  'png' => 'image/png',
  'webp' => 'image/webp',
  _ => 'image/jpeg',
};

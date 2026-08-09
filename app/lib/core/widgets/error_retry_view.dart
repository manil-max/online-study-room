import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Ortak tekrar-dene düğmesinin kimliği; testler bu anahtarla ölçer.
const Key kErrorRetryButtonKey = Key('errorRetryButton');

/// Uygulama genelinde ortak "hata + tekrar dene" gövdesi (WP-560).
///
/// 🔴 Varlık sebebi ölçüldü: `app/lib` içindeki 42 `error:` kolunun çoğunun
/// hiçbir çıkışı yoktu ve olanlar birbirine benzemiyordu — aynı sekmenin üç
/// kardeş ekranı (Alarm / Timer / Görevler) hataya üç farklı yüzle cevap
/// veriyordu. Kullanıcı böylece "hangi ekranda ne yapabilirim"i hiç öğrenemez.
/// Görsel dil yeniden icat edilmedi: desen `tasks_screen.dart` içindeki
/// `_TaskSyncError`dan (ikon + cümle + tekrar dene) alındı.
///
/// 🔴 [onRetry] gerçekten veriyi yeniden okumalı (`ref.invalidate` ya da
/// `refreshAppData`). "Düğme var ama hiçbir şey yapmıyor" hatanın kendisinden
/// kötüdür: kullanıcı basar, ekran değişmez, uygulamayı donmuş sayar.
/// `test/features/error_retry_wp560_test.dart` bunu sözle değil sahte
/// depodaki çağrı sayacıyla ölçer (1 → 2).
///
/// WP-562: sınıf WP-560'ta `features/home/widgets/card_data_gate.dart` içinde
/// doğmuştu; oradan `classroom` ve `clock` ekranları da import ediyordu, yani
/// üç özellik paketi ortak bir widget için `home` paketine bağlanmıştı. Ortak
/// olan `core/widgets/`e ait — l10n anahtarı da (`commonTekrarDene`) ortak.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
    this.dense = false,
    this.retryLabel,
  });

  /// Katalogdan gelen kullanıcı cümlesi (l10n kapısı: metin burada doğmaz).
  final String message;

  /// İlgili veri kaynağını yeniden okuyan geri çağrım.
  final VoidCallback onRetry;

  /// Tek satırlık şeritler (yatay çip listesi gibi) için sıkışık düzen.
  final bool dense;

  /// 🔴 WP-592: eylem her zaman "tekrar dene" değildir. Bildirim izni kapalıyken
  /// doğru çıkış sistem ayarlarını açmaktır; düğmeye "Tekrar dene" yazmak
  /// kullanıcıya yanlış şeyi vaat ederdi. Verilmezse katalogdaki ortak
  /// "Tekrar dene" metni kullanılır — varsayılan davranış değişmedi.
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final label = retryLabel ?? AppLocalizations.of(context).commonTekrarDene;

    if (dense) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 8, 2),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, size: 18, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: textStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              key: kErrorRetryButtonKey,
              onPressed: onRetry,
              child: Text(label),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 32, color: muted),
          const SizedBox(height: 8),
          Text(message, style: textStyle, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          OutlinedButton(
            key: kErrorRetryButtonKey,
            onPressed: onRetry,
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

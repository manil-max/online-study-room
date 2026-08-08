import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_pull_to_refresh.dart';
import 'card_scaffold.dart';

/// Pano kartının yer tutucusunun kimliği; testler bu anahtarla ölçer.
const Key kCardSkeletonKey = Key('cardSkeleton');

/// Ortak tekrar-dene düğmesinin kimliği; testler bu anahtarla ölçer.
const Key kErrorRetryButtonKey = Key('errorRetryButton');

/// Pano kartlarının ortak "veri henüz yok" kapısı (WP-495C).
///
/// `null` dönerse [sources]'ın hepsi ilk verisini vermiştir ve kart kendi
/// gövdesini çizer. Aksi hâlde başlığı koruyan bir yer tutucu döner.
///
/// 🔴 Varlık sebebi: `ref.watch(p).value ?? const []` yazımı **yükleniyor** ile
/// **veri yok** durumlarını aynı kefeye koyar. Sonuç kozmetik değil, yanlış bir
/// iddiadır: kaydı olan kullanıcı açılışta "Kayıt yok", boş ısı haritası ve
/// "0 dk" görür (V58-N07 sınıfı). Tarama: `docs/qa/V58-ASYNC-EMPTY-AUDIT.md`.
///
/// Hata ayrı ele alınır — yoksa hatalı bir akış sonsuza kadar iskelet döndürür.
Widget? cardDataGate(
  BuildContext context, {
  required String title,
  required List<AsyncValue<Object?>> sources,
}) {
  if (sources.every((source) => source.hasValue)) return null;
  final failed = sources.any((source) => source.hasError);
  return CardScaffold(
    header: cardTitle(context, title),
    bodyBuilder: (context, bodyHeight) => SizedBox(
      height: bodyHeight,
      // 🔴 WP-560: hata dalı eskiden yalnız bir CÜMLE idi. Kullanıcı "Veriler
      // yüklenemedi." okuyup çıkmaz sokakta kalıyordu: ana ekranda çıkış
      // yalnız uygulamayı kapatıp açmaktı. Artık aynı kapı yenileme yolunu da
      // verir. Bu tek kapı pano kartlarının hepsini beslediği için düzeltme
      // 13 karta birden iner.
      //
      // Yenileme yolu **kasıtlı olarak** [refreshAppData]: WP-550 onu tek
      // yenileme kaynağı yaptı (aşağı çekme jesti ve masaüstü yenile düğmesi
      // aynı fonksiyonu çağırır). Buraya ikinci bir invalidate listesi
      // yazılsaydı üçüncü bir "yenileme gerçeği" doğardı. [AsyncValue] hangi
      // provider'dan geldiğini taşımadığı için hedefli invalidate zaten
      // mümkün değil.
      child: failed
          ? Consumer(
              builder: (context, ref, _) => RefreshableBody(
                child: Center(
                  child: ErrorRetryView(
                    message: AppLocalizations.of(
                      context,
                    ).homeVerilerYuklenemedi,
                    onRetry: () => refreshAppData(ref),
                  ),
                ),
              ),
            )
          : const CardBlockSkeleton(key: kCardSkeletonKey),
    ),
  );
}

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
/// Yerleşim notu: bu sınıfın doğru evi `lib/core/widgets/`. WP-560'ın SAHiP
/// yolları orayı kapsamadığı için şimdilik burada duruyor; taşıma ayrı bir WP.
class ErrorRetryView extends StatelessWidget {
  const ErrorRetryView({
    super.key,
    required this.message,
    required this.onRetry,
    this.dense = false,
  });

  /// Katalogdan gelen kullanıcı cümlesi (l10n kapısı: metin burada doğmaz).
  final String message;

  /// İlgili veri kaynağını yeniden okuyan geri çağrım.
  final VoidCallback onRetry;

  /// Tek satırlık şeritler (yatay çip listesi gibi) için sıkışık düzen.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final textStyle = theme.textTheme.bodyMedium?.copyWith(color: muted);
    final label = AppLocalizations.of(context).commonTekrarDene;

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

/// Grafik/özet gövdeleri için yer tutucu: bir başlık şeridi + gövde bloğu.
///
/// Animasyonsuz: ana ekranda aynı anda onlarca kart bulunabilir; sürekli dönen
/// bir shimmer kare bütçesini yer.
class CardBlockSkeleton extends StatelessWidget {
  const CardBlockSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.08);
    BoxDecoration box() =>
        BoxDecoration(color: base, borderRadius: BorderRadius.circular(6));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kısa şerit: gövdenin kendi başlığı/sayısı buraya gelir.
        FractionallySizedBox(
          widthFactor: 0.45,
          child: Container(height: 12, decoration: box()),
        ),
        const SizedBox(height: 10),
        // Kalan alanı dolduran blok; kısa hücrede küçülür, taşmaz.
        Expanded(child: Container(decoration: box())),
      ],
    );
  }
}

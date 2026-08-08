import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_pull_to_refresh.dart';
import '../../../core/widgets/error_retry_view.dart';
import 'card_scaffold.dart';

/// Pano kartının yer tutucusunun kimliği; testler bu anahtarla ölçer.
const Key kCardSkeletonKey = Key('cardSkeleton');

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

// 🔴 `material.dart` DEĞİL: bu dosyayı `lib/data` katmanı da (faz bitişi
// titreşim aralığı için) içeri alıyor ve orada material bağımlılığı yok.
// `PageTransitionsBuilder` `widgets.dart`tan da geliyor.
import 'package:flutter/widgets.dart';

/// WP-808 — hareket dilinin **tek** süre kaynağı.
///
/// 🔴 Neden tek dosya: hareket süresi koda dağıldığında biri 200, biri 600 ms
/// olur ve uygulama "yavaş" hissettirir; üstelik hiçbir test bunu bir yerden
/// ölçemez. Buradaki her sabit [maxDuration]'ı aşamaz ve bu `motion_wp808_test`
/// ile kilitlidir. Yeni bir hareket eklerken süresini buraya yaz, widget'a
/// gömme.
///
/// Not: `theme_tokens.dart` içindeki [AppMotion] tema **hissi** içindir
/// (preset başına farklı olabilir, `slow` 450 ms'ye çıkar). Bu dosya ondan
/// bağımsız olarak uygulama genelindeki üç somut hareketin süresini sabitler.
class MotionTokens {
  MotionTokens._();

  /// Üst sınır: hiçbir hareket bunu aşmaz.
  static const Duration maxDuration = Duration(milliseconds: 320);

  /// Sayfa geçişi (ileri/geri).
  static const Duration page = Duration(milliseconds: 280);

  /// İstatistik/pano kartlarındaki sayı geçişi.
  static const Duration statNumber = Duration(milliseconds: 260);

  /// Günlük hedef kutlaması (ölçek darbesi + halka vurgusu).
  static const Duration celebration = Duration(milliseconds: 320);

  /// Test bu listeyi tarar; yeni süre eklerken buraya da ekle.
  static const List<Duration> all = <Duration>[page, statNumber, celebration];

  /// Faz bitişi çift darbesinde iki titreşim arası.
  ///
  /// Hareket değil **dokunsal** bir aralıktır; erişilebilirlik "animasyonları
  /// azalt" ayarına bağlanmaz (titreşim ayrı bir ayardır).
  static const Duration hapticPulseGap = Duration(milliseconds: 80);

  /// Girişte hızlı başlayıp yumuşak duran eğri (kayma + ölçek).
  static const Curve enter = Curves.easeOutCubic;

  /// Kullanıcı "animasyonları azalt"ı açtı mı.
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  /// Erişilebilirlik kapısı: ayar açıkken süre **sıfır**, yani hareket yok ve
  /// widget doğrudan son duruma geçer.
  static Duration resolve(BuildContext context, Duration base) =>
      reduced(context) ? Duration.zero : base;
}

/// Uygulamanın kendi sayfa geçişi: sağdan kayar + hafif ölçek; geri gidişte
/// aynı animasyon ters çalışır.
///
/// 🔴 Neden hazır bir kurucu seçilmedi:
/// * `ZoomPageTransitionsBuilder` (Android varsayılanının düştüğü yer) 300 ms
///   yakınlaştırma yapar, yön bilgisi taşımaz — "nereden geldim" hissi yok.
/// * `CupertinoPageTransitionsBuilder` sağdan kayar ama **400 ms**'dir
///   ([maxDuration]'ı aşar), ölçek taşımaz ve Android/Windows'a iOS'un kenardan
///   geri sürükleme jestini de takar.
/// [PageTransitionsBuilder.transitionDuration] override edilebildiği için kendi
/// kurucumuz süreyi de [MotionTokens.page]'e sabitler; hazır kurucuların hiçbiri
/// bunu 320 ms sınırının altına indirmiyordu.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  // 🔴 `CurvedAnimation` yerine `CurveTween` zinciri: `CurvedAnimation` atılabilir
  // (disposable) bir nesnedir ve her karede `buildTransitions` içinde
  // üretilirse sızıntı bırakır. Flutter'ın kendi kurucuları da bu yüzden
  // `drive`/`chain` kullanır.
  static final Animatable<double> _curve = CurveTween(
    curve: MotionTokens.enter,
  );
  static final Animatable<Offset> _slide = Tween<Offset>(
    begin: const Offset(0.16, 0),
    end: Offset.zero,
  ).chain(_curve);
  static final Animatable<double> _scale = Tween<double>(
    begin: 0.96,
    end: 1,
  ).chain(_curve);

  @override
  Duration get transitionDuration => MotionTokens.page;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Erişilebilirlik: hareket kapalıysa sayfa doğrudan son durumunda çizilir.
    if (MotionTokens.reduced(context)) return child;
    return SlideTransition(
      position: animation.drive(_slide),
      child: ScaleTransition(
        scale: animation.drive(_scale),
        child: FadeTransition(opacity: animation.drive(_curve), child: child),
      ),
    );
  }
}

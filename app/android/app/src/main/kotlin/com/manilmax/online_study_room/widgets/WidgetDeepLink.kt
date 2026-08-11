package com.manilmax.online_study_room.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import com.manilmax.online_study_room.MainActivity

/**
 * WP-700: widget'a dokununca uygulamanin ILGILI bolumu acilir.
 *
 * ## Neden tek dosya
 * Once ayni kod iki yerde duruyordu (`StudyWidgetProviders.openAppPendingIntent`
 * ve `CountdownWidget` icindeki kopyasi) ve ikisi de yalniz
 * `getLaunchIntentForPackage()` cagiriyordu: uretilen intent HICBIR rota
 * bilgisi tasimiyordu. Sonuc, HANGI widget'a dokunulursa dokunulsun
 * uygulamanin "en son nerede kaldiysa" oraya acilmasiydi. Rota adlari ve
 * PendingIntent uretimi bu yuzden tek kaynakta toplandi.
 *
 * ## Neden `getLaunchIntentForPackage` DEGIL
 * O intent `ACTION_MAIN` + `CATEGORY_LAUNCHER` tasir. Uygulama arka planda
 * acikken ayni MAIN/LAUNCHER intent'i gonderilince Android cogu launcher'da
 * var olan gorevi one getirmekle yetinir ve `onNewIntent` CAGRILMAYABILIR:
 * extra'lar `Intent.filterEquals` karsilastirmasina GIRMEZ, yani sistem iki
 * farkli rotayi "ayni intent" gorur. Rota sessizce kaybolurdu.
 *
 * Bunun yerine [MainActivity]'ye **acik (explicit)** intent gonderilir. Acik
 * intent filtre aramadigi icin `AndroidManifest.xml`e yeni bir intent-filter
 * eklemek gerekmez; rotaya ozel [routeUri] `data` alanina yazildigi icin de
 * her rota ayri bir intent olur.
 *
 * ## PendingIntent kimligi
 * `PendingIntent` esitligi = requestCode + `Intent.filterEquals` (extra'lar
 * HARIC). requestCode olarak `appWidgetId` yeter: iki farkli rota ayni widget
 * id'sinde bile [routeUri] farkli oldugu icin ayri PendingIntent uretir.
 * Rotayi yalniz extra'ya koymak bunu SAGLAMAZDI. (Eski `20 + widgetId` /
 * `30 + widgetId` request kodlari da id'leri 10 fark eden iki widget'ta
 * carpisiyordu.)
 *
 * ## Sicak/soguk yol
 * Rotayi Dart'a tasiyan iki AYRI yol vardir ve ikisi de sarttir:
 *  * **soguk**: surec bu intentle dogar, `onNewIntent` HIC cagrilmaz ->
 *    `MainActivity.onCreate` rotayi saklar, Dart [METHOD_INITIAL_ROUTE] ile
 *    tek seferlik okur.
 *  * **sicak**: uygulama zaten acik -> `onNewIntent` [METHOD_ON_ROUTE] ile
 *    Dart'a iter.
 * Yalniz sicak yolu kurmak, ozelligi "calisiyor gorunup" pratikte yari olu
 * birakirdi: kullanici widget'a dokundugunda uygulama cogu zaman KAPALIDIR.
 */
object WidgetDeepLink {
    /** Widget -> MainActivity intent'inin action'i (MAIN/LAUNCHER DEGIL). */
    const val ACTION_OPEN_ROUTE = "com.manilmax.online_study_room.OPEN_WIDGET_ROUTE"

    /** Rota adini tasiyan extra. Okuma her zaman [routeOf] uzerinden yapilir. */
    const val EXTRA_ROUTE = "com.manilmax.online_study_room.extra.WIDGET_ROUTE"

    /**
     * Rotanin Dart'a gectigi kanal. Cihaz entegrasyonu kanali
     * (`/device_integrations`) BILEREK kullanilmadi: oradaki
     * `getInitialAction` tek seferliktir ve `deviceIntegrationListener`
     * tarafindan tuketilir — ayni kanali paylasmak iki dinleyici arasinda
     * yaris olustururdu (hangisi once okursa digeri null alir).
     */
    const val CHANNEL = "com.manilmax.online_study_room/widget_deep_link"
    const val METHOD_INITIAL_ROUTE = "getInitialWidgetRoute"
    const val METHOD_ON_ROUTE = "onWidgetRoute"

    const val ROUTE_TIMER = "timer"
    const val ROUTE_COUNTDOWN = "countdown"
    const val ROUTE_STATS = "stats"
    const val ROUTE_GROUP = "group"
    const val ROUTE_CLOCK = "clock"

    /** WP-701 gorev widget'i icin; mekanizma genel yazildi. */
    const val ROUTE_TASKS = "tasks"

    /** Dart `WidgetRoute` enum'u ile birebir ayni kume (sozlesme testi olcer). */
    val ROUTES = listOf(
        ROUTE_TIMER,
        ROUTE_COUNTDOWN,
        ROUTE_STATS,
        ROUTE_GROUP,
        ROUTE_CLOCK,
        ROUTE_TASKS,
    )

    /** Rotaya ozel `data` Uri'si — PendingIntent'leri ayiran sey budur. */
    fun routeUri(route: String): String = "odakkampi://widget/$route"

    /**
     * Intent -> rota. Saf tutuldu (yalniz String alir) ki JVM birim testi
     * `android.jar` saplamalarina carpmadan olcebilsin. Tanimadigi rota
     * `null` doner: ileride eklenen bir rota eski bir APK'da uygulamayi
     * bilinmeyen bir sekmeye atmaz, hicbir sey yapmaz.
     */
    fun routeOf(action: String?, extra: String?): String? =
        if (action == ACTION_OPEN_ROUTE && extra != null && ROUTES.contains(extra)) {
            extra
        } else {
            null
        }

    fun openRouteIntent(context: Context, route: String): Intent =
        Intent(context, MainActivity::class.java).apply {
            action = ACTION_OPEN_ROUTE
            data = Uri.parse(routeUri(route))
            putExtra(EXTRA_ROUTE, route)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
        }

    fun pendingIntent(context: Context, route: String, widgetId: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            widgetId,
            openRouteIntent(context, route),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
}

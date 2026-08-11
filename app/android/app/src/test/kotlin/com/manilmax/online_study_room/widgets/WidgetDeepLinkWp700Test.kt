package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * WP-700: widget'a dokununca ILGILI bolum acilir.
 *
 * Burada olculen sey **rotanin intent'te hayatta kalmasidir**. Kusurun eski
 * hali su idi: uretilen PendingIntent yalniz
 * `getLaunchIntentForPackage()` cagiriyordu, yani hicbir rota tasimiyordu ve
 * her widget uygulamayi "en son nerede kaldiysa" oraya aciyordu.
 *
 * `Intent`/`PendingIntent`/`Uri` `android.jar` saplamalaridir ve JVM birim
 * testinde "not mocked" ile patlar (bkz. `CountdownWidget` icindeki
 * `MiniJson` gerekcesi). Bu yuzden karar veren parca — [WidgetDeepLink.routeOf]
 * ve [WidgetDeepLink.routeUri] — SAF tutuldu; testin olctugu de odur.
 * Intent'in gercekten gonderilmesi cihazda dogrulanir.
 */
class WidgetDeepLinkWp700Test {

    @Test
    fun her_rota_kayitli_ve_tekildir() {
        assertEquals(
            listOf("timer", "countdown", "stats", "group", "clock", "tasks"),
            WidgetDeepLink.ROUTES,
        )
        assertEquals(
            "ayni rota iki kez kayitli",
            WidgetDeepLink.ROUTES.size,
            WidgetDeepLink.ROUTES.toSet().size,
        )
    }

    @Test
    fun rota_uri_si_her_rota_icin_FARKLIDIR() {
        // 🔴 PendingIntent esitligi requestCode + `Intent.filterEquals`tir ve
        // filterEquals EXTRA'LARA BAKMAZ. Rotayi yalniz extra'ya koymak iki
        // farkli rotayi ayni PendingIntent yapardi: ikinci widget birincinin
        // rotasini gosterirdi. Rotalari ayiran sey `data` Uri'sidir.
        val uris = WidgetDeepLink.ROUTES.map { WidgetDeepLink.routeUri(it) }
        assertEquals("iki rota ayni Uri'yi uretiyor", uris.size, uris.toSet().size)
        assertEquals("odakkampi://widget/stats", WidgetDeepLink.routeUri("stats"))
    }

    @Test
    fun dogru_action_ve_extra_rotayi_geri_verir() {
        for (route in WidgetDeepLink.ROUTES) {
            assertEquals(
                route,
                WidgetDeepLink.routeOf(WidgetDeepLink.ACTION_OPEN_ROUTE, route),
            )
        }
    }

    @Test
    fun rota_tasimayan_launcher_intenti_HICBIR_bolum_acmaz() {
        // Kusurun ta kendisi: `getLaunchIntentForPackage()` ACTION_MAIN uretir
        // ve extra tasimaz. Boyle bir intent "ana ekrani ac" bile dememeli;
        // sessizce bir sekmeye atlamak yanlis bolumu acmak olurdu.
        assertNull(WidgetDeepLink.routeOf("android.intent.action.MAIN", null))
        assertNull(WidgetDeepLink.routeOf(WidgetDeepLink.ACTION_OPEN_ROUTE, null))
        assertNull(WidgetDeepLink.routeOf(null, "stats"))
    }

    @Test
    fun tanimadigi_rota_yok_sayilir() {
        // Ileride eklenen bir rota ESKI bir APK'ya duserse uygulama rastgele
        // bir sekmeye atlamamalidir.
        assertNull(WidgetDeepLink.routeOf(WidgetDeepLink.ACTION_OPEN_ROUTE, "profile"))
        assertNull(WidgetDeepLink.routeOf(WidgetDeepLink.ACTION_OPEN_ROUTE, ""))
        assertNull(WidgetDeepLink.routeOf(WidgetDeepLink.ACTION_OPEN_ROUTE, "STATS"))
    }

    @Test
    fun baska_bir_uygulamanin_actioni_rota_uretmez() {
        assertNull(
            WidgetDeepLink.routeOf("com.manilmax.online_study_room.START_TIMER", "timer"),
        )
    }
}

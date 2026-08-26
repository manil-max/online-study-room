package com.manilmax.online_study_room.timer

import com.manilmax.online_study_room.widgets.WIDGET_IDLE_TIMER_TEXT
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Bosta WIDGET'in sifir gosterimi.
 *
 * 🔴 WP-759: bu test eskiden ayni iddiayi BILDIRIM icin de yapiyordu
 * (`IDLE_NOTIFICATION_TIMER_TEXT`). O sabit silindi. Gerekce emulatorde
 * olculdu: bir widget bir KUTUdur, bosken de bir sey cizmek zorundadir ve
 * "00:00" orada dogru gosterimdir. Bildirim ise bir KARTtir; bosken hic
 * bulunmaz ve kalirsa tek icerigi sifirlanmis bir saat olur -- sahip bunu
 * "sayac bozuldu" diye okudu. Iki yuzeyin ayni sabiti paylasmasi, yanlis
 * yuzeyde dogru gorunen bir degeri gorunmez kiliyordu.
 *
 * Bildirim tarafinin nobetcisi artik `IdleNotificationWp759Test`tir.
 */
class IdleTimerDisplayFormatTest {
    @Test
    fun idle_timer_widget_starts_with_minutes_and_seconds() {
        assertEquals("00:00", WIDGET_IDLE_TIMER_TEXT)
    }
}

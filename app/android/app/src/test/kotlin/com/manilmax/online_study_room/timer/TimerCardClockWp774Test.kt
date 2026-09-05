package com.manilmax.online_study_room.timer

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * WP-774 (sahip, cihazda, v77): Live Update karti "bos bildirim gibi"
 * duruyordu -- yalniz ders adi vardi. Standart sablonda kronometre BASLIKTA
 * durur ve One UI onu one cikarmaz. Govde satiri artik `MM:SS` tasir ve kart
 * saniyede bir sessizce yenilenir. Metin burada SAF hesaplanir ki cihazsiz
 * JVM olcebilsin.
 */
class TimerCardClockWp774Test {

    private val started = 1_700_000_000_000L

    @Test
    fun stopwatch_shows_elapsed_as_MM_SS() {
        assertEquals("00:00", cardClockText(started, started, countDown = false, totalSeconds = 0))
        assertEquals("00:05", cardClockText(started + 5_000L, started, false, 0))
        assertEquals("12:34", cardClockText(started + 754_000L, started, false, 0))
        assertEquals("59:59", cardClockText(started + 3_599_000L, started, false, 0))
    }

    @Test
    fun an_hour_or_more_gains_an_hour_field_instead_of_a_three_digit_minute() {
        assertEquals("1:00:00", cardClockText(started + 3_600_000L, started, false, 0))
        assertEquals("2:05:09", cardClockText(started + 7_509_000L, started, false, 0))
    }

    @Test
    fun targeted_modes_count_down_and_stop_at_zero() {
        assertEquals("25:00", cardClockText(started, started, countDown = true, totalSeconds = 1500))
        assertEquals("24:55", cardClockText(started + 5_000L, started, true, 1500))
        // Hedef asildiysa eksiye dusmez; kart `00:00`da durur.
        assertEquals("00:00", cardClockText(started + 9_000_000L, started, true, 1500))
    }

    @Test
    fun a_clock_set_backwards_never_prints_a_negative_time() {
        assertEquals("00:00", cardClockText(started - 30_000L, started, false, 0))
    }

    @Test
    fun the_card_ticks_once_a_second_and_only_polls_while_the_screen_is_off() {
        assertEquals(1_000L, CARD_TICK_MS)
        assertEquals(5_000L, CARD_IDLE_POLL_MS)
    }
}

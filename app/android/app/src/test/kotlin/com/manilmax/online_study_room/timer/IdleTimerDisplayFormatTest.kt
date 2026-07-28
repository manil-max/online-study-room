package com.manilmax.online_study_room.timer

import com.manilmax.online_study_room.widgets.WIDGET_IDLE_TIMER_TEXT
import org.junit.Assert.assertEquals
import org.junit.Test

class IdleTimerDisplayFormatTest {
    @Test
    fun idle_timer_surfaces_start_with_minutes_and_seconds() {
        assertEquals("00:00", WIDGET_IDLE_TIMER_TEXT)
        assertEquals("00:00", IDLE_NOTIFICATION_TIMER_TEXT)
    }
}

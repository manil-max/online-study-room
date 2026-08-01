package com.manilmax.online_study_room.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class TimerChronometerProjectionTest {
    @Test
    fun stopwatch_counts_up_from_wall_clock_start() {
        val projection = timerChronometerProjection(
            isRunning = true,
            mode = "stopwatch",
            startedAtMs = 10_000L,
            targetSeconds = null,
            nowWallClockMs = 15_000L,
            nowElapsedRealtimeMs = 50_000L,
        )

        assertEquals(TimerChronometerDirection.UP, projection.direction)
        assertEquals(45_000L, projection.baseElapsedRealtimeMs)
        assertTrue(projection.running)
    }

    @Test
    fun countdown_uses_remaining_time_instead_of_zero() {
        val projection = timerChronometerProjection(
            isRunning = true,
            mode = "countdown",
            startedAtMs = 10_000L,
            targetSeconds = 60,
            nowWallClockMs = 25_000L,
            nowElapsedRealtimeMs = 50_000L,
        )

        assertEquals(TimerChronometerDirection.DOWN, projection.direction)
        assertEquals(95_000L, projection.baseElapsedRealtimeMs)
        assertTrue(projection.running)
    }

    @Test
    fun completed_countdown_stops_at_zero() {
        val projection = timerChronometerProjection(
            isRunning = true,
            mode = "pomodoro",
            startedAtMs = 10_000L,
            targetSeconds = 60,
            nowWallClockMs = 75_000L,
            nowElapsedRealtimeMs = 50_000L,
        )

        assertEquals(TimerChronometerDirection.DOWN, projection.direction)
        assertEquals(50_000L, projection.baseElapsedRealtimeMs)
        assertFalse(projection.running)
    }
}

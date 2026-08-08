package com.manilmax.online_study_room.alarm

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * WP-557: tekrarlayan alarmın **bir sonraki** occurrence'ı ve geçmiş tetik
 * kararı.
 *
 * 🔴 Kapatılan iki saha hatası:
 * 1. Pzt-Cum 07:00 alarmı bir kez çalıp bir daha ASLA kurulmuyordu.
 *    `AlarmReceiver`ın FIRE dalında hiç `scheduleAlarm` yoktu ve "Kapat"
 *    PendingIntent'i tamamen iptal ediyordu. Native tarafın bir sonrakini
 *    hesaplayabilmesi şart: uygulama hiç açılmayabilir.
 * 2. Mirror'daki geçmiş `triggerAtMs` körlemesine "kaçırılmış alarm"
 *    sayılıyordu; 07:00'de çalıp kapatılan alarm 14:30'da uygulama açılınca
 *    yeniden çalıyordu.
 *
 * Saf JVM — Robolectric yok. Bu yüzden [nextOccurrenceMs] ve
 * [pastTriggerAction] `NativeAlarmScheduler` nesnesinin DIŞINDA, `Context` ve
 * `org.json` bağımlılığı olmadan durur.
 *
 * Zaman dilimi açıkça verilir: makine TZ'si testin sonucunu değiştirmemeli.
 */
class AlarmNextOccurrenceTest {

    // 2016'dan beri DST uygulamayan sabit UTC+3 — takvim aritmetiği net.
    private val zone = ZoneId.of("Europe/Istanbul")

    private fun ms(year: Int, month: Int, day: Int, hour: Int, minute: Int): Long =
        LocalDateTime.of(year, month, day, hour, minute)
            .atZone(zone)
            .toInstant()
            .toEpochMilli()

    private val weekdays = listOf(1, 2, 3, 4, 5)

    // ─── Hata 1: bir sonraki occurrence ────────────────────────────────────

    /**
     * Salı 07:00'de çaldı. Kullanıcı "Kapat"a bastı. Çarşamba 07:00 gelmeli.
     * Öncesi: hiçbir şey gelmiyordu.
     */
    @Test
    fun weekday_alarm_advances_to_the_next_day_at_the_moment_it_rings() {
        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            days = weekdays,
            afterMs = ms(2026, 8, 11, 7, 0), // Salı, tam tetik anı
            zoneId = zone,
        )

        assertEquals(ms(2026, 8, 12, 7, 0), next) // Çarşamba
    }

    /** Cuma çaldıktan sonra hafta sonu atlanır; Pazartesiye kurulur. */
    @Test
    fun weekday_alarm_wraps_over_the_weekend() {
        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            days = weekdays,
            afterMs = ms(2026, 8, 14, 7, 0), // Cuma
            zoneId = zone,
        )

        assertEquals(ms(2026, 8, 17, 7, 0), next) // Pazartesi
    }

    /** "Bir sonrakini atla" işaretli gün gerçekten atlanır. */
    @Test
    fun skip_next_on_moves_past_the_skipped_calendar_day() {
        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            days = weekdays,
            skipNextOnYmd = "2026-08-12", // Çarşamba atlanacak
            afterMs = ms(2026, 8, 11, 7, 0), // Salı
            zoneId = zone,
        )

        assertEquals(ms(2026, 8, 13, 7, 0), next) // Perşembe
    }

    /** Gün listesi boş = günlük yuvarlanma (Dart `AlarmScheduler` ile aynı). */
    @Test
    fun alarm_without_day_list_rolls_over_to_tomorrow() {
        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            days = emptyList(),
            afterMs = ms(2026, 8, 11, 7, 0),
            zoneId = zone,
        )

        assertEquals(ms(2026, 8, 12, 7, 0), next)
    }

    /** Bugünün saati henüz geçmediyse bugüne kurulur, yarına atlanmaz. */
    @Test
    fun alarm_later_today_stays_today() {
        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            days = weekdays,
            afterMs = ms(2026, 8, 11, 6, 59),
            zoneId = zone,
        )

        assertEquals(ms(2026, 8, 11, 7, 0), next)
    }

    /**
     * Tek tarihli alarm çaldıktan sonra bir daha kurulmamalı — aksi halde
     * her gün çalan bir hayalet doğar.
     */
    @Test
    fun single_date_alarm_has_no_next_occurrence_after_it_fires() {
        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            dateYmd = "2026-08-11",
            afterMs = ms(2026, 8, 11, 7, 0),
            zoneId = zone,
        )

        assertNull(next)
    }

    // ─── Hata 2: geçmiş tetik kararı ───────────────────────────────────────

    @Test
    fun future_trigger_is_scheduled_normally() {
        assertEquals(
            PastTriggerAction.SCHEDULE,
            pastTriggerAction(
                triggerAtMs = ms(2026, 8, 11, 7, 0),
                nowMs = ms(2026, 8, 11, 6, 59),
            ),
        )
    }

    /** Cihaz kapalıyken kaçan alarm hâlâ çalmalı (pencere içi). */
    @Test
    fun trigger_missed_inside_the_window_still_rings() {
        assertEquals(
            PastTriggerAction.FIRE_NOW,
            pastTriggerAction(
                triggerAtMs = ms(2026, 8, 11, 7, 0),
                nowMs = ms(2026, 8, 11, 7, 10), // 10 dk gecikme
            ),
        )
    }

    /**
     * 🔴 Hayalet alarm: 07:00 çaldı ve kapatıldı, kullanıcı 14:30'da
     * uygulamayı açtı. Pencere olmadan burası FIRE_NOW dönüyordu ve odak
     * uygulaması açılır açılmaz siren çalıyordu.
     */
    @Test
    fun stale_trigger_is_rescheduled_instead_of_ringing() {
        assertEquals(
            PastTriggerAction.RESCHEDULE_SILENTLY,
            pastTriggerAction(
                triggerAtMs = ms(2026, 8, 11, 7, 0),
                nowMs = ms(2026, 8, 11, 14, 30),
            ),
        )
    }

    /** Pencerenin tam sınırı hâlâ "kaçırılmış" sayılır. */
    @Test
    fun window_boundary_is_inclusive() {
        val trigger = ms(2026, 8, 11, 7, 0)
        assertEquals(
            PastTriggerAction.FIRE_NOW,
            pastTriggerAction(trigger, trigger + MISSED_TRIGGER_WINDOW_MS),
        )
        assertEquals(
            PastTriggerAction.RESCHEDULE_SILENTLY,
            pastTriggerAction(trigger, trigger + MISSED_TRIGGER_WINDOW_MS + 1),
        )
    }

    /**
     * Hayalet tetik sessizce düşürüldükten sonra kurulacak tetik gerçekten
     * gelecekte olmalı — ikinci kez hayalet üretmemeli.
     */
    @Test
    fun rescheduled_stale_alarm_lands_in_the_future() {
        val now = ms(2026, 8, 11, 14, 30)

        val next = nextOccurrenceMs(
            hour = 7,
            minute = 0,
            days = weekdays,
            afterMs = now,
            zoneId = zone,
        )

        assertEquals(ms(2026, 8, 12, 7, 0), next)
        assertEquals(PastTriggerAction.SCHEDULE, pastTriggerAction(next!!, now))
    }
}

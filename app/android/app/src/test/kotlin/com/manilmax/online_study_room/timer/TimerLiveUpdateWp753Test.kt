package com.manilmax.online_study_room.timer

import android.content.SharedPreferences
import com.manilmax.online_study_room.R
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-753: Android Live Update (promoted ongoing) sözleşmesinin nöbetçisi.
 *
 * Altı denemenin kök nedeni tek cümleydi: **özel `RemoteViews` taşıyan bildirim
 * terfi edemez.** Her turda ikisi aynı bildirimde tutulmaya çalışıldı. Bu test
 * o çelişkiyi cihazsız yakalar — karar `Notification` nesnesinde değil, saf
 * [runningTimerNotificationPlan] içinde verildiği için ölçülebilir.
 *
 * Ölçülemeyen (ve bu testin ölçtüğünü İDDİA ETMEDİĞİ) şeyler: çipin gerçekten
 * çizilmesi, Now Bar, kilit ekranı, AOD. Onlar cihaz kanıtıdır.
 */
class TimerLiveUpdateWp753Test {

    private val startedAt = 1_700_000_000_000L

    @Test
    fun stopwatch_uses_standard_style_and_requests_promotion() {
        val plan = runningTimerNotificationPlan(
            richPanel = false,
            isBreak = false,
            targetSeconds = null,
            startedAtMs = startedAt,
            nowMs = startedAt + 90_000L,
        )

        assertEquals(TimerNotificationStyle.STANDARD, plan.style)
        assertTrue(plan.requestPromotedOngoing)
        // Resmî şart 1: açık uçlu kronometrenin üst sınırı yok, ProgressStyle
        // yanlış olurdu (yüzde diye bir şey yok).
        assertEquals(0, plan.totalSeconds)
        // `when` başlangıç anıdır → GEÇMİŞTE kalır. Belge: "The when time is in
        // the past: The text isn't shown." Çip metni bu yüzden kısa kritik
        // metinden gelmek ZORUNDA.
        assertEquals(startedAt, plan.whenMs)
        assertFalse(plan.countDown)
        assertNotEquals(0, plan.shortCriticalTextRes)
    }

    @Test
    fun targeted_mode_uses_progress_style_with_a_real_percentage() {
        val plan = runningTimerNotificationPlan(
            richPanel = false,
            isBreak = false,
            targetSeconds = 1500,
            startedAtMs = startedAt,
            nowMs = startedAt + 300_000L,
        )

        assertEquals(TimerNotificationStyle.PROGRESS, plan.style)
        assertTrue(plan.requestPromotedOngoing)
        assertEquals(1500, plan.totalSeconds)
        assertEquals(300, plan.progressSeconds)
        // `when` bitiş anıdır → GELECEKTEDİR, çipte canlı geri sayım akar.
        assertEquals(startedAt + 1_500_000L, plan.whenMs)
        assertTrue(plan.countDown)
        // Sabit kısa metin canlı geri sayımı gölgelemesin diye yazılmaz.
        assertEquals(0, plan.shortCriticalTextRes)
    }

    /**
     * 🔴 Bu WP'nin bütün anlamı. Resmî şart:
     * *"Must NOT have any customContentView set (no RemoteViews)."*
     * Terfi istenen HİÇBİR yol özel görünüm taşımamalı.
     */
    @Test
    fun promoted_path_never_carries_a_custom_view() {
        val promotedPlans = listOf(
            runningTimerNotificationPlan(false, false, null, startedAt, startedAt),
            runningTimerNotificationPlan(false, true, null, startedAt, startedAt),
            runningTimerNotificationPlan(false, false, 1500, startedAt, startedAt),
            runningTimerNotificationPlan(false, true, 300, startedAt, startedAt),
        )

        for (plan in promotedPlans) {
            assertTrue(
                "Terfi istenmeli: ${plan.style}",
                plan.requestPromotedOngoing,
            )
            assertFalse(
                "Terfi istenen yolda ozel gorunum OLAMAZ: ${plan.style}",
                plan.usesCustomView,
            )
        }
    }

    /** Resmî şart 3: *"Must have a contentTitle set."* Eski kod `""` yazıyordu. */
    @Test
    fun promoted_path_always_has_a_content_title() {
        for (isBreak in listOf(false, true)) {
            for (target in listOf(null, 1500)) {
                val plan = runningTimerNotificationPlan(
                    richPanel = false,
                    isBreak = isBreak,
                    targetSeconds = target,
                    startedAtMs = startedAt,
                    nowMs = startedAt,
                )
                assertNotEquals(
                    "contentTitle bos birakilamaz (isBreak=$isBreak, target=$target)",
                    0,
                    plan.titleRes,
                )
            }
        }
    }

    @Test
    fun break_phase_and_work_phase_do_not_share_the_same_copy() {
        val work = runningTimerNotificationPlan(false, false, null, startedAt, startedAt)
        val rest = runningTimerNotificationPlan(false, true, null, startedAt, startedAt)

        assertEquals(R.string.timer_focusing_title, work.titleRes)
        assertEquals(R.string.timer_break_title, rest.titleRes)
        assertEquals(R.string.timer_subtext_focus, work.shortCriticalTextRes)
        assertEquals(R.string.timer_subtext_break, rest.shortCriticalTextRes)
    }

    @Test
    fun rich_panel_flag_keeps_the_v43_custom_panel_and_asks_for_no_promotion() {
        val plan = runningTimerNotificationPlan(
            richPanel = true,
            isBreak = false,
            targetSeconds = 1500,
            startedAtMs = startedAt,
            nowMs = startedAt + 60_000L,
        )

        assertEquals(TimerNotificationStyle.CUSTOM_PANEL, plan.style)
        assertTrue(plan.usesCustomView)
        // Karşılıklı dışlama: özel görünüm varken terfi İSTENMEZ.
        assertFalse(plan.requestPromotedOngoing)
    }

    /**
     * Geri dönüş valfi gerçek bir valf olmalı.
     *
     * 🔴 Bugüne kadar değildi: varsayılan `true`ydu ve `timer_panel_expanded`
     * anahtarını yazan tek bir satır bile repoda yoktu, yani standart dal
     * ULAŞILAMAZDI (`docs/analiz/WP-751-dinamik-panel-kok-neden.md §8`).
     */
    @Test
    fun missing_flag_means_live_update_and_true_means_the_old_panel() {
        val fresh = Wp753Prefs()
        assertFalse("Anahtar yokken Live Update yolu kosmali", useV43CustomPanel(fresh))

        val optedOut = Wp753Prefs()
        optedOut.edit().putBoolean(KEY_PANEL_EXPANDED, true).commit()
        assertTrue("true yazilinca eski zengin panel geri gelmeli", useV43CustomPanel(optedOut))

        val optedIn = Wp753Prefs()
        optedIn.edit().putBoolean(KEY_PANEL_EXPANDED, false).commit()
        assertFalse(useV43CustomPanel(optedIn))
    }

    /**
     * Durum çubuğu/çip ikonu monokrom vektör olmalı. Bugüne kadar renkli adaptif
     * launcher ikonuydu (`setSmallIcon(R.mipmap.ic_launcher)`) — yanlış tür.
     */
    @Test
    fun status_bar_icon_is_not_the_colored_launcher_icon() {
        assertEquals(R.drawable.ic_stat_focus_timer, TIMER_NOTIFICATION_SMALL_ICON)
        assertNotEquals(R.mipmap.ic_launcher, TIMER_NOTIFICATION_SMALL_ICON)
    }

    @Test
    fun progress_never_leaves_the_segment_it_is_drawn_on() {
        val overrun = runningTimerNotificationPlan(
            false, false, 1500, startedAt, startedAt + 9_000_000L,
        )
        assertEquals(1500, overrun.progressSeconds)

        // Saat geri alınırsa `now < startedAt` olabilir; negatif ilerleme
        // ProgressStyle'ı bozar.
        val clockSkew = runningTimerNotificationPlan(
            false, false, 1500, startedAt, startedAt - 5_000L,
        )
        assertEquals(0, clockSkew.progressSeconds)
    }

    @Test
    fun a_non_positive_target_degrades_to_the_open_ended_stopwatch() {
        val plan = runningTimerNotificationPlan(
            false, false, 0, startedAt, startedAt,
        )
        assertEquals(TimerNotificationStyle.STANDARD, plan.style)
        assertTrue(plan.requestPromotedOngoing)
    }
}

/** Yalnız bu testin ihtiyacı kadar `SharedPreferences`. */
private class Wp753Prefs : SharedPreferences {
    private val values = LinkedHashMap<String, Any?>()

    override fun getAll(): MutableMap<String, *> = values

    override fun getString(key: String?, defValue: String?): String? =
        values[key] as? String ?: defValue

    override fun getStringSet(
        key: String?,
        defValues: MutableSet<String>?,
    ): MutableSet<String>? {
        @Suppress("UNCHECKED_CAST")
        return values[key] as? MutableSet<String> ?: defValues
    }

    override fun getInt(key: String?, defValue: Int): Int = values[key] as? Int ?: defValue

    override fun getLong(key: String?, defValue: Long): Long = values[key] as? Long ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        values[key] as? Float ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        values[key] as? Boolean ?: defValue

    override fun contains(key: String?): Boolean = values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = Wp753PrefsEditor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
}

private class Wp753PrefsEditor(
    private val target: LinkedHashMap<String, Any?>,
) : SharedPreferences.Editor {
    private val staged = LinkedHashMap<String, Any?>()

    private fun stage(key: String?, value: Any?): SharedPreferences.Editor {
        if (key != null) staged[key] = value
        return this
    }

    override fun putString(key: String?, value: String?) = stage(key, value)

    override fun putStringSet(key: String?, values: MutableSet<String>?) = stage(key, values)

    override fun putInt(key: String?, value: Int) = stage(key, value)

    override fun putLong(key: String?, value: Long) = stage(key, value)

    override fun putFloat(key: String?, value: Float) = stage(key, value)

    override fun putBoolean(key: String?, value: Boolean) = stage(key, value)

    override fun remove(key: String?) = stage(key, null)

    override fun clear(): SharedPreferences.Editor {
        target.clear()
        return this
    }

    override fun commit(): Boolean {
        staged.forEach { (key, value) ->
            if (value == null) target.remove(key) else target[key] = value
        }
        staged.clear()
        return true
    }

    override fun apply() {
        commit()
    }
}

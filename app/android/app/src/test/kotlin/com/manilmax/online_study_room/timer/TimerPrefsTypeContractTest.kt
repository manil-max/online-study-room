package com.manilmax.online_study_room.timer

import android.content.SharedPreferences
import com.manilmax.online_study_room.widgets.readTimerWidgetPrefs
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

/**
 * WP-489: Dart ↔ native `SharedPreferences` tip sözleşmesi.
 *
 * Flutter `prefs.setInt` Android'e **`putLong`** yazar. Native taraf aynı
 * anahtarı `getInt` ile okuduğunda `ClassCastException` fırlar; servis veya
 * widget receiver'ı içinde bu, uygulama **sürecini** öldürür (v58 sahasında
 * geri sayım ve pomodoro başlatılamıyordu).
 *
 * Bu testin anlamı [TypeStrictPrefs]'in tip sertliğine bağlıdır: gerçek
 * `SharedPreferencesImpl.getInt` gövdesi `(Integer) mMap.get(key)` yapar,
 * gevşek bir sahte prefs kusuru hiç göremezdi.
 */
class TimerPrefsTypeContractTest {

    @Test
    fun native_write_uses_long_so_both_writers_agree() {
        val prefs = TypeStrictPrefs()

        TimerStateStore.writeRunning(
            prefs,
            startedAtMs = 1_700_000_000_000L,
            mode = "pomodoro",
            phase = "work",
            cycle = 3,
            targetSeconds = 1500,
            subjectId = "math",
        )

        // Kanonik tip Long — Dart'ın `setInt`i de bu tipi yazar.
        assertEquals(3L, prefs.getLong(TimerStateStore.KEY_CYCLE, -1L))
        assertEquals(1500L, prefs.getLong(TimerStateStore.KEY_TARGET_SECONDS, -1L))
    }

    @Test
    fun dart_written_long_is_read_without_class_cast_exception() {
        val prefs = TypeStrictPrefs()
        // Dart: prefs.setInt(...) → Android putLong (SharedPreferencesPlugin.kt:317)
        prefs.edit()
            .putLong(TimerStateStore.KEY_CYCLE, 4L)
            .putLong(TimerStateStore.KEY_TARGET_SECONDS, 1500L)
            .commit()

        // Kırık girdi gerçekten kırık: eski okuma yolu bugün de patlıyor.
        assertThrows(ClassCastException::class.java) {
            prefs.getInt(TimerStateStore.KEY_CYCLE, 1)
        }

        // Mola yolu (StudyTimerService.handleStartBreak / handleEndBreak).
        assertEquals(4, TimerStateStore.readIntCompat(prefs, TimerStateStore.KEY_CYCLE, 1))
        // Widget yolu (TimerWidgetProvider.onUpdate).
        assertEquals(1500, readTimerWidgetPrefs(prefs).targetSeconds)
    }

    @Test
    fun legacy_int_written_by_an_older_build_still_reads() {
        val prefs = TypeStrictPrefs()
        prefs.edit().putInt(TimerStateStore.KEY_CYCLE, 2).commit()

        assertEquals(2, TimerStateStore.readIntCompat(prefs, TimerStateStore.KEY_CYCLE, 1))
    }

    @Test
    fun missing_or_corrupt_key_falls_back_instead_of_throwing() {
        val prefs = TypeStrictPrefs()
        assertEquals(1, TimerStateStore.readIntCompat(prefs, TimerStateStore.KEY_CYCLE, 1))

        prefs.edit().putString(TimerStateStore.KEY_CYCLE, "bozuk").commit()
        assertEquals(1, TimerStateStore.readIntCompat(prefs, TimerStateStore.KEY_CYCLE, 1))
    }

    @Test
    fun widget_read_survives_corrupt_prefs_instead_of_killing_the_process() {
        val prefs = TypeStrictPrefs()
        prefs.edit()
            .putLong(TimerStateStore.KEY_STARTED_AT_MS, 1_700_000_000_000L)
            .putString(TimerStateStore.KEY_MODE, "pomodoro")
            .putString(TimerStateStore.KEY_TARGET_SECONDS, "bozuk")
            .commit()

        val snapshot = readTimerWidgetPrefs(prefs)

        assertEquals(1_700_000_000_000L, snapshot.startedAtMs)
        assertEquals("pomodoro", snapshot.mode)
        assertNull(snapshot.targetSeconds)
    }
}

/** `SharedPreferencesImpl` ile aynı tip sertliği: yanlış tip cast'te patlar. */
private class TypeStrictPrefs : SharedPreferences {
    val values = LinkedHashMap<String, Any>()

    private fun raw(key: String?): Any? = if (key == null) null else values[key]

    override fun getAll(): MutableMap<String, *> = values

    override fun getString(key: String?, defValue: String?): String? =
        raw(key)?.let { it as String } ?: defValue

    @Suppress("UNCHECKED_CAST")
    override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
        raw(key)?.let { it as MutableSet<String> } ?: defValues

    override fun getInt(key: String?, defValue: Int): Int = raw(key)?.let { it as Int } ?: defValue

    override fun getLong(key: String?, defValue: Long): Long =
        raw(key)?.let { it as Long } ?: defValue

    override fun getFloat(key: String?, defValue: Float): Float =
        raw(key)?.let { it as Float } ?: defValue

    override fun getBoolean(key: String?, defValue: Boolean): Boolean =
        raw(key)?.let { it as Boolean } ?: defValue

    override fun contains(key: String?): Boolean = key != null && values.containsKey(key)

    override fun edit(): SharedPreferences.Editor = FakeEditor(values)

    override fun registerOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit

    override fun unregisterOnSharedPreferenceChangeListener(
        listener: SharedPreferences.OnSharedPreferenceChangeListener?,
    ) = Unit
}

private class FakeEditor(private val target: LinkedHashMap<String, Any>) : SharedPreferences.Editor {
    private val staged = LinkedHashMap<String, Any?>()
    private var clearAll = false

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
        clearAll = true
        return this
    }

    override fun commit(): Boolean {
        if (clearAll) target.clear()
        staged.forEach { (key, value) ->
            if (value == null) target.remove(key) else target[key] = value
        }
        staged.clear()
        clearAll = false
        return true
    }

    override fun apply() {
        commit()
    }
}

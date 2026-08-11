package com.manilmax.online_study_room.widgets

import android.content.SharedPreferences
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * WP-695: geri sayım widget'ının **çizdiği metni** ölçer.
 *
 * `daysText` doğrudan `setTextViewText(R.id.countdown_widget_days, …)`e gider;
 * yani buradaki her iddia kullanıcının ekranda gördüğü karakterlerdir.
 *
 * [FIXTURE] uygulamanın gerçekten ürettiği prefs metnidir: Dart tarafındaki
 * `countdown_widget_wp695_test.dart`, `ExamListNotifier.add(...)` çalıştırıp
 * `dday.exams_v2` anahtarını geri okur, kimliği sabitler ve sonucun bu dosyada
 * **birebir** geçtiğini iddia eder. Biçim değişirse (WP-694 sunucu taşıması)
 * fixture bayatlar ve o test kırmızı düşer.
 */
class CountdownWidgetModelWp695Test {

    private companion object {
        // WP-694 bu kayda `updatedAt` / `synced` / `deleted` alanlarini ekledi.
        // Ayristirici tanimadigi alanlari **yok sayar**; fixture yine de gercek
        // bicimi tasir, cunku amaci "bugun diskte ne var"i sabitlemektir.
        // 🔴 Tek satir: Dart testi bu metni .kt dosyasinda **birebir** arar.
        // Parcalara bolunurse arama bulamaz ve capraz-dil golden'i sessizce olur.
        @Suppress("MaxLineLength")
        const val FIXTURE = """{"entries":[{"id":"fixture","name":"YKS","day":"2026-09-01","updatedAt":"STAMP"}],"priority":null,"synced":[],"deleted":[]}"""

        /** 2026-08-11 12:00 UTC → İstanbul 15:00, aynı takvim günü. */
        const val NOW_2026_08_11 = 1_786_449_600_000L
        const val MS_PER_DAY = 86_400_000L
    }

    @Test
    fun istanbul_day_boundary_matches_dart_side() {
        // 2026-08-11T21:30Z = İstanbul 12 Ağustos 00:30 → ertesi gün.
        val lateEvening = NOW_2026_08_11 + 9 * 60 * 60 * 1000L + 30 * 60 * 1000L
        assertEquals(
            istanbulEpochDay(NOW_2026_08_11) + 1,
            istanbulEpochDay(lateEvening),
        )
        assertEquals(
            epochDayFromCivil(2026, 8, 11),
            istanbulEpochDay(NOW_2026_08_11),
        )
        // Epoch günü sıfır noktası: 1970-01-01.
        assertEquals(0L, epochDayFromCivil(1970, 1, 1))
    }

    @Test
    fun future_exam_shows_the_day_count_the_app_would_show() {
        val model = countdownWidgetModel(FIXTURE, NOW_2026_08_11)

        assertEquals(CountdownState.FUTURE, model.state)
        assertEquals("YKS", model.name)
        // 11 Ağustos → 1 Eylül = 21 gün.
        assertEquals(21L, model.days)
        assertEquals("21", model.daysText)
    }

    @Test
    fun exam_day_itself_is_today_not_zero_days_left() {
        val now = NOW_2026_08_11 + 21 * MS_PER_DAY

        val model = countdownWidgetModel(FIXTURE, now)

        assertEquals(CountdownState.TODAY, model.state)
        assertEquals(0L, model.days)
        assertEquals("0", model.daysText)
    }

    @Test
    fun past_exam_never_renders_a_negative_day_count() {
        // Sınavdan 1 gün sonrasından 400 gün sonrasına kadar tara.
        for (offset in 22..400) {
            val model = countdownWidgetModel(FIXTURE, NOW_2026_08_11 + offset * MS_PER_DAY)

            assertEquals("offset=$offset", CountdownState.PAST, model.state)
            assertEquals(COUNTDOWN_DASH, model.daysText)
            assertFalse(
                "offset=$offset ekrana '${model.daysText}' yaziyor",
                model.daysText.startsWith("-"),
            )
        }
    }

    @Test
    fun empty_and_corrupt_inputs_still_draw_something() {
        val inputs = listOf(
            null,
            "",
            "   ",
            "bozuk",
            "{",
            """{"entries":[],"priority":null}""",
            """{"entries":[{"id":"a","name":"X","day":"bozuk-tarih"}],"priority":null}""",
            """{"entries":[{"id":"a","name":"X"}],"priority":null}""",
            """{"entries":"dizi-degil","priority":null}""",
        )
        for (raw in inputs) {
            val model = countdownWidgetModel(raw, NOW_2026_08_11)

            assertEquals("girdi=$raw", CountdownState.EMPTY, model.state)
            // Bos ekran DEGIL: buyuk alanda bir isaret durur, etiket
            // `widget_countdown_empty` string kaynagindan gelir.
            assertEquals(COUNTDOWN_DASH, model.daysText)
            assertTrue(model.daysText.isNotEmpty())
        }
    }

    @Test
    fun priority_entry_wins_exactly_like_examDateProvider() {
        val json = """{"entries":[""" +
            """{"id":"a","name":"LGS","day":"2026-08-20"},""" +
            """{"id":"b","name":"YKS","day":"2026-09-01"}""" +
            """],"priority":"b"}"""

        val model = countdownWidgetModel(json, NOW_2026_08_11)

        assertEquals("YKS", model.name)
        assertEquals(21L, model.days)
    }

    @Test
    fun missing_priority_falls_back_to_the_first_entry() {
        val json = """{"entries":[""" +
            """{"id":"a","name":"LGS","day":"2026-08-20"},""" +
            """{"id":"b","name":"YKS","day":"2026-09-01"}""" +
            """],"priority":"silinmis-kimlik"}"""

        val model = countdownWidgetModel(json, NOW_2026_08_11)

        assertEquals("LGS", model.name)
        assertEquals(9L, model.days)
    }

    /**
     * WP-694 kayda `updatedAt` / `synced` / `deleted` ekledi ve ayristirici
     * kirilmadi. Asil risk **bir sonraki** eklemedir: kati bir ayristirici
     * bilinmeyen alani gorunce widget'i sessizce oldururdu.
     *
     * Bu yuzden iddia bugunku alanlara degil, **uydurma** alanlara baglidir —
     * ic ice nesne ve dizi dahil.
     */
    @Test
    fun unknown_fields_do_not_break_the_widget() {
        val json = """{"entries":[{"id":"fixture","name":"YKS","day":"2026-09-01",""" +
            """"updatedAt":"2026-08-11T10:00:00.000Z","yarininAlani":{"ic":[1,2,{"a":null}]},""" +
            """"bayrak":true}],"priority":null,"synced":["fixture"],"deleted":[],""" +
            """"gelecekUstAlan":[{"x":1.5}],"sayi":-3}"""

        val model = countdownWidgetModel(json, NOW_2026_08_11)

        assertEquals(CountdownState.FUTURE, model.state)
        assertEquals("YKS", model.name)
        assertEquals("21", model.daysText)
    }

    /** `updatedAt` bu widget'in isine yaramaz; varligi ayristirmayi bozmamali. */
    @Test
    fun updatedAt_is_ignored_not_parsed_as_the_exam_date() {
        val withStamp = """{"entries":[{"id":"a","name":"YKS","day":"2026-09-01",""" +
            """"updatedAt":"1999-01-01T00:00:00.000Z"}],"priority":null}"""
        val withoutStamp =
            """{"entries":[{"id":"a","name":"YKS","day":"2026-09-01"}],"priority":null}"""

        assertEquals(
            countdownWidgetModel(withoutStamp, NOW_2026_08_11),
            countdownWidgetModel(withStamp, NOW_2026_08_11),
        )
    }

    /**
     * WP-694 silmeyi ust duzey `deleted` KIMLIK LISTESI ile tasir. Kimlik
     * sunucuya gidene kadar `entries` icinde de durabilir; widget o kaydi
     * gostermemeli.
     */
    @Test
    fun entry_marked_deleted_is_not_shown() {
        val json = """{"entries":[""" +
            """{"id":"a","name":"SILINDI","day":"2026-08-20"},""" +
            """{"id":"b","name":"YKS","day":"2026-09-01"}""" +
            """],"priority":null,"synced":[],"deleted":["a"]}"""

        val model = countdownWidgetModel(json, NOW_2026_08_11)

        assertEquals("YKS", model.name)
        assertEquals(21L, model.days)

        // Silinen kayit ONE CIKARILMIS olsa bile gosterilmez.
        val prioritized = json.replace(""""priority":null""", """"priority":"a"""")
        assertEquals("YKS", countdownWidgetModel(prioritized, NOW_2026_08_11).name)

        // Tek kayit da silinmisse widget bos duruma duser, cop gostermez.
        val allDeleted = """{"entries":[{"id":"a","name":"X","day":"2026-09-01"}],""" +
            """"priority":null,"deleted":["a"]}"""
        val emptied = countdownWidgetModel(allDeleted, NOW_2026_08_11)
        assertEquals(CountdownState.EMPTY, emptied.state)
        assertEquals(COUNTDOWN_DASH, emptied.daysText)
    }

    @Test
    fun escaped_name_survives_the_parser() {
        val json = """{"entries":[{"id":"a","name":"A\"B\\Cç","day":"2026-09-01"}],""" +
            """"priority":null}"""

        val model = countdownWidgetModel(json, NOW_2026_08_11)

        assertEquals("A\"B\\Cç", model.name)
        assertEquals(CountdownState.FUTURE, model.state)
    }

    /**
     * 🔴 v58 saha çökmesi: Dart `setInt` diske **`putLong`** yazar; native
     * `getInt` `ClassCastException` fırlatır ve `onUpdate` bir
     * `BroadcastReceiver` içinde koştuğu için uygulama **süreci** ölür.
     *
     * Bu widget prefs'ten hiç sayı okumaz — tek okuma `getString`tir. Test
     * bunu iddia etmekle kalmaz, kırık yolun bugün de kırık olduğunu gösterir.
     */
    @Test
    fun countdown_read_never_touches_getInt_and_survives_wrong_types() {
        val prefs = StrictPrefs()
        prefs.edit().putLong(COUNTDOWN_PREFS_KEY, 42L).commit()

        // Kirik girdi gercekten kirik.
        assertThrows(ClassCastException::class.java) {
            prefs.getInt(COUNTDOWN_PREFS_KEY, 0)
        }
        // Widget yolu sureci oldurmez, bos duruma duser.
        assertNull(readCountdownJson(prefs))
        assertEquals(
            CountdownState.EMPTY,
            countdownWidgetModel(readCountdownJson(prefs), NOW_2026_08_11).state,
        )

        prefs.edit().putString(COUNTDOWN_PREFS_KEY, FIXTURE).commit()
        assertEquals(FIXTURE, readCountdownJson(prefs))
    }

    /** `SharedPreferencesImpl` ile ayni tip sertligi: yanlis tip cast'te patlar. */
    private class StrictPrefs : SharedPreferences {
        private val values = LinkedHashMap<String, Any>()

        private fun raw(key: String?): Any? = if (key == null) null else values[key]

        override fun getAll(): MutableMap<String, *> = values

        override fun getString(key: String?, defValue: String?): String? =
            raw(key)?.let { it as String } ?: defValue

        @Suppress("UNCHECKED_CAST")
        override fun getStringSet(
            key: String?,
            defValues: MutableSet<String>?,
        ): MutableSet<String>? = raw(key)?.let { it as MutableSet<String> } ?: defValues

        override fun getInt(key: String?, defValue: Int): Int =
            raw(key)?.let { it as Int } ?: defValue

        override fun getLong(key: String?, defValue: Long): Long =
            raw(key)?.let { it as Long } ?: defValue

        override fun getFloat(key: String?, defValue: Float): Float =
            raw(key)?.let { it as Float } ?: defValue

        override fun getBoolean(key: String?, defValue: Boolean): Boolean =
            raw(key)?.let { it as Boolean } ?: defValue

        override fun contains(key: String?): Boolean = key != null && values.containsKey(key)

        override fun edit(): SharedPreferences.Editor = StrictEditor(values)

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit

        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }

    private class StrictEditor(
        private val target: LinkedHashMap<String, Any>,
    ) : SharedPreferences.Editor {
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
}

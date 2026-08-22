package com.manilmax.online_study_room.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import androidx.core.content.ContextCompat
import com.manilmax.online_study_room.R
import es.antonborri.home_widget.HomeWidgetProvider

/** Kısa halde tek satır kalır; o satır listenin başı değil KULLANICININ sırasıdır. */
internal fun leaderboardShowsMyRank(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.SHORT

internal fun leaderboardRow2Visible(height: WidgetHeightClass): Boolean =
    height != WidgetHeightClass.SHORT

internal fun leaderboardRow3Visible(height: WidgetHeightClass): Boolean =
    height == WidgetHeightClass.TALL

/** Tire/bos placeholder satirlari artik gercek bir siralama satiri gibi cizilmez. */
internal fun leaderboardRowHasContent(value: String): Boolean =
    value.trim().let { it.isNotEmpty() && it != "-" && it != "\u2014" }

/** `#2` ya da `#2 (detay)` bicimindeki kendi sira aynasini ilk uce esler. */
internal fun leaderboardHighlightedPosition(myRank: String): Int? =
    Regex("^#([1-3])(?:\\b|\\s|\\u00B7)")
        .find(myRank.trim())
        ?.groupValues
        ?.get(1)
        ?.toIntOrNull()

class GroupLeaderboardWidgetProvider : HomeWidgetProvider() {
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val strings = widgetLocalizedContext(context)
        val ink = ContextCompat.getColor(context, R.color.widget_design_ink)
        val accent = ContextCompat.getColor(context, R.color.widget_design_accent)
        appWidgetIds.forEach { widgetId ->
            val views =
                RemoteViews(context.packageName, R.layout.odak_leaderboard_widget).apply {
                    setContentDescription(
                        R.id.leaderboard_widget_root,
                        strings.getString(R.string.cd_leaderboard_widget),
                    )
                    val size = appWidgetManager.sizeClass(WidgetSizeSpecs.leaderboard, widgetId)
                    val myRank = widgetData.text(
                        StudyWidgetKeys.LeaderboardMyRank,
                        strings.getString(R.string.widget_no_rank),
                    )
                    val short = leaderboardShowsMyRank(size.height)
                    val row1 = if (short) {
                        myRank
                    } else {
                        widgetData.text(
                            StudyWidgetKeys.LeaderboardRow1,
                            strings.getString(R.string.widget_no_records),
                        )
                    }
                    val row1HasRank = short || (
                        widgetData.contains(StudyWidgetKeys.LeaderboardRow1) &&
                            leaderboardRowHasContent(row1)
                        )
                    val row2 = widgetData.text(StudyWidgetKeys.LeaderboardRow2, "-")
                    val row3 = widgetData.text(StudyWidgetKeys.LeaderboardRow3, "-")
                    val highlighted = leaderboardHighlightedPosition(myRank)

                    setTextViewText(
                        R.id.leaderboard_widget_title,
                        widgetData.text(
                            StudyWidgetKeys.LeaderboardTitle,
                            strings.getString(R.string.widget_leaderboard_title),
                        ),
                    )
                    setTextViewText(R.id.leaderboard_widget_row_1, row1)
                    setTextViewText(
                        R.id.leaderboard_widget_rank_1,
                        if (short) strings.getString(R.string.widget_you) else "1",
                    )
                    setViewVisibility(
                        R.id.leaderboard_widget_rank_1,
                        if (row1HasRank) View.VISIBLE else View.GONE,
                    )
                    setOnClickPendingIntent(
                        R.id.leaderboard_widget_root,
                        WidgetDeepLink.pendingIntent(
                            context,
                            WidgetDeepLink.ROUTE_GROUP,
                            widgetId,
                        ),
                    )
                    setTextViewText(R.id.leaderboard_widget_row_2, row2)
                    setTextViewText(R.id.leaderboard_widget_row_3, row3)
                    setTextColor(
                        R.id.leaderboard_widget_row_1,
                        if (short || highlighted == 1) accent else ink,
                    )
                    setTextColor(
                        R.id.leaderboard_widget_row_2,
                        if (highlighted == 2) accent else ink,
                    )
                    setTextColor(
                        R.id.leaderboard_widget_row_3,
                        if (highlighted == 3) accent else ink,
                    )
                    // WP-699: üçüncü satır ancak gerçekten uzun kutuda gelir.
                    // Eskiden 2. ve 3. satır birlikte açılıyordu; 3×2'de üç
                    // satır + başlık 110dp'ye sığmıyordu.
                    setViewVisibility(
                        R.id.leaderboard_widget_row_container_2,
                        if (
                            leaderboardRow2Visible(size.height) &&
                            leaderboardRowHasContent(row2)
                        ) View.VISIBLE else View.GONE,
                    )
                    setViewVisibility(
                        R.id.leaderboard_widget_row_container_3,
                        if (
                            leaderboardRow3Visible(size.height) &&
                            leaderboardRowHasContent(row3)
                        ) View.VISIBLE else View.GONE,
                    )
                    applySp(
                        R.id.leaderboard_widget_title,
                        WidgetTypography.leaderboardTitle.of(size.width),
                    )
                    val rowSp = WidgetTypography.leaderboardRow.of(size.width)
                    applySp(R.id.leaderboard_widget_row_1, rowSp)
                    applySp(R.id.leaderboard_widget_row_2, rowSp)
                    applySp(R.id.leaderboard_widget_row_3, rowSp)
                    applyRootPadding(
                        context,
                        R.id.leaderboard_widget_card,
                        widgetRootPaddingDp(8, size.height),
                    )
                }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

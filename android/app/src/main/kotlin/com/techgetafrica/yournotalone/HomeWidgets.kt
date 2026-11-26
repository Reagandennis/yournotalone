package com.techgetafrica.yournotalone

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.temporal.TemporalAdjusters

// The home-screen widgets. They only display: every number and word comes
// from the app (lib/home_widgets/home_widget_sync.dart, which owns the keys
// read below), already in the app's language.

/** The small widget: this week and today's check-in. */
class RhythmWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.read(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_rhythm)
            if (state.signedOut) {
                views.setViewVisibility(R.id.widget_rhythm, View.GONE)
                showSignedOut(views, state)
            } else {
                views.setViewVisibility(R.id.widget_rhythm, View.VISIBLE)
                views.setViewVisibility(R.id.widget_signed_out, View.GONE)
                bindRhythm(views, state)
            }
            views.setOnClickPendingIntent(R.id.widget_root, launch(context, CHECK_IN_URI))
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

/** The wide widget: the week, and today's suggestion beside it. */
class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = WidgetState.read(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setOnClickPendingIntent(R.id.widget_root, launch(context, CHECK_IN_URI))
            if (state.signedOut) {
                views.setViewVisibility(R.id.widget_content, View.GONE)
                showSignedOut(views, state)
            } else {
                views.setViewVisibility(R.id.widget_content, View.VISIBLE)
                views.setViewVisibility(R.id.widget_signed_out, View.GONE)
                bindRhythm(views, state)
                views.setTextViewText(R.id.widget_for_you, state.labelForYou)
                if (state.pickId != null && state.pickTitle != null) {
                    views.setTextViewText(R.id.widget_pick_title, state.pickTitle)
                    views.setTextViewText(R.id.widget_pick_meta, state.pickMeta ?: "")
                    views.setViewVisibility(
                        R.id.widget_pick_meta,
                        if (state.pickMeta.isNullOrEmpty()) View.GONE else View.VISIBLE,
                    )
                    views.setOnClickPendingIntent(R.id.widget_pick, launch(context, pickUri(state.pickId)))
                } else {
                    views.setTextViewText(R.id.widget_pick_title, state.labelOpenForPick)
                    views.setViewVisibility(R.id.widget_pick_meta, View.GONE)
                    views.setOnClickPendingIntent(R.id.widget_pick, launch(context, CHECK_IN_URI))
                }
                if (state.sleepLine != null) {
                    views.setTextViewText(R.id.widget_sleep, state.sleepLine)
                    views.setViewVisibility(R.id.widget_sleep, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_sleep, View.GONE)
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

private const val CHECK_IN_URI = "yournotalone-widget://checkin?homeWidget=1"

private fun pickUri(id: String) =
    "yournotalone-widget://pick?id=${Uri.encode(id)}&homeWidget=1"

private fun launch(context: Context, uri: String) =
    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

private val DOTS = intArrayOf(
    R.id.widget_dot_0, R.id.widget_dot_1, R.id.widget_dot_2, R.id.widget_dot_3,
    R.id.widget_dot_4, R.id.widget_dot_5, R.id.widget_dot_6,
)

private fun bindRhythm(views: RemoteViews, state: WidgetState) {
    views.setTextViewText(R.id.widget_week_label, state.labelWeek)
    views.setTextViewText(
        R.id.widget_days,
        if (state.goalMet && state.labelGoalMet != null) state.labelGoalMet else state.labelDays,
    )
    for ((i, dot) in DOTS.withIndex()) {
        views.setImageViewResource(
            dot,
            when {
                state.week[i] -> R.drawable.widget_dot_on
                i == state.todayIndex -> R.drawable.widget_dot_today
                else -> R.drawable.widget_dot_off
            },
        )
    }
    if (state.checkedIn) {
        views.setViewVisibility(R.id.widget_check_in, View.GONE)
        views.setViewVisibility(R.id.widget_checked_in, View.VISIBLE)
        views.setTextViewText(R.id.widget_checked_in, "✓ " + state.labelCheckedIn)
    } else {
        views.setViewVisibility(R.id.widget_check_in, View.VISIBLE)
        views.setViewVisibility(R.id.widget_checked_in, View.GONE)
        views.setTextViewText(R.id.widget_check_in, state.labelCheckIn)
    }
}

private fun showSignedOut(views: RemoteViews, state: WidgetState) {
    views.setViewVisibility(R.id.widget_signed_out, View.VISIBLE)
    // Before the app's first run there are no words of its own yet: the
    // layout's (the phone's language) stay.
    if (state.labelOpenForPick.isNotEmpty()) {
        views.setTextViewText(R.id.widget_signed_out_text, state.labelOpenForPick)
    }
}

/**
 * What the app last wrote, made fit for today. The widget can outlive the
 * day it was written on: a new day loses yesterday's check-in, suggestion
 * and sleep, and a new week starts at nothing, rather than showing stale
 * ticks as if they were today's.
 */
private class WidgetState(
    val signedOut: Boolean,
    val days: Int,
    val goal: Int,
    val week: BooleanArray,
    val todayIndex: Int,
    val checkedIn: Boolean,
    val pickId: String?,
    val pickTitle: String?,
    val pickMeta: String?,
    val sleepLine: String?,
    val labelWeek: String,
    val labelDays: String,
    val labelGoalMet: String?,
    val labelCheckIn: String,
    val labelCheckedIn: String,
    val labelForYou: String,
    val labelOpenForPick: String,
) {
    val goalMet get() = days >= goal

    companion object {
        fun read(prefs: SharedPreferences): WidgetState {
            fun text(key: String) = prefs.getString(key, null)?.takeIf { it.isNotEmpty() }
            val today = LocalDate.now()
            val monday = today.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            val todayIndex = today.dayOfWeek.value - 1
            // Labels the app hasn't written yet (a widget placed before the
            // app's first run) fall back to the gallery's own words.
            val labelOpen = text("hw_label_open_for_pick") ?: ""
            val ready = text("hw_state") == "ready"
            val sameWeek = ready && text("hw_week_start") == monday.toString()
            val sameDay = sameWeek && text("hw_day") == today.toString()
            val weekBits = if (sameWeek) text("hw_week") ?: "" else ""
            val goal = readInt(prefs, "hw_goal", 3).coerceIn(1, 7)
            return WidgetState(
                signedOut = !ready,
                days = if (sameWeek) readInt(prefs, "hw_days", 0) else 0,
                goal = goal,
                week = BooleanArray(7) { weekBits.getOrNull(it) == '1' },
                todayIndex = todayIndex,
                checkedIn = sameDay && prefs.getBoolean("hw_checked_in", false),
                pickId = if (sameDay) text("hw_pick_id") else null,
                pickTitle = if (sameDay) text("hw_pick_title") else null,
                pickMeta = if (sameDay) text("hw_pick_meta") else null,
                sleepLine = if (sameDay) text("hw_sleep_line") else null,
                labelWeek = text("hw_label_week") ?: "",
                labelDays = (if (sameWeek) text("hw_label_days") else text("hw_label_days_zero")) ?: "",
                labelGoalMet = text("hw_label_goal_met"),
                labelCheckIn = text("hw_label_check_in") ?: "",
                labelCheckedIn = text("hw_label_checked_in") ?: "",
                labelForYou = text("hw_label_for_you") ?: "",
                labelOpenForPick = labelOpen,
            )
        }

        /** The plugin stores Dart ints as Long when they don't fit an Int. */
        private fun readInt(prefs: SharedPreferences, key: String, fallback: Int): Int =
            when (val value = prefs.all[key]) {
                is Int -> value
                is Long -> value.toInt()
                else -> fallback
            }
    }
}

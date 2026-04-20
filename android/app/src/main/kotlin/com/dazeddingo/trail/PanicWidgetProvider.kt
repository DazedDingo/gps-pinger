package com.dazeddingo.trail

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen widget entry point for continuous-panic.
 *
 * The widget is deliberately the minimum-viable shape: a single
 * full-width button labelled "Panic" that starts
 * [PanicForegroundService] with the user's chosen duration (via
 * [PanicPrefs]) when tapped. No state mirror, no countdown, no running
 * indicator — the FG service's notification already covers that.
 *
 * Widget buttons dispatch a *broadcast* on tap (PendingIntent
 * constraints — a widget RemoteViews root view can't kick an
 * `Intent.ACTION_VIEW` directly on older Android versions reliably).
 * So we handle `ACTION_WIDGET_PANIC` inside the provider's `onReceive`
 * and hand off to [PanicForegroundService.start] from there. This keeps
 * us on a single well-tested ignition path: native entry → FG service →
 * WorkManager → Flutter dispatcher, same as the QS tile.
 */
class PanicWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.panic_widget)
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, PanicWidgetProvider::class.java)
                    .setAction(ACTION_WIDGET_PANIC),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            views.setOnClickPendingIntent(R.id.panic_widget_button, pendingIntent)
            views.setTextViewText(
                R.id.panic_widget_subtitle,
                "${PanicPrefs.getDurationMinutes(context)} min",
            )
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_WIDGET_PANIC) {
            val minutes = PanicPrefs.getDurationMinutes(context)
            PanicForegroundService.start(context.applicationContext, minutes)
        }
    }

    companion object {
        private const val ACTION_WIDGET_PANIC =
            "com.dazeddingo.trail.WIDGET_PANIC"
    }
}

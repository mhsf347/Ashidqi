package com.ashidqi.app

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

class PrayerTimesWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout).apply {
                val prayerName = widgetData.getString("prayer_name", "--")
                val prayerTime = widgetData.getString("prayer_time", "--:--")
                val location = widgetData.getString("location", "Location")

                setTextViewText(R.id.widget_prayer_name, prayerName)
                setTextViewText(R.id.widget_prayer_time, prayerTime)
                setTextViewText(R.id.widget_location, location)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

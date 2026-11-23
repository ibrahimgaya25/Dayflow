package com.ibrahimgaya25.dayflow

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DayFlowWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.dayflow_widget)
            val count = widgetData.getInt("dayflow_count", 0)
            val tasks = widgetData.getString("dayflow_tasks", "").orEmpty()
            views.setTextViewText(R.id.widget_count, if (count == 1) "1 task" else "$count tasks")
            views.setTextViewText(
                R.id.widget_tasks,
                if (tasks.isBlank()) "Your day is clear." else tasks
            )
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            )
            views.setOnClickPendingIntent(
                R.id.widget_add,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("dayflow://add")
                )
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

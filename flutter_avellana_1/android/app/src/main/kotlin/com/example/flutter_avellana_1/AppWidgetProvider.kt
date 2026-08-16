package com.example.flutter_avellana_1
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File

class AppWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {

            val views = RemoteViews(context.packageName, R.layout.widget_layout)


            val prefs = HomeWidgetPlugin.getData(context)
            val imagePath = prefs.getString("imagePath", null)

            if (imagePath != null) {
                val file = File(imagePath)
                if (file.exists()) {

                    val bitmap = BitmapFactory.decodeFile(file.absolutePath)
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                }
            } else {
                // Imagen por defecto
                views.setImageViewResource(R.id.widget_image, R.drawable.launch_background)
            }


            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
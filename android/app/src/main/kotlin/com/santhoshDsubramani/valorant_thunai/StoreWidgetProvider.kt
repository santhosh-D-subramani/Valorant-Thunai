package com.santhoshDsubramani.valorant_thunai

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.util.concurrent.TimeUnit

class StoreWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.store_widget_layout)

            val isLoggedIn = widgetData.getBoolean("user_logged_in", false)
            val count = widgetData.getInt("skins_count", 0)

            if (!isLoggedIn || count == 0) {
                views.setViewVisibility(R.id.widget_content_view, View.GONE)
                views.setViewVisibility(R.id.widget_empty_view, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_content_view, View.VISIBLE)
                views.setViewVisibility(R.id.widget_empty_view, View.GONE)

                val resetTimestamp = widgetData.getLong("reset_timestamp", 0L)
                val diffMillis = resetTimestamp - System.currentTimeMillis()
                if (diffMillis > 0) {
                    val hours = TimeUnit.MILLISECONDS.toHours(diffMillis)
                    val minutes = TimeUnit.MILLISECONDS.toMinutes(diffMillis) % 60
                    views.setTextViewText(R.id.widget_countdown, "Resets in ${hours}h ${minutes}m")
                } else {
                    views.setTextViewText(R.id.widget_countdown, "Reset pending")
                }

                val itemLayouts = intArrayOf(
                    R.id.widget_item_0,
                    R.id.widget_item_1,
                    R.id.widget_item_2,
                    R.id.widget_item_3
                )
                val imageViews = intArrayOf(
                    R.id.widget_skin_img_0,
                    R.id.widget_skin_img_1,
                    R.id.widget_skin_img_2,
                    R.id.widget_skin_img_3
                )
                val nameViews = intArrayOf(
                    R.id.widget_skin_name_0,
                    R.id.widget_skin_name_1,
                    R.id.widget_skin_name_2,
                    R.id.widget_skin_name_3
                )
                val priceViews = intArrayOf(
                    R.id.widget_skin_price_0,
                    R.id.widget_skin_price_1,
                    R.id.widget_skin_price_2,
                    R.id.widget_skin_price_3
                )

                val hasExpiry = widgetData.getBoolean("has_expiry", false)
                val expiryLabel = widgetData.getString("expiry_label", "") ?: ""
                val expiryTimestamp = widgetData.getLong("expiry_timestamp", 0L)
                val expiryDiffMillis = expiryTimestamp - System.currentTimeMillis()
                if (hasExpiry && expiryLabel.isNotEmpty() && expiryDiffMillis > 0) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        views.setChronometerCountDown(R.id.widget_expiry_line, true)
                        views.setChronometer(
                            R.id.widget_expiry_line,
                            SystemClock.elapsedRealtime() + expiryDiffMillis,
                            "$expiryLabel: %s left",
                            true
                        )
                    } else {
                        val expHours = TimeUnit.MILLISECONDS.toHours(expiryDiffMillis)
                        val expMinutes = TimeUnit.MILLISECONDS.toMinutes(expiryDiffMillis) % 60
                        views.setTextViewText(
                            R.id.widget_expiry_line,
                            "$expiryLabel: ${expHours}h ${expMinutes}m left"
                        )
                    }
                    views.setViewVisibility(R.id.widget_expiry_line, View.VISIBLE)
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        views.setChronometer(R.id.widget_expiry_line, 0L, null, false)
                    }
                    views.setViewVisibility(R.id.widget_expiry_line, View.GONE)
                }

                for (i in 0 until 4) {
                    if (i < count) {
                        views.setViewVisibility(itemLayouts[i], View.VISIBLE)
                        val name = widgetData.getString("skin_${i}_name", "Skin") ?: "Skin"
                        val price = widgetData.getString("skin_${i}_price", "0") ?: "0"
                        val imagePath = widgetData.getString("skin_${i}_image_path", "") ?: ""

                        views.setTextViewText(nameViews[i], name)
                        views.setTextViewText(priceViews[i], "$price VP")

                        if (imagePath.isNotEmpty()) {
                            try {
                                val imgFile = File(imagePath)
                                if (imgFile.exists()) {
                                    val bitmap = BitmapFactory.decodeFile(imgFile.absolutePath)
                                    if (bitmap != null) {
                                        views.setImageViewBitmap(imageViews[i], bitmap)
                                    }
                                }
                            } catch (_: Exception) {
                            }
                        }
                    } else {
                        views.setViewVisibility(itemLayouts[i], View.INVISIBLE)
                    }
                }
            }

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse("valshop://dailyshop")
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}

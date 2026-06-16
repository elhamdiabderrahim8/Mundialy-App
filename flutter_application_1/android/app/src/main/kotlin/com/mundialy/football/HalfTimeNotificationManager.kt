package com.mundialy.football

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.*
import android.os.*
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.NotificationTarget

object HalfTimeNotificationManager {

    private const val CHANNEL_ID = "mundialy_live_alerts_v2"
    private const val NOTIFICATION_ID = 1003

    fun show(context: Context, payload: Map<String, Any?>) {
        createChannel(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scorers = payload["scorers"] as? List<Map<*, *>> ?: emptyList()
        
        val views = RemoteViews(context.packageName, R.layout.notification_half_time)
        
        views.setTextViewText(R.id.ht_score_text, "${home?.get("score") ?: 0} - ${away?.get("score") ?: 0}")
        views.setTextViewText(R.id.ht_subtitle, "Half Time")
        
        if (scorers.isNotEmpty()) {
            val summary = scorers.take(2).joinToString("\n") { 
                "⚽ ${it["name"]} — ${it["team"]}  ${it["minute"]}'"
            }
            views.setTextViewText(R.id.ht_scorers_summary, summary)
        }

        val bgCode = if (scorers.isEmpty()) {
            home?.get("countryCode")?.toString()
        } else {
            val lastScorer = scorers.last()
            val teamName = lastScorer["team"]?.toString()
            if (teamName == home?.get("name")) home?.get("countryCode")?.toString()
            else away?.get("countryCode")?.toString()
        } ?: home?.get("countryCode")?.toString() ?: ""

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views)
            .setCustomContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 150, 50, 150))
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(NOTIFICATION_ID, notification)

        if (bgCode.isNotEmpty()) {
            Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(bgCode, "w160"))
                .transform(FlagRepository.BlurAndDarkenTransformation(10, "#8C000000"))
                .into(NotificationTarget(context, R.id.ht_bg_flag, views, notification, NOTIFICATION_ID))
        }
        
        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ht_logo_home, views, notification, NOTIFICATION_ID))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ht_logo_away, views, notification, NOTIFICATION_ID))
        }

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            views.setViewVisibility(R.id.ht_sweep_line, View.VISIBLE)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 100)

        handler.postDelayed({
            views.setViewVisibility(R.id.ht_sweep_line, View.GONE)
            views.setViewVisibility(R.id.ht_badge, View.VISIBLE)
            views.setFloat(R.id.ht_badge, "setScaleX", 1.15f)
            views.setFloat(R.id.ht_badge, "setScaleY", 1.15f)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 800)

        handler.postDelayed({
            views.setViewVisibility(R.id.ht_score_row, View.VISIBLE)
            views.setViewVisibility(R.id.ht_subtitle, View.VISIBLE)
            if (scorers.isNotEmpty()) {
                views.setViewVisibility(R.id.ht_scorers_summary, View.VISIBLE)
            }
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 1200)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "Match Alerts", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }
    }
}

package com.mundialy.football

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.*
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.NotificationTarget

object FullTimeNotificationManager {

    private const val CHANNEL_ID = "mundialy_live_alerts_v3"
    private const val NOTIFICATION_ID = 1004

    fun show(context: Context, payload: Map<String, Any?>) {
        createChannel(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val winner = payload["winner"]?.toString()
        val duration = payload["duration"]?.toString()
        val motm = payload["manOfMatch"]?.toString()

        val views = RemoteViews(context.packageName, R.layout.notification_full_time)
        views.setTextViewText(R.id.ft_score_text, "${home?.get("score") ?: 0} - ${away?.get("score") ?: 0}")
        views.setTextViewText(R.id.ft_name_home, home?.get("name")?.toString())
        views.setTextViewText(R.id.ft_name_away, away?.get("name")?.toString())
        views.setTextViewText(R.id.ft_duration, if (duration != null) "Full Time • $duration" else "Full Time")

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views)
            .setCustomContentView(views)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(Notification.DEFAULT_ALL)
            .setVibrate(longArrayOf(0, 300, 100, 300))
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(NOTIFICATION_ID, notification)

        val homeCode = home?.get("countryCode")?.toString() ?: ""
        val awayCode = away?.get("countryCode")?.toString() ?: ""

        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond).into(NotificationTarget(context, R.id.ft_logo_home, views, notification, NOTIFICATION_ID))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond).into(NotificationTarget(context, R.id.ft_logo_away, views, notification, NOTIFICATION_ID))
        }

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            views.setViewVisibility(R.id.ft_badge, View.VISIBLE)
            if (!motm.isNullOrEmpty()) {
                views.setTextViewText(R.id.ft_motm, "⭐ Man of the Match: $motm")
                views.setViewVisibility(R.id.ft_motm, View.VISIBLE)
            }
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 500)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "Match Alerts High", NotificationManager.IMPORTANCE_HIGH).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}

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

object MatchStartNotificationManager {
    private const val CHANNEL_ID = "mundialy_live_alerts_v3"
    private const val NOTIFICATION_ID = 1002

    fun show(context: Context, payload: Map<String, Any?>) {
        createChannel(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        
        val views = RemoteViews(context.packageName, R.layout.notification_match_start)
        
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views) // Force le POP-UP
            .setCustomContentView(views)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(Notification.DEFAULT_ALL)
            .setVibrate(longArrayOf(0, 200, 100, 200))
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(NOTIFICATION_ID, notification)

        val homeCode = home?.get("countryCode")?.toString() ?: ""
        val awayCode = away?.get("countryCode")?.toString() ?: ""

        Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(homeCode))
            .into(NotificationTarget(context, R.id.flag_home_bg, views, notification, NOTIFICATION_ID))
        Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(awayCode))
            .into(NotificationTarget(context, R.id.flag_away_bg, views, notification, NOTIFICATION_ID))

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            views.setViewVisibility(R.id.pitch_line, View.VISIBLE)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 800)

        handler.postDelayed({
            views.setViewVisibility(R.id.live_pill, View.VISIBLE)
            views.setViewVisibility(R.id.logo_home_start, View.VISIBLE)
            views.setViewVisibility(R.id.logo_away_start, View.VISIBLE)
            views.setViewVisibility(R.id.match_teams_text, View.VISIBLE)
            views.setTextViewText(R.id.match_teams_text, "${home?.get("name")}  VS  ${away?.get("name")}")
            views.setTextViewText(R.id.match_footer, "${payload["competition"]}  •  ${payload["kickoffTime"]}")
            
            notificationManager.notify(NOTIFICATION_ID, notification)

            val diamond = FlagRepository.DiamondTransformation()
            home?.get("logoUrl")?.toString()?.let { url ->
                Glide.with(context).asBitmap().load(url).transform(diamond)
                    .into(NotificationTarget(context, R.id.logo_home_start, views, notification, NOTIFICATION_ID))
            }
            away?.get("logoUrl")?.toString()?.let { url ->
                Glide.with(context).asBitmap().load(url).transform(diamond)
                    .into(NotificationTarget(context, R.id.logo_away_start, views, notification, NOTIFICATION_ID))
            }
        }, 1500)
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

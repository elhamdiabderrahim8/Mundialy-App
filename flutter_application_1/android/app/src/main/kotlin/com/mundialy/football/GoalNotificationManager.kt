package com.mundialy.football

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.*
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.NotificationTarget

class GoalNotificationManager(private val context: Context) {

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val channelId = "mundialy_live_alerts_v2"
    private val notificationId = 1001

    fun showGoalNotification(payload: Map<String, Any?>) {
        createChannel()

        val rootViews = RemoteViews(context.packageName, R.layout.notification_goal_container)
        
        // Phase 1 Letters
        val letters = arrayOf(R.id.letter_g, R.id.letter_o, R.id.letter_a, R.id.letter_l, R.id.exclamation)
        letters.forEach { rootViews.setViewVisibility(it, View.INVISIBLE) }
        
        // Ensure Phase 1 is displayed first
        rootViews.setDisplayedChild(R.id.goal_view_flipper, 0)

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(rootViews)
            .setCustomContentView(rootViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        val scoringTeam = payload["scoringTeam"] as? String
        val homeData = payload["homeTeam"] as? Map<*, *>
        val awayData = payload["awayTeam"] as? Map<*, *>
        
        val scoringCountryCode = if (scoringTeam == "home") 
            homeData?.get("countryCode")?.toString() else awayData?.get("countryCode")?.toString()

        if (scoringCountryCode != null) {
            FlagRepository.loadFlag(
                context, scoringCountryCode, R.id.bg_flag_blur, 
                rootViews, builder.build(), notificationId,
                size = "w160", isBlurred = true
            )
        }

        val handler = Handler(Looper.getMainLooper())
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        // Phase 1 Animation
        letters.forEachIndexed { index, viewId ->
            handler.postDelayed({
                rootViews.setViewVisibility(viewId, View.VISIBLE)
                vibrate(vibrator, 80)
                notificationManager.notify(notificationId, builder.build())
            }, 220L * index)
        }

        // Phase 2 Transition
        handler.postDelayed({
            updatePhase2Data(rootViews, payload)
            rootViews.setDisplayedChild(R.id.goal_view_flipper, 1)
            
            val notification = builder.build()
            notificationManager.notify(notificationId, notification)
            
            // Load Logos in Phase 2
            val homeLogo = homeData?.get("logoUrl")?.toString()
            val awayLogo = awayData?.get("logoUrl")?.toString()
            if (homeLogo != null) {
                Glide.with(context).asBitmap().load(homeLogo).transform(FlagRepository.DiamondTransformation())
                    .into(NotificationTarget(context, R.id.logo_home, rootViews, notification, notificationId))
            }
            if (awayLogo != null) {
                Glide.with(context).asBitmap().load(awayLogo).transform(FlagRepository.DiamondTransformation())
                    .into(NotificationTarget(context, R.id.logo_away, rootViews, notification, notificationId))
            }
        }, 2500)
    }

    private fun updatePhase2Data(rootViews: RemoteViews, payload: Map<String, Any?>) {
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scoringTeam = payload["scoringTeam"] as? String
        
        rootViews.setTextViewText(R.id.name_home, home?.get("name")?.toString()?.uppercase() ?: "")
        rootViews.setTextViewText(R.id.name_away, away?.get("name")?.toString()?.uppercase() ?: "")
        
        val hScore = home?.get("score")?.toString() ?: "0"
        val aScore = away?.get("score")?.toString() ?: "0"
        
        rootViews.setTextViewText(R.id.score_home_text, hScore)
        rootViews.setTextViewText(R.id.score_away_text, aScore)
        
        // Style new score
        val highlightColor = Color.parseColor("#FF3333")
        val defaultColor = Color.parseColor("#FFD700")
        rootViews.setTextColor(R.id.score_home_text, if (scoringTeam == "home") highlightColor else defaultColor)
        rootViews.setTextColor(R.id.score_away_text, if (scoringTeam == "away") highlightColor else defaultColor)

        rootViews.setTextViewText(R.id.scorer_name, "⚽ " + (payload["scorer"]?.toString() ?: ""))
        rootViews.setTextViewText(R.id.goal_minute, (payload["minute"]?.toString() ?: "") + "'")
        
        val isPenalty = payload["isPenalty"]?.toString()?.toBoolean() ?: false
        rootViews.setViewVisibility(R.id.penalty_badge, if (isPenalty) View.VISIBLE else View.GONE)
    }

    private fun vibrate(vibrator: Vibrator, duration: Long) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            vibrator.vibrate(duration)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Live Goals", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Animated goal alerts"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 80, 40, 80)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showMatchStartNotification(p: Map<String, Any?>) {}
    fun showHalfTimeNotification(p: Map<String, Any?>) {}
    fun showFullTimeNotification(p: Map<String, Any?>) {}
}

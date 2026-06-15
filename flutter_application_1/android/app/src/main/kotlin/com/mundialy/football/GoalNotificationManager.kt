package com.mundialy.football

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.os.Build
import android.os.Handler
import android.os.Looper
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
        
        val homeData = payload["homeTeam"] as? Map<*, *>
        val awayData = payload["awayTeam"] as? Map<*, *>
        val scoringTeam = payload["scoringTeam"] as? String
        
        val scoringCountryCode = if (scoringTeam == "home") 
            homeData?.get("countryCode")?.toString() else awayData?.get("countryCode")?.toString()

        // PHASE 1 : GOAL Animation
        val phase1Views = RemoteViews(context.packageName, R.layout.notification_goal_phase1)
        
        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(phase1Views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVibrate(longArrayOf(0, 80, 40, 80))
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        val notification = notificationBuilder.build()
        notificationManager.notify(notificationId, notification)

        // Charger le drapeau en fond (Phase 1) via FlagRepository (centralise les LOGS)
        if (scoringCountryCode != null) {
            FlagRepository.loadFlagIntoNotification(
                context, scoringCountryCode, R.id.bg_flag_blur, 
                phase1Views, notification, notificationId,
                size = "w160", isBlurred = true
            )
        }

        // Animation des lettres (Simulée par Handler)
        val handler = Handler(Looper.getMainLooper())
        val letters = arrayOf(R.id.letter_g, R.id.letter_o, R.id.letter_a, R.id.letter_l, R.id.exclamation)
        
        letters.forEachIndexed { index, viewId ->
            handler.postDelayed({
                phase1Views.setViewVisibility(viewId, View.VISIBLE)
                notificationManager.notify(notificationId, notificationBuilder.build())
            }, 220L * (index + 1))
        }

        // TRANSITION PHASE 2 (Après 2.5s)
        handler.postDelayed({
            showPhase2(payload, notificationBuilder)
        }, 2500)
    }

    fun showMatchStartNotification(payload: Map<String, Any?>) {
        // ... (code existant)
    }

    fun showHalfTimeNotification(payload: Map<String, Any?>) {
        // ... (existant)
    }

    fun showFullTimeNotification(payload: Map<String, Any?>) {
        createChannel()
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val winner = payload["winner"] as? String ?: "draw"
        
        val ftViews = RemoteViews(context.packageName, R.layout.notification_full_time)
        
        val hScore = home?.get("score")?.toString() ?: "0"
        val aScore = away?.get("score")?.toString() ?: "0"
        ftViews.setTextViewText(R.id.ft_score_text, "$hScore - $aScore")
        
        // Winner/Loser Styling
        ftViews.setTextViewText(R.id.ft_name_home, home?.get("name")?.toString() ?: "")
        ftViews.setTextViewText(R.id.ft_name_away, away?.get("name")?.toString() ?: "")
        
        if (winner == "home") {
            ftViews.setTextColor(R.id.ft_name_home, Color.WHITE)
            ftViews.setTextColor(R.id.ft_name_away, Color.parseColor("#888888"))
        } else if (winner == "away") {
            ftViews.setTextColor(R.id.ft_name_away, Color.WHITE)
            ftViews.setTextColor(R.id.ft_name_home, Color.parseColor("#888888"))
        }

        val duration = payload["duration"]?.toString() ?: ""
        ftViews.setTextViewText(R.id.ft_duration, if (duration.isNotEmpty()) "Full Time  •  $duration" else "Full Time")
        
        val motm = payload["manOfMatch"]?.toString() ?: ""
        if (motm.isNotEmpty()) {
            ftViews.setViewVisibility(R.id.ft_motm, View.VISIBLE)
            ftViews.setTextViewText(R.id.ft_motm, "⭐ Man of the Match: $motm")
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(ftViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVibrate(longArrayOf(0, 300, 100, 300, 100, 300))
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        val notification = builder.build()
        notificationManager.notify(notificationId, notification)

        // Background Logic
        val hIso = home?.get("countryCode")?.toString() ?: "un"
        val aIso = away?.get("countryCode")?.toString() ?: "un"

        if (winner == "draw") {
            FlagRepository.loadFlagIntoNotification(context, hIso, R.id.ft_bg_flag_left, ftViews, notification, notificationId, isBlurred = true, darkenOpacity = 0.45f)
            FlagRepository.loadFlagIntoNotification(context, aIso, R.id.ft_bg_flag_right, ftViews, notification, notificationId, isBlurred = true, darkenOpacity = 0.45f)
            ftViews.setImageViewBitmap(R.id.ft_confetti_overlay, createConfetti(listOf(Color.parseColor("#E7C16A"), Color.WHITE)))
        } else {
            val winIso = if (winner == "home") hIso else aIso
            FlagRepository.loadFlagIntoNotification(context, winIso, R.id.ft_bg_flag_left, ftViews, notification, notificationId, isBlurred = true, darkenOpacity = 0.45f)
            
            // Extraction de couleur pour confettis
            val flagUrl = "https://flagcdn.com/w160/${winIso.lowercase()}.png"
            Glide.with(context).asBitmap().load(flagUrl).into(object : com.bumptech.glide.request.target.CustomTarget<Bitmap>() {
                override fun onResourceReady(resource: Bitmap, transition: com.bumptech.glide.request.transition.Transition<in Bitmap>?) {
                    androidx.palette.graphics.Palette.from(resource).generate { palette ->
                        val color1 = palette?.getVibrantColor(Color.WHITE) ?: Color.WHITE
                        val color2 = palette?.getDominantColor(Color.YELLOW) ?: Color.YELLOW
                        ftViews.setImageViewBitmap(R.id.ft_confetti_overlay, createConfetti(listOf(color1, color2)))
                        notificationManager.notify(notificationId, builder.build())
                    }
                }
                override fun onLoadCleared(placeholder: android.graphics.drawable.Drawable?) {}
            })
        }

        // Logos
        val homeLogo = home?.get("logoUrl")?.toString()
        val awayLogo = away?.get("logoUrl")?.toString()
        if (homeLogo != null) {
            Glide.with(context).asBitmap().load(homeLogo).transform(FlagRepository.DiamondTransformation())
                .into(NotificationTarget(context, R.id.ft_logo_home, ftViews, notification, notificationId))
        }
        if (awayLogo != null) {
            Glide.with(context).asBitmap().load(awayLogo).transform(FlagRepository.DiamondTransformation())
                .into(NotificationTarget(context, R.id.ft_logo_away, ftViews, notification, notificationId))
        }

        // Animation FT Badge
        Handler(Looper.getMainLooper()).postDelayed({
            ftViews.setViewVisibility(R.id.ft_badge, View.VISIBLE)
            notificationManager.notify(notificationId, builder.build())
        }, 600)
    }

    private fun createConfetti(colors: List<Int>): Bitmap {
        val b = Bitmap.createBitmap(500, 250, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(b)
        val p = Paint()
        val random = java.util.Random()
        for (i in 0..60) {
            p.color = colors[random.nextInt(colors.size)]
            val x = random.nextFloat() * 500
            val y = random.nextFloat() * 250
            val size = 4f + random.nextFloat() * 6f
            if (random.nextBoolean()) canvas.drawRect(x, y, x+size, y+size, p) 
            else canvas.drawCircle(x, y, size/2, p)
        }
        return b
    }

    private fun showPhase2(payload: Map<String, Any?>, builder: NotificationCompat.Builder) {
        val phase2Views = RemoteViews(context.packageName, R.layout.notification_goal_phase2)
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        
        phase2Views.setTextViewText(R.id.name_home, home?.get("name")?.toString() ?: "TBD")
        phase2Views.setTextViewText(R.id.name_away, away?.get("name")?.toString() ?: "TBD")
        phase2Views.setTextViewText(R.id.score_home_text, home?.get("score")?.toString() ?: "0")
        phase2Views.setTextViewText(R.id.score_away_text, away?.get("score")?.toString() ?: "0")
        
        phase2Views.setTextViewText(R.id.scorer_name, "⚽ " + (payload["scorer"]?.toString() ?: "But"))
        phase2Views.setTextViewText(R.id.goal_minute, (payload["minute"]?.toString() ?: "0") + "'")
        
        if (payload["isPenalty"] == true || payload["isPenalty"] == "true") {
            phase2Views.setViewVisibility(R.id.penalty_badge, View.VISIBLE)
        }

        builder.setCustomHeadsUpContentView(phase2Views)
        builder.setCustomContentView(phase2Views)
        
        val notification = builder.build()
        notificationManager.notify(notificationId, notification)

        // Logos en Phase 2 (Style Diamond)
        val homeLogo = home?.get("logoUrl")?.toString()
        val awayLogo = away?.get("logoUrl")?.toString()
        
        if (homeLogo != null) {
            Glide.with(context).asBitmap().load(homeLogo).transform(FlagRepository.DiamondTransformation())
                .into(NotificationTarget(context, R.id.logo_home, phase2Views, notification, notificationId))
        }
        if (awayLogo != null) {
            Glide.with(context).asBitmap().load(awayLogo).transform(FlagRepository.DiamondTransformation())
                .into(NotificationTarget(context, R.id.logo_away, phase2Views, notification, notificationId))
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Live Matches", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Goal and match alerts"
                enableLights(true)
                lightColor = Color.YELLOW
                enableVibration(true)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}

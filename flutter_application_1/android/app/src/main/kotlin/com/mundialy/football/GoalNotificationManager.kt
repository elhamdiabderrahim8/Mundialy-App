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

class GoalNotificationManager(private val context: Context) {

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val channelId = "mundialy_live_alerts_v2"
    private val notificationId = 1001

    fun showGoalNotification(payload: Map<String, Any?>) {
        createChannel()

        val rootViews = RemoteViews(context.packageName, R.layout.notification_goal_container)
        
        // Initial state
        val letterIds = arrayOf(R.id.img_g, R.id.img_o, R.id.img_a, R.id.img_l)
        letterIds.forEach { rootViews.setViewVisibility(it, View.INVISIBLE) }
        rootViews.setViewVisibility(R.id.exclamation, View.INVISIBLE)
        rootViews.setDisplayedChild(R.id.goal_view_flipper, 0)

        val scoringTeam = payload["scoringTeam"]?.toString()
        val homeData = payload["homeTeam"] as? Map<*, *>
        val awayData = payload["awayTeam"] as? Map<*, *>
        
        val scoringCountryCode = if (scoringTeam == "home") {
            homeData?.get("countryCode")?.toString() ?: payload["homeCountryCode"]?.toString()
        } else {
            awayData?.get("countryCode")?.toString() ?: payload["awayCountryCode"]?.toString()
        }

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(rootViews)
            .setCustomContentView(rootViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        // 1. Generation des lettres Premium (Texture Drapeau)
        if (scoringCountryCode != null) {
            val flagUrl = "https://flagcdn.com/w160/${scoringCountryCode.lowercase()}.png"
            
            Thread {
                try {
                    val flagBitmap = Glide.with(context).asBitmap().load(flagUrl).submit().get()
                    val letters = arrayOf("G", "O", "A", "L")
                    
                    Handler(Looper.getMainLooper()).post {
                        letters.forEachIndexed { i, letter ->
                            val letterBitmap = createPremiumLetter(letter, flagBitmap)
                            rootViews.setImageViewBitmap(letterIds[i], letterBitmap)
                        }
                        
                        // Start animation sequence
                        animateGoalLetters(rootViews, builder)
                    }
                } catch (e: Exception) {
                    Handler(Looper.getMainLooper()).post { animateGoalLetters(rootViews, builder) }
                }
            }.start()
            
            // Background flag (blurred)
            FlagRepository.loadFlag(context, scoringCountryCode, R.id.bg_flag_blur, rootViews, builder.build(), notificationId, isBlurred = true)
        }

        // Transition Phase 2 after 2.8s
        Handler(Looper.getMainLooper()).postDelayed({
            setupPhase2UI(rootViews, payload)
            rootViews.setDisplayedChild(R.id.goal_view_flipper, 1)
            
            val notification = builder.build()
            notificationManager.notify(notificationId, notification)
            
            // Phase 2 Logos
            loadLogosPhase2(context, payload, rootViews, notification)
        }, 2800)
    }

    private fun createPremiumLetter(letter: String, flag: Bitmap): Bitmap {
        val width = 110 // Plus fin
        val height = 140
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.textSize = 120f // Taille reduite pour plus d'elegance
        paint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        paint.textAlign = Paint.Align.CENTER
        
        // Phase 1: Draw Text Mask
        canvas.drawText(letter, width / 2f, height * 0.8f, paint)
        
        // Phase 2: Fill with Flag
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(flag, Rect(0, 0, flag.width, flag.height), Rect(0, 0, width, height), paint)
        
        // Phase 3: Ultra-thin Silver Outline
        paint.xfermode = null
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 2f
        paint.color = Color.parseColor("#E0E0E0") // Argent doux
        canvas.drawText(letter, width / 2f, height * 0.8f, paint)
        
        return bitmap
    }

    private fun animateGoalLetters(rootViews: RemoteViews, builder: NotificationCompat.Builder) {
        val ids = arrayOf(R.id.img_g, R.id.img_o, R.id.img_a, R.id.img_l, R.id.exclamation)
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        val handler = Handler(Looper.getMainLooper())
        
        ids.forEachIndexed { i, id ->
            handler.postDelayed({
                rootViews.setViewVisibility(id, View.VISIBLE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createOneShot(50, 100))
                }
                notificationManager.notify(notificationId, builder.build())
            }, 220L * i)
        }
    }

    private fun setupPhase2UI(rootViews: RemoteViews, payload: Map<String, Any?>) {
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scoringTeam = payload["scoringTeam"]?.toString()
        
        // Extraction robuste des noms
        val nameHome = home?.get("name")?.toString() 
            ?: payload["homeTeamName"]?.toString() 
            ?: payload["home"]?.toString() 
            ?: "HOME"
            
        val nameAway = away?.get("name")?.toString() 
            ?: payload["awayTeamName"]?.toString() 
            ?: payload["away"]?.toString() 
            ?: "AWAY"

        rootViews.setTextViewText(R.id.name_home, nameHome.uppercase())
        rootViews.setTextViewText(R.id.name_away, nameAway.uppercase())
        
        // Extraction robuste des scores
        val hScore = home?.get("score")?.toString() ?: payload["homeScore"]?.toString() ?: "0"
        val aScore = away?.get("score")?.toString() ?: payload["awayScore"]?.toString() ?: "0"
        
        rootViews.setTextViewText(R.id.score_home_text, hScore)
        rootViews.setTextViewText(R.id.score_away_text, aScore)
        
        // Highlight logic
        val scoreColor = Color.WHITE
        val highlightColor = Color.parseColor("#FF3333")
        rootViews.setTextColor(R.id.score_home_text, if (scoringTeam == "home") highlightColor else scoreColor)
        rootViews.setTextColor(R.id.score_away_text, if (scoringTeam == "away") highlightColor else scoreColor)

        val scorer = payload["scorer"]?.toString() ?: payload["scorerName"]?.toString() ?: "Goal"
        val minute = payload["minute"]?.toString() ?: ""
        
        rootViews.setTextViewText(R.id.scorer_name, "⚽ $scorer")
        rootViews.setTextViewText(R.id.goal_minute, if (minute.isNotEmpty()) "$minute'" else "")
    }

    private fun loadLogosPhase2(ctx: Context, payload: Map<String, Any?>, views: RemoteViews, notif: android.app.Notification) {
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        
        val homeLogo = home?.get("logoUrl")?.toString() ?: payload["homeLogoUrl"]?.toString()
        val awayLogo = away?.get("logoUrl")?.toString() ?: payload["awayLogoUrl"]?.toString()
        
        if (homeLogo != null && homeLogo.isNotEmpty()) {
            Glide.with(ctx).asBitmap().load(homeLogo).transform(FlagRepository.DiamondTransformation())
                .into(NotificationTarget(ctx, R.id.logo_home, views, notif, notificationId))
        }
        if (awayLogo != null && awayLogo.isNotEmpty()) {
            Glide.with(ctx).asBitmap().load(awayLogo).transform(FlagRepository.DiamondTransformation())
                .into(NotificationTarget(ctx, R.id.logo_away, views, notif, notificationId))
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Match Alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}

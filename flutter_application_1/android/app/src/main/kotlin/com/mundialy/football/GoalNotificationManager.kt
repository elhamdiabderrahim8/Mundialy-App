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
        
        // Phase 1 Preparation
        val letterIds = arrayOf(R.id.img_g, R.id.img_o, R.id.img_a, R.id.img_l)
        letterIds.forEach { rootViews.setViewVisibility(it, View.INVISIBLE) }
        rootViews.setViewVisibility(R.id.exclamation, View.INVISIBLE)
        rootViews.setDisplayedChild(R.id.goal_view_flipper, 0)

        val scoringTeam = payload["scoringTeam"] as? String
        val homeData = payload["homeTeam"] as? Map<*, *>
        val awayData = payload["awayTeam"] as? Map<*, *>
        val scoringCountryCode = if (scoringTeam == "home") 
            homeData?.get("countryCode")?.toString() else awayData?.get("countryCode")?.toString()

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(rootViews)
            .setCustomContentView(rootViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        // 1. Generation des lettres "Flag-Text"
        if (scoringCountryCode != null) {
            val flagUrl = "https://flagcdn.com/w160/${scoringCountryCode.lowercase()}.png"
            
            val fallbackHandler = Handler(Looper.getMainLooper())
            var hasStarted = false

            // Securite : Si le flag ne charge pas en 2.5s, on lance quand meme avec des couleurs
            val fallbackRunnable = Runnable {
                if (!hasStarted) {
                    hasStarted = true
                    animateLetters(rootViews, builder)
                }
            }
            fallbackHandler.postDelayed(fallbackRunnable, 2500)

            // On charge le drapeau en Bitmap pour creer les lettres
            Thread {
                try {
                    val flagBitmap = Glide.with(context).asBitmap().load(flagUrl).submit().get()
                    val letters = arrayOf("G", "O", "A", "L")
                    
                    Handler(Looper.getMainLooper()).post {
                        if (!hasStarted) {
                            hasStarted = true
                            fallbackHandler.removeCallbacks(fallbackRunnable)
                            letters.forEachIndexed { i, letter ->
                                val letterBitmap = createFlagLetterBitmap(letter, flagBitmap)
                                rootViews.setImageViewBitmap(letterIds[i], letterBitmap)
                            }
                            animateLetters(rootViews, builder)
                        }
                    }
                } catch (e: Exception) {
                    Handler(Looper.getMainLooper()).post { fallbackRunnable.run() }
                }
            }.start()
        } else {
            animateLetters(rootViews, builder)
        }

        // Transition to Phase 2 after 2.5s
        Handler(Looper.getMainLooper()).postDelayed({
            updatePhase2UI(rootViews, payload)
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
        }, 2800)
    }

    private fun createFlagLetterBitmap(letter: String, flag: Bitmap): Bitmap {
        val width = 120
        val height = 160
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.textSize = 140f
        paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        paint.textAlign = Paint.Align.CENTER
        
        // 1. Draw Text Mask
        canvas.drawText(letter, width / 2f, height * 0.8f, paint)
        
        // 2. Composite with Flag using PorterDuff
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        val flagRect = Rect(0, 0, flag.width, flag.height)
        val destRect = Rect(0, 0, width, height)
        canvas.drawBitmap(flag, flagRect, destRect, paint)
        
        // 3. Add a slight white stroke for professional look
        paint.xfermode = null
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 3f
        paint.color = Color.WHITE
        canvas.drawText(letter, width / 2f, height * 0.8f, paint)
        
        return bitmap
    }

    private fun animateLetters(rootViews: RemoteViews, builder: NotificationCompat.Builder) {
        val ids = arrayOf(R.id.img_g, R.id.img_o, R.id.img_a, R.id.img_l, R.id.exclamation)
        val handler = Handler(Looper.getMainLooper())
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        ids.forEachIndexed { index, viewId ->
            handler.postDelayed({
                rootViews.setViewVisibility(viewId, View.VISIBLE)
                vibrate(vibrator, 70)
                notificationManager.notify(notificationId, builder.build())
            }, 220L * index)
        }
    }

    private fun updatePhase2UI(rootViews: RemoteViews, payload: Map<String, Any?>) {
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scoringTeam = payload["scoringTeam"] as? String
        
        rootViews.setTextViewText(R.id.name_home, home?.get("name")?.toString()?.uppercase() ?: "")
        rootViews.setTextViewText(R.id.name_away, away?.get("name")?.toString()?.uppercase() ?: "")
        
        val hScore = home?.get("score")?.toString() ?: "0"
        val aScore = away?.get("score")?.toString() ?: "0"
        
        rootViews.setTextViewText(R.id.score_home_text, hScore)
        rootViews.setTextViewText(R.id.score_away_text, aScore)
        
        val highlightColor = Color.parseColor("#FF3333")
        val defaultColor = Color.parseColor("#E7C16A")
        rootViews.setTextColor(R.id.score_home_text, if (scoringTeam == "home") highlightColor else defaultColor)
        rootViews.setTextColor(R.id.score_away_text, if (scoringTeam == "away") highlightColor else defaultColor)

        rootViews.setTextViewText(R.id.scorer_name, "⚽ " + (payload["scorer"]?.toString() ?: "But Scored"))
        rootViews.setTextViewText(R.id.goal_minute, (payload["minute"]?.toString() ?: "") + "'")
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
                setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI, null)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }

    fun showMatchStartNotification(p: Map<String, Any?>) {}
    fun showHalfTimeNotification(p: Map<String, Any?>) {}
    fun showFullTimeNotification(p: Map<String, Any?>) {}
}

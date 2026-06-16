package com.mundialy.football

import android.app.Notification
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

object GoalNotificationManager {

    private const val CHANNEL_ID = "mundialy_live_alerts_v3" // Nouveau canal pour forcer les réglages
    private const val NOTIFICATION_ID = 1001

    fun show(context: Context, payload: Map<String, Any?>) {
        createChannel(context)
        
        val handler = Handler(Looper.getMainLooper())
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val scoringTeam = payload["scoringTeam"]?.toString()
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scoringCountry = if (scoringTeam == "home") home?.get("countryCode")?.toString() else away?.get("countryCode")?.toString()

        val phase1 = RemoteViews(context.packageName, R.layout.notification_goal_phase1)
        // IMAGE 1 FIX: On ne met PAS de background drapeau flou. Le layout reste noir (#0D0D1A).
        phase1.setViewVisibility(R.id.bg_flag_blur, View.GONE) 

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(phase1) // Force l'affichage en haut
            .setCustomContentView(phase1)
            .setPriority(NotificationCompat.PRIORITY_MAX) // Urgence maximale pour pop-up
            .setDefaults(Notification.DEFAULT_ALL) // Force vibration + visuel
            .setVibrate(longArrayOf(0, 100, 50, 100))
            .setOnlyAlertOnce(false) // Permet de mettre à jour visuellement
            .setAutoCancel(true)

        Thread {
            val flagUrl = scoringCountry?.let { FlagRepository.getFlagUrl(it, "w160") }
            val flagBitmap: Bitmap? = try {
                if (flagUrl != null) Glide.with(context).asBitmap().load(flagUrl).submit().get() else null
            } catch (e: Exception) { null }

            handler.post {
                notificationManager.notify(NOTIFICATION_ID, builder.build())

                val letters = arrayOf("G", "O", "A", "L")
                val letterIds = arrayOf(R.id.letter_g, R.id.letter_o, R.id.letter_a, R.id.letter_l)
                val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

                letters.forEachIndexed { i, letter ->
                    handler.postDelayed({
                        val letterBitmap = createLetterBitmap(letter, flagBitmap)
                        phase1.setImageViewBitmap(letterIds[i], letterBitmap)
                        phase1.setViewVisibility(letterIds[i], View.VISIBLE)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(VibrationEffect.createOneShot(50, 100))
                        }
                        notificationManager.notify(NOTIFICATION_ID, builder.build())
                    }, 220L * i)
                }

                handler.postDelayed({
                    phase1.setViewVisibility(R.id.exclamation, View.VISIBLE)
                    notificationManager.notify(NOTIFICATION_ID, builder.build())
                }, 220L * letters.size)

                // TRANSITION VERS PHASE 2 (Image 2)
                handler.postDelayed({
                    val phase2 = RemoteViews(context.packageName, R.layout.notification_goal_phase2)
                    setupPhase2UI(phase2, payload)
                    
                    builder.setCustomHeadsUpContentView(phase2)
                    builder.setCustomContentView(phase2)
                    
                    val phase2Notification = builder.build()
                    notificationManager.notify(NOTIFICATION_ID, phase2Notification)
                    loadLogosPhase2(context, phase2, home, away, phase2Notification)
                }, 2500)
            }
        }.start()
    }

    private fun createLetterBitmap(letter: String, flag: Bitmap?): Bitmap {
        val width = 110
        val height = 150
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        paint.textSize = 120f
        paint.typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
        paint.textAlign = Paint.Align.CENTER
        if (flag != null) {
            // Dessine la lettre
            canvas.drawText(letter, width / 2f, height * 0.8f, paint)
            // Masque avec le drapeau (Image 1)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            canvas.drawBitmap(flag, Rect(0, 0, flag.width, flag.height), Rect(0, 0, width, height), paint)
            paint.xfermode = null
            // Contour de la lettre
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 3f
            paint.color = Color.parseColor("#E0E0E0")
            canvas.drawText(letter, width / 2f, height * 0.8f, paint)
        } else {
            paint.color = Color.parseColor("#FFD700")
            canvas.drawText(letter, width / 2f, height * 0.8f, paint)
        }
        return bitmap
    }

    private fun setupPhase2UI(views: RemoteViews, payload: Map<String, Any?>) {
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scoringTeam = payload["scoringTeam"]?.toString()
        
        views.setTextViewText(R.id.name_home, home?.get("name")?.toString()?.uppercase())
        views.setTextViewText(R.id.name_away, away?.get("name")?.toString()?.uppercase())
        views.setTextViewText(R.id.score_home, home?.get("score")?.toString() ?: "0")
        views.setTextViewText(R.id.score_away, away?.get("score")?.toString() ?: "0")
        
        // IMAGE 2 FIX: Le score du buteur passe en ROUGE
        val red = Color.parseColor("#FF3333")
        val white = Color.WHITE
        if (scoringTeam == "home") {
            views.setTextColor(R.id.score_home, red)
            views.setTextColor(R.id.score_away, white)
        } else {
            views.setTextColor(R.id.score_home, white)
            views.setTextColor(R.id.score_away, red)
        }
        
        // Marqueur⚽ (Image 2)
        views.setTextViewText(R.id.scorer_info, "⚽ ${payload["scorer"]}")
        views.setTextViewText(R.id.minute_pill, "${payload["minute"]}'")
        if (payload["isPenalty"] == "true") views.setViewVisibility(R.id.penalty_badge, View.VISIBLE)
    }

    private fun loadLogosPhase2(context: Context, views: RemoteViews, home: Map<*, *>?, away: Map<*, *>?, notif: Notification) {
        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond).into(NotificationTarget(context, R.id.logo_home, views, notif, NOTIFICATION_ID))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond).into(NotificationTarget(context, R.id.logo_away, views, notif, NOTIFICATION_ID))
        }
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "Match Alerts High", NotificationManager.IMPORTANCE_HIGH).apply {
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 100, 50, 100)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}

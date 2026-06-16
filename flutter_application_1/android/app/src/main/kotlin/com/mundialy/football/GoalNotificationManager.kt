package com.mundialy.football

import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.View
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.request.RequestOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

object GoalNotificationManager {
    fun show(context: Context, data: Map<String, String>) {
        val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        
        fun vibrate(duration: Long) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(duration)
            }
        }

        CoroutineScope(Dispatchers.IO).launch {
            val scoringCountryCode = data["scoringCountryCode"] ?: "un"
            val homeCountryCode = data["homeCountryCode"] ?: "un"
            val awayCountryCode = data["awayCountryCode"] ?: "un"
            val homeTeamName = data["homeTeamName"] ?: "Home"
            val awayTeamName = data["awayTeamName"] ?: "Away"
            val homeScore = data["homeScore"] ?: "0"
            val awayScore = data["awayScore"] ?: "0"
            val scoringTeam = data["scoringTeam"] ?: "home"
            val scorerName = data["scorerName"] ?: "Unknown"
            val minute = data["minute"] ?: "0"
            val isPenalty = data["isPenalty"]?.toBoolean() ?: false

            val flagUrl = "https://flagcdn.com/w160/${scoringCountryCode}.png"
            val flagBitmap = Glide.with(context)
                .asBitmap()
                .load(flagUrl)
                .submit()
                .get()

            val homeUrl = "https://flagcdn.com/w160/${homeCountryCode}.png"
            val homeLogo = Glide.with(context)
                .asBitmap()
                .load(homeUrl)
                .apply(RequestOptions().transform(DiamondFlagTransformation()))
                .submit(120, 120)
                .get()

            val awayUrl = "https://flagcdn.com/w160/${awayCountryCode}.png"
            val awayLogo = Glide.with(context)
                .asBitmap()
                .load(awayUrl)
                .apply(RequestOptions().transform(DiamondFlagTransformation()))
                .submit(120, 120)
                .get()

            fun createGoalBitmap(textToDraw: String, drawExclaim: Boolean): android.graphics.Bitmap {
                val width = 800
                val height = 240
                val resultBitmap = android.graphics.Bitmap.createBitmap(width, height, android.graphics.Bitmap.Config.ARGB_8888)
                val canvas = android.graphics.Canvas(resultBitmap)
                
                val textPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                    textSize = 180f
                    typeface = android.graphics.Typeface.create("sans-serif-black", android.graphics.Typeface.NORMAL)
                    textAlign = android.graphics.Paint.Align.LEFT
                }

                val goalWidth = textPaint.measureText("GOAL")
                val exclWidth = textPaint.measureText("!")
                val totalWidth = goalWidth + exclWidth
                
                val startX = (width - totalWidth) / 2
                val startY = (height / 2) - ((textPaint.descent() + textPaint.ascent()) / 2)

                val goalHeight = textPaint.descent() - textPaint.ascent()
                if (goalWidth > 0 && goalHeight > 0) {
                    val scaledFlag = android.graphics.Bitmap.createScaledBitmap(flagBitmap, goalWidth.toInt(), goalHeight.toInt(), true)
                    val shader = android.graphics.BitmapShader(scaledFlag, android.graphics.Shader.TileMode.CLAMP, android.graphics.Shader.TileMode.CLAMP)
                    val matrix = android.graphics.Matrix()
                    matrix.setTranslate(startX, startY + textPaint.ascent())
                    shader.setLocalMatrix(matrix)
                    textPaint.shader = shader
                }

                canvas.drawText(textToDraw, startX, startY, textPaint)

                if (drawExclaim) {
                    val exclPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG).apply {
                        textSize = 180f
                        typeface = android.graphics.Typeface.create("sans-serif-black", android.graphics.Typeface.NORMAL)
                        textAlign = android.graphics.Paint.Align.LEFT
                        color = android.graphics.Color.parseColor("#FFD700")
                    }
                    canvas.drawText("!", startX + goalWidth, startY, exclPaint)
                }
                return resultBitmap
            }

            withContext(Dispatchers.Main) {
                val pkg = context.packageName
                val handler = Handler(Looper.getMainLooper())
                
                val views1 = RemoteViews(pkg, R.layout.notification_goal_phase1)
                
                views1.setImageViewBitmap(R.id.iv_goal_text_image, createGoalBitmap("", false))
                notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))

                handler.postDelayed({
                    views1.setImageViewBitmap(R.id.iv_goal_text_image, createGoalBitmap("G", false))
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(60)
                }, 100)
                handler.postDelayed({
                    views1.setImageViewBitmap(R.id.iv_goal_text_image, createGoalBitmap("GO", false))
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(60)
                }, 320)
                handler.postDelayed({
                    views1.setImageViewBitmap(R.id.iv_goal_text_image, createGoalBitmap("GOA", false))
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(60)
                }, 540)
                handler.postDelayed({
                    views1.setImageViewBitmap(R.id.iv_goal_text_image, createGoalBitmap("GOAL", false))
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(80)
                }, 760)
                handler.postDelayed({
                    views1.setImageViewBitmap(R.id.iv_goal_text_image, createGoalBitmap("GOAL", true))
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(120)
                }, 1100)

                handler.postDelayed({
                    val views2 = RemoteViews(pkg, R.layout.notification_goal_phase2)
                    
                    views2.setImageViewBitmap(R.id.iv_home_logo, homeLogo)
                    views2.setImageViewBitmap(R.id.iv_away_logo, awayLogo)
                    
                    views2.setTextViewText(R.id.tv_home_name, homeTeamName)
                    views2.setTextViewText(R.id.tv_away_name, awayTeamName)
                    
                    views2.setTextViewText(R.id.tv_score_home, homeScore)
                    views2.setTextViewText(R.id.tv_score_away, awayScore)
                    
                    if (scoringTeam == "home") {
                        views2.setTextColor(R.id.tv_score_home, Color.parseColor("#FF3C3C"))
                    } else {
                        views2.setTextColor(R.id.tv_score_away, Color.parseColor("#FF3C3C"))
                    }
                    
                    views2.setTextViewText(R.id.tv_scorer_name, "⚽ $scorerName")
                    views2.setTextViewText(R.id.tv_minute, "${minute}'")
                    views2.setViewVisibility(
                        R.id.tv_penalty,
                        if (isPenalty) View.VISIBLE else View.GONE
                    )
                    
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views2, context))
                    vibrate(100)
                }, 2400)
            }
        }
    }
}

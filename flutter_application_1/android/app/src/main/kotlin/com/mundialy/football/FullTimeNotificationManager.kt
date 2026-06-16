package com.mundialy.football

import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
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

object FullTimeNotificationManager {
    fun show(context: Context, data: Map<String, String>) {
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        fun vibratePattern() {
            val pattern = longArrayOf(0, 300, 100, 300, 100, 300)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
        }

        CoroutineScope(Dispatchers.IO).launch {
            val homeCountryCode = data["homeCountryCode"] ?: "un"
            val awayCountryCode = data["awayCountryCode"] ?: "un"
            val homeTeamName = data["homeTeamName"] ?: "Home"
            val awayTeamName = data["awayTeamName"] ?: "Away"
            val homeScore = data["homeScore"] ?: "0"
            val awayScore = data["awayScore"] ?: "0"
            val motm = data["motm"]

            val homeScoreInt = homeScore.toIntOrNull() ?: 0
            val awayScoreInt = awayScore.toIntOrNull() ?: 0

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

            withContext(Dispatchers.Main) {
                val views = RemoteViews(context.packageName, R.layout.notification_full_time)
                views.setImageViewBitmap(R.id.iv_home_logo, homeLogo)
                views.setImageViewBitmap(R.id.iv_away_logo, awayLogo)
                
                views.setTextViewText(R.id.tv_home_name, homeTeamName)
                views.setTextViewText(R.id.tv_away_name, awayTeamName)
                views.setTextViewText(R.id.tv_score_home, homeScore)
                views.setTextViewText(R.id.tv_score_away, awayScore)
                
                val winnerColor = Color.parseColor("#E6FFFFFF")
                val loserColor = Color.parseColor("#59FFFFFF")
                val defaultColor = Color.parseColor("#FFFFFF")
                
                if (homeScoreInt > awayScoreInt) {
                    views.setTextColor(R.id.tv_home_name, winnerColor)
                    views.setTextColor(R.id.tv_score_home, winnerColor)
                    views.setTextColor(R.id.tv_away_name, loserColor)
                    views.setTextColor(R.id.tv_score_away, loserColor)
                } else if (awayScoreInt > homeScoreInt) {
                    views.setTextColor(R.id.tv_away_name, winnerColor)
                    views.setTextColor(R.id.tv_score_away, winnerColor)
                    views.setTextColor(R.id.tv_home_name, loserColor)
                    views.setTextColor(R.id.tv_score_home, loserColor)
                } else {
                    views.setTextColor(R.id.tv_home_name, winnerColor)
                    views.setTextColor(R.id.tv_score_home, defaultColor)
                    views.setTextColor(R.id.tv_away_name, winnerColor)
                    views.setTextColor(R.id.tv_score_away, defaultColor)
                }
                
                if (motm != null && motm.isNotBlank()) {
                    views.setTextViewText(R.id.tv_motm, motm)
                    views.setViewVisibility(R.id.tv_motm, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.tv_motm, View.GONE)
                }
                
                val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views, context))
                vibratePattern()
            }
        }
    }
}

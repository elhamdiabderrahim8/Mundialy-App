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
import com.bumptech.glide.load.MultiTransformation
import com.bumptech.glide.request.RequestOptions
import jp.wasabeef.glide.transformations.BlurTransformation
import jp.wasabeef.glide.transformations.ColorFilterTransformation
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
            
            val blurredFlag = Glide.with(context)
                .asBitmap()
                .load(flagUrl)
                .apply(RequestOptions().transform(
                    MultiTransformation(
                        BlurTransformation(12),
                        ColorFilterTransformation(Color.parseColor("#99000000"))
                    )
                ))
                .submit(800, 200)
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

            withContext(Dispatchers.Main) {
                val pkg = context.packageName
                val handler = Handler(Looper.getMainLooper())
                
                val views1 = RemoteViews(pkg, R.layout.notification_goal_phase1)
                views1.setImageViewBitmap(R.id.iv_flag_bg, blurredFlag)
                views1.setFloat(R.id.iv_flag_bg, "setAlpha", 0.35f)
                views1.setViewVisibility(R.id.tv_letter_g, View.INVISIBLE)
                views1.setViewVisibility(R.id.tv_letter_o, View.INVISIBLE)
                views1.setViewVisibility(R.id.tv_letter_a, View.INVISIBLE)
                views1.setViewVisibility(R.id.tv_letter_l, View.INVISIBLE)
                views1.setViewVisibility(R.id.tv_exclaim,  View.INVISIBLE)
                
                notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))

                handler.postDelayed({
                    views1.setViewVisibility(R.id.tv_letter_g, View.VISIBLE)
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(60)
                }, 100)
                handler.postDelayed({
                    views1.setViewVisibility(R.id.tv_letter_o, View.VISIBLE)
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(60)
                }, 320)
                handler.postDelayed({
                    views1.setViewVisibility(R.id.tv_letter_a, View.VISIBLE)
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(60)
                }, 540)
                handler.postDelayed({
                    views1.setViewVisibility(R.id.tv_letter_l, View.VISIBLE)
                    notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views1, context))
                    vibrate(80)
                }, 760)
                handler.postDelayed({
                    views1.setViewVisibility(R.id.tv_exclaim, View.VISIBLE)
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

package com.mundialy.football

import android.app.NotificationManager
import android.content.Context
import android.widget.RemoteViews
import com.bumptech.glide.Glide
import com.bumptech.glide.request.RequestOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

object MatchStartNotificationManager {
    fun show(context: Context, data: Map<String, String>) {
        CoroutineScope(Dispatchers.IO).launch {
            val homeCountryCode = data["homeCountryCode"] ?: "un"
            val awayCountryCode = data["awayCountryCode"] ?: "un"
            val homeTeamName = data["homeTeamName"] ?: "Home"
            val awayTeamName = data["awayTeamName"] ?: "Away"
            val competition = data["competition"] ?: "Competition"

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
                val views = RemoteViews(context.packageName, R.layout.notification_match_start)
                views.setImageViewBitmap(R.id.iv_home_logo, homeLogo)
                views.setImageViewBitmap(R.id.iv_away_logo, awayLogo)
                views.setTextViewText(R.id.tv_home_name, homeTeamName)
                views.setTextViewText(R.id.tv_away_name, awayTeamName)
                views.setTextViewText(R.id.tv_competition, competition)
                
                val notifManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notifManager.notify(NotificationChannelSetup.NOTIF_ID, NotificationChannelSetup.buildNotif(views, context))
            }
        }
    }
}

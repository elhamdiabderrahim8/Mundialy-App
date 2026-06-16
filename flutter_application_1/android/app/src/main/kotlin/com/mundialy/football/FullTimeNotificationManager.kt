package com.mundialy.football

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.graphics.*
import android.os.*
import android.text.Html
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.palette.graphics.Palette
import com.bumptech.glide.Glide
import com.bumptech.glide.request.target.NotificationTarget

object FullTimeNotificationManager {

    private const val CHANNEL_ID = "mundialy_live_alerts_v2"
    private const val NOTIFICATION_ID = 1004

    fun show(context: Context, payload: Map<String, Any?>) {
        createChannel(context)
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val winner = payload["winner"]?.toString()
        val duration = payload["duration"]?.toString()
        val motm = payload["manOfMatch"]?.toString()

        val views = RemoteViews(context.packageName, R.layout.notification_full_time)

        views.setTextViewText(R.id.ft_score_text, "${home?.get("score") ?: 0} - ${away?.get("score") ?: 0}")
        views.setTextViewText(R.id.ft_name_home, home?.get("name")?.toString())
        views.setTextViewText(R.id.ft_name_away, away?.get("name")?.toString())
        views.setTextViewText(R.id.ft_duration, if (duration != null) "Full Time  •  $duration" else "Full Time")

        val white = Color.WHITE
        val gray = Color.parseColor("#888888")

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views)
            .setCustomContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 300, 100, 300, 100, 300))
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(NOTIFICATION_ID, notification)

        val homeCode = home?.get("countryCode")?.toString() ?: ""
        val awayCode = away?.get("countryCode")?.toString() ?: ""
        val homeName = home?.get("name")?.toString() ?: ""
        val awayName = away?.get("name")?.toString() ?: ""
        val trans = FlagRepository.BlurAndDarkenTransformation(6, "#73000000")

        when (winner) {
            "home" -> {
                views.setTextViewText(R.id.ft_name_home, Html.fromHtml("<b>$homeName</b>"))
                views.setTextViewText(R.id.ft_name_away, awayName)
                views.setTextColor(R.id.ft_name_home, white)
                views.setTextColor(R.id.ft_name_away, gray)
                views.setViewVisibility(R.id.ft_bg_flag_right, View.GONE)
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(homeCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_left, views, notification, NOTIFICATION_ID))
            }
            "away" -> {
                views.setTextViewText(R.id.ft_name_home, homeName)
                views.setTextViewText(R.id.ft_name_away, Html.fromHtml("<b>$awayName</b>"))
                views.setTextColor(R.id.ft_name_home, gray)
                views.setTextColor(R.id.ft_name_away, white)
                views.setViewVisibility(R.id.ft_bg_flag_left, View.GONE)
                views.setViewVisibility(R.id.ft_bg_flag_right, View.VISIBLE)
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(awayCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_right, views, notification, NOTIFICATION_ID))
            }
            else -> {
                views.setTextViewText(R.id.ft_name_home, homeName)
                views.setTextViewText(R.id.ft_name_away, awayName)
                views.setTextColor(R.id.ft_name_home, white)
                views.setTextColor(R.id.ft_name_away, white)
                views.setViewVisibility(R.id.ft_bg_flag_left, View.VISIBLE)
                views.setViewVisibility(R.id.ft_bg_flag_right, View.VISIBLE)
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(homeCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_left, views, notification, NOTIFICATION_ID))
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(awayCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_right, views, notification, NOTIFICATION_ID))
            }
        }

        if (!motm.isNullOrEmpty()) {
            views.setTextViewText(R.id.ft_motm, "⭐ Man of the Match: $motm")
            views.setViewVisibility(R.id.ft_motm, View.VISIBLE)
        }

        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ft_logo_home, views, notification, NOTIFICATION_ID))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ft_logo_away, views, notification, NOTIFICATION_ID))
        }

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            views.setViewVisibility(R.id.ft_badge, View.VISIBLE)
            views.setFloat(R.id.ft_badge, "setTranslationY", -30f)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 600)

        handler.postDelayed({
            views.setFloat(R.id.ft_badge, "setTranslationY", 0f)
            notificationManager.notify(NOTIFICATION_ID, notification)
        }, 900)

        Thread {
            val confettiColors = mutableListOf<Int>()
            if (winner == "draw" || winner == null) {
                confettiColors.add(Color.parseColor("#FFD700"))
                confettiColors.add(Color.WHITE)
            } else {
                val winnerCode = if (winner == "home") homeCode else awayCode
                try {
                    val flag = Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(winnerCode)).submit().get()
                    val palette = Palette.from(flag).generate()
                    palette.vibrantSwatch?.rgb?.let { confettiColors.add(it) }
                    palette.dominantSwatch?.rgb?.let { confettiColors.add(it) }
                } catch (e: Exception) {}
            }
            if (confettiColors.isEmpty()) {
                confettiColors.add(Color.parseColor("#FFD700"))
                confettiColors.add(Color.WHITE)
            }
            val confetti = generateConfettiBitmap(confettiColors)
            handler.post {
                views.setImageViewBitmap(R.id.ft_confetti_overlay, confetti)
                notificationManager.notify(NOTIFICATION_ID, notification)
            }
        }.start()
    }

    private fun generateConfettiBitmap(colors: List<Int>): Bitmap {
        val width = 500
        val height = 128
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val random = java.util.Random()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        for (i in 0 until 60) {
            paint.color = colors[random.nextInt(colors.size)]
            paint.alpha = 150 + random.nextInt(105)
            val x = random.nextFloat() * width
            val y = random.nextFloat() * height
            val size = 4f + random.nextFloat() * 6f
            if (random.nextBoolean()) canvas.drawRect(x, y, x + size, y + size, paint)
            else canvas.drawCircle(x, y, size / 2, paint)
        }
        return bitmap
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "Match Alerts", NotificationManager.IMPORTANCE_HIGH)
            notificationManager.createNotificationChannel(channel)
        }
    }
}

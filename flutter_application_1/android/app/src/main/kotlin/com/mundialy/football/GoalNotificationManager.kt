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

class GoalNotificationManager(private val context: Context) {

    private val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    private val channelId = "mundialy_live_alerts_v2"
    private val notificationId = 1001

    fun showGoalNotification(payload: Map<String, Any?>) {
        createChannel()

        val scoringTeam = payload["scoringTeam"]?.toString()
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scoringCountry = if (scoringTeam == "home") home?.get("countryCode")?.toString() else away?.get("countryCode")?.toString()

        val phase1 = RemoteViews(context.packageName, R.layout.notification_goal_phase1)
        
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(phase1)
            .setCustomContentView(phase1)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 80, 40, 80))
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(notificationId, notification)

        // PHASE 1: Blurred Background Flag
        scoringCountry?.let { code ->
            val url = FlagRepository.getFlagUrl(code, "w160")
            Glide.with(context).asBitmap().load(url)
                .transform(FlagRepository.BlurAndDarkenTransformation(8))
                .into(NotificationTarget(context, R.id.bg_flag_blur, phase1, notification, notificationId))
        }

        val letters = arrayOf("G", "O", "A", "L")
        val letterIds = arrayOf(R.id.letter_g, R.id.letter_o, R.id.letter_a, R.id.letter_l)
        val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

        Thread {
            val flagBitmap = try {
                if (scoringCountry != null) {
                    Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(scoringCountry)).submit().get()
                } else null
            } catch (e: Exception) { null }

            Handler(Looper.getMainLooper()).post {
                letters.forEachIndexed { i, letter ->
                    val letterBitmap = createLetterBitmap(letter, flagBitmap)
                    phase1.setImageViewBitmap(letterIds[i], letterBitmap)
                }

                letters.forEachIndexed { i, _ ->
                    Handler(Looper.getMainLooper()).postDelayed({
                        phase1.setViewVisibility(letterIds[i], View.VISIBLE)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            vibrator.vibrate(VibrationEffect.createOneShot(50, 100))
                        }
                        notificationManager.notify(notificationId, notification)
                        
                        if (i == letters.size - 1) {
                            Handler(Looper.getMainLooper()).postDelayed({
                                phase1.setViewVisibility(R.id.exclamation, View.VISIBLE)
                                notificationManager.notify(notificationId, notification)
                            }, 220)
                        }
                    }, 220L * i)
                }
            }
        }.start()

        Handler(Looper.getMainLooper()).postDelayed({
            val phase2 = RemoteViews(context.packageName, R.layout.notification_goal_phase2)
            setupPhase2UI(phase2, payload)
            
            builder.setCustomHeadsUpContentView(phase2)
            builder.setCustomContentView(phase2)
            
            notification = builder.build()
            notificationManager.notify(notificationId, notification)
            
            loadLogosPhase2(phase2, home, away, notification)
        }, 2500)
    }

    fun showHalfTimeNotification(payload: Map<String, Any?>) {
        createChannel()
        
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        val scorers = payload["scorers"] as? List<Map<*, *>> ?: emptyList()
        
        val views = RemoteViews(context.packageName, R.layout.notification_half_time)
        
        views.setTextViewText(R.id.ht_score_text, "${home?.get("score") ?: 0} - ${away?.get("score") ?: 0}")
        views.setTextViewText(R.id.ht_subtitle, "Half Time")
        
        if (scorers.isNotEmpty()) {
            val summary = scorers.take(2).joinToString("\n") { 
                "⚽ ${it["name"]} — ${it["team"]}  ${it["minute"]}'"
            }
            views.setTextViewText(R.id.ht_scorers_summary, summary)
        }

        val bgCode = if (scorers.isEmpty()) {
            home?.get("countryCode")?.toString()
        } else {
            val lastScorer = scorers.last()
            val teamName = lastScorer["team"]?.toString()
            if (teamName == home?.get("name")) home?.get("countryCode")?.toString()
            else away?.get("countryCode")?.toString()
        } ?: home?.get("countryCode")?.toString() ?: ""

        val soundUri = android.net.Uri.parse("android.resource://${context.packageName}/raw/whistle_double")
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views)
            .setCustomContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 150, 50, 150))
            .setSound(soundUri)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(notificationId, notification)

        if (bgCode.isNotEmpty()) {
            Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(bgCode, "w160"))
                .transform(FlagRepository.BlurAndDarkenTransformation(10, "#8C000000"))
                .into(NotificationTarget(context, R.id.ht_bg_flag, views, notification, notificationId))
        }
        
        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ht_logo_home, views, notification, notificationId))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ht_logo_away, views, notification, notificationId))
        }

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            views.setViewVisibility(R.id.ht_sweep_line, View.VISIBLE)
            notificationManager.notify(notificationId, notification)
        }, 100)

        handler.postDelayed({
            views.setViewVisibility(R.id.ht_sweep_line, View.GONE)
            views.setViewVisibility(R.id.ht_badge, View.VISIBLE)
            views.setFloat(R.id.ht_badge, "setScaleX", 1.15f)
            views.setFloat(R.id.ht_badge, "setScaleY", 1.15f)
            notificationManager.notify(notificationId, notification)
        }, 800)

        handler.postDelayed({
            views.setViewVisibility(R.id.ht_score_row, View.VISIBLE)
            views.setViewVisibility(R.id.ht_subtitle, View.VISIBLE)
            if (scorers.isNotEmpty()) {
                views.setViewVisibility(R.id.ht_scorers_summary, View.VISIBLE)
            }
            notificationManager.notify(notificationId, notification)
        }, 1200)
    }

    fun showMatchStartNotification(payload: Map<String, Any?>) {
        createChannel()
        val home = payload["homeTeam"] as? Map<*, *>
        val away = payload["awayTeam"] as? Map<*, *>
        
        val views = RemoteViews(context.packageName, R.layout.notification_match_start)
        
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views)
            .setCustomContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 200, 100, 200))
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(notificationId, notification)

        val homeCode = home?.get("countryCode")?.toString() ?: ""
        val awayCode = away?.get("countryCode")?.toString() ?: ""

        Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(homeCode))
            .into(NotificationTarget(context, R.id.flag_home_bg, views, notification, notificationId))
        Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(awayCode))
            .into(NotificationTarget(context, R.id.flag_away_bg, views, notification, notificationId))

        val handler = Handler(Looper.getMainLooper())
        
        handler.postDelayed({
            views.setViewVisibility(R.id.pitch_line, View.VISIBLE)
            notificationManager.notify(notificationId, notification)
        }, 800)

        handler.postDelayed({
            views.setViewVisibility(R.id.live_pill, View.VISIBLE)
            views.setViewVisibility(R.id.logo_home_start, View.VISIBLE)
            views.setViewVisibility(R.id.logo_away_start, View.VISIBLE)
            views.setViewVisibility(R.id.match_teams_text, View.VISIBLE)
            
            views.setTextViewText(R.id.match_teams_text, "${home?.get("name")}  VS  ${away?.get("name")}")
            views.setTextViewText(R.id.match_footer, "${payload["competition"]}  •  ${payload["kickoffTime"]}")
            
            notificationManager.notify(notificationId, notification)

            val diamond = FlagRepository.DiamondTransformation()
            home?.get("logoUrl")?.toString()?.let { url ->
                Glide.with(context).asBitmap().load(url).transform(diamond)
                    .into(NotificationTarget(context, R.id.logo_home_start, views, notification, notificationId))
            }
            away?.get("logoUrl")?.toString()?.let { url ->
                Glide.with(context).asBitmap().load(url).transform(diamond)
                    .into(NotificationTarget(context, R.id.logo_away_start, views, notification, notificationId))
            }
        }, 1500)
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
            canvas.drawText(letter, width / 2f, height * 0.8f, paint)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            canvas.drawBitmap(flag, Rect(0, 0, flag.width, flag.height), Rect(0, 0, width, height), paint)
            paint.xfermode = null
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
        val highlightColor = Color.parseColor("#FF3333")
        if (scoringTeam == "home") views.setTextColor(R.id.score_home, highlightColor) else views.setTextColor(R.id.score_away, highlightColor)
        views.setTextViewText(R.id.scorer_info, "⚽ ${payload["scorer"]}")
        views.setTextViewText(R.id.minute_pill, "${payload["minute"]}'")
        if (payload["isPenalty"] == true) views.setViewVisibility(R.id.penalty_badge, View.VISIBLE)
    }

    private fun loadLogosPhase2(views: RemoteViews, home: Map<*, *>?, away: Map<*, *>?, notif: android.app.Notification) {
        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.logo_home, views, notif, notificationId))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.logo_away, views, notif, notificationId))
        }
    }

    fun showFullTimeNotification(payload: Map<String, Any?>) {
        createChannel()
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

        val soundUri = android.net.Uri.parse("android.resource://${context.packageName}/raw/final_whistle")
        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.ic_notification)
            .setCustomHeadsUpContentView(views)
            .setCustomContentView(views)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setVibrate(longArrayOf(0, 300, 100, 300, 100, 300))
            .setSound(soundUri)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)

        var notification = builder.build()
        notificationManager.notify(notificationId, notification)

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
                    .into(NotificationTarget(context, R.id.ft_bg_flag_left, views, notification, notificationId))
            }
            "away" -> {
                views.setTextViewText(R.id.ft_name_home, homeName)
                views.setTextViewText(R.id.ft_name_away, Html.fromHtml("<b>$awayName</b>"))
                views.setTextColor(R.id.ft_name_home, gray)
                views.setTextColor(R.id.ft_name_away, white)
                views.setViewVisibility(R.id.ft_bg_flag_left, View.GONE)
                views.setViewVisibility(R.id.ft_bg_flag_right, View.VISIBLE)
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(awayCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_right, views, notification, notificationId))
            }
            else -> {
                views.setTextViewText(R.id.ft_name_home, homeName)
                views.setTextViewText(R.id.ft_name_away, awayName)
                views.setTextColor(R.id.ft_name_home, white)
                views.setTextColor(R.id.ft_name_away, white)
                views.setViewVisibility(R.id.ft_bg_flag_left, View.VISIBLE)
                views.setViewVisibility(R.id.ft_bg_flag_right, View.VISIBLE)
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(homeCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_left, views, notification, notificationId))
                Glide.with(context).asBitmap().load(FlagRepository.getFlagUrl(awayCode)).transform(trans)
                    .into(NotificationTarget(context, R.id.ft_bg_flag_right, views, notification, notificationId))
            }
        }

        if (!motm.isNullOrEmpty()) {
            views.setTextViewText(R.id.ft_motm, "⭐ Man of the Match: $motm")
            views.setViewVisibility(R.id.ft_motm, View.VISIBLE)
        }

        val diamond = FlagRepository.DiamondTransformation()
        home?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ft_logo_home, views, notification, notificationId))
        }
        away?.get("logoUrl")?.toString()?.let { url ->
            Glide.with(context).asBitmap().load(url).transform(diamond)
                .into(NotificationTarget(context, R.id.ft_logo_away, views, notification, notificationId))
        }

        val handler = Handler(Looper.getMainLooper())
        handler.postDelayed({
            views.setViewVisibility(R.id.ft_badge, View.VISIBLE)
            views.setFloat(R.id.ft_badge, "setTranslationY", -30f)
            notificationManager.notify(notificationId, notification)
        }, 600)

        handler.postDelayed({
            views.setFloat(R.id.ft_badge, "setTranslationY", 0f)
            notificationManager.notify(notificationId, notification)
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
                notificationManager.notify(notificationId, notification)
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

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Match Alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 80, 40, 80)
            }
            notificationManager.createNotificationChannel(channel)
        }
    }
}

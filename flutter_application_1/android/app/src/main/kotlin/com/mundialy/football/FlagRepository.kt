package com.mundialy.football

import android.content.Context
import android.graphics.*
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.resource.bitmap.BitmapTransformation
import com.bumptech.glide.load.engine.bitmap_recycle.BitmapPool
import com.bumptech.glide.request.target.NotificationTarget
import java.security.MessageDigest

object FlagRepository {
    private const val BASE_URL = "https://flagcdn.com"

    fun getFlagUrl(countryCode: String, size: String = "w160"): String {
        return "$BASE_URL/$size/${countryCode.lowercase()}.png"
    }

    class BlurAndDarkenTransformation(private val radius: Int, private val overlayColor: String = "#66000000") : BitmapTransformation() {
        override fun transform(pool: BitmapPool, toTransform: Bitmap, outWidth: Int, outHeight: Int): Bitmap {
            val width = toTransform.width
            val height = toTransform.height
            val bitmap = pool.get(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            
            // Filtre de noirceur
            paint.colorFilter = PorterDuffColorFilter(Color.parseColor(overlayColor), PorterDuff.Mode.SRC_ATOP)
            
            // Simulation de flou par redimensionnement
            val scaledDown = Bitmap.createScaledBitmap(toTransform, (width / radius).coerceAtLeast(1), (height / radius).coerceAtLeast(1), true)
            val blurred = Bitmap.createScaledBitmap(scaledDown, width, height, true)
            
            canvas.drawBitmap(blurred, 0f, 0f, paint)
            return bitmap
        }
        override fun updateDiskCacheKey(md: MessageDigest) = md.update("blur_darken_v2_$radius$overlayColor".toByteArray())
    }

    class DiamondTransformation : BitmapTransformation() {
        override fun transform(pool: BitmapPool, toTransform: Bitmap, outWidth: Int, outHeight: Int): Bitmap {
            val size = toTransform.width.coerceAtMost(toTransform.height)
            val bitmap = pool.get(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val path = Path().apply {
                moveTo(size / 2f, 0f)
                lineTo(size.toFloat(), size / 2f)
                lineTo(size / 2f, size.toFloat())
                lineTo(0f, size / 2f)
                close()
            }
            canvas.clipPath(path)
            canvas.drawBitmap(toTransform, Rect(0, 0, toTransform.width, toTransform.height), Rect(0, 0, size, size), Paint(Paint.ANTI_ALIAS_FLAG))
            return bitmap
        }
        override fun updateDiskCacheKey(md: MessageDigest) = md.update("diamond_v1".toByteArray())
    }

    fun loadFlag(
        context: Context,
        countryCode: String,
        viewId: Int,
        remoteViews: android.widget.RemoteViews,
        notification: android.app.Notification,
        notificationId: Int,
        isBlurred: Boolean = false
    ) {
        val url = getFlagUrl(countryCode)
        var builder = Glide.with(context)
            .asBitmap()
            .load(url)
            .diskCacheStrategy(DiskCacheStrategy.ALL)

        if (isBlurred) {
            builder = builder.transform(BlurAndDarkenTransformation(8))
        } else {
            builder = builder.transform(DiamondTransformation())
        }

        builder.into(NotificationTarget(context, viewId, remoteViews, notification, notificationId))
    }
}

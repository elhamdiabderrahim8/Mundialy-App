package com.mundialy.football

import android.content.Context
import android.graphics.*
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.engine.bitmap_recycle.BitmapPool
import com.bumptech.glide.load.resource.bitmap.BitmapTransformation
import com.bumptech.glide.request.target.NotificationTarget
import java.security.MessageDigest

object FlagRepository {
    private const val BASE_URL = "https://flagcdn.com"

    fun loadFlag(
        context: Context,
        countryCode: String,
        viewId: Int,
        remoteViews: android.widget.RemoteViews,
        notification: android.app.Notification,
        notificationId: Int,
        size: String = "w80",
        isBlurred: Boolean = false
    ) {
        val url = "$BASE_URL/$size/${countryCode.lowercase()}.png"
        
        var builder = Glide.with(context)
            .asBitmap()
            .load(url)
            .diskCacheStrategy(DiskCacheStrategy.ALL)
            .placeholder(R.drawable.ic_notification)

        if (isBlurred) {
            builder = builder.transform(BlurAndDarkenTransformation(8, 0.4f))
        } else {
            builder = builder.transform(DiamondTransformation())
        }

        builder.into(NotificationTarget(context, viewId, remoteViews, notification, notificationId))
    }

    class BlurAndDarkenTransformation(private val radius: Int, private val opacity: Float) : BitmapTransformation() {
        override fun updateDiskCacheKey(messageDigest: MessageDigest) {
            messageDigest.update("blur_darken_${radius}_${opacity}".toByteArray())
        }

        override fun transform(pool: BitmapPool, toTransform: Bitmap, outWidth: Int, outHeight: Int): Bitmap {
            val width = toTransform.width
            val height = toTransform.height
            val bitmap = pool.get(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            
            // Darkening Filter (40% opacity = 0x66)
            paint.colorFilter = PorterDuffColorFilter(Color.argb(102, 0, 0, 0), PorterDuff.Mode.SRC_ATOP)
            
            // Simple Blur by scaling
            val scaledDown = Bitmap.createScaledBitmap(toTransform, width / 4, height / 4, true)
            val blurred = Bitmap.createScaledBitmap(scaledDown, width, height, true)
            
            canvas.drawBitmap(blurred, 0f, 0f, paint)
            return bitmap
        }
    }

    class DiamondTransformation : BitmapTransformation() {
        override fun updateDiskCacheKey(messageDigest: MessageDigest) {
            messageDigest.update("diamond_v1".toByteArray())
        }

        override fun transform(pool: BitmapPool, toTransform: Bitmap, outWidth: Int, outHeight: Int): Bitmap {
            val size = Math.min(toTransform.width, toTransform.height)
            val bitmap = pool.get(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG)
            
            val path = Path()
            path.moveTo(size / 2f, 0f)
            path.lineTo(size.toFloat(), size / 2f)
            path.lineTo(size / 2f, size.toFloat())
            path.lineTo(0f, size / 2f)
            path.close()

            canvas.clipPath(path)
            canvas.drawBitmap(toTransform, Rect(0, 0, toTransform.width, toTransform.height), Rect(0, 0, size, size), paint)
            
            return bitmap
        }
    }
}

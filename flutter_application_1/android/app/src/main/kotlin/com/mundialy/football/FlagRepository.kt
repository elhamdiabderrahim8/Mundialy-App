package com.mundialy.football

import android.content.Context
import android.graphics.*
import android.util.Log
import com.bumptech.glide.Glide
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.load.engine.bitmap_recycle.BitmapPool
import com.bumptech.glide.load.resource.bitmap.BitmapTransformation
import com.bumptech.glide.request.target.NotificationTarget
import java.security.MessageDigest

object FlagRepository {
    private const val TAG = "FlagRepository"
    private const val BASE_URL = "https://flagcdn.com"

    /**
     * Règle de log centralisée pour tous les accès à flagcdn.com
     */
    private fun logFlagRequest(countryCode: String, size: String, type: String) {
        Log.d(TAG, "🚩 Requesting flag: $BASE_URL/$size/${countryCode.lowercase()}.png [Type: $type]")
    }

    fun loadFlagIntoNotification(
        context: Context,
        countryCode: String,
        viewId: Int,
        remoteViews: android.widget.RemoteViews,
        notification: android.app.Notification,
        notificationId: Int,
        size: String = "w160",
        isDiamond: Boolean = false,
        isBlurred: Boolean = false,
        darkenOpacity: Float = 0.4f
    ) {
        val url = "$BASE_URL/$size/${countryCode.lowercase()}.png"
        logFlagRequest(countryCode, size, if (isBlurred) "Background-Blur" else "Logo-Standard")

        val requestBuilder = Glide.with(context)
            .asBitmap()
            .load(url)
            .diskCacheStrategy(DiskCacheStrategy.ALL)
            .placeholder(R.drawable.ic_notification)

        val transformations = mutableListOf<com.bumptech.glide.load.Transformation<Bitmap>>()
        
        if (isDiamond) {
            transformations.add(DiamondTransformation())
        }
        
        if (isBlurred) {
            transformations.add(object : BitmapTransformation() {
                override fun updateDiskCacheKey(messageDigest: MessageDigest) {
                    messageDigest.update("blur_darken_$darkenOpacity".toByteArray())
                }
                override fun transform(pool: BitmapPool, toTransform: Bitmap, outWidth: Int, outHeight: Int): Bitmap {
                    val bitmap = Bitmap.createBitmap(toTransform.width, toTransform.height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)
                    val paint = Paint()
                    val alpha = (darkenOpacity * 255).toInt()
                    paint.colorFilter = PorterDuffColorFilter(Color.argb(alpha, 0, 0, 0), PorterDuff.Mode.SRC_ATOP)
                    canvas.drawBitmap(toTransform, 0f, 0f, paint)
                    return bitmap
                }
            })
        }

        if (transformations.isNotEmpty()) {
            requestBuilder.transform(*transformations.toTypedArray())
        }

        val target = NotificationTarget(context, viewId, remoteViews, notification, notificationId)
        requestBuilder.into(target)
    }

    /**
     * Transformation Diamond pour correspondre au style "TeamLogoView" de l'app Flutter
     */
    class DiamondTransformation : BitmapTransformation() {
        override fun updateDiskCacheKey(messageDigest: MessageDigest) {
            messageDigest.update("diamond_crop".toByteArray())
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

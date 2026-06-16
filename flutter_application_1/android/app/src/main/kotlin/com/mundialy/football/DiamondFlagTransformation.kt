package com.mundialy.football

import android.graphics.*
import com.bumptech.glide.load.engine.bitmap_recycle.BitmapPool
import com.bumptech.glide.load.resource.bitmap.BitmapTransformation
import java.security.MessageDigest
import kotlin.math.min

class DiamondFlagTransformation : BitmapTransformation() {
    override fun transform(pool: BitmapPool, source: Bitmap, outWidth: Int, outHeight: Int): Bitmap {
        val size = min(source.width, source.height)
        val output = pool.get(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        
        // Diamond clip path
        val path = Path().apply {
            moveTo(size / 2f, 0f)           // top
            lineTo(size.toFloat(), size / 2f) // right
            lineTo(size / 2f, size.toFloat()) // bottom
            lineTo(0f, size / 2f)             // left
            close()
        }
        canvas.clipPath(path)
        
        // Draw scaled flag inside diamond
        val src = Bitmap.createScaledBitmap(source, size, size, true)
        canvas.drawBitmap(src, 0f, 0f, paint)
        
        // White border stroke
        val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            color = Color.parseColor("#BFFFFFFF")
            strokeWidth = size * 0.065f
            strokeJoin = Paint.Join.ROUND
        }
        canvas.drawPath(path, borderPaint)
        
        return output
    }
    
    override fun updateDiskCacheKey(md: MessageDigest) {
        md.update("DiamondFlagTransformation".toByteArray())
    }
}

package com.copydrop.android.model

import java.text.SimpleDateFormat
import java.util.*

data class ClipboardHistory(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val direction: Direction,
    val deviceName: String? = null
) {
    enum class Direction {
        SENT,     // Android → Mac으로 전송
        RECEIVED  // Mac → Android로 수신
    }
    
    fun getFormattedTime(): String {
        val sdf = SimpleDateFormat("HH:mm:ss", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }
    
    fun getFormattedDate(): String {
        val sdf = SimpleDateFormat("MM/dd", Locale.getDefault())
        return sdf.format(Date(timestamp))
    }
    
    fun getDirectionText(): String {
        return when (direction) {
            Direction.SENT -> "📤 전송"
            Direction.RECEIVED -> "📥 수신"
        }
    }
    
    fun getPreviewText(maxLength: Int = 50): String {
        return if (content.length > maxLength) {
            content.take(maxLength) + "..."
        } else {
            content
        }
    }
}
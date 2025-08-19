package com.copydrop.android.model

import java.util.*

/**
 * Mac의 ClipboardMessage와 동일한 구조
 * docs/PROTOCOL.md 참조
 */
data class ClipboardMessage(
    val content: String,
    val timestamp: String, // ISO8601 문자열로 변경
    val deviceId: String,
    val messageId: String,
    val contentSize: Int = 0 // 바이트 단위 크기
) {
    constructor(content: String, deviceId: String) : this(
        content = content,
        timestamp = java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", java.util.Locale.getDefault()).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }.format(Date()),
        deviceId = deviceId,
        messageId = UUID.randomUUID().toString(),
        contentSize = content.toByteArray(Charsets.UTF_8).size
    )
}
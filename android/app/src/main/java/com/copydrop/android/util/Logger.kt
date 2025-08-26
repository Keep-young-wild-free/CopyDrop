package com.copydrop.android.util

import timber.log.Timber
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.*

/**
 * 구조화된 로깅 시스템
 */
object Logger {
    
    private const val LOG_FILE_NAME = "copydrop_debug.log"
    private const val MAX_LOG_SIZE = 5 * 1024 * 1024 // 5MB
    
    /**
     * 로그 레벨
     */
    enum class Level(val tag: String, val priority: Int) {
        VERBOSE("VERBOSE", android.util.Log.VERBOSE),
        DEBUG("DEBUG", android.util.Log.DEBUG),
        INFO("INFO", android.util.Log.INFO),
        WARN("WARN", android.util.Log.WARN),
        ERROR("ERROR", android.util.Log.ERROR)
    }
    
    /**
     * 로그 카테고리
     */
    enum class Category(val tag: String) {
        BLUETOOTH("BLE"),
        CRYPTO("CRYPTO"),
        CLIPBOARD("CLIPBOARD"),
        UI("UI"),
        NETWORK("NETWORK"),
        AUTH("AUTH"),
        PERFORMANCE("PERF"),
        LIFECYCLE("LIFECYCLE")
    }
    
    private val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.getDefault())
    
    /**
     * 구조화된 로그 출력
     */
    fun log(
        level: Level,
        category: Category,
        message: String,
        tag: String = category.tag,
        throwable: Throwable? = null,
        metadata: Map<String, Any> = emptyMap()
    ) {
        val timestamp = dateFormat.format(Date())
        val threadName = Thread.currentThread().name
        
        // 메타데이터 문자열 생성
        val metadataStr = if (metadata.isNotEmpty()) {
            metadata.entries.joinToString(", ") { "${it.key}=${it.value}" }
        } else ""
        
        // 로그 메시지 포맷팅
        val formattedMessage = buildString {
            append("[$timestamp] ")
            append("[${level.tag}] ")
            append("[${category.tag}] ")
            append("[$threadName] ")
            append(message)
            
            if (metadataStr.isNotEmpty()) {
                append(" | ")
                append(metadataStr)
            }
        }
        
        // Timber로 출력
        when (level) {
            Level.VERBOSE -> Timber.tag(tag).v(throwable, formattedMessage)
            Level.DEBUG -> Timber.tag(tag).d(throwable, formattedMessage)
            Level.INFO -> Timber.tag(tag).i(throwable, formattedMessage)
            Level.WARN -> Timber.tag(tag).w(throwable, formattedMessage)
            Level.ERROR -> Timber.tag(tag).e(throwable, formattedMessage)
        }
    }
    
    // 편의 메서드들
    fun v(category: Category, message: String, metadata: Map<String, Any> = emptyMap()) {
        log(Level.VERBOSE, category, message, metadata = metadata)
    }
    
    fun d(category: Category, message: String, metadata: Map<String, Any> = emptyMap()) {
        log(Level.DEBUG, category, message, metadata = metadata)
    }
    
    fun i(category: Category, message: String, metadata: Map<String, Any> = emptyMap()) {
        log(Level.INFO, category, message, metadata = metadata)
    }
    
    fun w(category: Category, message: String, throwable: Throwable? = null, metadata: Map<String, Any> = emptyMap()) {
        log(Level.WARN, category, message, throwable = throwable, metadata = metadata)
    }
    
    fun e(category: Category, message: String, throwable: Throwable? = null, metadata: Map<String, Any> = emptyMap()) {
        log(Level.ERROR, category, message, throwable = throwable, metadata = metadata)
    }
    
    // 특화된 로깅 메서드들
    
    /**
     * 블루투스 연결 상태 로깅
     */
    fun logBluetoothConnection(deviceName: String?, isConnected: Boolean, rssi: Int? = null) {
        val metadata = mapOf(
            "device" to (deviceName ?: "Unknown"),
            "connected" to isConnected,
            "rssi" to (rssi ?: "N/A")
        )
        
        val message = if (isConnected) {
            "블루투스 연결 성공: $deviceName"
        } else {
            "블루투스 연결 해제: $deviceName"
        }
        
        i(Category.BLUETOOTH, message, metadata)
    }
    
    /**
     * 데이터 전송 로깅
     */
    fun logDataTransfer(direction: String, size: Int, type: String, encrypted: Boolean = false) {
        val metadata = mapOf(
            "direction" to direction,
            "size_bytes" to size,
            "size_kb" to (size / 1024),
            "type" to type,
            "encrypted" to encrypted,
            "timestamp" to System.currentTimeMillis()
        )
        
        val encryptedText = if (encrypted) " (암호화됨)" else ""
        val message = "$direction 데이터 전송: ${size / 1024}KB $type$encryptedText"
        
        i(Category.NETWORK, message, metadata)
    }
    
    /**
     * PIN 인증 로깅
     */
    fun logPinAuthentication(success: Boolean, attemptCount: Int = 1, sessionDuration: Long? = null) {
        val metadata = mutableMapOf<String, Any>(
            "success" to success,
            "attempt_count" to attemptCount
        )
        
        sessionDuration?.let { metadata["session_duration_hours"] = it / (1000 * 60 * 60) }
        
        val message = if (success) {
            "PIN 인증 성공 (${attemptCount}회 시도)"
        } else {
            "PIN 인증 실패 (${attemptCount}회 시도)"
        }
        
        if (success) {
            i(Category.AUTH, message, metadata)
        } else {
            w(Category.AUTH, message, metadata = metadata)
        }
    }
    
    /**
     * 성능 측정 로깅
     */
    fun logPerformance(operation: String, durationMs: Long, success: Boolean = true) {
        val metadata = mapOf(
            "operation" to operation,
            "duration_ms" to durationMs,
            "duration_s" to (durationMs / 1000.0),
            "success" to success
        )
        
        val message = "$operation 완료: ${durationMs}ms"
        
        when {
            !success -> w(Category.PERFORMANCE, "$message (실패)", metadata = metadata)
            durationMs > 5000 -> w(Category.PERFORMANCE, "$message (느림)", metadata = metadata)
            else -> d(Category.PERFORMANCE, message, metadata)
        }
    }
    
    /**
     * UI 이벤트 로깅
     */
    fun logUserAction(action: String, screen: String, metadata: Map<String, Any> = emptyMap()) {
        val enrichedMetadata = metadata + mapOf(
            "screen" to screen,
            "action" to action,
            "user_timestamp" to System.currentTimeMillis()
        )
        
        d(Category.UI, "사용자 액션: $action (화면: $screen)", enrichedMetadata)
    }
    
    /**
     * 앱 생명주기 로깅
     */
    fun logLifecycle(component: String, event: String, metadata: Map<String, Any> = emptyMap()) {
        val enrichedMetadata = metadata + mapOf(
            "component" to component,
            "lifecycle_event" to event
        )
        
        i(Category.LIFECYCLE, "$component: $event", enrichedMetadata)
    }
    
    /**
     * 에러 컨텍스트와 함께 로깅
     */
    fun logError(category: Category, message: String, throwable: Throwable, context: Map<String, Any> = emptyMap()) {
        val errorMetadata = context + mapOf(
            "exception_type" to throwable.javaClass.simpleName,
            "exception_message" to (throwable.message ?: "No message"),
            "stack_trace_size" to throwable.stackTrace.size
        )
        
        e(category, message, throwable, errorMetadata)
    }
}

/**
 * 성능 측정을 위한 유틸리티
 */
inline fun <T> Logger.measurePerformance(operation: String, block: () -> T): T {
    val startTime = System.currentTimeMillis()
    return try {
        val result = block()
        val duration = System.currentTimeMillis() - startTime
        logPerformance(operation, duration, true)
        result
    } catch (e: Exception) {
        val duration = System.currentTimeMillis() - startTime
        logPerformance(operation, duration, false)
        throw e
    }
}
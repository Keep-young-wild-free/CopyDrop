package com.copydrop.android.service

import android.accessibilityservice.AccessibilityService
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * 클립보드 접근을 위한 Accessibility Service
 * Android 10+ 클립보드 접근 제한을 우회
 */
class ClipboardAccessibilityService : AccessibilityService() {
    
    companion object {
        private const val TAG = "ClipboardAccessService"
        const val ACTION_SET_CLIPBOARD = "SET_CLIPBOARD"
        const val ACTION_GET_CLIPBOARD = "GET_CLIPBOARD"
        const val EXTRA_CONTENT = "content"
        
        private var instance: ClipboardAccessibilityService? = null
        private var lastScreenReaderCaptureTime = 0L
        
        fun isServiceEnabled(): Boolean = instance != null
        
        fun hasRecentScreenReaderCapture(): Boolean {
            return (System.currentTimeMillis() - lastScreenReaderCaptureTime) < 2000 // 2초 이내
        }
        
        fun setClipboardContent(context: Context, content: String) {
            if (instance != null) {
                instance?.performSetClipboard(content)
            } else {
                // 서비스가 활성화되지 않은 경우 Intent로 요청
                val intent = Intent(context, ClipboardAccessibilityService::class.java).apply {
                    action = ACTION_SET_CLIPBOARD
                    putExtra(EXTRA_CONTENT, content)
                }
                context.startService(intent)
            }
        }
        
        fun getClipboardContent(): String? {
            return instance?.performGetClipboard()
        }
    }
    
    private lateinit var clipboardManager: ClipboardManager
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ClipboardAccessibilityService 생성됨")
        clipboardManager = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        instance = this
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "ClipboardAccessibilityService 종료됨")
        instance = null
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d(TAG, "✅ Accessibility Service 연결됨 - 클립보드 접근 가능")
        instance = this
        
        // 연결 확인을 위한 테스트
        try {
            val testClipData = ClipData.newPlainText("test", "test")
            clipboardManager.setPrimaryClip(testClipData)
            Log.d(TAG, "✅ 접근성 서비스에서 클립보드 테스트 성공")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 접근성 서비스에서 클립보드 테스트 실패: ${e.message}")
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        event?.let { 
            // 🔍 모든 이벤트 로깅 (디버깅용)
            Log.d(TAG, "🔔 접근성 이벤트 감지: ${getEventTypeName(it.eventType)} from ${it.packageName}")
            
            when (it.eventType) {
                AccessibilityEvent.TYPE_VIEW_CLICKED -> {
                    Log.d(TAG, "👆 클릭 이벤트 감지: ${it.text}")
                    // "복사" 버튼 클릭 등을 감지할 수 있음
                    val text = it.text?.toString()
                    if (text?.contains("복사") == true || text?.contains("copy") == true) {
                        Log.d(TAG, "📋 복사 버튼 클릭 감지 - 강제 클립보드 체크 시작")
                        
                        // 복사 완료를 위해 좀 더 길게 기다린 후 체크
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            forceCheckClipboardAfterCopy()
                        }, 500) // 500ms 대기
                    } else {
                        // 복사 관련 클릭이 아닌 경우는 무시
                    }
                }
                else -> {
                    // 다른 이벤트도 로깅
                    Log.d(TAG, "🔄 기타 이벤트: ${getEventTypeName(it.eventType)}")
                }
            }
        }
    }
    
    /**
     * 이벤트 타입을 읽기 쉬운 문자열로 변환
     */
    private fun getEventTypeName(eventType: Int): String {
        return when (eventType) {
            AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED -> "TEXT_SELECTION_CHANGED"
            AccessibilityEvent.TYPE_VIEW_CLICKED -> "VIEW_CLICKED"
            AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED -> "NOTIFICATION_STATE_CHANGED"
            AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> "WINDOW_STATE_CHANGED"
            AccessibilityEvent.TYPE_VIEW_FOCUSED -> "VIEW_FOCUSED"
            AccessibilityEvent.TYPE_VIEW_SCROLLED -> "VIEW_SCROLLED"
            else -> "TYPE_$eventType"
        }
    }
    
    override fun onInterrupt() {
        Log.d(TAG, "Accessibility Service 중단됨")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SET_CLIPBOARD -> {
                val content = intent.getStringExtra(EXTRA_CONTENT)
                if (!content.isNullOrEmpty()) {
                    performSetClipboard(content)
                }
            }
            else -> {
                // 다른 액션은 무시
            }
        }
        return START_NOT_STICKY
    }
    
    private fun performSetClipboard(content: String) {
        try {
            val clipData = ClipData.newPlainText("CopyDrop", content)
            clipboardManager.setPrimaryClip(clipData)
            Log.d(TAG, "✅ 클립보드 설정 성공 (Accessibility Service): ${content.take(30)}...")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 클립보드 설정 실패: ${e.message}")
        }
    }
    
    private fun performGetClipboard(): String? {
        return try {
            val clipData = clipboardManager.primaryClip
            val content = if (clipData != null && clipData.itemCount > 0) {
                clipData.getItemAt(0).text?.toString()
            } else {
                null
            }
            Log.d(TAG, "✅ 클립보드 읽기 성공 (Accessibility Service): ${content?.take(30)}...")
            content
        } catch (e: Exception) {
            Log.e(TAG, "❌ 클립보드 읽기 실패: ${e.message}")
            null
        }
    }
    
    private var lastClipboardContent = ""
    private var lastScreenReaderContent = "" // 스크린 리더 전용 중복 방지
    
    private fun checkAndNotifyClipboardChange() {
        try {
            val currentContent = performGetClipboard()
            if (!currentContent.isNullOrEmpty() && currentContent != lastClipboardContent) {
                lastClipboardContent = currentContent
                Log.d(TAG, "🎯 백그라운드에서 클립보드 변경 감지: ${currentContent.take(30)}...")
                
                // MainActivity에 클립보드 변경 알림
                notifyMainAppOfClipboardChange(currentContent)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 백그라운드 클립보드 체크 실패: ${e.message}")
        }
    }
    
    private fun notifyMainAppOfClipboardChange(content: String) {
        // 브로드캐스트로 MainActivity에 알림
        val intent = android.content.Intent("com.copydrop.android.CLIPBOARD_CHANGED").apply {
            putExtra("content", content)
            putExtra("source", "accessibility")
        }
        sendBroadcast(intent)
        Log.d(TAG, "📡 MainActivity에 클립보드 변경 알림 전송")
    }
    
    /**
     * 복사 버튼 클릭 후 토스트 알림 표시
     */
    private fun forceCheckClipboardAfterCopy() {
        try {
            Log.d(TAG, "🔍 복사 감지 - 토스트 알림 표시")
            
            // 토스트 메시지로 사용자에게 선택권 제공
            showSyncToastMessage()
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 복사 후 토스트 알림 실패: ${e.message}")
        }
    }
    
    /**
     * "Mac과 동기화?" 토스트 메시지 표시
     */
    private fun showSyncToastMessage() {
        try {
            // 현재 클립보드 내용 확인
            val currentContent = performGetClipboard()
            Log.d(TAG, "📋 현재 클립보드 내용: '${currentContent?.take(30)}...'")
            Log.d(TAG, "📋 이전 알림 내용: '${lastScreenReaderContent.take(30)}...'")
            
            // 클립보드 읽기 실패 시 강제 알림 표시
            if (currentContent.isNullOrEmpty()) {
                Log.w(TAG, "⚠️ 클립보드 읽기 실패 - 복사 버튼 클릭 감지했으므로 강제 알림 표시")
                
                // MainActivity에 강제 알림 (현재 클립보드 읽기는 MainActivity에서 처리)
                val intent = android.content.Intent("com.copydrop.android.SHOW_SYNC_TOAST").apply {
                    putExtra("message", "📱 → 💻 Mac으로 전송하시겠습니까?")
                    putExtra("action", "터치하여 전송")
                    putExtra("content", null as String?) // 타입 명시
                }
                sendBroadcast(intent)
                Log.d(TAG, "📡 강제 알림 브로드캐스트 전송")
                
            } else if (currentContent != lastScreenReaderContent) {
                lastScreenReaderContent = currentContent // 기록 업데이트
                
                Log.d(TAG, "📱 → 💻 Mac 동기화 알림 표시 (새로운 내용)")
                
                // MainActivity에 토스트 요청 알림
                val intent = android.content.Intent("com.copydrop.android.SHOW_SYNC_TOAST").apply {
                    putExtra("message", "📱 → 💻 Mac으로 전송하시겠습니까?")
                    putExtra("action", "터치하여 전송")
                    putExtra("content", currentContent) // 내용도 같이 전송
                }
                sendBroadcast(intent)
                Log.d(TAG, "📡 알림 브로드캐스트 전송")
            } else {
                Log.d(TAG, "⏭️ 중복된 클립보드 내용 - 알림 스킵: ${currentContent.take(30)}...")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 토스트 메시지 표시 실패: ${e.message}")
        }
    }
    
}
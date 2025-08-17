package com.copydrop.android.service

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Android 클립보드 모니터링 및 관리
 * Mac ClipboardManager와 유사한 기능
 */
class ClipboardService(private val context: Context) {
    
    companion object {
        private const val TAG = "ClipboardService"
    }
    
    private val clipboardManager = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    private var lastClipboardContent = ""
    private var isMonitoring = false
    private var pollingHandler: android.os.Handler? = null
    private var pollingRunnable: Runnable? = null
    private var lastProcessedTime = 0L  // 중복 전송 방지용
    
    interface ClipboardChangeListener {
        fun onClipboardChanged(content: String)
        fun onClipboardChangedForAutoSend() // 자동 전송을 위한 새로운 콜백
        fun isAppInForeground(): Boolean // 포그라운드 상태 확인
    }
    
    private var listener: ClipboardChangeListener? = null
    
    fun setListener(listener: ClipboardChangeListener) {
        this.listener = listener
    }
    
    private val clipboardListener = ClipboardManager.OnPrimaryClipChangedListener {
        Log.d(TAG, "🔔 클립보드 변경 이벤트 발생")
        
        try {
            val clipData = clipboardManager.primaryClip
            if (clipData != null && clipData.itemCount > 0) {
                val newContent = clipData.getItemAt(0).text?.toString() ?: ""
                
                Log.d(TAG, "📋 현재 클립보드 내용: ${newContent.take(50)}...")
                Log.d(TAG, "📋 이전 클립보드 내용: ${lastClipboardContent.take(50)}...")
                
                // 빈 내용이거나 이전과 동일하면 무시
                if (newContent.isNotEmpty() && newContent != lastClipboardContent) {
                    handleClipboardChange(newContent, "리스너")
                } else {
                    Log.d(TAG, "⏭️ 클립보드 변경 무시 (빈 내용 또는 중복)")
                }
            } else {
                Log.d(TAG, "⚠️ 클립보드 데이터가 없거나 비어있음")
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ 클립보드 읽기 권한 거부: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 클립보드 읽기 오류: ${e.message}")
        }
    }
    
    private fun handleClipboardChange(newContent: String, source: String) {
        val currentTime = System.currentTimeMillis()
        
        // 200ms 내에 동일한 내용이 감지되면 중복으로 간주하고 무시
        if (currentTime - lastProcessedTime < 200 && newContent == lastClipboardContent) {
            Log.d(TAG, "⚠️ 중복 클립보드 변경 무시 ($source): ${newContent.take(30)}...")
            return
        }
        
        lastClipboardContent = newContent
        lastProcessedTime = currentTime
        
        Log.d(TAG, "✅ 클립보드 변경 처리 ($source): ${newContent.take(30)}...")
        
        // 기존 콜백 (로깅용)
        listener?.onClipboardChanged(newContent)
        
        // 자동 전송 콜백 (실제 전송 트리거)
        listener?.onClipboardChangedForAutoSend()
    }
    
    fun startMonitoring() {
        if (isMonitoring) return
        
        Log.d(TAG, "📋 클립보드 폴링 모니터링 시작")
        isMonitoring = true
        
        // 현재 클립보드 내용 저장
        try {
            getCurrentClipboardContent()?.let { 
                lastClipboardContent = it
                Log.d(TAG, "초기 클립보드 내용: ${it.take(30)}...")
            }
        } catch (e: Exception) {
            Log.w(TAG, "초기 클립보드 읽기 실패: ${e.message}")
        }
        
        // 리스너 방식도 시도 (백업)
        try {
            clipboardManager.addPrimaryClipChangedListener(clipboardListener)
            Log.d(TAG, "클립보드 리스너 등록됨")
        } catch (e: Exception) {
            Log.w(TAG, "클립보드 리스너 등록 실패: ${e.message}")
        }
        
        // 폴링 방식 시작 (메인 방법)
        startPolling()
    }
    
    private fun startPolling() {
        pollingHandler = android.os.Handler(android.os.Looper.getMainLooper())
        pollingRunnable = object : Runnable {
            override fun run() {
                if (isMonitoring) {
                    checkClipboardChange()
                    pollingHandler?.postDelayed(this, 500) // 0.5초마다 체크
                }
            }
        }
        pollingHandler?.post(pollingRunnable!!)
        Log.d(TAG, "📊 클립보드 폴링 시작 (0.5초 간격)")
    }
    
    private fun checkClipboardChange() {
        val isInForeground = listener?.isAppInForeground() ?: false
        Log.d(TAG, "🔄 클립보드 체크 - 포그라운드: $isInForeground")
        
        // 앱이 포그라운드에 있을 때만 클립보드 체크 (백그라운드는 접근성 서비스가 담당)
        if (!isInForeground) {
            Log.d(TAG, "⏸️ 백그라운드 상태 - 클립보드 체크 스킵 (접근성 서비스가 담당)")
            return
        }
        
        try {
            val currentContent = getCurrentClipboardContent()
            Log.d(TAG, "📋 현재 클립보드: '${currentContent?.take(30)}...'")
            Log.d(TAG, "📋 이전 클립보드: '${lastClipboardContent.take(30)}...'")
            
            if (!currentContent.isNullOrEmpty() && currentContent != lastClipboardContent) {
                handleClipboardChange(currentContent, "폴링")
            } else {
                Log.d(TAG, "📋 클립보드 변경 없음 또는 빈 내용")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 클립보드 체크 오류: ${e.message}")
        }
    }
    
    fun stopMonitoring() {
        if (!isMonitoring) return
        
        Log.d(TAG, "📋 클립보드 모니터링 중지")
        isMonitoring = false
        
        // 폴링 중지
        pollingRunnable?.let { runnable ->
            pollingHandler?.removeCallbacks(runnable)
        }
        pollingHandler = null
        pollingRunnable = null
        
        // 리스너 제거
        try {
            clipboardManager.removePrimaryClipChangedListener(clipboardListener)
        } catch (e: Exception) {
            Log.w(TAG, "클립보드 리스너 제거 실패: ${e.message}")
        }
    }
    
    fun getCurrentClipboardContent(): String? {
        val clipData = clipboardManager.primaryClip
        return if (clipData != null && clipData.itemCount > 0) {
            clipData.getItemAt(0).text?.toString()
        } else {
            null
        }
    }
    
    fun setClipboardContent(content: String) {
        // 강제로 메인 스레드에서 실행하고 앱을 포그라운드로 전환
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            performClipboardAccess(content)
        }
    }
    
    private fun performClipboardAccess(content: String) {
        Log.d(TAG, "🔥 클립보드 접근 시작: ${content.take(30)}...")
        
        // 앱을 강제로 포그라운드로 전환
        bringAppToForeground()
        
        // 잠시 대기
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            try {
                val clipData = ClipData.newPlainText("CopyDrop", content)
                clipboardManager.setPrimaryClip(clipData)
                lastClipboardContent = content
                Log.d(TAG, "✅ 클립보드 설정 성공: ${content.take(30)}...")
            } catch (e: SecurityException) {
                Log.e(TAG, "❌ 클립보드 접근 거부: ${e.message}")
                // Accessibility Service 재시도
                retryWithAccessibilityService(content)
            } catch (e: Exception) {
                Log.e(TAG, "❌ 클립보드 설정 실패: ${e.message}")
            }
        }, 200) // 200ms 대기
    }
    
    private fun retryWithAccessibilityService(content: String) {
        if (ClipboardAccessibilityService.isServiceEnabled()) {
            Log.d(TAG, "🔄 Accessibility Service로 재시도")
            ClipboardAccessibilityService.setClipboardContent(context, content)
            lastClipboardContent = content
        } else {
            Log.e(TAG, "❌ Accessibility Service도 비활성화됨")
        }
    }
    
    private fun bringAppToForeground() {
        try {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            context.startActivity(intent)
            Log.d(TAG, "앱을 포그라운드로 가져옴")
        } catch (e: Exception) {
            Log.e(TAG, "앱을 포그라운드로 가져오기 실패: ${e.message}")
        }
    }
    
    fun isMonitoring(): Boolean = isMonitoring
}
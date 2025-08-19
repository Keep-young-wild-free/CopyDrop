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
    
    // 스마트 폴링 관련 변수들
    private var noChangeCount = 0  // 연속으로 변경이 없었던 횟수
    private var isSmartPollingStopped = false  // 스마트 폴링 중단 상태
    private val MAX_NO_CHANGE_COUNT = 3  // 3번 연속 변경 없으면 폴링 중단
    
    // 능동적 동기화 관련 변수들
    private var isActiveSyncEnabled = false  // 포그라운드 시 능동적 동기화
    private var activeSyncHandler: android.os.Handler? = null
    private var activeSyncRunnable: Runnable? = null
    private val ACTIVE_SYNC_INTERVAL = 1000L  // 1초 간격으로 능동 체크
    
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
                if (isMonitoring && !isSmartPollingStopped) {
                    checkClipboardChange()
                    pollingHandler?.postDelayed(this, 1000) // 1초마다 체크 (최적화)
                } else if (isSmartPollingStopped) {
                    Log.d(TAG, "⏸️ 스마트 폴링 중단됨 - 변경 감지 시 재시작")
                }
            }
        }
        pollingHandler?.post(pollingRunnable!!)
        Log.d(TAG, "📊 클립보드 스마트 폴링 시작 (1초 간격, 3회 무변경 시 중단)")
    }
    
    private fun checkClipboardChange() {
        val isInForeground = listener?.isAppInForeground() ?: false
        Log.d(TAG, "🔄 클립보드 체크 - 포그라운드: $isInForeground")
        
        // 포그라운드일 때는 능동적으로 체크, 백그라운드일 때는 접근성 서비스와 함께 동작
        // 백그라운드에서도 최소한의 폴링은 유지하여 이중 보안
        
        try {
            val currentContent = getCurrentClipboardContent()
            Log.d(TAG, "📋 현재 클립보드: '${currentContent?.take(30)}...'")
            Log.d(TAG, "📋 이전 클립보드: '${lastClipboardContent.take(30)}...'")
            
            if (!currentContent.isNullOrEmpty() && currentContent != lastClipboardContent) {
                // 변경 감지됨 - 카운터 리셋
                noChangeCount = 0
                isSmartPollingStopped = false
                Log.d(TAG, "✅ 클립보드 변경 감지 - 스마트 폴링 카운터 리셋")
                handleClipboardChange(currentContent, "폴링")
            } else {
                // 변경 없음 - 카운터 증가
                noChangeCount++
                Log.d(TAG, "📋 클립보드 변경 없음 ($noChangeCount/$MAX_NO_CHANGE_COUNT)")
                
                if (noChangeCount >= MAX_NO_CHANGE_COUNT) {
                    isSmartPollingStopped = true
                    Log.i(TAG, "⏸️ 스마트 폴링 중단됨 (${MAX_NO_CHANGE_COUNT}회 연속 무변경)")
                }
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
    
    // MARK: - 능동적 동기화 메서드들 (포그라운드 시 사용)
    
    /**
     * 포그라운드 전환 시 능동적 동기화 시작
     */
    fun startActiveSync() {
        if (isActiveSyncEnabled) return
        
        isActiveSyncEnabled = true
        Log.d(TAG, "🚀 능동적 동기화 시작 - ${ACTIVE_SYNC_INTERVAL}ms 간격")
        
        activeSyncHandler = android.os.Handler(android.os.Looper.getMainLooper())
        activeSyncRunnable = object : Runnable {
            override fun run() {
                if (isActiveSyncEnabled) {
                    checkClipboardForActiveSync()
                    activeSyncHandler?.postDelayed(this, ACTIVE_SYNC_INTERVAL)
                }
            }
        }
        
        activeSyncHandler?.post(activeSyncRunnable!!)
    }
    
    /**
     * 백그라운드 전환 시 능동적 동기화 중단
     */
    fun stopActiveSync() {
        if (!isActiveSyncEnabled) return
        
        isActiveSyncEnabled = false
        Log.d(TAG, "⏸️ 능동적 동기화 중단")
        
        activeSyncRunnable?.let { runnable ->
            activeSyncHandler?.removeCallbacks(runnable)
        }
        activeSyncHandler = null
        activeSyncRunnable = null
    }
    
    /**
     * 능동적 동기화를 위한 클립보드 체크
     */
    private fun checkClipboardForActiveSync() {
        try {
            val currentContent = getCurrentClipboardContent()
            
            if (!currentContent.isNullOrEmpty() && currentContent != lastClipboardContent) {
                Log.d(TAG, "🔄 능동적 동기화: 클립보드 변경 감지")
                handleClipboardChange(currentContent, "능동동기화")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 능동적 동기화 클립보드 체크 오류: ${e.message}")
        }
    }
    
    /**
     * 즉시 클립보드 체크 (푸시 알림 클릭 시 사용)
     */
    fun forceCheckClipboard() {
        Log.d(TAG, "🚀 즉시 클립보드 체크 요청")
        if (isMonitoring) {
            // 스마트 폴링이 중단된 경우 재시작
            if (isSmartPollingStopped) {
                Log.i(TAG, "🔄 스마트 폴링 재시작 (즉시 체크 요청)")
                resumeSmartPolling()
            }
            checkClipboardChange()
        } else {
            Log.w(TAG, "⚠️ 모니터링이 비활성화된 상태입니다")
        }
    }
    
    /**
     * 스마트 폴링 재시작
     */
    private fun resumeSmartPolling() {
        isSmartPollingStopped = false
        noChangeCount = 0
        Log.i(TAG, "▶️ 스마트 폴링 재시작됨")
        
        // 폴링이 중단된 상태라면 다시 시작
        if (pollingRunnable != null && pollingHandler != null) {
            pollingHandler?.post(pollingRunnable!!)
        }
    }
    
    /**
     * 포그라운드 전환 시 스마트 폴링 재시작
     */
    fun onAppForeground() {
        if (isSmartPollingStopped) {
            Log.i(TAG, "🔄 앱 포그라운드 전환 - 스마트 폴링 재시작")
            resumeSmartPolling()
        }
    }
}
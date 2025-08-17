package com.copydrop.android.service

import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.Log
import android.view.*
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import com.copydrop.android.MainActivity
import com.copydrop.android.R

class FloatingService : Service() {
    
    companion object {
        private const val TAG = "FloatingService"
        
        // 서비스 액션
        const val ACTION_START_FLOATING = "START_FLOATING"
        const val ACTION_STOP_FLOATING = "STOP_FLOATING"
        const val ACTION_UPDATE_STATUS = "UPDATE_STATUS"
        
        // 상태 업데이트 인텐트 extras
        const val EXTRA_CONNECTION_STATUS = "connection_status"
        const val EXTRA_RECENT_ACTIVITY = "recent_activity"
        
        // 연결 상태
        const val STATUS_DISCONNECTED = 0
        const val STATUS_CONNECTING = 1
        const val STATUS_CONNECTED = 2
    }
    
    private var windowManager: WindowManager? = null
    private var floatingView: View? = null
    private var expandedView: View? = null
    
    private var isExpanded = false
    private var connectionStatus = STATUS_DISCONNECTED
    private var recentActivity = "활동 없음"
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_FLOATING -> {
                if (checkPermission()) {
                    startFloating()
                } else {
                    Log.w(TAG, "오버레이 권한이 없습니다")
                    stopSelf()
                }
            }
            ACTION_STOP_FLOATING -> {
                stopFloating()
            }
            ACTION_UPDATE_STATUS -> {
                updateStatus(intent)
            }
        }
        return START_NOT_STICKY
    }
    
    private fun checkPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    private fun startFloating() {
        if (floatingView != null) return
        
        Log.d(TAG, "플로팅 윈도우 시작")
        
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        
        // 작은 플로팅 버튼 생성
        createFloatingButton()
    }
    
    private fun createFloatingButton() {
        floatingView = LayoutInflater.from(this).inflate(R.layout.floating_widget, null)
        
        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        
        // 초기 위치 설정 (화면 오른쪽 중앙)
        layoutParams.gravity = Gravity.TOP or Gravity.START
        layoutParams.x = 100
        layoutParams.y = 300
        
        // UI 컴포넌트 설정
        val floatingIcon = floatingView?.findViewById<TextView>(R.id.floatingIcon)
        val floatingStatus = floatingView?.findViewById<TextView>(R.id.floatingStatus)
        
        updateFloatingStatus(floatingStatus)
        
        // 터치 이벤트 설정
        setupFloatingTouchEvents(layoutParams)
        
        // 클릭 이벤트 설정
        floatingView?.setOnClickListener {
            Log.d(TAG, "🖱️ 플로팅 버튼 클릭됨 (확장상태: $isExpanded)")
            if (isExpanded) {
                collapseFloating()
            } else {
                expandFloating()
            }
        }
        
        try {
            windowManager?.addView(floatingView, layoutParams)
        } catch (e: Exception) {
            Log.e(TAG, "플로팅 윈도우 추가 실패: ${e.message}")
        }
    }
    
    private fun setupFloatingTouchEvents(layoutParams: WindowManager.LayoutParams) {
        var initialX = 0
        var initialY = 0
        var initialTouchX = 0f
        var initialTouchY = 0f
        var isDragging = false
        
        floatingView?.setOnTouchListener { view, event ->
            when (event.action) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = layoutParams.x
                    initialY = layoutParams.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    isDragging = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val deltaX = Math.abs(event.rawX - initialTouchX)
                    val deltaY = Math.abs(event.rawY - initialTouchY)
                    
                    // 10픽셀 이상 움직이면 드래그로 인식
                    if (deltaX > 10 || deltaY > 10) {
                        isDragging = true
                        layoutParams.x = initialX + (event.rawX - initialTouchX).toInt()
                        layoutParams.y = initialY + (event.rawY - initialTouchY).toInt()
                        windowManager?.updateViewLayout(floatingView, layoutParams)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!isDragging) {
                        // 드래그가 아니면 클릭으로 처리
                        view.performClick()
                    }
                    false
                }
                else -> false
            }
        }
    }
    
    private fun expandFloating() {
        if (isExpanded) return
        
        Log.d(TAG, "📈 확장 윈도우 열기 시작")
        isExpanded = true
        
        // 확장된 뷰 생성
        expandedView = LayoutInflater.from(this).inflate(R.layout.floating_expanded, null)
        
        val layoutParams = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            },
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )
        
        layoutParams.gravity = Gravity.CENTER
        
        // UI 업데이트
        updateExpandedView()
        
        // 버튼 이벤트 설정
        setupExpandedButtons()
        
        try {
            windowManager?.addView(expandedView, layoutParams)
            Log.d(TAG, "✅ 확장 윈도우 추가 성공")
            
            // 작은 버튼 숨기기
            floatingView?.visibility = View.GONE
        } catch (e: Exception) {
            Log.e(TAG, "❌ 확장 윈도우 추가 실패: ${e.message}")
            isExpanded = false
        }
    }
    
    private fun collapseFloating() {
        if (!isExpanded) return
        
        isExpanded = false
        
        try {
            expandedView?.let { windowManager?.removeView(it) }
            expandedView = null
            
            // 작은 버튼 다시 보이기
            floatingView?.visibility = View.VISIBLE
        } catch (e: Exception) {
            Log.e(TAG, "확장 윈도우 제거 실패: ${e.message}")
        }
    }
    
    private fun setupExpandedButtons() {
        val closeButton = expandedView?.findViewById<TextView>(R.id.closeButton)
        val syncButton = expandedView?.findViewById<Button>(R.id.syncButton)
        val openAppButton = expandedView?.findViewById<Button>(R.id.openAppButton)
        
        closeButton?.setOnClickListener {
            collapseFloating()
        }
        
        syncButton?.setOnClickListener {
            // 메인 앱에 동기화 요청 전송
            sendBroadcast(Intent("com.copydrop.android.MANUAL_SYNC"))
            Toast.makeText(this, "동기화 요청됨", Toast.LENGTH_SHORT).show()
        }
        
        openAppButton?.setOnClickListener {
            openMainApp()
            collapseFloating()
        }
    }
    
    private fun updateExpandedView() {
        val connectionStatusView = expandedView?.findViewById<TextView>(R.id.connectionStatus)
        val recentActivityView = expandedView?.findViewById<TextView>(R.id.recentActivity)
        
        connectionStatusView?.text = when (connectionStatus) {
            STATUS_DISCONNECTED -> "🔴 연결 안됨"
            STATUS_CONNECTING -> "🟡 연결 중"
            STATUS_CONNECTED -> "🟢 연결됨"
            else -> "❓ 알 수 없음"
        }
        
        recentActivityView?.text = recentActivity
    }
    
    private fun updateFloatingStatus(statusView: TextView?) {
        statusView?.text = when (connectionStatus) {
            STATUS_DISCONNECTED -> "●"
            STATUS_CONNECTING -> "●"
            STATUS_CONNECTED -> "●"
            else -> "●"
        }
        
        statusView?.setTextColor(
            resources.getColor(
                when (connectionStatus) {
                    STATUS_DISCONNECTED -> android.R.color.holo_red_dark
                    STATUS_CONNECTING -> android.R.color.holo_orange_dark
                    STATUS_CONNECTED -> android.R.color.holo_green_dark
                    else -> android.R.color.darker_gray
                }
            )
        )
    }
    
    private fun updateStatus(intent: Intent) {
        connectionStatus = intent.getIntExtra(EXTRA_CONNECTION_STATUS, STATUS_DISCONNECTED)
        recentActivity = intent.getStringExtra(EXTRA_RECENT_ACTIVITY) ?: "활동 없음"
        
        // UI 업데이트
        val floatingStatus = floatingView?.findViewById<TextView>(R.id.floatingStatus)
        updateFloatingStatus(floatingStatus)
        
        if (isExpanded) {
            updateExpandedView()
        }
        
        Log.d(TAG, "상태 업데이트: 연결=$connectionStatus, 활동=$recentActivity")
    }
    
    private fun stopFloating() {
        Log.d(TAG, "플로팅 윈도우 중지")
        
        try {
            floatingView?.let { windowManager?.removeView(it) }
            expandedView?.let { windowManager?.removeView(it) }
        } catch (e: Exception) {
            Log.e(TAG, "플로팅 윈도우 제거 실패: ${e.message}")
        }
        
        floatingView = null
        expandedView = null
        isExpanded = false
        
        stopSelf()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopFloating()
    }
    
    private fun openMainApp() {
        try {
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            startActivity(intent)
            Log.d(TAG, "메인 앱 열기")
        } catch (e: Exception) {
            Log.e(TAG, "메인 앱 열기 실패: ${e.message}")
        }
    }
}
package com.copydrop.android.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.copydrop.android.MainActivity
import com.copydrop.android.R

/**
 * 클립보드 동기화를 위한 포그라운드 서비스
 * Android 10+ 클립보드 접근 제한을 우회하기 위해 사용
 */
class ClipboardSyncService : Service() {
    
    companion object {
        private const val TAG = "ClipboardSyncService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "clipboard_sync_channel"
        const val ACTION_START_SYNC = "START_SYNC"
        const val ACTION_STOP_SYNC = "STOP_SYNC"
    }
    
    private lateinit var clipboardService: ClipboardService
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ClipboardSyncService 생성됨")
        
        clipboardService = ClipboardService(this)
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START_SYNC -> {
                Log.d(TAG, "클립보드 동기화 시작")
                startForeground(NOTIFICATION_ID, createNotification())
                clipboardService.startMonitoring()
            }
            ACTION_STOP_SYNC -> {
                Log.d(TAG, "클립보드 동기화 중지")
                clipboardService.stopMonitoring()
                stopForeground(true)
                stopSelf()
            }
        }
        
        return START_STICKY // 서비스가 종료되면 자동으로 재시작
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "ClipboardSyncService 종료됨")
        clipboardService.stopMonitoring()
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "클립보드 동기화",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Mac과 클립보드를 동기화합니다"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("CopyDrop")
            .setContentText("클립보드 동기화 중...")
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
    
    fun setClipboardListener(listener: ClipboardService.ClipboardChangeListener) {
        clipboardService.setListener(listener)
    }
    
    fun setClipboardContent(content: String) {
        clipboardService.setClipboardContent(content)
    }
}
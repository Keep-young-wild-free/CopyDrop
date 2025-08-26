package com.copydrop.android.util

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * 알림 관련 유틸리티 클래스
 * 알림 생성 및 관리를 담당
 */
object NotificationUtil {
    
    // 알림 채널 ID
    const val CLIPBOARD_SYNC_CHANNEL = "clipboard_sync"
    const val SYNC_CHANNEL_ID = "sync_channel"
    
    // 알림 ID
    const val CLIPBOARD_SYNC_NOTIFICATION_ID = 1001
    const val SYNC_NOTIFICATION_ID = 2
    
    /**
     * 알림 채널 초기화
     */
    fun createNotificationChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // 클립보드 동기화 채널
            val clipboardChannel = NotificationChannel(
                CLIPBOARD_SYNC_CHANNEL,
                "클립보드 동기화",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Mac에서 클립보드 동기화 알림"
                setSound(null, null)
                enableVibration(false)
            }
            
            // 동기화 서비스 채널
            val syncChannel = NotificationChannel(
                SYNC_CHANNEL_ID,
                "동기화 서비스",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "백그라운드 클립보드 동기화 서비스"
                setSound(null, null)
                enableVibration(false)
            }
            
            notificationManager.createNotificationChannel(clipboardChannel)
            notificationManager.createNotificationChannel(syncChannel)
        }
    }
    
    /**
     * 클립보드 동기화 알림 생성
     */
    fun createClipboardSyncNotification(context: Context, content: String): Notification {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pendingIntent = PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CLIPBOARD_SYNC_CHANNEL)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentTitle("📥 Mac에서 클립보드 동기화")
                .setContentText("${content.take(40)}...")
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .build()
        } else {
            Notification.Builder(context)
                .setSmallIcon(android.R.drawable.ic_menu_share)
                .setContentTitle("📥 Mac에서 클립보드 동기화")
                .setContentText("${content.take(40)}...")
                .setContentIntent(pendingIntent)
                .setAutoCancel(true)
                .setPriority(Notification.PRIORITY_DEFAULT)
                .build()
        }
    }
    
    /**
     * 동기화 서비스 포그라운드 알림 생성
     */
    fun createSyncServiceNotification(context: Context): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, SYNC_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_email)
                .setContentTitle("CopyDrop")
                .setContentText("클립보드 동기화 서비스 실행 중...")
                .setOngoing(true)
                .build()
        } else {
            Notification.Builder(context)
                .setSmallIcon(android.R.drawable.ic_dialog_email)
                .setContentTitle("CopyDrop")
                .setContentText("클립보드 동기화 서비스 실행 중...")
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_LOW)
                .build()
        }
    }
    
    /**
     * 알림 표시
     */
    fun showNotification(context: Context, notificationId: Int, notification: Notification) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(notificationId, notification)
    }
    
    /**
     * 클립보드 동기화 알림 표시 (편의 메서드)
     */
    fun showClipboardSyncNotification(context: Context, content: String) {
        val notification = createClipboardSyncNotification(context, content)
        showNotification(context, CLIPBOARD_SYNC_NOTIFICATION_ID, notification)
    }
}
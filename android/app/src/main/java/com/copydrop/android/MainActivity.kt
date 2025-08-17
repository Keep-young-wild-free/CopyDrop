package com.copydrop.android

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.widget.Toast
import android.app.Activity
import com.copydrop.android.model.ClipboardMessage
import com.copydrop.android.model.ClipboardHistory
import com.copydrop.android.service.BluetoothService
import com.copydrop.android.service.ClipboardService
import com.copydrop.android.service.ClipboardSyncService
import com.copydrop.android.service.ClipboardAccessibilityService
import com.copydrop.android.adapter.ClipboardHistoryAdapter
import android.provider.Settings
import android.text.TextUtils
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent

class MainActivity : Activity() {
    
    companion object {
        private const val TAG = "MainActivity"
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
        private const val SYNC_NOTIFICATION_ID = 1001
        private const val SYNC_CHANNEL_ID = "clipboard_sync_channel"
    }
    
    // UI 컴포넌트들
    private lateinit var statusText: android.widget.TextView
    private lateinit var connectionIndicator: android.view.View
    private lateinit var scanButton: android.widget.Button
    private lateinit var disconnectButton: android.widget.Button
    private lateinit var clipboardStatus: android.widget.TextView
    private lateinit var sendClipboardButton: android.widget.Button
    private lateinit var accessibilityButton: android.widget.Button
    private lateinit var historyListView: android.widget.ListView
    private lateinit var clearHistoryButton: android.widget.Button
    private lateinit var bluetoothService: BluetoothService
    private lateinit var clipboardService: ClipboardService
    
    // 클립보드 기록
    private lateinit var historyAdapter: ClipboardHistoryAdapter
    private val historyList = mutableListOf<ClipboardHistory>()
    
    private var isConnected = false
    private var discoveredDevices = mutableListOf<BluetoothDevice>()
    private var isAppInForeground = false
    private var pendingClipboardContent: String? = null
    private var lastSentContent = ""
    private var lastSentTime = 0L
    
    // 브로드캐스트 리시버
    private val appReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: android.content.Context?, intent: Intent?) {
            when (intent?.action) {
                "com.copydrop.android.MANUAL_SYNC" -> {
                    sendCurrentClipboard(isAutomatic = false)
                }
                "com.copydrop.android.CLIPBOARD_CHANGED" -> {
                    val content = intent.getStringExtra("content")
                    val source = intent.getStringExtra("source")
                    Log.d(TAG, "📡 백그라운드 클립보드 변경 알림 수신 ($source): ${content?.take(30)}...")
                    
                    if (!content.isNullOrEmpty() && isConnected) {
                        Log.d(TAG, "🚀 백그라운드에서 자동 전송 시작")
                        sendClipboardContent(content, isAutomatic = true)
                    }
                }
                "com.copydrop.android.SHOW_SYNC_TOAST" -> {
                    val message = intent.getStringExtra("message") ?: "Mac으로 전송하시겠습니까?"
                    val action = intent.getStringExtra("action") ?: "터치하여 전송"
                    val content = intent.getStringExtra("content")
                    Log.d(TAG, "📱 알림 요청 수신: $message, 내용: ${content?.take(30)}...")
                    
                    showSyncToast(message, action, content)
                }
                "com.copydrop.android.SYNC_FROM_NOTIFICATION" -> {
                    Log.d(TAG, "🔔 알림 클릭됨 - 앱 포그라운드 전환 후 클립보드 전송")
                    bringAppToForegroundForClipboard()
                }
            }
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        try {
            setTheme(R.style.Theme_CopyDrop)
        } catch (e: Exception) {
            // 테마 설정 실패 시 무시
        }
        
        setContentView(R.layout.activity_main)
        
        initUI()
        initServices()
        setupUI()
        checkAccessibilityService()
        checkBluetoothSupport()
        createNotificationChannel()
        
        // 브로드캐스트 리시버 등록
        val intentFilter = IntentFilter().apply {
            addAction("com.copydrop.android.MANUAL_SYNC")
            addAction("com.copydrop.android.CLIPBOARD_CHANGED")
            addAction("com.copydrop.android.SHOW_SYNC_TOAST")
            addAction("com.copydrop.android.SYNC_FROM_NOTIFICATION")
        }
        registerReceiver(appReceiver, intentFilter)
    }
    
    private fun initUI() {
        statusText = findViewById(R.id.statusText)
        connectionIndicator = findViewById(R.id.connectionIndicator)
        scanButton = findViewById(R.id.scanButton)
        disconnectButton = findViewById(R.id.disconnectButton)
        clipboardStatus = findViewById(R.id.clipboardStatus)
        sendClipboardButton = findViewById(R.id.sendClipboardButton)
        accessibilityButton = findViewById(R.id.accessibilityButton)
        historyListView = findViewById(R.id.historyListView)
        clearHistoryButton = findViewById(R.id.clearHistoryButton)
        
        // 리스트뷰 어댑터 설정
        historyAdapter = ClipboardHistoryAdapter(this, historyList)
        historyListView.adapter = historyAdapter
    }
    
    private fun initServices() {
        bluetoothService = BluetoothService(this)
        clipboardService = ClipboardService(this)
        
        bluetoothService.setCallback(bluetoothCallback)
        clipboardService.setListener(clipboardListener)
    }
    
    private fun setupUI() {
        scanButton.setOnClickListener {
            if (!isConnected) {
                startScan()
            }
        }
        
        disconnectButton.setOnClickListener {
            disconnect()
        }
        
        sendClipboardButton.setOnClickListener {
            sendCurrentClipboard()
        }
        
        clearHistoryButton.setOnClickListener {
            historyAdapter.clearHistory()
            showMessage("🗑️ 클립보드 기록이 삭제되었습니다")
        }
        
        accessibilityButton.setOnClickListener {
            openAccessibilitySettings()
        }
        
        updateUI()
    }
    
    private fun checkAccessibilityService() {
        val isServiceEnabled = ClipboardAccessibilityService.isServiceEnabled()
        val isSystemEnabled = isAccessibilityServiceEnabled()
        
        Log.d(TAG, "접근성 서비스 상태 체크:")
        Log.d(TAG, "- Instance 존재: $isServiceEnabled")
        Log.d(TAG, "- 시스템 설정 활성화: $isSystemEnabled")
        
        if (!isServiceEnabled) {
            Log.w(TAG, "⚠️ 접근성 서비스 Instance가 비활성화되어 있습니다")
        } else {
            Log.d(TAG, "✅ 접근성 서비스 Instance가 활성화되어 있습니다")
        }
        
        if (!isSystemEnabled) {
            Log.w(TAG, "⚠️ 시스템 설정에서 접근성 서비스가 비활성화되어 있습니다")
        } else {
            Log.d(TAG, "✅ 시스템 설정에서 접근성 서비스가 활성화되어 있습니다")
        }
    }
    
    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = try {
            Settings.Secure.getInt(contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED)
        } catch (e: Settings.SettingNotFoundException) {
            0
        }
        
        if (accessibilityEnabled == 1) {
            val services = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            val serviceName = "${packageName}/.service.ClipboardAccessibilityService"
            return !TextUtils.isEmpty(services) && services.contains(serviceName)
        }
        return false
    }
    
    private fun checkBluetoothSupport() {
        if (!packageManager.hasSystemFeature(PackageManager.FEATURE_BLUETOOTH_LE)) {
            showMessage("이 기기는 BLE를 지원하지 않습니다")
            finish()
            return
        }
        
        val bluetoothManager = getSystemService(BLUETOOTH_SERVICE) as BluetoothManager
        if (bluetoothManager.adapter == null) {
            showMessage("블루투스를 지원하지 않는 기기입니다")
            finish()
            return
        }
        
        checkBluetoothEnabled()
    }
    
    private fun checkBluetoothEnabled() {
        if (!bluetoothService.isBluetoothEnabled()) {
            val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
            startActivityForResult(enableBtIntent, 1000)
        } else {
            checkPermissions()
        }
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 1000) {
            if (resultCode == RESULT_OK) {
                checkPermissions()
            } else {
                showMessage("블루투스가 필요합니다")
            }
        }
    }
    
    private fun checkPermissions() {
        val permissions = mutableListOf<String>()
        
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_SCAN) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.BLUETOOTH_SCAN)
            }
            if (checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
            }
        }
        
        if (permissions.isNotEmpty()) {
            requestPermissions(permissions.toTypedArray(), LOCATION_PERMISSION_REQUEST_CODE)
        } else {
            onPermissionsGranted()
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == LOCATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                onPermissionsGranted()
            } else {
                showMessage("블루투스 권한이 필요합니다")
            }
        }
    }
    
    private fun onPermissionsGranted() {
        scanButton.isEnabled = true
        statusText.text = "준비됨 - 스캔을 시작하세요"
        statusText.setTextColor(resources.getColor(android.R.color.holo_orange_dark))
        startScan()
    }
    
    private fun startScan() {
        Log.d(TAG, "Mac CopyDropService 검색 시작")
        discoveredDevices.clear()
        scanButton.text = "🔍 " + getString(R.string.scanning)
        scanButton.isEnabled = false
        statusText.text = "🔍 Mac 검색 중..."
        statusText.setTextColor(resources.getColor(android.R.color.holo_orange_dark))
        updateConnectionIndicator(false, true)
        
        bluetoothService.startScan()
    }
    
    private fun connect(device: BluetoothDevice) {
        Log.d(TAG, "CopyDropService 연결 시도")
        bluetoothService.connectToDevice(device)
        scanButton.text = "🔗 연결 중..."
        scanButton.isEnabled = false
        statusText.text = "🔗 Mac에 연결 중..."
        statusText.setTextColor(resources.getColor(android.R.color.holo_orange_dark))
        updateConnectionIndicator(false, true)
    }
    
    private fun disconnect() {
        bluetoothService.disconnect()
        stopClipboardSyncService()
        isConnected = false
        updateUI()
    }
    
    private fun updateUI() {
        if (isConnected) {
            statusText.text = "✅ " + getString(R.string.connected)
            statusText.setTextColor(resources.getColor(android.R.color.holo_green_dark))
            updateConnectionIndicator(true)
            scanButton.text = "✅ 연결됨"
            scanButton.isEnabled = false
            disconnectButton.isEnabled = true
            clipboardStatus.text = "🔄 클립보드 동기화 활성화 - 자동 감지 중"
            clipboardStatus.setTextColor(resources.getColor(android.R.color.holo_green_dark))
            sendClipboardButton.isEnabled = true
        } else {
            statusText.text = "❌ " + getString(R.string.disconnected)
            statusText.setTextColor(resources.getColor(android.R.color.holo_red_dark))
            updateConnectionIndicator(false)
            scanButton.text = getString(R.string.scan_for_devices)
            scanButton.isEnabled = true
            disconnectButton.isEnabled = false
            clipboardStatus.text = "⏸️ 클립보드 동기화 비활성화"
            clipboardStatus.setTextColor(resources.getColor(android.R.color.darker_gray))
            sendClipboardButton.isEnabled = false
        }
    }
    
    private fun updateConnectionIndicator(connected: Boolean, scanning: Boolean = false) {
        val drawable = android.graphics.drawable.GradientDrawable()
        drawable.shape = android.graphics.drawable.GradientDrawable.OVAL
        drawable.setColor(
            when {
                connected -> resources.getColor(android.R.color.holo_green_dark)
                scanning -> resources.getColor(android.R.color.holo_orange_dark)
                else -> resources.getColor(android.R.color.holo_red_dark)
            }
        )
        connectionIndicator.background = drawable
    }
    
    private fun startClipboardSyncService() {
        val intent = Intent(this, ClipboardSyncService::class.java).apply {
            action = ClipboardSyncService.ACTION_START_SYNC
        }
        startForegroundService(intent)
        Log.d(TAG, "ClipboardSyncService 시작됨")
    }
    
    private fun stopClipboardSyncService() {
        val intent = Intent(this, ClipboardSyncService::class.java).apply {
            action = ClipboardSyncService.ACTION_STOP_SYNC
        }
        startService(intent)
        Log.d(TAG, "ClipboardSyncService 중지됨")
    }
    
    private fun sendCurrentClipboard(isAutomatic: Boolean = false) {
        if (!isConnected) {
            if (!isAutomatic) showMessage("Mac과 연결되지 않음")
            return
        }
        
        try {
            var currentContent = clipboardService.getCurrentClipboardContent()
            
            if (currentContent.isNullOrEmpty() && isAutomatic) {
                Log.w(TAG, "일반 클립보드 읽기 실패, 접근성 서비스 상태 확인")
                
                if (ClipboardAccessibilityService.isServiceEnabled()) {
                    Log.d(TAG, "접근성 서비스 활성화됨, 재시도")
                    Thread.sleep(50)
                    currentContent = clipboardService.getCurrentClipboardContent()
                }
            }
            
            if (!currentContent.isNullOrEmpty()) {
                // 중복 전송 방지
                val currentTime = System.currentTimeMillis()
                if (currentContent == lastSentContent && currentTime - lastSentTime < 2000) {
                    Log.d(TAG, "⚠️ 중복 전송 방지: ${currentContent.take(30)}...")
                    return
                }
                
                if (isAutomatic) {
                    Log.d(TAG, "🤖 자동 클립보드 전송: ${currentContent.take(30)}...")
                } else {
                    Log.d(TAG, "🚀 수동 클립보드 전송: ${currentContent.take(30)}...")
                }
                
                lastSentContent = currentContent
                lastSentTime = currentTime
                
                bluetoothService.sendMessage(currentContent)
                
                val history = ClipboardHistory(
                    content = currentContent,
                    direction = ClipboardHistory.Direction.SENT,
                    deviceName = "Mac"
                )
                
                runOnUiThread {
                    historyAdapter.addHistory(history)
                }
                
                if (isAutomatic) {
                    showMessage("📱 → 💻 자동 동기화됨")
                } else {
                    showMessage("📤 클립보드 전송됨")
                }
            } else {
                if (isAutomatic) {
                    Log.w(TAG, "자동 전송: 클립보드 내용이 비어있거나 읽기 실패")
                } else {
                    showMessage("클립보드가 비어있습니다")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "클립보드 읽기 실패: ${e.message}")
            if (!isAutomatic) showMessage("클립보드 읽기 실패")
        }
    }
    
    private fun sendClipboardContent(content: String, isAutomatic: Boolean = false) {
        if (!isConnected) {
            if (!isAutomatic) showMessage("Mac과 연결되지 않음")
            return
        }
        
        try {
            // 중복 전송 방지
            val currentTime = System.currentTimeMillis()
            if (content == lastSentContent && currentTime - lastSentTime < 2000) {
                Log.d(TAG, "⚠️ 중복 전송 방지: ${content.take(30)}...")
                return
            }
            
            if (isAutomatic) {
                Log.d(TAG, "🤖 자동 클립보드 전송: ${content.take(30)}...")
            } else {
                Log.d(TAG, "🚀 수동 클립보드 전송: ${content.take(30)}...")
            }
            
            lastSentContent = content
            lastSentTime = currentTime
            
            bluetoothService.sendMessage(content)
            
            val history = ClipboardHistory(
                content = content,
                direction = ClipboardHistory.Direction.SENT,
                deviceName = "Mac"
            )
            
            runOnUiThread {
                historyAdapter.addHistory(history)
            }
            
            if (isAutomatic) {
                showMessage("📱 → 💻 백그라운드 동기화됨")
            } else {
                showMessage("📤 클립보드 전송됨")
            }
        } catch (e: Exception) {
            Log.e(TAG, "클립보드 전송 실패: ${e.message}")
            if (!isAutomatic) showMessage("클립보드 전송 실패")
        }
    }
    
    private fun showMessage(message: String) {
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                SYNC_CHANNEL_ID,
                "클립보드 동기화",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Mac과 클립보드 동기화 알림"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun showSyncToast(message: String, action: String, content: String?) {
        runOnUiThread {
            Log.d(TAG, "📱 동기화 알림 표시: $message")
            
            pendingClipboardContent = content
            
            val syncIntent = Intent("com.copydrop.android.SYNC_FROM_NOTIFICATION")
            val syncPendingIntent = PendingIntent.getBroadcast(
                this, 0, syncIntent, 
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.app.Notification.Builder(this, SYNC_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_menu_send)
                    .setContentTitle("📱 → 💻 Mac으로 전송")
                    .setContentText("탭하여 클립보드를 Mac으로 전송")
                    .setAutoCancel(true)
                    .setTimeoutAfter(5000)
                    .setContentIntent(syncPendingIntent)
                    .addAction(android.app.Notification.Action.Builder(
                        android.R.drawable.ic_menu_send, "전송", syncPendingIntent).build())
                    .build()
            } else {
                android.app.Notification.Builder(this)
                    .setSmallIcon(android.R.drawable.ic_menu_send)
                    .setContentTitle("📱 → 💻 Mac으로 전송")
                    .setContentText("탭하여 클립보드를 Mac으로 전송")
                    .setAutoCancel(true)
                    .setContentIntent(syncPendingIntent)
                    .build()
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(SYNC_NOTIFICATION_ID, notification)
            
            Log.d(TAG, "📡 동기화 알림 표시 완료")
        }
    }
    
    private fun bringAppToForegroundForClipboard() {
        try {
            Log.d(TAG, "🚀 알림 클릭 - 앱을 포그라운드로 전환")
            
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            startActivity(intent)
            
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                sendCurrentClipboardFromToast()
            }, 300)
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ 포그라운드 전환 실패: ${e.message}")
            showMessage("❌ 전송 실패")
        }
    }
    
    private fun sendCurrentClipboardFromToast() {
        try {
            Log.d(TAG, "🔍 알림 클릭 - 저장된 클립보드 전송 시작")
            
            val currentContent = pendingClipboardContent ?: clipboardService.getCurrentClipboardContent()
            
            if (!currentContent.isNullOrEmpty() && isConnected) {
                Log.d(TAG, "📤 알림 클릭으로 클립보드 전송: ${currentContent.take(30)}...")
                sendClipboardContent(currentContent, isAutomatic = false)
                showMessage("📱 → 💻 Mac으로 전송됨!")
                
                pendingClipboardContent = null
            } else if (!isConnected) {
                showMessage("❌ Mac과 연결되지 않음")
            } else {
                showMessage("❌ 클립보드가 비어있음")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ 알림 클릭 클립보드 전송 실패: ${e.message}")
            showMessage("❌ 전송 실패")
        }
    }
    
    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            showMessage("⚡ CopyDrop을 찾아서 활성화해주세요")
        } catch (e: Exception) {
            Log.e(TAG, "접근성 설정 열기 실패: ${e.message}")
            showMessage("설정을 열 수 없습니다")
        }
    }
    
    private fun updateAccessibilityButton() {
        val isServiceEnabled = ClipboardAccessibilityService.isServiceEnabled()
        val isSystemEnabled = isAccessibilityServiceEnabled()
        
        if (isServiceEnabled && isSystemEnabled) {
            accessibilityButton.text = "⚡ 접근성 서비스 활성화됨"
            accessibilityButton.setBackgroundColor(resources.getColor(android.R.color.holo_green_light))
            accessibilityButton.setTextColor(resources.getColor(android.R.color.white))
        } else {
            accessibilityButton.text = "⚡ 접근성 설정 필요 (백그라운드용)"
            accessibilityButton.setBackgroundColor(resources.getColor(android.R.color.holo_orange_light))
            accessibilityButton.setTextColor(resources.getColor(android.R.color.black))
        }
        
        Log.d(TAG, "접근성 상태 - Instance: $isServiceEnabled, System: $isSystemEnabled")
    }
    
    private val bluetoothCallback = object : BluetoothService.BluetoothServiceCallback {
        override fun onDeviceFound(device: BluetoothDevice) {
            runOnUiThread {
                Log.d(TAG, "CopyDropService 발견: ${device.name}")
                discoveredDevices.add(device)
                
                connect(device)
            }
        }
        
        override fun onConnected() {
            runOnUiThread {
                Log.d(TAG, "CopyDropService 연결 완료")
                isConnected = true
                updateUI()
                startClipboardSyncService()
                clipboardService.startMonitoring()
                showMessage("🎉 Mac과 연결되었습니다!")
            }
        }
        
        override fun onDisconnected() {
            runOnUiThread {
                Log.d(TAG, "CopyDropService 연결 해제")
                isConnected = false
                updateUI()
                stopClipboardSyncService()
                clipboardService.stopMonitoring()
                showMessage("🔌 연결이 해제되었습니다")
            }
        }
        
        override fun onMessageReceived(message: ClipboardMessage) {
            runOnUiThread {
                Log.d(TAG, "📥 Mac에서 클립보드 수신: ${message.content.take(30)}...")
                
                clipboardService.setClipboardContent(message.content)
                
                val history = ClipboardHistory(
                    content = message.content,
                    direction = ClipboardHistory.Direction.RECEIVED,
                    deviceName = "Mac"
                )
                historyAdapter.addHistory(history)
                
                showMessage("📥 클립보드 동기화됨")
            }
        }
        
        override fun onError(error: String) {
            runOnUiThread {
                Log.e(TAG, "BLE 오류: $error")
                showMessage("오류: $error")
                scanButton.text = getString(R.string.scan_for_devices)
                scanButton.isEnabled = true
            }
        }
    }
    
    private val clipboardListener = object : ClipboardService.ClipboardChangeListener {
        override fun onClipboardChanged(content: String) {
            Log.d(TAG, "📋 MainActivity: onClipboardChanged 호출됨")
        }
        
        override fun onClipboardChangedForAutoSend() {
            Log.d(TAG, "🚀 MainActivity: onClipboardChangedForAutoSend 호출됨 (연결상태: $isConnected)")
            
            if (isConnected) {
                Log.d(TAG, "🔄 클립보드 변경 감지 → 자동 전송 시작")
                
                isAppInForeground = true
                
                sendCurrentClipboard(isAutomatic = true)
            } else {
                Log.d(TAG, "⚠️ 클립보드 변경 감지되었지만 Mac과 연결되지 않음")
            }
        }
        
        override fun isAppInForeground(): Boolean {
            return isAppInForeground
        }
    }
    
    override fun onResume() {
        super.onResume()
        isAppInForeground = true
        Log.d(TAG, "📱 앱이 포그라운드로 전환됨 - 폴링 활성화")
        
        updateAccessibilityButton()
    }
    
    override fun onPause() {
        super.onPause()
        isAppInForeground = false
        Log.d(TAG, "📱 앱이 백그라운드로 전환됨 - 폴링 비활성화")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        stopClipboardSyncService()
        clipboardService.stopMonitoring()
        bluetoothService.disconnect()
        
        try {
            unregisterReceiver(appReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "브로드캐스트 리시버 해제 실패: ${e.message}")
        }
    }
}
package com.copydrop.android.ui

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.TextView
import android.widget.RelativeLayout
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.copydrop.android.MainActivity
import com.copydrop.android.R
import com.copydrop.android.service.BluetoothService
import com.copydrop.android.model.ClipboardMessage

/**
 * Pin 입력 전용 Activity
 * 앱 진입 시 전체 화면으로 Pin 입력 받기
 */
class PinInputActivity : Activity() {
    
    companion object {
        private const val TAG = "PinInputActivity"
        private const val BLUETOOTH_PERMISSION_REQUEST_CODE = 100
    }
    
    private lateinit var pinContainer: RelativeLayout
    private lateinit var pinInputs: List<TextView>
    private lateinit var statusText: TextView
    private lateinit var titleText: TextView
    private lateinit var bluetoothService: BluetoothService
    
    private var currentPinIndex = 0
    private var enteredPin = StringBuilder()
    private var isAuthenticating = false
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_pin_input)
        
        initViews()
        setupPinInputs()
        
        // BluetoothService 초기화
        bluetoothService = BluetoothService(this)
        bluetoothService.setCallback(bluetoothCallback)
        
        // 블루투스 권한 확인 및 요청
        checkBluetoothPermissions()
        
        Log.d(TAG, "🔐 Pin 입력 화면 시작")
    }
    
    private fun initViews() {
        pinContainer = findViewById(R.id.pinContainer)
        titleText = findViewById(R.id.titleText)
        statusText = findViewById(R.id.statusText)
        
        pinInputs = listOf(
            findViewById(R.id.pin1),
            findViewById(R.id.pin2),
            findViewById(R.id.pin3),
            findViewById(R.id.pin4)
        )
        
        titleText.text = "CopyDrop"
        statusText.text = "Mac에서 표시된 4자리 Pin을 입력하세요"
    }
    
    private fun setupPinInputs() {
        // 숫자 버튼 클릭 리스너
        val numberButtons = listOf(
            findViewById<View>(R.id.btn1),
            findViewById<View>(R.id.btn2),
            findViewById<View>(R.id.btn3),
            findViewById<View>(R.id.btn4),
            findViewById<View>(R.id.btn5),
            findViewById<View>(R.id.btn6),
            findViewById<View>(R.id.btn7),
            findViewById<View>(R.id.btn8),
            findViewById<View>(R.id.btn9),
            findViewById<View>(R.id.btn0)
        )
        
        numberButtons.forEachIndexed { index, button ->
            val number = if (index == 9) "0" else "${index + 1}"
            button.setOnClickListener { onNumberClicked(number) }
        }
    }
    
    private fun onNumberClicked(number: String) {
        if (currentPinIndex < 4 && !isAuthenticating) {
            pinInputs[currentPinIndex].text = number
            pinInputs[currentPinIndex].setBackgroundResource(R.drawable.pin_digit_filled)
            
            enteredPin.append(number)
            currentPinIndex++
            
            if (currentPinIndex == 4) {
                // 4자리 입력 완료 - 자동 인증 시작
                startAuthentication()
            }
        }
    }
    
    private fun checkBluetoothPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) { // Android 12+
            val permissions = arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT,
                Manifest.permission.ACCESS_FINE_LOCATION
            )
            
            val missingPermissions = permissions.filter { permission ->
                ContextCompat.checkSelfPermission(this, permission) != PackageManager.PERMISSION_GRANTED
            }
            
            if (missingPermissions.isNotEmpty()) {
                Log.d(TAG, "🔐 블루투스 권한 요청: ${missingPermissions.joinToString()}")
                statusText.text = "블루투스 권한이 필요합니다"
                ActivityCompat.requestPermissions(
                    this,
                    missingPermissions.toTypedArray(),
                    BLUETOOTH_PERMISSION_REQUEST_CODE
                )
            } else {
                Log.d(TAG, "✅ 모든 블루투스 권한 확인됨")
            }
        }
    }
    
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        
        if (requestCode == BLUETOOTH_PERMISSION_REQUEST_CODE) {
            val allGranted = grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            
            if (allGranted) {
                Log.d(TAG, "✅ 블루투스 권한 승인됨")
                statusText.text = "Mac에서 표시된 4자리 Pin을 입력하세요"
            } else {
                Log.w(TAG, "❌ 블루투스 권한 거부됨")
                statusText.text = "블루투스 권한이 필요합니다. 설정에서 권한을 허용해주세요."
                statusText.setTextColor(resources.getColor(android.R.color.holo_red_dark))
            }
        }
    }
    
    private fun startAuthentication() {
        // 권한 재확인
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = ContextCompat.checkSelfPermission(
                this, Manifest.permission.BLUETOOTH_SCAN
            ) == PackageManager.PERMISSION_GRANTED
            
            if (!hasPermission) {
                showError("블루투스 스캔 권한이 필요합니다")
                return
            }
        }
        
        isAuthenticating = true
        statusText.text = "Mac과 연결 중입니다..."
        
        val pin = enteredPin.toString()
        Log.d(TAG, "🔐 Pin 입력 완료: $pin - 자동 스캔 및 인증 시작")
        
        if (!bluetoothService.isBluetoothEnabled()) {
            showError("블루투스를 활성화해주세요")
            return
        }
        
        // Pin 인증 시작
        bluetoothService.authenticateWithPin(pin)
        bluetoothService.startScan()
        
        // 20초 타임아웃
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            if (isAuthenticating) {
                bluetoothService.stopScan()
                showError("Mac을 찾을 수 없습니다")
            }
        }, 20000)
    }
    
    private fun showError(message: String) {
        isAuthenticating = false
        statusText.text = "❌ $message"
        statusText.setTextColor(resources.getColor(android.R.color.holo_red_dark))
        
        // Pin 입력 초기화
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            resetPinInput()
        }, 2000)
    }
    
    private fun resetPinInput() {
        enteredPin.clear()
        currentPinIndex = 0
        
        pinInputs.forEach { pinView ->
            pinView.text = ""
            pinView.setBackgroundResource(R.drawable.pin_digit_empty)
        }
        
        statusText.text = "Mac에서 표시된 4자리 Pin을 입력하세요"
        statusText.setTextColor(resources.getColor(android.R.color.black))
    }
    
    private fun navigateToMainActivity() {
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        startActivity(intent)
        finish()
    }
    
    private val bluetoothCallback = object : BluetoothService.BluetoothServiceCallback {
        override fun onDeviceFound(device: android.bluetooth.BluetoothDevice) {
            runOnUiThread {
                Log.d(TAG, "📱 Mac 발견: ${device.name} - 연결 시도")
                statusText.text = "Mac 발견! 연결 중..."
                
                // BluetoothService의 connectToDevice 메서드 호출
                bluetoothService.connectToDevice(device)
            }
        }
        
        override fun onConnected() {
            runOnUiThread {
                Log.d(TAG, "✅ 블루투스 연결 성공")
                statusText.text = "✅ 연결되었습니다!"
                statusText.setTextColor(resources.getColor(android.R.color.holo_green_dark))
            }
        }
        
        override fun onDisconnected() {
            runOnUiThread {
                showError("연결이 끊어졌습니다")
            }
        }
        
        override fun onMessageReceived(message: ClipboardMessage) {
            // 메시지 처리
        }
        
        override fun onError(error: String) {
            runOnUiThread {
                showError(error)
            }
        }
        
        override fun onSyncRequested() {
            // 동기화 요청 처리
        }
        
        override fun onAuthRequired() {
            runOnUiThread {
                showError("Pin 인증이 필요합니다")
            }
        }
        
        override fun onAuthSuccess(sessionToken: String) {
            runOnUiThread {
                Log.d(TAG, "🎉 Pin 인증 성공!")
                statusText.text = "✅ 인증 성공!"
                statusText.setTextColor(resources.getColor(android.R.color.holo_green_dark))
                
                // 1.5초 후 메인 화면으로 이동
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    navigateToMainActivity()
                }, 1500)
            }
        }
        
        override fun onAuthFailed(error: String) {
            runOnUiThread {
                Log.w(TAG, "❌ PIN 인증 실패: $error")
                bluetoothService.clearPinAuthentication() // PIN 상태 초기화
                showError(error)
            }
        }
    }
}
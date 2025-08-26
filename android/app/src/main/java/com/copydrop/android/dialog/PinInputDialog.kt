package com.copydrop.android.dialog

import android.app.AlertDialog
import android.content.Context
import android.graphics.Color
import android.text.Editable
import android.text.TextWatcher
import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.EditText
import android.widget.ProgressBar
import android.widget.TextView
import com.copydrop.android.R

/**
 * Pin 입력 다이얼로그
 * Mac에서 생성된 4자리 Pin을 입력받습니다
 */
class PinInputDialog(
    private val context: Context,
    private val onPinEntered: (String) -> Unit,
    private val onCancel: () -> Unit
) {
    
    private var bluetoothService: com.copydrop.android.service.BluetoothService? = null
    
    private var dialog: AlertDialog? = null
    private lateinit var pinEditText: EditText
    private lateinit var connectButton: Button
    private lateinit var progressBar: ProgressBar
    private lateinit var statusText: TextView
    private lateinit var instructionText: TextView
    
    fun show() {
        val dialogView = LayoutInflater.from(context).inflate(R.layout.dialog_pin_input, null)
        
        setupViews(dialogView)
        setupListeners(dialogView)
        
        dialog = AlertDialog.Builder(context)
            .setView(dialogView)
            .setCancelable(true)
            .setOnCancelListener { onCancel() }
            .create()
        
        dialog?.show()
        
        // 입력 필드에 포커스
        pinEditText.requestFocus()
    }
    
    /**
     * BluetoothService 설정
     */
    fun setBluetoothService(service: com.copydrop.android.service.BluetoothService) {
        this.bluetoothService = service
    }
    
    private fun setupViews(view: View) {
        pinEditText = view.findViewById(R.id.pinEditText)
        connectButton = view.findViewById(R.id.connectButton)
        progressBar = view.findViewById(R.id.progressBar)
        statusText = view.findViewById(R.id.statusText)
        instructionText = view.findViewById(R.id.instructionText)
        
        // 초기 상태 설정
        connectButton.isEnabled = false
        progressBar.visibility = View.GONE
        statusText.text = ""
        instructionText.text = "Mac에서 표시된 4자리 Pin을 입력하세요"
        
        // Pin 입력 필드 설정
        pinEditText.filters = arrayOf(android.text.InputFilter.LengthFilter(4))
        pinEditText.inputType = android.text.InputType.TYPE_CLASS_NUMBER
    }
    
    private fun setupListeners(view: View) {
        // Pin 입력 감지
        pinEditText.addTextChangedListener(object : TextWatcher {
            override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
            
            override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {
                val pin = s?.toString() ?: ""
                connectButton.isEnabled = pin.length == 4 && pin.all { it.isDigit() }
                
                // 입력 상태에 따른 UI 업데이트
                if (pin.length == 4) {
                    statusText.text = ""
                    statusText.setTextColor(Color.BLACK)
                } else if (pin.isNotEmpty()) {
                    statusText.text = "4자리를 모두 입력하세요"
                    statusText.setTextColor(Color.GRAY)
                } else {
                    statusText.text = ""
                }
            }
            
            override fun afterTextChanged(s: Editable?) {}
        })
        
        // 연결 버튼 클릭
        connectButton.setOnClickListener {
            val pin = pinEditText.text.toString()
            if (pin.length == 4 && pin.all { it.isDigit() }) {
                showAuthenticating()
                startBluetoothScanAndConnect(pin)
            }
        }
        
        // 취소 버튼 클릭
        view.findViewById<Button>(R.id.cancelButton).setOnClickListener {
            dismiss()
            onCancel()
        }
    }
    
    /**
     * 인증 중 상태 표시
     */
    fun showAuthenticating() {
        pinEditText.isEnabled = false
        connectButton.isEnabled = false
        progressBar.visibility = View.VISIBLE
        statusText.text = "인증 중..."
        statusText.setTextColor(Color.BLUE)
        instructionText.text = "Mac과 연결 중입니다. 잠시만 기다려주세요."
    }
    
    /**
     * 인증 성공 상태 표시
     */
    fun showAuthSuccess() {
        progressBar.visibility = View.GONE
        statusText.text = "✅ 연결 성공!"
        statusText.setTextColor(Color.parseColor("#4CAF50")) // Green
        instructionText.text = "Mac과 성공적으로 연결되었습니다."
        
        // 1초 후 다이얼로그 닫기
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            dismiss()
        }, 1500)
    }
    
    /**
     * 인증 실패 상태 표시
     */
    fun showAuthError(error: String) {
        pinEditText.isEnabled = true
        connectButton.isEnabled = pinEditText.text.toString().length == 4
        progressBar.visibility = View.GONE
        statusText.text = "❌ $error"
        statusText.setTextColor(Color.RED)
        instructionText.text = "Pin을 다시 확인하고 재시도하세요."
        
        // 입력 필드 선택
        pinEditText.selectAll()
        pinEditText.requestFocus()
    }
    
    /**
     * 다이얼로그 닫기
     */
    fun dismiss() {
        dialog?.dismiss()
        dialog = null
    }
    
    /**
     * 다이얼로그가 표시 중인지 확인
     */
    fun isShowing(): Boolean {
        return dialog?.isShowing == true
    }
    
    /**
     * Pin 입력 후 자동으로 블루투스 스캔 및 연결 시작
     */
    private fun startBluetoothScanAndConnect(pin: String) {
        bluetoothService?.let { service ->
            // 스캔 시작
            instructionText.text = "Mac을 검색하고 있습니다..."
            statusText.text = "검색 중..."
            
            // Pin을 저장하고 인증 시작
            onPinEntered(pin)
        } ?: run {
            // BluetoothService가 없는 경우 기본 동작
            onPinEntered(pin)
        }
    }
}
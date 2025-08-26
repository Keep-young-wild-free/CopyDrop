package com.copydrop.android.util

import android.content.Context
import android.widget.Toast
import timber.log.Timber

/**
 * 사용자 친화적인 에러 핸들링 및 메시지 표시
 */
object ErrorHandler {
    
    /**
     * 에러 타입별 분류
     */
    sealed class CopyDropError(
        val title: String,
        val message: String,
        val actionMessage: String? = null,
        val isRecoverable: Boolean = true
    ) {
        
        // 블루투스 관련 에러
        object BluetoothNotSupported : CopyDropError(
            title = "블루투스 미지원",
            message = "이 기기는 Bluetooth Low Energy를 지원하지 않습니다.",
            isRecoverable = false
        )
        
        object BluetoothDisabled : CopyDropError(
            title = "블루투스 비활성화",
            message = "블루투스를 켜주세요.",
            actionMessage = "설정 → 블루투스"
        )
        
        object BluetoothPermissionDenied : CopyDropError(
            title = "블루투스 권한 필요",
            message = "앱이 다른 기기와 연결하려면 블루투스 권한이 필요합니다.",
            actionMessage = "설정 → 권한 → 근처 기기"
        )
        
        object LocationPermissionDenied : CopyDropError(
            title = "위치 권한 필요",
            message = "블루투스 기기 검색을 위해 위치 권한이 필요합니다.",
            actionMessage = "설정 → 권한 → 위치"
        )
        
        // 연결 관련 에러
        object ConnectionTimeout : CopyDropError(
            title = "연결 시간 초과",
            message = "Mac을 찾을 수 없습니다. Mac에서 블루투스 서버가 시작되었는지 확인해주세요.",
            actionMessage = "Mac에서 '블루투스 서버 시작' 확인"
        )
        
        object ConnectionLost : CopyDropError(
            title = "연결 끊김",
            message = "Mac과의 연결이 끊어졌습니다. 다시 연결을 시도합니다.",
            actionMessage = "기기를 가까이 두고 재시도"
        )
        
        object DeviceNotFound : CopyDropError(
            title = "기기를 찾을 수 없음",
            message = "CopyDrop이 실행 중인 Mac을 찾을 수 없습니다.",
            actionMessage = "Mac 앱 실행 후 '블루투스 서버 시작'"
        )
        
        // PIN 인증 관련 에러
        object InvalidPin : CopyDropError(
            title = "잘못된 PIN",
            message = "입력한 PIN이 올바르지 않습니다. Mac 화면의 4자리 PIN을 확인해주세요.",
            actionMessage = "Mac 화면의 PIN 확인"
        )
        
        object PinExpired : CopyDropError(
            title = "PIN 만료",
            message = "PIN이 만료되었습니다. Mac에서 새 PIN을 생성해주세요.",
            actionMessage = "Mac에서 'Pin으로 연결' 다시 선택"
        )
        
        object SessionExpired : CopyDropError(
            title = "세션 만료",
            message = "인증 세션이 만료되었습니다. 다시 PIN을 입력해주세요.",
            actionMessage = "PIN 재입력 필요"
        )
        
        // 클립보드 관련 에러
        object ClipboardAccessDenied : CopyDropError(
            title = "클립보드 접근 권한 필요",
            message = "백그라운드 클립보드 동기화를 위해 접근성 서비스 권한이 필요합니다.",
            actionMessage = "설정 → 접근성 → CopyDrop 활성화"
        )
        
        object ClipboardEmpty : CopyDropError(
            title = "빈 클립보드",
            message = "클립보드가 비어있어서 전송할 내용이 없습니다.",
            isRecoverable = true
        )
        
        object DataTooLarge : CopyDropError(
            title = "데이터 크기 초과",
            message = "파일이 너무 큽니다. Wi-Fi 환경에서 더 빠르게 전송할 수 있습니다.",
            actionMessage = "Wi-Fi 연결 권장"
        )
        
        // 암호화 관련 에러
        object EncryptionFailed : CopyDropError(
            title = "암호화 실패",
            message = "데이터 암호화에 실패했습니다. 다시 시도해주세요.",
            isRecoverable = true
        )
        
        object DecryptionFailed : CopyDropError(
            title = "복호화 실패",
            message = "받은 데이터를 해독할 수 없습니다. 다시 전송을 요청해주세요.",
            isRecoverable = true
        )
        
        // 네트워크/일반 에러
        data class Unknown(val originalError: String) : CopyDropError(
            title = "예상치 못한 오류",
            message = "알 수 없는 오류가 발생했습니다: $originalError",
            actionMessage = "앱 재시작 또는 문의",
            isRecoverable = true
        )
    }
    
    /**
     * 사용자에게 친절한 에러 메시지 표시
     */
    fun showError(context: Context, error: CopyDropError) {
        Timber.e("에러 발생: ${error.title} - ${error.message}")
        
        val displayMessage = if (error.actionMessage != null) {
            "${error.message}\n\n💡 해결방법: ${error.actionMessage}"
        } else {
            error.message
        }
        
        // Toast로 표시 (추후 Dialog나 Snackbar로 확장 가능)
        Toast.makeText(context, displayMessage, Toast.LENGTH_LONG).show()
    }
    
    /**
     * 간단한 에러 메시지 표시
     */
    fun showSimpleError(context: Context, message: String) {
        Timber.w("간단한 에러: $message")
        Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
    }
    
    /**
     * 성공 메시지 표시
     */
    fun showSuccess(context: Context, message: String) {
        Timber.i("성공: $message")
        Toast.makeText(context, "✅ $message", Toast.LENGTH_SHORT).show()
    }
    
    /**
     * 정보 메시지 표시
     */
    fun showInfo(context: Context, message: String) {
        Timber.i("정보: $message")
        Toast.makeText(context, "ℹ️ $message", Toast.LENGTH_SHORT).show()
    }
    
    /**
     * Exception으로부터 CopyDropError 생성
     */
    fun fromException(exception: Exception): CopyDropError {
        return when {
            exception.message?.contains("bluetooth", ignoreCase = true) == true -> 
                CopyDropError.BluetoothDisabled
            exception.message?.contains("permission", ignoreCase = true) == true -> 
                CopyDropError.BluetoothPermissionDenied
            exception.message?.contains("timeout", ignoreCase = true) == true -> 
                CopyDropError.ConnectionTimeout
            exception.message?.contains("connection", ignoreCase = true) == true -> 
                CopyDropError.ConnectionLost
            else -> CopyDropError.Unknown(exception.message ?: "알 수 없는 오류")
        }
    }
}
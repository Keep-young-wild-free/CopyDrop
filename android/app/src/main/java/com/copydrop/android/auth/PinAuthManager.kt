package com.copydrop.android.auth

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import com.google.gson.Gson
import com.copydrop.android.util.CryptoUtil
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.SecretKeySpec
import kotlin.random.Random

/**
 * Pin 기반 인증 관리 클래스
 * - Pin 검증
 * - 세션 키 생성 및 관리
 * - 자동 재연결을 위한 토큰 관리
 */
class PinAuthManager(private val context: Context) {
    
    companion object {
        private const val TAG = "PinAuthManager"
        private const val PREFS_NAME = "copydrop_auth"
        private const val KEY_SESSION_TOKEN = "session_token"
        private const val KEY_DEVICE_ID = "device_id"
        private const val PIN_LENGTH = 4
        private const val SESSION_VALIDITY_HOURS = 24
    }
    
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val gson = Gson()
    
    /**
     * 세션 토큰 정보
     */
    data class SessionToken(
        val token: String,
        val deviceId: String,
        val createdAt: Long,
        val expiresAt: Long
    )
    
    /**
     * 인증 요청 메시지
     */
    data class AuthRequest(
        val pin: String,
        val deviceId: String,
        val timestamp: Long = System.currentTimeMillis()
    )
    
    /**
     * 인증 응답 메시지  
     */
    data class AuthResponse(
        val success: Boolean,
        val sessionToken: String? = null,
        val error: String? = null,
        val timestamp: Long = System.currentTimeMillis()
    )
    
    /**
     * Pin 검증 (Mac에서 받은 Pin과 비교)
     */
    fun validatePin(inputPin: String, expectedPin: String): Boolean {
        if (inputPin.length != PIN_LENGTH || expectedPin.length != PIN_LENGTH) {
            Log.w(TAG, "Pin 길이 오류: input=${inputPin.length}, expected=${expectedPin.length}")
            return false
        }
        
        val isValid = inputPin == expectedPin
        Log.d(TAG, "Pin 검증 결과: $isValid")
        return isValid
    }
    
    /**
     * 세션 토큰 생성
     */
    fun generateSessionToken(): String {
        val random = SecureRandom()
        val bytes = ByteArray(32)
        random.nextBytes(bytes)
        return bytes.joinToString("") { "%02x".format(it) }
    }
    
    /**
     * 세션 토큰 저장
     */
    fun saveSessionToken(token: String, deviceId: String) {
        val sessionToken = SessionToken(
            token = token,
            deviceId = deviceId,
            createdAt = System.currentTimeMillis(),
            expiresAt = System.currentTimeMillis() + (SESSION_VALIDITY_HOURS * 60 * 60 * 1000)
        )
        
        prefs.edit()
            .putString(KEY_SESSION_TOKEN, gson.toJson(sessionToken))
            .apply()
            
        Log.d(TAG, "세션 토큰 저장 완료: ${token.take(8)}...")
    }
    
    /**
     * 저장된 세션 토큰 가져오기
     */
    fun getSavedSessionToken(): SessionToken? {
        val tokenJson = prefs.getString(KEY_SESSION_TOKEN, null) ?: return null
        
        return try {
            val sessionToken = gson.fromJson(tokenJson, SessionToken::class.java)
            
            // 만료 확인
            if (System.currentTimeMillis() > sessionToken.expiresAt) {
                Log.d(TAG, "세션 토큰 만료됨")
                clearSessionToken()
                null
            } else {
                Log.d(TAG, "유효한 세션 토큰 발견: ${sessionToken.token.take(8)}...")
                sessionToken
            }
        } catch (e: Exception) {
            Log.e(TAG, "세션 토큰 파싱 실패", e)
            clearSessionToken()
            null
        }
    }
    
    /**
     * 세션 토큰 삭제
     */
    fun clearSessionToken() {
        prefs.edit()
            .remove(KEY_SESSION_TOKEN)
            .apply()
        
        // 암호화 키도 함께 삭제
        CryptoUtil.deleteSessionKey()
        
        Log.d(TAG, "세션 토큰 및 암호화 키 삭제됨")
    }
    
    /**
     * 디바이스 ID 생성 또는 가져오기
     */
    fun getOrCreateDeviceId(): String {
        var deviceId = prefs.getString(KEY_DEVICE_ID, null)
        
        if (deviceId == null) {
            // 새 디바이스 ID 생성
            deviceId = "android-${System.currentTimeMillis()}-${Random.nextInt(1000, 9999)}"
            prefs.edit()
                .putString(KEY_DEVICE_ID, deviceId)
                .apply()
            Log.d(TAG, "새 디바이스 ID 생성: $deviceId")
        }
        
        return deviceId
    }
    
    /**
     * 인증 요청 메시지 생성
     */
    fun createAuthRequest(pin: String): String {
        val deviceId = getOrCreateDeviceId()
        val authRequest = AuthRequest(pin = pin, deviceId = deviceId)
        
        val message = mapOf(
            "type" to "auth_request",
            "data" to authRequest
        )
        
        return gson.toJson(message)
    }
    
    /**
     * 인증 응답 파싱
     */
    fun parseAuthResponse(jsonString: String): AuthResponse? {
        return try {
            val messageMap = gson.fromJson(jsonString, Map::class.java) as Map<String, Any>
            
            if (messageMap["type"] == "auth_response") {
                val dataMap = messageMap["data"] as Map<String, Any>
                AuthResponse(
                    success = dataMap["success"] as Boolean,
                    sessionToken = dataMap["sessionToken"] as? String,
                    error = dataMap["error"] as? String,
                    timestamp = (dataMap["timestamp"] as Double).toLong()
                )
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e(TAG, "인증 응답 파싱 실패", e)
            null
        }
    }
    
    /**
     * 자동 재연결 시도
     */
    fun canAutoReconnect(): Boolean {
        val sessionToken = getSavedSessionToken()
        val canReconnect = sessionToken != null
        Log.d(TAG, "자동 재연결 가능: $canReconnect")
        return canReconnect
    }
    
    /**
     * 세션 토큰으로 재연결 요청 생성
     */
    fun createReconnectRequest(): String? {
        val sessionToken = getSavedSessionToken() ?: return null
        
        val message = mapOf(
            "type" to "reconnect_request",
            "data" to mapOf(
                "sessionToken" to sessionToken.token,
                "deviceId" to sessionToken.deviceId,
                "timestamp" to System.currentTimeMillis()
            )
        )
        
        return gson.toJson(message)
    }
}
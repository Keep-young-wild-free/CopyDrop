package com.copydrop.android.util

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * BLE 통신용 AES 암호화 유틸리티
 */
object CryptoUtil {
    private const val TAG = "CryptoUtil"
    
    // 암호화 설정
    private const val TRANSFORMATION = "AES/CBC/PKCS5Padding"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val KEY_ALIAS = "copydrop_session_key"
    private const val IV_SIZE = 16 // AES block size
    
    /**
     * 세션 키 생성 (Android KeyStore 사용)
     */
    fun generateSessionKey(): String {
        return try {
            val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
            val keyGenParameterSpec = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_CBC)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_PKCS7)
                .setRandomizedEncryptionRequired(true)
                .build()
            
            keyGenerator.init(keyGenParameterSpec)
            keyGenerator.generateKey()
            
            Log.d(TAG, "✅ Android KeyStore에 세션 키 생성됨")
            KEY_ALIAS
        } catch (e: Exception) {
            Log.e(TAG, "❌ 세션 키 생성 실패: ${e.message}")
            // Fallback: 임시 키 생성
            generateFallbackKey()
        }
    }
    
    /**
     * Fallback 키 생성 (KeyStore 실패 시)
     */
    private fun generateFallbackKey(): String {
        val keyGenerator = KeyGenerator.getInstance("AES")
        keyGenerator.init(256)
        val secretKey = keyGenerator.generateKey()
        return Base64.encodeToString(secretKey.encoded, Base64.NO_WRAP)
    }
    
    /**
     * 데이터 암호화
     */
    fun encrypt(data: String, sessionToken: String): String? {
        return try {
            val secretKey = getSecretKey(sessionToken)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            
            val iv = cipher.iv
            val encryptedData = cipher.doFinal(data.toByteArray())
            
            // IV + 암호화된 데이터를 Base64로 인코딩
            val combined = iv + encryptedData
            Base64.encodeToString(combined, Base64.NO_WRAP)
        } catch (e: Exception) {
            Log.e(TAG, "❌ 암호화 실패: ${e.message}")
            null
        }
    }
    
    /**
     * 데이터 복호화
     */
    fun decrypt(encryptedData: String, sessionToken: String): String? {
        return try {
            val secretKey = getSecretKey(sessionToken)
            val combined = Base64.decode(encryptedData, Base64.NO_WRAP)
            
            // IV와 암호화된 데이터 분리
            val iv = combined.sliceArray(0 until IV_SIZE)
            val encrypted = combined.sliceArray(IV_SIZE until combined.size)
            
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, secretKey, IvParameterSpec(iv))
            
            val decryptedData = cipher.doFinal(encrypted)
            String(decryptedData)
        } catch (e: Exception) {
            Log.e(TAG, "❌ 복호화 실패: ${e.message}")
            null
        }
    }
    
    /**
     * 세션 토큰으로부터 SecretKey 생성
     */
    private fun getSecretKey(sessionToken: String): SecretKey {
        return try {
            // Android KeyStore에서 키 조회 시도
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
            keyStore.load(null)
            
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.getKey(KEY_ALIAS, null) as SecretKey
            } else {
                // KeyStore에 키가 없으면 세션 토큰 기반으로 생성
                createKeyFromToken(sessionToken)
            }
        } catch (e: Exception) {
            Log.w(TAG, "KeyStore 접근 실패, 세션 토큰 기반 키 사용: ${e.message}")
            createKeyFromToken(sessionToken)
        }
    }
    
    /**
     * 세션 토큰으로부터 AES 키 파생
     */
    private fun createKeyFromToken(sessionToken: String): SecretKey {
        // 세션 토큰을 SHA-256으로 해시하여 32바이트 키 생성
        val digest = java.security.MessageDigest.getInstance("SHA-256")
        val keyBytes = digest.digest(sessionToken.toByteArray())
        return SecretKeySpec(keyBytes, "AES")
    }
    
    /**
     * 키 삭제 (로그아웃 시)
     */
    fun deleteSessionKey() {
        try {
            val keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
            keyStore.load(null)
            keyStore.deleteEntry(KEY_ALIAS)
            Log.d(TAG, "🗑️ 세션 키 삭제됨")
        } catch (e: Exception) {
            Log.e(TAG, "❌ 세션 키 삭제 실패: ${e.message}")
        }
    }
}
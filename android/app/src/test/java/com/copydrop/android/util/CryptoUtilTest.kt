package com.copydrop.android.util

import org.junit.Test
import org.junit.Assert.*
import org.junit.Before
import org.mockito.MockedStatic
import org.mockito.Mockito.*

/**
 * CryptoUtil 단위 테스트
 */
class CryptoUtilTest {
    
    private val testSessionToken = "test-session-token-12345"
    private val testPlainText = "Hello, CopyDrop! This is a test message for encryption."
    
    @Before
    fun setUp() {
        // 테스트 초기화
    }
    
    @Test
    fun `암호화 후 복호화가 원본 데이터와 일치하는지 테스트`() {
        // Given
        val originalText = testPlainText
        
        // When
        val encrypted = CryptoUtil.encrypt(originalText, testSessionToken)
        
        // Then
        assertNotNull("암호화 결과가 null이면 안됨", encrypted)
        assertNotEquals("암호화된 데이터는 원본과 달라야 함", originalText, encrypted)
        
        // When
        val decrypted = CryptoUtil.decrypt(encrypted!!, testSessionToken)
        
        // Then
        assertNotNull("복호화 결과가 null이면 안됨", decrypted)
        assertEquals("복호화된 데이터는 원본과 같아야 함", originalText, decrypted)
    }
    
    @Test
    fun `빈 문자열 암호화 테스트`() {
        // Given
        val emptyText = ""
        
        // When
        val encrypted = CryptoUtil.encrypt(emptyText, testSessionToken)
        val decrypted = CryptoUtil.decrypt(encrypted!!, testSessionToken)
        
        // Then
        assertEquals("빈 문자열도 정상 처리되어야 함", emptyText, decrypted)
    }
    
    @Test
    fun `잘못된 세션 토큰으로 복호화 실패 테스트`() {
        // Given
        val originalText = testPlainText
        val encrypted = CryptoUtil.encrypt(originalText, testSessionToken)
        val wrongToken = "wrong-session-token"
        
        // When
        val decrypted = CryptoUtil.decrypt(encrypted!!, wrongToken)
        
        // Then
        assertNull("잘못된 토큰으로는 복호화가 실패해야 함", decrypted)
    }
    
    @Test
    fun `잘못된 Base64 데이터 복호화 실패 테스트`() {
        // Given
        val invalidBase64 = "this-is-not-base64-data!"
        
        // When
        val decrypted = CryptoUtil.decrypt(invalidBase64, testSessionToken)
        
        // Then
        assertNull("잘못된 Base64 데이터는 복호화 실패해야 함", decrypted)
    }
    
    @Test
    fun `긴 텍스트 암호화 테스트`() {
        // Given
        val longText = "안녕하세요! ".repeat(1000) // 약 8KB 텍스트
        
        // When
        val encrypted = CryptoUtil.encrypt(longText, testSessionToken)
        val decrypted = CryptoUtil.decrypt(encrypted!!, testSessionToken)
        
        // Then
        assertEquals("긴 텍스트도 정상 처리되어야 함", longText, decrypted)
    }
    
    @Test
    fun `한글 텍스트 암호화 테스트`() {
        // Given
        val koreanText = "안녕하세요! CopyDrop 암호화 테스트입니다. 🔐✨"
        
        // When
        val encrypted = CryptoUtil.encrypt(koreanText, testSessionToken)
        val decrypted = CryptoUtil.decrypt(encrypted!!, testSessionToken)
        
        // Then
        assertEquals("한글과 이모지가 정상 처리되어야 함", koreanText, decrypted)
    }
    
    @Test
    fun `세션 키 삭제 테스트`() {
        // Given - 키가 생성되어 있다고 가정
        
        // When
        CryptoUtil.deleteSessionKey()
        
        // Then
        // 예외가 발생하지 않아야 함 (성공 케이스)
        assertTrue("키 삭제가 예외 없이 완료되어야 함", true)
    }
    
    @Test
    fun `동시성 테스트 - 여러 스레드에서 암호화`() {
        // Given
        val testData = "Concurrent encryption test"
        val results = mutableListOf<String?>()
        
        // When
        val threads = (1..5).map { threadId ->
            Thread {
                val encrypted = CryptoUtil.encrypt("$testData-$threadId", testSessionToken)
                synchronized(results) {
                    results.add(encrypted)
                }
            }
        }
        
        threads.forEach { it.start() }
        threads.forEach { it.join() }
        
        // Then
        assertEquals("모든 스레드가 성공해야 함", 5, results.size)
        results.forEach { encrypted ->
            assertNotNull("모든 암호화가 성공해야 함", encrypted)
        }
    }
    
    @Test
    fun `암호화 성능 테스트`() {
        // Given
        val testText = "Performance test data"
        
        // When
        val startTime = System.currentTimeMillis()
        repeat(100) {
            val encrypted = CryptoUtil.encrypt(testText, testSessionToken)
            CryptoUtil.decrypt(encrypted!!, testSessionToken)
        }
        val duration = System.currentTimeMillis() - startTime
        
        // Then
        assertTrue("100회 암복호화가 5초 이내 완료되어야 함", duration < 5000)
        println("100회 암복호화 소요시간: ${duration}ms")
    }
}
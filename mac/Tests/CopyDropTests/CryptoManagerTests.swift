import XCTest
@testable import CopyDrop

/**
 * CryptoManager 단위 테스트
 */
final class CryptoManagerTests: XCTestCase {
    
    private var cryptoManager: CryptoManager!
    private let testSessionToken = "test-session-token-12345"
    
    override func setUp() {
        super.setUp()
        cryptoManager = CryptoManager.shared
    }
    
    override func tearDown() {
        cryptoManager = nil
        super.tearDown()
    }
    
    func testEncryptionAndDecryption() {
        // Given
        let originalText = "Hello, CopyDrop! This is a test message for Mac encryption."
        
        // When
        let encrypted = cryptoManager.encrypt(originalText, sessionToken: testSessionToken)
        
        // Then
        XCTAssertNotNil(encrypted, "암호화 결과가 nil이면 안됨")
        XCTAssertNotEqual(originalText, encrypted, "암호화된 데이터는 원본과 달라야 함")
        
        // When
        let decrypted = cryptoManager.decrypt(encrypted!, sessionToken: testSessionToken)
        
        // Then
        XCTAssertNotNil(decrypted, "복호화 결과가 null이면 안됨")
        XCTAssertEqual(originalText, decrypted, "복호화된 데이터는 원본과 같아야 함")
    }
    
    func testEmptyStringEncryption() {
        // Given
        let emptyText = ""
        
        // When
        let encrypted = cryptoManager.encrypt(emptyText, sessionToken: testSessionToken)
        let decrypted = cryptoManager.decrypt(encrypted!, sessionToken: testSessionToken)
        
        // Then
        XCTAssertEqual(emptyText, decrypted, "빈 문자열도 정상 처리되어야 함")
    }
    
    func testWrongSessionTokenDecryption() {
        // Given
        let originalText = "Test message"
        let encrypted = cryptoManager.encrypt(originalText, sessionToken: testSessionToken)
        let wrongToken = "wrong-session-token"
        
        // When
        let decrypted = cryptoManager.decrypt(encrypted!, sessionToken: wrongToken)
        
        // Then
        XCTAssertNil(decrypted, "잘못된 토큰으로는 복호화가 실패해야 함")
    }
    
    func testInvalidBase64Decryption() {
        // Given
        let invalidBase64 = "this-is-not-base64-data!"
        
        // When
        let decrypted = cryptoManager.decrypt(invalidBase64, sessionToken: testSessionToken)
        
        // Then
        XCTAssertNil(decrypted, "잘못된 Base64 데이터는 복호화 실패해야 함")
    }
    
    func testLongTextEncryption() {
        // Given
        let longText = String(repeating: "안녕하세요! ", count: 1000) // 약 8KB 텍스트
        
        // When
        let encrypted = cryptoManager.encrypt(longText, sessionToken: testSessionToken)
        let decrypted = cryptoManager.decrypt(encrypted!, sessionToken: testSessionToken)
        
        // Then
        XCTAssertEqual(longText, decrypted, "긴 텍스트도 정상 처리되어야 함")
    }
    
    func testKoreanTextWithEmojis() {
        // Given
        let koreanText = "안녕하세요! CopyDrop Mac 암호화 테스트입니다. 🔐✨🚀"
        
        // When
        let encrypted = cryptoManager.encrypt(koreanText, sessionToken: testSessionToken)
        let decrypted = cryptoManager.decrypt(encrypted!, sessionToken: testSessionToken)
        
        // Then
        XCTAssertEqual(koreanText, decrypted, "한글과 이모지가 정상 처리되어야 함")
    }
    
    func testEncryptionConsistency() {
        // Given
        let testText = "Consistency test"
        
        // When - 같은 데이터를 여러 번 암호화
        let encrypted1 = cryptoManager.encrypt(testText, sessionToken: testSessionToken)
        let encrypted2 = cryptoManager.encrypt(testText, sessionToken: testSessionToken)
        
        // Then - AES-GCM은 매번 다른 결과를 생성해야 함 (랜덤 nonce 사용)
        XCTAssertNotEqual(encrypted1, encrypted2, "AES-GCM은 매번 다른 암호화 결과를 생성해야 함")
        
        // But both should decrypt to the same original text
        let decrypted1 = cryptoManager.decrypt(encrypted1!, sessionToken: testSessionToken)
        let decrypted2 = cryptoManager.decrypt(encrypted2!, sessionToken: testSessionToken)
        
        XCTAssertEqual(testText, decrypted1, "첫 번째 복호화가 원본과 같아야 함")
        XCTAssertEqual(testText, decrypted2, "두 번째 복호화가 원본과 같아야 함")
    }
    
    func testEncryptionPerformance() {
        // Given
        let testText = "Performance test data for encryption"
        
        // When & Then
        self.measure {
            for _ in 0..<100 {
                let encrypted = cryptoManager.encrypt(testText, sessionToken: testSessionToken)
                _ = cryptoManager.decrypt(encrypted!, sessionToken: testSessionToken)
            }
        }
    }
    
    func testConcurrentEncryption() {
        // Given
        let testText = "Concurrent encryption test"
        let expectation = self.expectation(description: "Concurrent encryption")
        expectation.expectedFulfillmentCount = 5
        var results: [String?] = []
        let resultsQueue = DispatchQueue(label: "results")
        
        // When
        for i in 1...5 {
            DispatchQueue.global().async {
                let text = "\(testText)-\(i)"
                let encrypted = self.cryptoManager.encrypt(text, sessionToken: self.testSessionToken)
                let decrypted = self.cryptoManager.decrypt(encrypted!, sessionToken: self.testSessionToken)
                
                resultsQueue.async {
                    results.append(decrypted)
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        waitForExpectations(timeout: 5.0) { _ in
            XCTAssertEqual(5, results.count, "모든 스레드가 완료되어야 함")
            results.forEach { result in
                XCTAssertNotNil(result, "모든 결과가 성공해야 함")
                XCTAssertTrue(result!.contains("Concurrent encryption test"), "결과가 예상 텍스트를 포함해야 함")
            }
        }
    }
    
    func testIsEncryptedHeuristic() {
        // Given
        let plainText = "This is plain text"
        let encrypted = cryptoManager.encrypt(plainText, sessionToken: testSessionToken)
        let notBase64 = "This is definitely not base64!"
        
        // When & Then
        XCTAssertTrue(cryptoManager.isEncrypted(encrypted!), "암호화된 데이터는 암호화된 것으로 인식되어야 함")
        XCTAssertFalse(cryptoManager.isEncrypted(plainText), "평문은 암호화되지 않은 것으로 인식되어야 함")
        XCTAssertFalse(cryptoManager.isEncrypted(notBase64), "Base64가 아닌 텍스트는 암호화되지 않은 것으로 인식되어야 함")
    }
}
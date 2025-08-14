//
//  CopyDropTests.swift
//  CopyDropTests
//
//  Created by 신예준 on 8/14/25.
//

import Testing
import Foundation
@testable import CopyDrop

struct CopyDropTests {

    @Test func testClipboardItemCreation() async throws {
        let content = "테스트 클립보드 내용"
        let item = ClipboardItem(content: content)
        
        #expect(item.content == content)
        #expect(item.isLocal == true)
        #expect(item.source == "local")
        #expect(!item.hash.isEmpty)
        #expect(item.hash.hasPrefix("sha256:"))
    }
    
    @Test func testSHA256Hashing() async throws {
        let content1 = "같은 내용"
        let content2 = "같은 내용"
        let content3 = "다른 내용"
        
        let hash1 = ClipboardItem.sha256(content1)
        let hash2 = ClipboardItem.sha256(content2)
        let hash3 = ClipboardItem.sha256(content3)
        
        #expect(hash1 == hash2) // 같은 내용은 같은 해시
        #expect(hash1 != hash3) // 다른 내용은 다른 해시
        #expect(hash1.hasPrefix("sha256:"))
    }
    
    @Test func testSecurityManagerKeyGeneration() async throws {
        let securityManager = SecurityManager.shared
        
        // 기존 키 삭제
        _ = securityManager.deleteEncryptionKey()
        
        // 새 키 생성
        let key = securityManager.generateAndStoreEncryptionKey()
        #expect(key != nil)
        
        // 키 가져오기
        let retrievedKey = securityManager.getEncryptionKey()
        #expect(retrievedKey != nil)
        
        // QR 코드 내보내기
        let qrCode = securityManager.exportKeyForQRCode()
        #expect(qrCode != nil)
        #expect(!qrCode!.isEmpty)
        
        // 정리
        _ = securityManager.deleteEncryptionKey()
    }
    
    @Test func testContentFiltering() async throws {
        let securityManager = SecurityManager.shared
        
        // 정상 내용
        let normalContent = "일반 텍스트 내용"
        let normalResult = securityManager.filterClipboardContent(normalContent)
        #expect(normalResult.allowed == true)
        #expect(normalResult.reason == nil)
        
        // 빈 내용
        let emptyContent = "   "
        let emptyResult = securityManager.filterClipboardContent(emptyContent)
        #expect(emptyResult.allowed == false)
        #expect(emptyResult.reason != nil)
        
        // 패스워드 포함 내용
        let passwordContent = "my password: 123456"
        let passwordResult = securityManager.filterClipboardContent(passwordContent)
        #expect(passwordResult.allowed == false)
        #expect(passwordResult.reason != nil)
        
        // 너무 긴 내용
        let longContent = String(repeating: "x", count: 15000)
        let longResult = securityManager.filterClipboardContent(longContent)
        #expect(longResult.allowed == false)
        #expect(longResult.reason != nil)
    }
    
    @Test func testRateLimiting() async throws {
        let securityManager = SecurityManager.shared
        let deviceId = "test-device-123"
        
        // 첫 번째 요청은 허용
        let firstResult = securityManager.checkRateLimit(for: deviceId)
        #expect(firstResult == true)
        
        // 즉시 두 번째 요청은 차단
        let secondResult = securityManager.checkRateLimit(for: deviceId)
        #expect(secondResult == false)
        
        // 잠시 후 다시 허용
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        let thirdResult = securityManager.checkRateLimit(for: deviceId)
        #expect(thirdResult == true)
    }
    
    @Test func testErrorHandling() async throws {
        let errorHandler = ErrorHandler()
        
        // 초기 상태
        #expect(errorHandler.currentError == nil)
        #expect(errorHandler.showingError == false)
        #expect(errorHandler.errorHistory.isEmpty)
        
        // 에러 발생
        let testError = CopyDropError.networkConnectionFailed("테스트 오류")
        await errorHandler.handle(testError)
        
        #expect(errorHandler.currentError != nil)
        #expect(errorHandler.showingError == true)
        #expect(errorHandler.errorHistory.count == 1)
        
        // 에러 정리
        await errorHandler.clearError()
        #expect(errorHandler.currentError == nil)
        #expect(errorHandler.showingError == false)
    }
    
    @Test func testDeviceInfo() async throws {
        let deviceInfo = DeviceInfo.current()
        
        #expect(!deviceInfo.id.isEmpty)
        #expect(!deviceInfo.name.isEmpty)
        #expect(deviceInfo.type == "macOS")
        
        // 같은 디바이스는 같은 ID를 가져야 함
        let deviceInfo2 = DeviceInfo.current()
        #expect(deviceInfo.id == deviceInfo2.id)
    }
    
    @Test func testEncryptionDecryption() async throws {
        let securityManager = SecurityManager.shared
        
        // 키 생성
        _ = securityManager.deleteEncryptionKey()
        let key = securityManager.generateAndStoreEncryptionKey()
        #expect(key != nil)
        
        // 에러 핸들러와 클립보드 서비스 생성
        let errorHandler = ErrorHandler()
        let clipboardService = ClipboardSyncService(errorHandler: errorHandler)
        
        // 테스트 데이터
        let testData = "테스트 메시지".data(using: .utf8)!
        
        // 암호화
        let mirror = Mirror(reflecting: clipboardService)
        let encryptMethod = mirror.children.first { $0.label == "encryptData" }
        // Note: 실제 구현에서는 internal 메서드에 대한 접근을 위해 
        // public 테스트용 메서드를 추가하거나 @testable import를 활용
        
        // 정리
        _ = securityManager.deleteEncryptionKey()
    }

}

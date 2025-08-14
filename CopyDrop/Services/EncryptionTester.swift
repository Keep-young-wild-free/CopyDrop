//
//  EncryptionTester.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import CryptoKit

/// 암호화 시스템 테스트 도구
@MainActor
@Observable
class EncryptionTester {
    var testResults: [TestResult] = []
    var isRunning: Bool = false
    
    private let logger = Logger.shared
    
    struct TestResult {
        let testName: String
        let success: Bool
        let message: String
        let timestamp: Date
        
        init(_ testName: String, success: Bool, message: String) {
            self.testName = testName
            self.success = success
            self.message = message
            self.timestamp = Date()
        }
    }
    
    func runAllTests() async {
        guard !isRunning else { return }
        
        isRunning = true
        testResults.removeAll()
        logger.logSecurity("암호화 시스템 테스트 시작")
        
        await testKeyGeneration()
        await testKeyStorage()
        await testEncryptionDecryption()
        await testContentFiltering()
        await testQRCodeExport()
        
        isRunning = false
        logger.logSecurity("암호화 시스템 테스트 완료: \(testResults.filter(\.success).count)/\(testResults.count) 성공")
    }
    
    private func testKeyGeneration() async {
        logger.logSecurity("키 생성 테스트 시작")
        
        // 기존 키 삭제
        _ = SecurityManager.shared.deleteEncryptionKey()
        
        // 새 키 생성
        let key = SecurityManager.shared.generateAndStoreEncryptionKey()
        
        if let key = key {
            testResults.append(TestResult("키 생성", success: true, message: "32바이트 AES 키 생성 성공"))
        } else {
            testResults.append(TestResult("키 생성", success: false, message: "키 생성 실패"))
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초 대기
    }
    
    private func testKeyStorage() async {
        logger.logSecurity("키 저장/불러오기 테스트 시작")
        
        // 키체인에서 키 가져오기
        let retrievedKey = SecurityManager.shared.getEncryptionKey()
        
        if retrievedKey != nil {
            testResults.append(TestResult("키 저장/불러오기", success: true, message: "키체인에서 키 불러오기 성공"))
        } else {
            testResults.append(TestResult("키 저장/불러오기", success: false, message: "키체인에서 키 불러오기 실패"))
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    private func testEncryptionDecryption() async {
        logger.logSecurity("암호화/복호화 테스트 시작")
        
        let testData = "🔐 암호화 테스트 데이터 - 한글과 이모지 포함 🚀".data(using: .utf8)!
        
        // 임시 암호화 서비스 생성
        let errorHandler = ErrorHandler()
        let clipboardService = ClipboardSyncService(errorHandler: errorHandler)
        
        // 암호화
        let encryptedData = clipboardService.testEncryptData(testData)
        if encryptedData != nil {
            testResults.append(TestResult("데이터 암호화", success: true, message: "테스트 데이터 암호화 성공 (\(encryptedData!.count) bytes)"))
        } else {
            testResults.append(TestResult("데이터 암호화", success: false, message: "테스트 데이터 암호화 실패"))
            return
        }
        
        // 복호화
        let decryptedData = clipboardService.testDecryptData(encryptedData!)
        if let decryptedData = decryptedData,
           let decryptedString = String(data: decryptedData, encoding: .utf8),
           decryptedString == "🔐 암호화 테스트 데이터 - 한글과 이모지 포함 🚀" {
            testResults.append(TestResult("데이터 복호화", success: true, message: "테스트 데이터 복호화 성공: \(decryptedString.prefix(30))..."))
        } else {
            testResults.append(TestResult("데이터 복호화", success: false, message: "테스트 데이터 복호화 실패 또는 내용 불일치"))
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    private func testContentFiltering() async {
        logger.logSecurity("내용 필터링 테스트 시작")
        
        let testCases = [
            ("정상 텍스트", "안녕하세요 CopyDrop입니다!", true),
            ("패스워드 포함", "my password: 123456", false),
            ("신용카드 번호", "1234 5678 9012 3456", false),
            ("빈 내용", "   ", false),
            ("너무 긴 내용", String(repeating: "x", count: 15000), false)
        ]
        
        var passedTests = 0
        
        for (testName, content, shouldPass) in testCases {
            let result = SecurityManager.shared.filterClipboardContent(content)
            
            if result.allowed == shouldPass {
                passedTests += 1
                logger.logSecurity("✅ \(testName): 예상대로 \(shouldPass ? "허용" : "차단")")
            } else {
                logger.logSecurity("❌ \(testName): 예상과 다름 - 예상: \(shouldPass), 실제: \(result.allowed)")
            }
        }
        
        testResults.append(TestResult("내용 필터링", 
                                    success: passedTests == testCases.count, 
                                    message: "\(passedTests)/\(testCases.count) 필터링 테스트 통과"))
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    private func testQRCodeExport() async {
        logger.logSecurity("QR 코드 내보내기 테스트 시작")
        
        let qrKey = SecurityManager.shared.exportKeyForQRCode()
        
        if let qrKey = qrKey, !qrKey.isEmpty {
            // Base64 디코딩 테스트
            if let keyData = Data(base64Encoded: qrKey), keyData.count == 32 {
                testResults.append(TestResult("QR 코드 내보내기", success: true, message: "Base64 키 내보내기 성공 (32 bytes)"))
            } else {
                testResults.append(TestResult("QR 코드 내보내기", success: false, message: "Base64 키 형식 오류"))
            }
        } else {
            testResults.append(TestResult("QR 코드 내보내기", success: false, message: "QR 코드 키 내보내기 실패"))
        }
        
        try? await Task.sleep(nanoseconds: 100_000_000)
    }
    
    func clearResults() {
        testResults.removeAll()
    }
}

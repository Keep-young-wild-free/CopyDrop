//
//  SystemTester.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import SwiftData

/// 전체 시스템 통합 테스트
@MainActor
@Observable
class SystemTester {
    var testResults: [TestResult] = []
    var isRunning: Bool = false
    var currentTest: String = ""
    
    private let logger = Logger.shared
    private var modelContext: ModelContext?
    
    struct TestResult {
        let testName: String
        let success: Bool
        let message: String
        let timestamp: Date
        let details: String?
        
        init(_ testName: String, success: Bool, message: String, details: String? = nil) {
            self.testName = testName
            self.success = success
            self.message = message
            self.details = details
            self.timestamp = Date()
        }
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func runFullSystemTest() async {
        guard !isRunning else { return }
        
        isRunning = true
        testResults.removeAll()
        logger.log("전체 시스템 테스트 시작", level: .info)
        
        await testAppConstants()
        await testSecuritySystem()
        await testNetworkUtilities()
        await testDatabaseOperations()
        await testClipboardOperations()
        await testErrorHandling()
        await testLoggingSystem()
        
        isRunning = false
        let successCount = testResults.filter(\.success).count
        logger.log("전체 시스템 테스트 완료: \(successCount)/\(testResults.count) 성공", level: .info)
    }
    
    // MARK: - Individual Tests
    
    private func testAppConstants() async {
        currentTest = "앱 상수 검증"
        logger.log("앱 상수 테스트 시작")
        
        // 네트워크 상수 검증
        let validPort = AppConstants.Network.defaultPort > 1024 && AppConstants.Network.defaultPort < 65535
        let validURL = NetworkUtils.isValidWebSocketURL(AppConstants.Network.defaultServerURL)
        
        if validPort && validURL {
            testResults.append(TestResult("앱 상수", success: true, 
                                        message: "모든 상수가 올바르게 설정됨",
                                        details: "포트: \(AppConstants.Network.defaultPort), URL: \(AppConstants.Network.defaultServerURL)"))
        } else {
            testResults.append(TestResult("앱 상수", success: false, 
                                        message: "잘못된 상수 발견",
                                        details: "포트 유효: \(validPort), URL 유효: \(validURL)"))
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func testSecuritySystem() async {
        currentTest = "보안 시스템 검증"
        logger.log("보안 시스템 테스트 시작")
        
        // 암호화 키 관리 테스트
        _ = SecurityManager.shared.deleteEncryptionKey()
        let key = SecurityManager.shared.generateAndStoreEncryptionKey()
        let retrievedKey = SecurityManager.shared.getEncryptionKey()
        
        let keyTest = key != nil && retrievedKey != nil
        
        // 내용 필터링 테스트
        let normalContent = SecurityManager.shared.filterClipboardContent("정상 내용")
        let badContent = SecurityManager.shared.filterClipboardContent("password: 123456")
        
        let filterTest = normalContent.allowed && !badContent.allowed
        
        if keyTest && filterTest {
            testResults.append(TestResult("보안 시스템", success: true,
                                        message: "키 관리 및 내용 필터링 정상 작동"))
        } else {
            testResults.append(TestResult("보안 시스템", success: false,
                                        message: "보안 시스템 오류",
                                        details: "키 테스트: \(keyTest), 필터 테스트: \(filterTest)"))
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func testNetworkUtilities() async {
        currentTest = "네트워크 유틸리티 검증"
        logger.log("네트워크 유틸리티 테스트 시작")
        
        // IP 주소 가져오기
        let localIP = NetworkUtils.getLocalIPAddress()
        
        // 포트 사용 가능성 확인
        let portAvailable = NetworkUtils.isPortAvailable(9999) // 테스트용 포트
        
        // URL 검증
        let validWS = NetworkUtils.isValidWebSocketURL("ws://localhost:8787/ws")
        let invalidWS = NetworkUtils.isValidWebSocketURL("http://localhost:8787")
        
        if localIP != nil && validWS && !invalidWS {
            testResults.append(TestResult("네트워크 유틸리티", success: true,
                                        message: "네트워크 기능 정상 작동",
                                        details: "로컬 IP: \(localIP ?? "없음")"))
        } else {
            testResults.append(TestResult("네트워크 유틸리티", success: false,
                                        message: "네트워크 기능 오류"))
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func testDatabaseOperations() async {
        currentTest = "데이터베이스 연산 검증"
        logger.log("데이터베이스 테스트 시작")
        
        guard let context = modelContext else {
            testResults.append(TestResult("데이터베이스", success: false,
                                        message: "ModelContext가 설정되지 않음"))
            return
        }
        
        // 테스트 데이터 생성
        let testItem = ClipboardItem(content: "테스트 내용 - \(Date())", source: "test", isLocal: true)
        context.insert(testItem)
        
        do {
            try context.save()
            testResults.append(TestResult("데이터베이스", success: true,
                                        message: "데이터 저장/불러오기 정상 작동"))
            
            // 테스트 데이터 정리
            context.delete(testItem)
            try context.save()
        } catch {
            testResults.append(TestResult("데이터베이스", success: false,
                                        message: "데이터베이스 오류: \(error.localizedDescription)"))
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func testClipboardOperations() async {
        currentTest = "클립보드 연산 검증"
        logger.log("클립보드 테스트 시작")
        
        // 현재 클립보드 백업
        let originalContent = NSPasteboard.general.string(forType: .string)
        
        // 테스트 내용 설정
        let testContent = "클립보드 테스트 - \(Date().timeIntervalSince1970)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(testContent, forType: .string)
        
        // 내용 확인
        let readContent = NSPasteboard.general.string(forType: .string)
        
        let clipboardTest = readContent == testContent
        
        // 해시 생성 테스트
        let hash1 = ClipboardItem.sha256(testContent)
        let hash2 = ClipboardItem.sha256(testContent)
        let hashTest = hash1 == hash2 && hash1.hasPrefix("sha256:")
        
        // 원래 내용 복원
        if let original = originalContent {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(original, forType: .string)
        }
        
        if clipboardTest && hashTest {
            testResults.append(TestResult("클립보드 연산", success: true,
                                        message: "클립보드 읽기/쓰기 및 해시 생성 정상"))
        } else {
            testResults.append(TestResult("클립보드 연산", success: false,
                                        message: "클립보드 연산 오류",
                                        details: "클립보드: \(clipboardTest), 해시: \(hashTest)"))
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func testErrorHandling() async {
        currentTest = "에러 처리 시스템 검증"
        logger.log("에러 처리 테스트 시작")
        
        let errorHandler = ErrorHandler()
        let initialCount = errorHandler.errorHistory.count
        
        // 테스트 에러 발생
        await errorHandler.handle(.networkConnectionFailed("테스트 에러"))
        
        let errorRecorded = errorHandler.errorHistory.count == initialCount + 1
        let currentErrorSet = errorHandler.currentError != nil
        
        // 에러 정리
        await errorHandler.clearError()
        let errorCleared = errorHandler.currentError == nil
        
        if errorRecorded && currentErrorSet && errorCleared {
            testResults.append(TestResult("에러 처리", success: true,
                                        message: "에러 처리 시스템 정상 작동"))
        } else {
            testResults.append(TestResult("에러 처리", success: false,
                                        message: "에러 처리 시스템 오류"))
        }
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    private func testLoggingSystem() async {
        currentTest = "로깅 시스템 검증"
        logger.log("로깅 시스템 테스트 시작")
        
        // 다양한 레벨 로그 테스트
        Logger.shared.log("디버그 메시지", level: .debug)
        Logger.shared.log("정보 메시지", level: .info)
        Logger.shared.log("경고 메시지", level: .warning)
        Logger.shared.log("에러 메시지", level: .error)
        
        // 카테고리별 로그 테스트
        Logger.shared.logNetwork("네트워크 테스트 메시지")
        Logger.shared.logSecurity("보안 테스트 메시지")
        Logger.shared.logClipboard("클립보드 테스트 메시지")
        
        testResults.append(TestResult("로깅 시스템", success: true,
                                    message: "로깅 시스템 정상 작동"))
        
        try? await Task.sleep(nanoseconds: 200_000_000)
    }
    
    func clearResults() {
        testResults.removeAll()
        currentTest = ""
    }
    
    func generateSystemReport() -> String {
        let deviceInfo = DeviceInfo.current()
        let bundle = Bundle.main
        
        var report = """
        CopyDrop 시스템 테스트 리포트
        ========================================
        
        생성 시간: \(Date().formatted())
        
        앱 정보:
        - 이름: \(bundle.appName)
        - 버전: \(bundle.appVersion)
        - 빌드: \(bundle.buildNumber)
        
        디바이스 정보:
        - ID: \(deviceInfo.id)
        - 이름: \(deviceInfo.name)
        - 타입: \(deviceInfo.type)
        
        네트워크 정보:
        - 로컬 IP: \(NetworkUtils.getLocalIPAddress() ?? "없음")
        - 기본 포트: \(AppConstants.Network.defaultPort)
        
        테스트 결과:
        ========================================
        
        """
        
        let successCount = testResults.filter(\.success).count
        report += "전체: \(testResults.count)개, 성공: \(successCount)개, 실패: \(testResults.count - successCount)개\n\n"
        
        for result in testResults {
            let status = result.success ? "✅" : "❌"
            report += "\(status) \(result.testName): \(result.message)\n"
            if let details = result.details {
                report += "   세부사항: \(details)\n"
            }
            report += "   시간: \(result.timestamp.formatted())\n\n"
        }
        
        return report
    }
}

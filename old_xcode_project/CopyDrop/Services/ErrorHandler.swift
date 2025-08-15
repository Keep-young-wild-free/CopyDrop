//
//  ErrorHandler.swift
//  CopyDrop
//
//  Created by 신예준 on 8/14/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Error Types
enum CopyDropError: LocalizedError {
    case networkConnectionFailed(String)
    case encryptionFailed
    case decryptionFailed
    case invalidKey
    case keychainError(String)
    case serverStartFailed(String)
    case clipboardAccessDenied
    case contentFiltered(String)
    case rateLimitExceeded
    case invalidMessage
    case deviceNotTrusted
    
    var errorDescription: String? {
        switch self {
        case .networkConnectionFailed(let details):
            return "네트워크 연결 실패: \(details)"
        case .encryptionFailed:
            return "데이터 암호화에 실패했습니다"
        case .decryptionFailed:
            return "데이터 복호화에 실패했습니다"
        case .invalidKey:
            return "올바르지 않은 암호화 키입니다"
        case .keychainError(let details):
            return "키체인 오류: \(details)"
        case .serverStartFailed(let details):
            return "서버 시작 실패: \(details)"
        case .clipboardAccessDenied:
            return "클립보드 접근 권한이 필요합니다"
        case .contentFiltered(let reason):
            return "내용이 필터링되었습니다: \(reason)"
        case .rateLimitExceeded:
            return "너무 많은 요청이 발생했습니다"
        case .invalidMessage:
            return "올바르지 않은 메시지 형식입니다"
        case .deviceNotTrusted:
            return "신뢰되지 않은 디바이스입니다"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkConnectionFailed:
            return "네트워크 연결 상태를 확인하고 다시 시도해주세요."
        case .encryptionFailed, .decryptionFailed:
            return "암호화 키를 다시 생성하거나 확인해주세요."
        case .invalidKey:
            return "새로운 암호화 키를 생성해주세요."
        case .keychainError:
            return "시스템을 재시작하거나 키체인 접근을 허용해주세요."
        case .serverStartFailed:
            return "다른 포트를 사용하거나 방화벽 설정을 확인해주세요."
        case .clipboardAccessDenied:
            return "시스템 환경설정에서 클립보드 접근 권한을 허용해주세요."
        case .contentFiltered:
            return "다른 내용으로 다시 시도해주세요."
        case .rateLimitExceeded:
            return "잠시 후에 다시 시도해주세요."
        case .invalidMessage:
            return "데이터를 다시 전송해주세요."
        case .deviceNotTrusted:
            return "디바이스 인증을 다시 진행해주세요."
        }
    }
}

// MARK: - Error Log Entry
struct ErrorLogEntry: Identifiable {
    let id = UUID()
    let error: CopyDropError
    let timestamp: Date
    let context: String?
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: timestamp)
    }
}

// MARK: - Error Handler
@MainActor
@Observable
class ErrorHandler {
    var currentError: CopyDropError?
    var showingError = false
    var errorHistory: [ErrorLogEntry] = []
    
    func handle(_ error: CopyDropError) {
        Logger.shared.log("오류 발생: \(error.localizedDescription)", level: LogLevel.error)
        
        currentError = error
        showingError = true
        
        // 에러 히스토리에 추가
        let entry = ErrorLogEntry(
            error: error,
            timestamp: Date(),
            context: getCurrentContext()
        )
        errorHistory.append(entry)
        
        // 최대 개수 유지
        if errorHistory.count > AppConstants.Storage.maxErrorLogEntries {
            errorHistory.removeFirst(errorHistory.count - AppConstants.Storage.maxErrorLogEntries)
        }
        
        // 자동 복구 시도
        attemptAutoRecovery(for: error)
    }
    
    func clearError() {
        currentError = nil
        showingError = false
    }
    
    func clearErrorHistory() {
        errorHistory.removeAll()
    }
    
    func exportErrorLog() -> String {
        var logContent = "CopyDrop Error Log\n"
        logContent += "Generated: \(Date())\n"
        logContent += "Total Errors: \(errorHistory.count)\n"
        logContent += "\n" + String(repeating: "=", count: 50) + "\n\n"
        
        for entry in errorHistory.reversed() {
            logContent += "[\(entry.formattedTimestamp)]\n"
            logContent += "Error: \(entry.error.localizedDescription)\n"
            if let context = entry.context {
                logContent += "Context: \(context)\n"
            }
            if let recovery = entry.error.recoverySuggestion {
                logContent += "Suggested Fix: \(recovery)\n"
            }
            logContent += "\n" + String(repeating: "-", count: 30) + "\n\n"
        }
        
        return logContent
    }
    
    private func getCurrentContext() -> String? {
        // 현재 실행 중인 작업이나 상태에 대한 컨텍스트 정보 수집
        // 예: 현재 동기화 상태, 연결된 디바이스 수 등
        return "앱 실행 중"
    }
    
    private func attemptAutoRecovery(for error: CopyDropError) {
        switch error {
        case .networkConnectionFailed:
            // 자동 재연결 시도는 SyncManager에서 처리
            break
        case .invalidKey:
            // 새로운 키 생성은 사용자 확인 후 진행
            break
        case .rateLimitExceeded:
            // 일정 시간 후 자동으로 해제됨
            break
        default:
            // 다른 오류들은 수동 해결 필요
            break
        }
    }
}
